/**
 * @file scanner.ts
 * @notice ArbitrageScanner — the core engine of the bot.
 *
 * On every new block:
 *   1. Fetch gas price
 *   2. For each configured token pair, query on-chain spread via PriceOraclePolygon
 *   3. Estimate net profit after gas
 *   4. If profit > MIN_PROFIT_USD and gas < MAX_GAS_GWEI, enqueue execution
 *   5. Execute via FlashLoanSecure.initiateFlashLoan
 *
 * Risk management:
 *   • Skip execution when gas exceeds MAX_GAS_GWEI
 *   • Track dailyPnL; halt if drawdown > MAX_DAILY_LOSS_USD
 *   • Retry failed transactions up to MAX_RETRIES times with exponential back-off
 */

import {
  ethers,
  Contract,
  WebSocketProvider,
  JsonRpcProvider,
  Wallet,
  parseUnits,
  formatUnits,
} from "ethers";
import {
  ENV,
  TOKEN_PAIRS,
  TokenPair,
  MIN_PROFIT_USD,
  MAX_GAS_GWEI,
  MAX_DAILY_LOSS_USD,
  ESTIMATED_GAS_UNITS,
  MAX_RETRIES,
  RETRY_BASE_DELAY_MS,
  FLASH_LOAN_ABI,
  PRICE_ORACLE_ABI,
} from "./config";
import { logInfo, logWarn, logError, logDebug } from "./logger";

// ─────────────────────────────────────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────────────────────────────────────

interface ArbitrageOpportunity {
  pair:       TokenPair;
  spread:     bigint;
  cheaperDex: string;
  expensiveDex: string;
  estimatedProfitUsd: number;
  gasPrice:   bigint;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** Convert a raw bigint price (18 decimals) to USD using a rough MATIC/USD rate.
 *  In production replace with a proper price feed. */
function spreadToUsd(spread: bigint, decimals: number, tokenPriceUsd: number): number {
  const floatSpread = Number(formatUnits(spread, decimals));
  return floatSpread * tokenPriceUsd;
}

/** Estimate gas cost in USD */
function estimateGasCostUsd(
  gasPrice: bigint,  // in wei
  gasUnits: number,
  maticPriceUsd: number
): number {
  const gasCostMatic = Number(formatUnits(gasPrice * BigInt(gasUnits), 18));
  return gasCostMatic * maticPriceUsd;
}

// ─────────────────────────────────────────────────────────────────────────────
// ArbitrageScanner
// ─────────────────────────────────────────────────────────────────────────────

export class ArbitrageScanner {
  private wsProvider:        WebSocketProvider | null = null;
  private httpProvider:      JsonRpcProvider;
  private wallet:            Wallet;
  private flashLoanContract: Contract;
  private priceOracle:       Contract;

  /** Accumulated PnL for today in USD (negative = loss) */
  private dailyPnLUsd = 0;
  /** UTC day string at which dailyPnL was reset (YYYY-MM-DD) */
  private dailyPnLDate = "";

  /** True while an execution is in-flight (prevents concurrent submissions) */
  private executing = false;

  /** Whether the scanner is running */
  private running = false;

