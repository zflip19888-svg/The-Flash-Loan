/**
 * @file scanner.ts
 * @notice ArbitrageScanner — core engine of the flash loan arbitrage bot.
 *
 * Per-block pipeline:
 *   1. Flush Chainlink cache → warm fresh prices
 *   2. Check gas vs MAX_GAS_GWEI guard
 *   3. For each token pair:
 *      a. Fetch DEX pool depth on both QuickSwap + SushiSwap
 *      b. Skip pair if EITHER DEX side has < MIN_POOL_DEPTH_USD ($40K) liquidity
 *      c. Query on-chain spread via PriceOraclePolygon
 *      d. Estimate net profit (spread − gas − Aave fee)
 *      e. Execute if profit > MIN_PROFIT_USD
 *   4. Track daily PnL; halt if drawdown > MAX_DAILY_LOSS_USD
 *   5. NonceManager ensures sequential nonces — no concurrent tx collisions
 */

import {
  ethers,
  Contract,
  WebSocketProvider,
  JsonRpcProvider,
  Wallet,
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
import { NonceManager }                          from "./nonce-manager";
import { ChainlinkPriceFeed, TOKEN_TO_FEED, FEEDS } from "./price-feed";

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

/** Minimum USD liquidity required on EACH DEX side for a pair to be scannable */
const MIN_POOL_DEPTH_USD = 40_000;

const QUICKSWAP_FACTORY = "0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32";
const SUSHISWAP_FACTORY = "0xc35DADB65012eC5796536bD9864eD8773aBc74C4";

const FACTORY_ABI = [
  "function getPair(address tokenA, address tokenB) external view returns (address pair)",
] as const;

const PAIR_ABI = [
  "function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast)",
  "function token0() external view returns (address)",
] as const;

// ─────────────────────────────────────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────────────────────────────────────

interface DepthResult {
  depthUsd:   number;
  reserveIn:  bigint;
  reserveOut: bigint;
}

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
  return new Promise((r) => setTimeout(r, ms));
}

