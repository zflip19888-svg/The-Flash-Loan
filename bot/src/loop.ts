/**
 * @file loop.ts
 * @notice Continuous block-by-block arbitrage scanner loop.
 *
 * Features:
 *   • WebSocket block subscription (falls back to 2 s HTTP polling)
 *   • Liquidity depth filter: skips pairs where either DEX side < MIN_POOL_DEPTH_USD
 *   • Chainlink price feeds (on-chain, 1 h staleness guard)
 *   • Gas gate: skips blocks where gas > MAX_GAS_GWEI
 *   • Daily PnL tracker with auto-reset; halts on MAX_DAILY_LOSS_USD drawdown
 *   • Execution gate: DRY_RUN=true logs opportunities but never sends a tx
 *   • Every opportunity (executed or not) written to logs/opportunities-YYYY-MM-DD.jsonl
 *   • Periodic status report every STATUS_INTERVAL_BLOCKS blocks
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
import { ChainlinkPriceFeed, FEEDS }             from "./price-feed";
import { writeOpportunity, readTodayLog, OpportunityRecord } from "./opportunity-log";

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const MIN_POOL_DEPTH_USD    = 50_000;
const STATUS_INTERVAL_BLOCKS = 50;   // print a summary every ~100 s on Polygon

const DRY_RUN = process.env.DRY_RUN === "true";

const QUICKSWAP_FACTORY = "0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32";
const SUSHISWAP_FACTORY = "0xc35DADB65012eC5796536bD9864eD8773aBc74C4";

const FACTORY_ABI = [
  "function getPair(address,address) external view returns (address)",
] as const;

const PAIR_ABI = [
  "function getReserves() external view returns (uint112,uint112,uint32)",
  "function token0() external view returns (address)",
] as const;

// ─────────────────────────────────────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────────────────────────────────────

interface PairResult {
  pair:          TokenPair;
  qsDepthUsd:    number;
  ssDepthUsd:    number;
  spreadUsd:     number;
  gasCostUsd:    number;
  aaveFeeUsd:    number;
  netProfitUsd:  number;
  cheaperDex:    string;
  expensiveDex:  string;
  spread:        bigint;
  viable:        boolean;   // passed depth + profit filters
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

function sleep(ms: number) { return new Promise<void>((r) => setTimeout(r, ms)); }

function decimalsOf(addr: string): number {
  const a = addr.toLowerCase();
  if (a === "0x2791bca1f2de4661ed88a30c99a7a9449aa84174") return 6;  // USDC
  if (a === "0x1bfd67037b42cf73acf2047067bd4f2c47d9bfd6") return 8;  // WBTC
  return 18;
}

// ─────────────────────────────────────────────────────────────────────────────
// ScanLoop
// ─────────────────────────────────────────────────────────────────────────────

export class ScanLoop {
  private http:          JsonRpcProvider;
  private ws:            WebSocketProvider | null = null;
  private wallet:        Wallet | null = null;
  private flashLoan:     Contract | null = null;
  private oracle:        Contract;
  private qsFactory:     Contract;
  private ssFactory:     Contract;
  private nonceMgr:      NonceManager | null = null;
  private priceFeed:     ChainlinkPriceFeed;

  private running       = false;
  private executing     = false;
  private blocksScanned = 0;
  private lastBlock     = 0;

  // Stats
  private dailyPnL      = 0;
  private dailyDate     = "";
  private sessionOpps   = 0;
  private sessionTrades = 0;
  private sessionProfit = 0;

  constructor() {
    this.http      = new JsonRpcProvider(ENV.POLYGON_RPC_URL);
    this.oracle    = new Contract(ENV.PRICE_ORACLE_ADDRESS, PRICE_ORACLE_ABI, this.http);
    this.qsFactory = new Contract(QUICKSWAP_FACTORY, FACTORY_ABI, this.http);
    this.ssFactory = new Contract(SUSHISWAP_FACTORY, FACTORY_ABI, this.http);
    this.priceFeed = new ChainlinkPriceFeed(this.http);

    // Execution is disabled in DRY_RUN mode or when PRIVATE_KEY / FLASH_LOAN_ADDRESS
    // are not set (e.g. scan-only mode)
    const canExecute = !DRY_RUN &&
      ENV.PRIVATE_KEY !== "" &&
      ENV.FLASH_LOAN_ADDRESS !== "";

    if (canExecute) {
      this.wallet   = new Wallet(ENV.PRIVATE_KEY, this.http);
      this.flashLoan = new Contract(ENV.FLASH_LOAN_ADDRESS, FLASH_LOAN_ABI, this.wallet);
      this.nonceMgr  = new NonceManager(this.http, this.wallet.address);
      logInfo("Execution ENABLED", { wallet: this.wallet.address });
    } else {
      logInfo(`Execution DISABLED — ${DRY_RUN ? "DRY_RUN=true" : "missing PRIVATE_KEY or FLASH_LOAN_ADDRESS"}`);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Start / Stop
  // ──────────────────────────────────────────────────────────────────────────

  async start(): Promise<void> {
    this.running = true;
    logInfo("ScanLoop starting", {
      rpc:          ENV.POLYGON_RPC_URL.replace(/\/v2\/.+/, "/v2/***"),
      minProfitUsd: MIN_PROFIT_USD,
      maxGasGwei:   MAX_GAS_GWEI,
      minDepthUsd:  MIN_POOL_DEPTH_USD,
      dryRun:       DRY_RUN,
      pairs:        TOKEN_PAIRS.map((p) => p.name),
    });

    await this.priceFeed.warmCache().catch((e) =>
      logWarn("Price cache warm failed", { error: String(e) })
    );

    // Try WebSocket first
    if (ENV.POLYGON_WS_URL) {
      try {
        this.ws = new WebSocketProvider(ENV.POLYGON_WS_URL);
        await new Promise<void>((resolve, reject) => {
          const timeout = setTimeout(() => reject(new Error("WS timeout")), 8_000);
          this.ws!.once("block", () => { clearTimeout(timeout); resolve(); });
        });
        this.ws.on("block", (n: number) => this._onBlock(n));
        logInfo("WebSocket block subscription active");
        return; // stay alive via event loop
      } catch (err) {
        logWarn("WebSocket failed — using HTTP polling", { err: String(err) });
        if (this.ws) { try { await this.ws.destroy(); } catch {} }
        this.ws = null;
      }
    }

    // HTTP polling fallback
    this._pollLoop();
  }

  async stop(): Promise<void> {
    this.running = false;
    if (this.ws) await this.ws.destroy().catch(() => {});
    this._printStatus("SHUTDOWN");
    logInfo("ScanLoop stopped");
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HTTP polling
  // ──────────────────────────────────────────────────────────────────────────

  private async _pollLoop(): Promise<void> {
    logInfo("HTTP polling active (2 s)");
    while (this.running) {
      try {
        const block = await this.http.getBlockNumber();
        if (block > this.lastBlock) {
          this.lastBlock = block;
          await this._onBlock(block);
        }
      } catch (err) {
        logError("Poll error", err);
      }
      await sleep(2_000);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Per-block handler
  // ──────────────────────────────────────────────────────────────────────────

  private async _onBlock(blockNumber: number): Promise<void> {
    this.blocksScanned++;
    this._resetDailyIfNeeded();
    logDebug("Block", { blockNumber, blocksScanned: this.blocksScanned });

    // Daily drawdown circuit breaker
    if (this.dailyPnL < -MAX_DAILY_LOSS_USD) {
      logWarn("Daily loss limit hit — skipping block", {
        dailyPnL: this.dailyPnL.toFixed(2), limit: MAX_DAILY_LOSS_USD,
      });
      return;
    }

    if (this.executing) {
      logDebug("Execution in-flight — skipping block", { blockNumber });
      return;
    }

    this.priceFeed.flushCache();

    // Fetch gas + MATIC price in parallel
    const [feeData, maticUsd] = await Promise.all([
      this.http.getFeeData().catch(() => null),
      this.priceFeed.getPrice(FEEDS.MATIC_USD, 0.9),
    ]);

    const gasPrice     = feeData?.gasPrice ?? 100_000_000_000n;
    const gasPriceGwei = Number(formatUnits(gasPrice, "gwei"));

    if (gasPriceGwei > MAX_GAS_GWEI) {
      logWarn("Gas too high — skipping", { gasPriceGwei, max: MAX_GAS_GWEI });
      return;
    }

    const gasCostUsd = Number(formatUnits(gasPrice * BigInt(ESTIMATED_GAS_UNITS), 18)) * maticUsd;

    // Scan all pairs
    const results = await Promise.all(
      TOKEN_PAIRS.map((p) => this._scanPair(p, gasPrice, maticUsd, gasCostUsd))
    );

    const viable = results.filter((r) => r !== null && r.viable) as PairResult[];

    // Log every viable opportunity (even if not executed)
    for (const r of viable) {
      this.sessionOpps++;
      const record: OpportunityRecord = {
        ts:           new Date().toISOString(),
        block:        blockNumber,
        pair:         r.pair.name,
        qsDepthUsd:   r.qsDepthUsd,
        ssDepthUsd:   r.ssDepthUsd,
        spreadUsd:    r.spreadUsd,
        gasCostUsd:   r.gasCostUsd,
        aaveFeeUsd:   r.aaveFeeUsd,
        netProfitUsd: r.netProfitUsd,
        cheaperDex:   r.cheaperDex,
        executed:     false,
      };

      logInfo("Opportunity", {
        pair:        r.pair.name,
        net:         `$${r.netProfitUsd.toFixed(2)}`,
        spread:      `$${r.spreadUsd.toFixed(2)}`,
        cheaper:     r.cheaperDex,
        qsDepth:     `$${(r.qsDepthUsd / 1000).toFixed(0)}K`,
        ssDepth:     `$${(r.ssDepthUsd / 1000).toFixed(0)}K`,
        dryRun:      DRY_RUN || !this.flashLoan,
      });

      // Execute — only first viable pair per block
      if (this.flashLoan && this.nonceMgr && this.wallet && !DRY_RUN) {
        const txResult = await this._execute(r, gasPrice);
        record.executed  = true;
        record.txHash    = txResult.hash;
        record.txStatus  = txResult.status;
        if (txResult.error) record.error = txResult.error;

        if (txResult.status === "success") {
          this.sessionTrades++;
          this.sessionProfit += r.netProfitUsd;
          this.dailyPnL      += r.netProfitUsd;
        } else {
          this.dailyPnL -= gasCostUsd;
        }

        writeOpportunity(record);
        break; // one trade per block
      } else {
        writeOpportunity(record);
      }
    }

    // Periodic status report
    if (this.blocksScanned % STATUS_INTERVAL_BLOCKS === 0) {
      this._printStatus("PERIODIC");
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Pair scan (depth → quote → profit)
  // ──────────────────────────────────────────────────────────────────────────

  private async _scanPair(
    pair:       TokenPair,
    gasPrice:   bigint,
    maticUsd:   number,
    gasCostUsd: number,
  ): Promise<PairResult | null> {
    try {
      const inDec  = decimalsOf(pair.tokenIn);
      const outDec = decimalsOf(pair.tokenOut);

      const tokenInUsd  = await this.priceFeed.getTokenPriceUsd(pair.tokenIn,  0);
      const tokenOutUsd = await this.priceFeed.getTokenPriceUsd(pair.tokenOut, 0);
      if (tokenInUsd === 0) return null;

      // ── Depth check ─────────────────────────────────────────────────────────
      const [qsDep, ssDep] = await Promise.all([
        this._depth(this.qsFactory, pair.tokenIn, pair.tokenOut, inDec, tokenInUsd),
        this._depth(this.ssFactory, pair.tokenIn, pair.tokenOut, inDec, tokenInUsd),
      ]);

      const minDepth = Math.min(qsDep, ssDep);
      if (minDepth < MIN_POOL_DEPTH_USD) {
        logDebug(`Depth skip — ${pair.name}`, {
          qs: qsDep.toFixed(0), ss: ssDep.toFixed(0), min: MIN_POOL_DEPTH_USD,
        });
        return null;
      }

      // ── Spread from oracle ───────────────────────────────────────────────────
      let spread: bigint, cheaperDex: string, expensiveDex: string;
      try {
        [spread, cheaperDex, expensiveDex] =
          await this.oracle.getArbitrageSpread(pair.tokenIn, pair.tokenOut, pair.loanAmount);
      } catch {
        return null;
      }
      if (spread === 0n) return null;

      // ── Profit calc ──────────────────────────────────────────────────────────
      const spreadUsd    = parseFloat(formatUnits(spread, outDec)) * (tokenOutUsd || 1);
      const loanNotional = parseFloat(formatUnits(pair.loanAmount, inDec)) * tokenInUsd;
      const aaveFeeUsd   = loanNotional * 0.0005;
      const netProfitUsd = spreadUsd - gasCostUsd - aaveFeeUsd;

      return {
        pair, qsDepthUsd: qsDep, ssDepthUsd: ssDep,
        spreadUsd, gasCostUsd, aaveFeeUsd, netProfitUsd,
        cheaperDex, expensiveDex, spread,
        viable: netProfitUsd >= MIN_PROFIT_USD,
      };
    } catch (err) {
      logError(`Scan error — ${pair.name}`, err);
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Depth helper
  // ──────────────────────────────────────────────────────────────────────────

  private async _depth(
    factory:    Contract,
    tokenIn:    string,
    tokenOut:   string,
    inDec:      number,
    priceInUsd: number,
  ): Promise<number> {
    try {
      const pairAddr: string = await factory.getPair(tokenIn, tokenOut);
      if (!pairAddr || pairAddr === ethers.ZeroAddress) return 0;

      const p = new Contract(pairAddr, PAIR_ABI, this.http);
      const [[r0, r1], t0]: [[bigint, bigint, number], string] =
        await Promise.all([p.getReserves(), p.token0()]);

      const isT0    = t0.toLowerCase() === tokenIn.toLowerCase();
      const resIn   = isT0 ? r0 : r1;
      const resInF  = parseFloat(formatUnits(resIn, inDec));
      return resInF * priceInUsd;
    } catch {
      return 0;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Execution
  // ──────────────────────────────────────────────────────────────────────────

  private async _execute(
    r:        PairResult,
    gasPrice: bigint,
  ): Promise<{ hash: string; status: "success" | "reverted" | "pending"; error?: string }> {
    this.executing = true;
    const minProfit = (r.pair.loanAmount * 5n) / 10_000n;
    const params    = ethers.AbiCoder.defaultAbiCoder().encode(
      ["address", "address", "address", "address", "uint256"],
      [r.pair.tokenIn, r.pair.tokenOut, r.cheaperDex, r.expensiveDex, minProfit]
    );

    let attempt = 0;
    while (attempt <= MAX_RETRIES) {
      const nonce = await this.nonceMgr!.acquire();
      try {
        const tx = await this.flashLoan!.initiateFlashLoan(
          r.pair.tokenIn, r.pair.loanAmount, params,
          { gasPrice, gasLimit: BigInt(ESTIMATED_GAS_UNITS) + 100_000n, nonce }
        );
        this.nonceMgr!.commit();

        logInfo("Tx submitted", { txHash: tx.hash, pair: r.pair.name });

        const receipt = await tx.wait(1);
        this.executing = false;

        if (receipt?.status === 1) {
          logInfo("Trade success", {
            txHash: tx.hash, gasUsed: receipt.gasUsed.toString(),
            block: receipt.blockNumber, netUsd: r.netProfitUsd.toFixed(2),
          });
          return { hash: tx.hash, status: "success" };
        } else {
          logWarn("Tx reverted", { txHash: tx.hash });
          return { hash: tx.hash, status: "reverted" };
        }
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : String(err);
        if (msg.includes("nonce too low") || msg.includes("replacement fee")) {
          this.nonceMgr!.rollback();
          await this.nonceMgr!.resync();
        } else {
          this.nonceMgr!.rollback();
        }
        if (attempt >= MAX_RETRIES) {
          this.executing = false;
          return { hash: "", status: "pending", error: msg };
        }
        attempt++;
        await sleep(RETRY_BASE_DELAY_MS * 2 ** attempt);
      }
    }
    this.executing = false;
    return { hash: "", status: "pending", error: "max retries" };
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Status report
  // ──────────────────────────────────────────────────────────────────────────

  private _printStatus(trigger: string): void {
    const today    = readTodayLog();
    const executed = today.filter((r) => r.executed && r.txStatus === "success");
    const totalNet = executed.reduce((s, r) => s + r.netProfitUsd, 0);

    logInfo(`=== STATUS [${trigger}] ===`, {
      blocksScanned:     this.blocksScanned,
      sessionOpps:       this.sessionOpps,
      sessionTrades:     this.sessionTrades,
      sessionProfitUsd:  this.sessionProfit.toFixed(2),
      dailyPnLUsd:       this.dailyPnL.toFixed(2),
      todayLoggedTrades: executed.length,
      todayLoggedNetUsd: totalNet.toFixed(2),
      dryRun:            DRY_RUN,
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Daily reset
  // ──────────────────────────────────────────────────────────────────────────

  private _resetDailyIfNeeded(): void {
    const today = new Date().toISOString().slice(0, 10);
    if (today !== this.dailyDate) {
      if (this.dailyDate) {
        logInfo("Daily PnL reset", { date: this.dailyDate, pnl: this.dailyPnL.toFixed(2) });
      }
      this.dailyPnL  = 0;
      this.dailyDate = today;
    }
  }
}