  constructor() {
    this.httpProvider = new JsonRpcProvider(ENV.POLYGON_RPC_URL);
    this.wallet       = new Wallet(ENV.PRIVATE_KEY, this.httpProvider);

    this.flashLoanContract = new Contract(
      ENV.FLASH_LOAN_ADDRESS,
      FLASH_LOAN_ABI,
      this.wallet
    );

    this.priceOracle = new Contract(
      ENV.PRICE_ORACLE_ADDRESS,
      PRICE_ORACLE_ABI,
      this.httpProvider
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ──────────────────────────────────────────────────────────────────────────

  /**
   * @notice Start the scanner. Subscribes to new blocks via WebSocket;
   *         falls back to polling if WS is unavailable.
   */
  async start(): Promise<void> {
    this.running = true;
    logInfo("ArbitrageScanner starting…", {
      account:    this.wallet.address,
      flashLoan:  ENV.FLASH_LOAN_ADDRESS,
      oracle:     ENV.PRICE_ORACLE_ADDRESS,
    });

    try {
      this.wsProvider = new WebSocketProvider(ENV.POLYGON_WS_URL);

      this.wsProvider.on("block", async (blockNumber: number) => {
        if (!this.running) return;
        await this.onBlock(blockNumber).catch((err) =>
          logError("onBlock error", err, { blockNumber })
        );
      });

      logInfo("WebSocket subscription established.");
    } catch (err) {
      logWarn("WebSocket unavailable — falling back to polling.", { err });
      this._startPolling();
    }
  }

  /**
   * @notice Stop the scanner gracefully.
   */
  async stop(): Promise<void> {
    this.running = false;
    if (this.wsProvider) {
      await this.wsProvider.destroy();
    }
    logInfo("ArbitrageScanner stopped.");
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Block handler
  // ──────────────────────────────────────────────────────────────────────────

  /**
   * @notice Invoked on each new block. Scans all token pairs and enqueues
   *         profitable opportunities.
   * @param blockNumber  Current block height.
   */
  async onBlock(blockNumber: number): Promise<void> {
    logDebug("New block", { blockNumber });

    this._resetDailyPnLIfNeeded();

    // Halt if drawdown exceeded
    if (this.dailyPnLUsd < -MAX_DAILY_LOSS_USD) {
      logWarn("Daily loss limit reached — scanner halted for the day.", {
        dailyPnLUsd: this.dailyPnLUsd,
        limit:       MAX_DAILY_LOSS_USD,
      });
      return;
    }

    // Don't pile up opportunities if already executing
    if (this.executing) {
      logDebug("Execution in-flight — skipping block scan.", { blockNumber });
      return;
    }

    const gasPrice = await this._fetchGasPrice();
    const gasPriceGwei = Number(formatUnits(gasPrice, "gwei"));

    if (gasPriceGwei > MAX_GAS_GWEI) {
      logWarn("Gas price too high — skipping block.", {
        gasPriceGwei,
        maxGwei: MAX_GAS_GWEI,
      });
      return;
    }

    // Rough MATIC price in USD (production: use Chainlink feed)
    const maticPriceUsd = await this._getMaticPriceUsd();

    for (const pair of TOKEN_PAIRS) {
      try {
        const opportunity = await this._evaluatePair(pair, gasPrice, maticPriceUsd);
        if (opportunity) {
          logInfo("Opportunity found!", {
            pair:                pair.name,
            estimatedProfitUsd:  opportunity.estimatedProfitUsd.toFixed(2),
            cheaperDex:          opportunity.cheaperDex,
            expensiveDex:        opportunity.expensiveDex,
            gasPriceGwei:        gasPriceGwei.toFixed(2),
          });
          await this.executeArbitrage(opportunity);
          break; // execute one opportunity per block to avoid nonce conflicts
        }
      } catch (err) {
        logError(`Failed evaluating pair ${pair.name}`, err);
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Opportunity evaluation
  // ──────────────────────────────────────────────────────────────────────────

  /**
   * @notice Query the on-chain oracle for the arbitrage spread and estimate
   *         net profit after gas costs.
   * @returns ArbitrageOpportunity if profitable, null otherwise.
   */
  private async _evaluatePair(
    pair: TokenPair,
    gasPrice: bigint,
    maticPriceUsd: number
  ): Promise<ArbitrageOpportunity | null> {
    const [spread, cheaperDex, expensiveDex]: [bigint, string, string] =
      await this.priceOracle.getArbitrageSpread(
        pair.tokenIn,
        pair.tokenOut,
        pair.loanAmount
      );

    if (spread === 0n) return null;

    // Determine token decimals (simplified: USDC=6, others=18)
    const outDecimals = pair.tokenOut.toLowerCase() === "0x2791bca1f2de4661ed88a30c99a7a9449aa84174"
      ? 6
      : 18;

    // Use maticPriceUsd as an approximation for tokenOut price
    // In production, look up each token's USD price from Chainlink
    const spreadUsd   = spreadToUsd(spread, outDecimals, maticPriceUsd);
    const gasCostUsd  = estimateGasCostUsd(gasPrice, ESTIMATED_GAS_UNITS, maticPriceUsd);

    // Aave fee ≈ 0.05% of loan amount
    const aaveFeeUsd  = (Number(formatUnits(pair.loanAmount, 18)) * maticPriceUsd) * 0.0005;

    const estimatedProfitUsd = spreadUsd - gasCostUsd - aaveFeeUsd;

    logDebug("Pair evaluated", {
      pair:              pair.name,
      spreadUsd:         spreadUsd.toFixed(4),
      gasCostUsd:        gasCostUsd.toFixed(4),
      aaveFeeUsd:        aaveFeeUsd.toFixed(4),
      estimatedProfitUsd: estimatedProfitUsd.toFixed(4),
    });

    if (estimatedProfitUsd < MIN_PROFIT_USD) return null;

    return { pair, spread, cheaperDex, expensiveDex, estimatedProfitUsd, gasPrice };
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Execution
  // ──────────────────────────────────────────────────────────────────────────

  /**
   * @notice Encode the arbitrage params and submit the flash loan transaction.
   *         Retries up to MAX_RETRIES times with exponential back-off.
   * @param opportunity  Qualified arbitrage opportunity.
   */
  async executeArbitrage(opportunity: ArbitrageOpportunity): Promise<void> {
    this.executing = true;
    const { pair, cheaperDex, expensiveDex, estimatedProfitUsd, gasPrice } = opportunity;

    // minProfit expressed in tokenIn native decimals (10% haircut on estimate)
    // Using a haircut to account for on-chain slippage vs. static oracle prices
    const minProfitNative = (pair.loanAmount * 5n) / 10_000n; // 0.05% of loan amount

    const params = ethers.AbiCoder.defaultAbiCoder().encode(
      ["address", "address", "address", "address", "uint256"],
      [pair.tokenIn, pair.tokenOut, cheaperDex, expensiveDex, minProfitNative]
    );

    let attempt = 0;
    while (attempt <= MAX_RETRIES) {
      try {
        logInfo(`Submitting flash loan (attempt ${attempt + 1}/${MAX_RETRIES + 1})`, {
          pair:       pair.name,
          loanAmount: formatUnits(pair.loanAmount, 18),
          cheaperDex,
          expensiveDex,
          gasPriceGwei: Number(formatUnits(gasPrice, "gwei")).toFixed(2),
        });

        const tx = await this.flashLoanContract.initiateFlashLoan(
          pair.tokenIn,
          pair.loanAmount,
          params,
          {
            gasPrice,
            gasLimit: BigInt(ESTIMATED_GAS_UNITS) + 100_000n, // headroom
          }
        );

        logInfo("Transaction submitted", { txHash: tx.hash });

        const receipt = await tx.wait(1); // wait for 1 confirmation

        if (receipt?.status === 1) {
          logInfo("✅ Arbitrage succeeded!", {
            txHash:             receipt.hash,
            gasUsed:            receipt.gasUsed.toString(),
            estimatedProfitUsd: estimatedProfitUsd.toFixed(2),
          });
          // Optimistically credit PnL (actual profit logged from on-chain event)
          this.dailyPnLUsd += estimatedProfitUsd;
        } else {
          logError("Transaction reverted", undefined, { txHash: receipt?.hash });
          this.dailyPnLUsd -= estimatedProfitUsd * 0.1; // gas cost of failed tx
        }

        break; // success or revert — stop retrying

      } catch (err: unknown) {
        const isTransient = _isTransientError(err);
        if (!isTransient || attempt >= MAX_RETRIES) {
          logError("Flash loan execution failed permanently", err, { pair: pair.name, attempt });
          break;
        }
        const backoff = RETRY_BASE_DELAY_MS * 2 ** attempt;
        logWarn(`Transient error — retrying in ${backoff}ms`, { attempt, error: String(err) });
        await sleep(backoff);
        attempt++;
      }
    }

    this.executing = false;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Internal helpers
  // ──────────────────────────────────────────────────────────────────────────

  private async _fetchGasPrice(): Promise<bigint> {
    const feeData = await this.httpProvider.getFeeData();
    return feeData.gasPrice ?? parseUnits("50", "gwei");
  }

  /** Approximate MATIC/USD using a simple HTTP call to a public endpoint.
   *  In production wire this to your Chainlink feed. */
  private async _getMaticPriceUsd(): Promise<number> {
    try {
      const res = await fetch(
        "https://api.coingecko.com/api/v3/simple/price?ids=matic-network&vs_currencies=usd"
      );
      const json = (await res.json()) as { "matic-network"?: { usd?: number } };
      return json["matic-network"]?.usd ?? 0.9;
    } catch {
      return 0.9; // fallback to approximate price
    }
  }

  private _resetDailyPnLIfNeeded(): void {
    const today = new Date().toISOString().slice(0, 10);
    if (this.dailyPnLDate !== today) {
      logInfo("Resetting daily PnL tracker.", { previousDate: this.dailyPnLDate, previousPnL: this.dailyPnLUsd });
      this.dailyPnLUsd  = 0;
      this.dailyPnLDate = today;
    }
  }

  private _startPolling(): void {
    const poll = async () => {
      while (this.running) {
        try {
          const blockNumber = await this.httpProvider.getBlockNumber();
          await this.onBlock(blockNumber);
        } catch (err) {
          logError("Polling error", err);
        }
        await sleep(12_000); // ~Polygon block time
      }
    };
    poll().catch((err) => logError("Polling loop crashed", err));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error classification
// ─────────────────────────────────────────────────────────────────────────────

function _isTransientError(err: unknown): boolean {
  if (!(err instanceof Error)) return false;
  const msg = err.message.toLowerCase();
  return (
    msg.includes("network") ||
    msg.includes("timeout") ||
    msg.includes("rate limit") ||
    msg.includes("nonce too low") ||
    msg.includes("replacement fee too low")
  );
}
