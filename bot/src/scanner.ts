/**
 * @file scanner.ts
 * @notice ArbitrageScanner — core engine of the flash loan arbitrage bot.
 *
 * On every new block:
 *   1. Warm Chainlink price cache (on-chain, no CoinGecko)
 *   2. Fetch gas price
 *   3. For each configured token pair, query on-chain spread via PriceOraclePolygon
 *   4. Estimate net profit after gas + Aave fee
 *   5. If profit > MIN_PROFIT_USD and gas < MAX_GAS_GWEI, execute
 *   6. Submit tx via NonceManager to prevent nonce collisions across pairs
 *
 * Risk management:
 *   • Skip when gas > MAX_GAS_GWEI
 *   • Track dailyPnL; halt if drawdown > MAX_DAILY_LOSS_USD
 *   • Retry up to MAX_RETRIES with exponential back-off
 *   • Resync nonce on "nonce too low" errors
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
import { NonceManager }      from "./nonce-manager";
import { ChainlinkPriceFeed, TOKEN_TO_FEED, FEEDS } from "./price-feed";

// ─────────────────────────────────────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────────────────────────────────────

interface ArbitrageOpportunity {
  pair:               TokenPair;
  spread:             bigint;
  cheaperDex:         string;
  expensiveDex:       string;
  estimatedProfitUsd: number;
  gasPrice:           bigint;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function estimateGasCostUsd(
  gasPrice: bigint,
  gasUnits: number,
  maticPriceUsd: number
): number {
  return Number(formatUnits(gasPrice * BigInt(gasUnits), 18)) * maticPriceUsd;
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
  private nonceManager:      NonceManager;
  private priceFeed:         ChainlinkPriceFeed;

  private dailyPnLUsd  = 0;
  private dailyPnLDate = "";

  /** True while an execution is in-flight */
  private executing = false;
  private running   = false;

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

    this.nonceManager = new NonceManager(this.httpProvider, this.wallet.address);
    this.priceFeed    = new ChainlinkPriceFeed(this.httpProvider);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ──────────────────────────────────────────────────────────────────────────

  async start(): Promise<void> {
    this.running = true;
    logInfo("ArbitrageScanner starting…", {
      account:   this.wallet.address,
      flashLoan: ENV.FLASH_LOAN_ADDRESS,
      oracle:    ENV.PRICE_ORACLE_ADDRESS,
    });

    // Pre-warm Chainlink price cache before first block
    await this.priceFeed.warmCache().catch((e) =>
      logWarn("Price cache warm failed (will retry per-block)", { error: String(e) })
    );

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
      logWarn("WebSocket unavailable — falling back to HTTP polling.", { err });
      this._startPolling();
    }
  }

  async stop(): Promise<void> {
    this.running = false;
    if (this.wsProvider) await this.wsProvider.destroy();
    logInfo("ArbitrageScanner stopped.");
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Block handler
  // ──────────────────────────────────────────────────────────────────────────

  async onBlock(blockNumber: number): Promise<void> {
    logDebug("New block", { blockNumber });
    this._resetDailyPnLIfNeeded();

    if (this.dailyPnLUsd < -MAX_DAILY_LOSS_USD) {
      logWarn("Daily loss limit reached — scanner halted for the day.", {
        dailyPnLUsd: this.dailyPnLUsd,
        limit:       MAX_DAILY_LOSS_USD,
      });
      return;
    }

    if (this.executing) {
      logDebug("Execution in-flight — skipping block.", { blockNumber });
      return;
    }

    // Flush stale cached prices at the start of each block
    this.priceFeed.flushCache();

    const [gasPrice, maticUsd] = await Promise.all([
      this._fetchGasPrice(),
      this.priceFeed.getPrice(FEEDS.MATIC_USD, 0.9),
    ]);

    const gasPriceGwei = Number(formatUnits(gasPrice, "gwei"));
    if (gasPriceGwei > MAX_GAS_GWEI) {
      logWarn("Gas too high — skipping block.", { gasPriceGwei, maxGwei: MAX_GAS_GWEI });
      return;
    }

    for (const pair of TOKEN_PAIRS) {
      try {
        const tokenInPriceUsd = await this.priceFeed.getTokenPriceUsd(pair.tokenIn, maticUsd);
        const opportunity = await this._evaluatePair(pair, gasPrice, maticUsd, tokenInPriceUsd);
        if (opportunity) {
          logInfo("Opportunity found!", {
            pair:               pair.name,
            profitUsd:          opportunity.estimatedProfitUsd.toFixed(2),
            cheaperDex:         opportunity.cheaperDex,
            expensiveDex:       opportunity.expensiveDex,
            gasPriceGwei:       gasPriceGwei.toFixed(2),
          });
          await this.executeArbitrage(opportunity);
          break;
        }
      } catch (err) {
        logError(`Failed evaluating pair ${pair.name}`, err);
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Opportunity evaluation
  // ──────────────────────────────────────────────────────────────────────────

  private async _evaluatePair(
    pair:             TokenPair,
    gasPrice:         bigint,
    maticUsd:         number,
    tokenInPriceUsd:  number
  ): Promise<ArbitrageOpportunity | null> {
    const [spread, cheaperDex, expensiveDex]: [bigint, string, string] =
      await this.priceOracle.getArbitrageSpread(pair.tokenIn, pair.tokenOut, pair.loanAmount);

    if (spread === 0n) return null;

    // Determine tokenOut decimals (USDC = 6, everything else = 18)
    const isUsdcOut = pair.tokenOut.toLowerCase() ===
      "0x2791bca1f2de4661ed88a30c99a7a9449aa84174";
    const outDecimals = isUsdcOut ? 6 : 18;
    const tokenOutPriceUsd = isUsdcOut
      ? await this.priceFeed.getPrice(FEEDS.USDC_USD, 1.0)
      : await this.priceFeed.getTokenPriceUsd(pair.tokenOut, tokenInPriceUsd);

    const spreadUsd  = Number(formatUnits(spread, outDecimals)) * tokenOutPriceUsd;
    const gasCostUsd = estimateGasCostUsd(gasPrice, ESTIMATED_GAS_UNITS, maticUsd);

    // Aave fee: 0.05% of loan notional in tokenIn
    const loanNotionalUsd = Number(formatUnits(pair.loanAmount, 18)) * tokenInPriceUsd;
    const aaveFeeUsd      = loanNotionalUsd * 0.0005;

    const estimatedProfitUsd = spreadUsd - gasCostUsd - aaveFeeUsd;

    logDebug("Pair evaluated", {
      pair:               pair.name,
      spreadUsd:          spreadUsd.toFixed(4),
      gasCostUsd:         gasCostUsd.toFixed(4),
      aaveFeeUsd:         aaveFeeUsd.toFixed(4),
      estimatedProfitUsd: estimatedProfitUsd.toFixed(4),
    });

    if (estimatedProfitUsd < MIN_PROFIT_USD) return null;

    return { pair, spread, cheaperDex, expensiveDex, estimatedProfitUsd, gasPrice };
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Execution
  // ──────────────────────────────────────────────────────────────────────────

  async executeArbitrage(opportunity: ArbitrageOpportunity): Promise<void> {
    this.executing = true;
    const { pair, cheaperDex, expensiveDex, estimatedProfitUsd, gasPrice } = opportunity;

    // minProfit = 0.05% of loan — conservative on-chain slippage guard
    const minProfitNative = (pair.loanAmount * 5n) / 10_000n;

    const params = ethers.AbiCoder.defaultAbiCoder().encode(
      ["address", "address", "address", "address", "uint256"],
      [pair.tokenIn, pair.tokenOut, cheaperDex, expensiveDex, minProfitNative]
    );

    let attempt = 0;
    while (attempt <= MAX_RETRIES) {
      const nonce = await this.nonceManager.acquire();
      try {
        logInfo(`Submitting flash loan (attempt ${attempt + 1}/${MAX_RETRIES + 1})`, {
          pair:         pair.name,
          loanAmount:   formatUnits(pair.loanAmount, 18),
          cheaperDex,
          expensiveDex,
          nonce,
          gasPriceGwei: Number(formatUnits(gasPrice, "gwei")).toFixed(2),
        });

        const tx = await this.flashLoanContract.initiateFlashLoan(
          pair.tokenIn,
          pair.loanAmount,
          params,
          {
            gasPrice,
            gasLimit: BigInt(ESTIMATED_GAS_UNITS) + 100_000n,
            nonce,
          }
        );

        this.nonceManager.commit();
        logInfo("Transaction submitted", { txHash: tx.hash });

        const receipt = await tx.wait(1);
        if (receipt?.status === 1) {
          logInfo("✅ Arbitrage succeeded!", {
            txHash:    receipt.hash,
            gasUsed:   receipt.gasUsed.toString(),
            profitUsd: estimatedProfitUsd.toFixed(2),
          });
          this.dailyPnLUsd += estimatedProfitUsd;
        } else {
          logError("Transaction reverted", undefined, { txHash: receipt?.hash });
          this.dailyPnLUsd -= estimateGasCostUsd(gasPrice, Number(receipt?.gasUsed ?? 500000n), 0.9);
        }
        break;

      } catch (err: unknown) {
        const isNonceLow = _isNonceLow(err);
        if (isNonceLow) {
          logWarn("Nonce too low — resyncing…", { attempt });
          await this.nonceManager.resync();
          attempt++;
          continue;
        }

        const isTransient = _isTransientError(err);
        if (!isTransient || attempt >= MAX_RETRIES) {
          logError("Flash loan failed permanently", err, { pair: pair.name, attempt });
          this.nonceManager.rollback();
          break;
        }

        this.nonceManager.rollback();
        const backoff = RETRY_BASE_DELAY_MS * 2 ** attempt;
        logWarn(`Transient error — retrying in ${backoff}ms`, { attempt, error: String(err) });
        await sleep(backoff);
        attempt++;
      }
    }

    this.executing = false;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Internals
  // ──────────────────────────────────────────────────────────────────────────

  private async _fetchGasPrice(): Promise<bigint> {
    const feeData = await this.httpProvider.getFeeData();
    return feeData.gasPrice ?? parseUnits("50", "gwei");
  }

  private _resetDailyPnLIfNeeded(): void {
    const today = new Date().toISOString().slice(0, 10);
    if (this.dailyPnLDate !== today) {
      logInfo("Resetting daily PnL tracker.", {
        previousDate: this.dailyPnLDate,
        previousPnL:  this.dailyPnLUsd,
      });
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
        await sleep(12_000);
      }
    };
    poll().catch((err) => logError("Polling loop crashed", err));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error classification helpers
// ─────────────────────────────────────────────────────────────────────────────

function _isNonceLow(err: unknown): boolean {
  if (!(err instanceof Error)) return false;
  const msg = err.message.toLowerCase();
  return msg.includes("nonce too low") || msg.includes("already known");
}

function _isTransientError(err: unknown): boolean {
  if (!(err instanceof Error)) return false;
  const msg = err.message.toLowerCase();
  return (
    msg.includes("network") ||
    msg.includes("timeout") ||
    msg.includes("rate limit") ||
    msg.includes("replacement fee too low") ||
    msg.includes("server error")
  );
}