function estimateGasCostUsd(gasPrice: bigint, gasUnits: number, maticUsd: number): number {
  return Number(formatUnits(gasPrice * BigInt(gasUnits), 18)) * maticUsd;
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
  private qsFactory:         Contract;
  private ssFactory:         Contract;
  private nonceManager:      NonceManager;
  private priceFeed:         ChainlinkPriceFeed;

  private dailyPnLUsd  = 0;
  private dailyPnLDate = "";

  private executing = false;
  private running   = false;

  constructor() {
    this.httpProvider = new JsonRpcProvider(ENV.POLYGON_RPC_URL);
    this.wallet       = new Wallet(ENV.PRIVATE_KEY, this.httpProvider);

    this.flashLoanContract = new Contract(ENV.FLASH_LOAN_ADDRESS, FLASH_LOAN_ABI, this.wallet);
    this.priceOracle       = new Contract(ENV.PRICE_ORACLE_ADDRESS, PRICE_ORACLE_ABI, this.httpProvider);
    this.qsFactory         = new Contract(QUICKSWAP_FACTORY, FACTORY_ABI, this.httpProvider);
    this.ssFactory         = new Contract(SUSHISWAP_FACTORY, FACTORY_ABI, this.httpProvider);
    this.nonceManager      = new NonceManager(this.httpProvider, this.wallet.address);
    this.priceFeed         = new ChainlinkPriceFeed(this.httpProvider);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ──────────────────────────────────────────────────────────────────────────

  async start(): Promise<void> {
    this.running = true;
    logInfo("ArbitrageScanner starting", {
      account:   this.wallet.address,
      flashLoan: ENV.FLASH_LOAN_ADDRESS,
      oracle:    ENV.PRICE_ORACLE_ADDRESS,
      minProfitUsd:    MIN_PROFIT_USD,
      maxGasGwei:      MAX_GAS_GWEI,
      minPoolDepthUsd: MIN_POOL_DEPTH_USD,
    });

    await this.priceFeed.warmCache().catch((e) =>
      logWarn("Price cache warm failed", { error: String(e) })
    );

    // Prefer WebSocket for zero-latency block events; fall back to HTTP polling
    if (ENV.POLYGON_WS_URL) {
      try {
        this.wsProvider = new WebSocketProvider(ENV.POLYGON_WS_URL);
        this.wsProvider.on("block", (blockNumber: number) => {
          if (!this.running) return;
          this.onBlock(blockNumber).catch((err) =>
            logError("onBlock error", err, { blockNumber })
          );
        });
        logInfo("WebSocket block subscription active");
        return;
      } catch (err) {
        logWarn("WebSocket failed — falling back to HTTP polling", { err: String(err) });
      }
    }
    this._startPolling();
  }

  async stop(): Promise<void> {
    this.running = false;
    if (this.wsProvider) await this.wsProvider.destroy();
    logInfo("ArbitrageScanner stopped", { dailyPnLUsd: this.dailyPnLUsd });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HTTP polling fallback (~2 s interval)
  // ──────────────────────────────────────────────────────────────────────────

  private _startPolling(): void {
    logInfo("HTTP polling mode active (2 s interval)");
    let lastBlock = 0;
    const poll = async () => {
      if (!this.running) return;
      try {
        const block = await this.httpProvider.getBlockNumber();
        if (block > lastBlock) {
          lastBlock = block;
          await this.onBlock(block).catch((err) =>
            logError("onBlock error (poll)", err, { block })
          );
        }
      } catch (err) {
        logError("Polling error", err);
      }
      setTimeout(poll, 2_000);
    };
    poll();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Block handler
  // ──────────────────────────────────────────────────────────────────────────

  async onBlock(blockNumber: number): Promise<void> {
    logDebug("Block", { blockNumber });
    this._resetDailyPnLIfNeeded();

    if (this.dailyPnLUsd < -MAX_DAILY_LOSS_USD) {
      logWarn("Daily loss limit reached — halted for today", {
        dailyPnLUsd: this.dailyPnLUsd,
        limit: MAX_DAILY_LOSS_USD,
      });
      return;
    }

    if (this.executing) {
      logDebug("Execution in-flight — skipping block", { blockNumber });
      return;
    }

    this.priceFeed.flushCache();

    const [gasPrice, maticUsd] = await Promise.all([
      this._fetchGasPrice(),
      this.priceFeed.getPrice(FEEDS.MATIC_USD, 0.9),
    ]);

    const gasPriceGwei = Number(formatUnits(gasPrice, "gwei"));
    if (gasPriceGwei > MAX_GAS_GWEI) {
      logWarn("Gas too high — skipping block", { gasPriceGwei, max: MAX_GAS_GWEI });
      return;
    }

    for (const pair of TOKEN_PAIRS) {
      try {
        const opp = await this._evaluatePair(pair, gasPrice, maticUsd);
        if (opp) {
          logInfo("Opportunity found", {
            pair:        pair.name,
            profitUsd:   opp.estimatedProfitUsd.toFixed(2),
            cheaperDex:  opp.cheaperDex,
            gasPriceGwei: gasPriceGwei.toFixed(1),
          });
          await this.executeArbitrage(opp);
          break; // one trade per block
        }
      } catch (err) {
        logError(`Evaluation error — ${pair.name}`, err);
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Liquidity depth check
  // ──────────────────────────────────────────────────────────────────────────

  /**
   * Returns the USD depth of the tokenIn side for a given factory's pair.
   * Returns 0 if the pair doesn't exist or reserves are empty.
   */
  private async _poolDepth(
    factory:      Contract,
    tokenIn:      string,
    tokenOut:     string,
    tokenInDecimals: number,
    tokenInPriceUsd: number,
  ): Promise<DepthResult> {
    try {
      const pairAddr: string = await factory.getPair(tokenIn, tokenOut);
      if (!pairAddr || pairAddr === ethers.ZeroAddress) {
        return { depthUsd: 0, reserveIn: 0n, reserveOut: 0n };
      }

      const pair = new Contract(pairAddr, PAIR_ABI, this.httpProvider);
      const [[r0, r1], t0]: [[bigint, bigint, number], string] = await Promise.all([
        pair.getReserves(),
        pair.token0(),
      ]);

      const isToken0 = t0.toLowerCase() === tokenIn.toLowerCase();
      const reserveIn  = isToken0 ? r0 : r1;
      const reserveOut = isToken0 ? r1 : r0;

      const resInFloat = parseFloat(formatUnits(reserveIn, tokenInDecimals));
      const depthUsd   = resInFloat * tokenInPriceUsd;

      return { depthUsd, reserveIn, reserveOut };
    } catch {
      return { depthUsd: 0, reserveIn: 0n, reserveOut: 0n };
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Pair evaluation (depth check → spread check → profit calc)
  // ──────────────────────────────────────────────────────────────────────────

  private async _evaluatePair(
    pair:     TokenPair,
    gasPrice: bigint,
    maticUsd: number,
  ): Promise<ArbitrageOpportunity | null> {

    // ── Token prices ──────────────────────────────────────────────────────────
    const tokenInPriceUsd  = await this.priceFeed.getTokenPriceUsd(pair.tokenIn, 0);
    const tokenOutPriceUsd = await this.priceFeed.getTokenPriceUsd(pair.tokenOut, 0);

    if (tokenInPriceUsd === 0) {
      logDebug(`No price for tokenIn — skipping ${pair.name}`);
      return null;
    }

    // Decimals: USDC/WBTC special cases; default 18
    const inDecimals = _decimalsOf(pair.tokenIn);

    // ── Depth check (parallel) ────────────────────────────────────────────────
    const [qsDepth, ssDepth] = await Promise.all([
      this._poolDepth(this.qsFactory, pair.tokenIn, pair.tokenOut, inDecimals, tokenInPriceUsd),
      this._poolDepth(this.ssFactory, pair.tokenIn, pair.tokenOut, inDecimals, tokenInPriceUsd),
    ]);

    const minDepth = Math.min(qsDepth.depthUsd, ssDepth.depthUsd);

    if (minDepth < MIN_POOL_DEPTH_USD) {
      logDebug(`Depth filter — skipping ${pair.name}`, {
        qsDepthUsd: qsDepth.depthUsd.toFixed(0),
        ssDepthUsd: ssDepth.depthUsd.toFixed(0),
        minRequired: MIN_POOL_DEPTH_USD,
      });
      return null;
    }

    // ── Spread check ──────────────────────────────────────────────────────────
    let spread: bigint, cheaperDex: string, expensiveDex: string;
    try {
      [spread, cheaperDex, expensiveDex] = await this.priceOracle.getArbitrageSpread(
        pair.tokenIn, pair.tokenOut, pair.loanAmount
      );
    } catch (err) {
      logDebug(`getArbitrageSpread failed — ${pair.name}`, { err: String(err) });
      return null;
    }

    if (spread === 0n) return null;

    // ── Profit estimate ───────────────────────────────────────────────────────
    const outDecimals    = _decimalsOf(pair.tokenOut);
    const spreadUsd      = parseFloat(formatUnits(spread, outDecimals)) *
                           (tokenOutPriceUsd || 1);
    const gasCostUsd     = estimateGasCostUsd(gasPrice, ESTIMATED_GAS_UNITS, maticUsd);
    const loanNotional   = parseFloat(formatUnits(pair.loanAmount, inDecimals)) * tokenInPriceUsd;
    const aaveFeeUsd     = loanNotional * 0.0005;
    const estimatedProfit = spreadUsd - gasCostUsd - aaveFeeUsd;

    logDebug(`Evaluated ${pair.name}`, {
      qsDepth: qsDepth.depthUsd.toFixed(0),
      ssDepth: ssDepth.depthUsd.toFixed(0),
      spreadUsd: spreadUsd.toFixed(2),
      gasCostUsd: gasCostUsd.toFixed(3),
      aaveFee: aaveFeeUsd.toFixed(3),
      netProfit: estimatedProfit.toFixed(2),
    });

    if (estimatedProfit < MIN_PROFIT_USD) return null;

    return { pair, spread, cheaperDex, expensiveDex, estimatedProfitUsd: estimatedProfit, gasPrice };
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Execution
  // ──────────────────────────────────────────────────────────────────────────

  async executeArbitrage(opp: ArbitrageOpportunity): Promise<void> {
    this.executing = true;
    const { pair, cheaperDex, expensiveDex, estimatedProfitUsd, gasPrice } = opp;

    const minProfitNative = (pair.loanAmount * 5n) / 10_000n; // 0.05% of loan

    const params = ethers.AbiCoder.defaultAbiCoder().encode(
      ["address", "address", "address", "address", "uint256"],
      [pair.tokenIn, pair.tokenOut, cheaperDex, expensiveDex, minProfitNative]
    );

    let attempt = 0;
    while (attempt <= MAX_RETRIES) {
      const nonce = await this.nonceManager.acquire();
      try {
        logInfo(`Flash loan attempt ${attempt + 1}/${MAX_RETRIES + 1}`, {
          pair: pair.name, cheaperDex, expensiveDex, nonce,
          gasPriceGwei: Number(formatUnits(gasPrice, "gwei")).toFixed(1),
          estimatedProfitUsd: estimatedProfitUsd.toFixed(2),
        });

        const tx = await this.flashLoanContract.initiateFlashLoan(
          pair.tokenIn, pair.loanAmount, params,
          { gasPrice, gasLimit: BigInt(ESTIMATED_GAS_UNITS) + 100_000n, nonce }
        );
        this.nonceManager.commit();

        logInfo("Tx submitted", { txHash: tx.hash });
        const receipt = await tx.wait(1);

        if (receipt?.status === 1) {
          logInfo("Trade executed successfully", {
            txHash:    tx.hash,
            gasUsed:   receipt.gasUsed.toString(),
            block:     receipt.blockNumber,
            profitUsd: estimatedProfitUsd.toFixed(2),
          });
          this.dailyPnLUsd += estimatedProfitUsd;
        } else {
          logWarn("Tx mined but reverted", { txHash: tx.hash });
          this.dailyPnLUsd -= estimateGasCostUsd(
            gasPrice, Number(receipt?.gasUsed ?? ESTIMATED_GAS_UNITS),
            await this.priceFeed.getPrice(FEEDS.MATIC_USD, 0.9)
          );
        }
        break;

      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : String(err);

        if (msg.includes("nonce too low") || msg.includes("replacement fee too low")) {
          logWarn("Nonce error — resyncing", { attempt });
          this.nonceManager.rollback();
          await this.nonceManager.resync();
        } else {
          this.nonceManager.rollback();
        }

        if (attempt >= MAX_RETRIES) {
          logError(`All retries exhausted for ${pair.name}`, err);
          break;
        }
        attempt++;
        await sleep(RETRY_BASE_DELAY_MS * 2 ** attempt);
      }
    }

    this.executing = false;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Internals
  // ──────────────────────────────────────────────────────────────────────────

  private async _fetchGasPrice(): Promise<bigint> {
    try {
      const fee = await this.httpProvider.getFeeData();
      return fee.gasPrice ?? 100_000_000_000n; // 100 Gwei fallback
    } catch {
      return 100_000_000_000n;
    }
  }

  private _resetDailyPnLIfNeeded(): void {
    const today = new Date().toISOString().slice(0, 10);
    if (today !== this.dailyPnLDate) {
      if (this.dailyPnLDate) {
        logInfo("Daily PnL reset", { date: this.dailyPnLDate, pnlUsd: this.dailyPnLUsd.toFixed(2) });
      }
      this.dailyPnLUsd  = 0;
      this.dailyPnLDate = today;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Token decimal helper
// ─────────────────────────────────────────────────────────────────────────────

function _decimalsOf(tokenAddress: string): number {
  const addr = tokenAddress.toLowerCase();
  if (addr === "0x2791bca1f2de4661ed88a30c99a7a9449aa84174") return 6;  // USDC
  if (addr === "0x1bfd67037b42cf73acf2047067bd4f2c47d9bfd6") return 8;  // WBTC
  return 18;
}
