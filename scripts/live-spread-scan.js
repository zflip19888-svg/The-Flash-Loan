/**
 * @file live-spread-scan.js
 * @notice Live spread scanner with liquidity depth filtering + rotating RPC pool.
 *
 * REAL LIVE DATA ONLY — no simulation, no mock, no synthetic fallbacks:
 *   - Quotes come exclusively from DEX router `getAmountsOut` (real AMM math incl. fees).
 *     The old constant-product "simulation" fallback has been REMOVED.
 *   - Reserve/depth fetch failures are NOT silently swallowed — the scanner
 *     rotates to the next RPC and retries; if every RPC fails the pair is
 *     marked RPC_ERROR rather than showing fabricated numbers.
 *   - Freshness gates: the chain head must be < MAX_BLOCK_AGE_S old, and all
 *     Chainlink feeds must be < 1h old (strict freshness policy). Otherwise
 *     the scan rotates or aborts.
 *
 * RPC rotation: primary endpoint (env POLYGON_RPC_URL, e.g. Alchemy) followed
 * by public failovers. On connection error, rate-limit, or stale head the
 * scanner rotates to the next endpoint — per pair and mid-scan if needed.
 *
 * Run:
 *   node scripts/live-spread-scan.js
 *   POLYGON_RPC_URL=https://... node scripts/live-spread-scan.js
 */

require("dotenv").config();
const { ethers } = require("ethers");

// ─────────────────────────────────────────────────────────────────────────────
// Config
// ─────────────────────────────────────────────────────────────────────────────

/** Rotating RPC pool — tried in order; env-configured primary first. */
const RPC_POOL = [
  ...(process.env.POLYGON_RPC_URL ? [["primary",  process.env.POLYGON_RPC_URL]] : []),
  ["publicnode", "https://polygon-bor-rpc.publicnode.com"],
  ["drpc",       "https://polygon.drpc.org"],
  ["1rpc",       "https://1rpc.io/matic"],
];

/** Max acceptable age of the chain head (seconds) — freshness gate for live data. */
const MAX_BLOCK_AGE_S = 120;

/** Max acceptable age for Chainlink price feeds (seconds) — strict freshness policy. */
const MAX_ORACLE_AGE_S = 3600;

/** Skip a DEX side if USD reserve depth is below this */
const MIN_RESERVE_USD = 15_000;

/** Skip a pair entirely if BOTH DEXes have reserve < this (no market) */
const MIN_EITHER_RESERVE_USD = 15_000;

/** Minimum spread % to bother estimating profit */
const MIN_SPREAD_PCT = 0.02;

const QUICKSWAP_ROUTER  = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";
const SUSHISWAP_ROUTER  = "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506";
const QUICKSWAP_FACTORY = "0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32";
const SUSHISWAP_FACTORY = "0xc35DADB65012eC5796536bD9864eD8773aBc74C4";
const CL_MATIC_USD      = "0xAB594600376Ec9fD91F8e885dADF0CE036862dE0";
const CL_ETH_USD        = "0xF9680D99D6C9589e2a93a78A04A279e509205945";
const CL_BTC_USD        = "0xc907E116054Ad103354f2D350FD2514433D57F6f";

const TOKENS = {
  USDC:  { addr: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", decimals: 6,  symbol: "USDC",  usdPrice: 1.0 },
  WMATIC:{ addr: "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270", decimals: 18, symbol: "WMATIC", usdPrice: null },
  WETH:  { addr: "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619", decimals: 18, symbol: "WETH",  usdPrice: null },
  DAI:   { addr: "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063", decimals: 18, symbol: "DAI",   usdPrice: 1.0 },
};

// Aave v3 Polygon: USDC borrowing DISABLED — all pairs now route via WETH borrow
// WETH available: 9,440 ETH (~$17M) — fully open for flash loans
const SCAN_PAIRS = [
  // ── Native WETH pairs (primary — always enabled) ─────────────────────────
  { from: TOKENS.WETH,   to: TOKENS.USDC,   amount: 10,     label: 'WETH→USDC (borrow WETH)' },
  { from: TOKENS.WETH,   to: TOKENS.USDC,   amount: 15,     label: 'WETH→USDC (15 ETH)' },
  // ── WETH-routed WMATIC arb ────────────────────────────────────────────────
  // Borrow WETH → swap to USDC on QS → swap to WMATIC on SS → net spread
  { from: TOKENS.WETH,   to: TOKENS.WMATIC, amount: 10,     label: 'WETH→USDC→WMATIC (via WETH borrow)' },
  // ── WMATIC native ────────────────────────────────────────────────────────
  { from: TOKENS.WMATIC, to: TOKENS.USDC,   amount: 20_000, label: 'WMATIC→USDC' },
  { from: TOKENS.WMATIC, to: TOKENS.USDC,   amount: 50_000, label: 'WMATIC→USDC (50K)' },
];

// ─────────────────────────────────────────────────────────────────────────────
// ABIs
// ─────────────────────────────────────────────────────────────────────────────

const ROUTER_ABI = [
  "function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts)",
];
const FACTORY_ABI = [
  "function getPair(address tokenA, address tokenB) external view returns (address pair)",
];
const PAIR_ABI = [
  "function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast)",
  "function token0() external view returns (address)",
];
const CL_ABI = [
  "function latestRoundData() external view returns (uint80,int256,uint256,uint256,uint80)",
  "function decimals() external view returns (uint8)",
];

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

function pad(str, len) { return String(str).padEnd(len); }
function pct(a, b) {
  const diff = Math.abs(a - b);
  return Math.max(a, b) === 0 ? 0 : (diff / Math.max(a, b)) * 100;
}

// ─────────────────────────────────────────────────────────────────────────────
// Rotating RPC provider
// ─────────────────────────────────────────────────────────────────────────────

/** Probe one RPC endpoint; resolve fresh candidate or null (never throws). */
async function probeRpc(name, url) {
  try {
    const provider = new ethers.JsonRpcProvider(url, undefined, {
      staticNetwork: true,
      batchMaxCount: 1,
    });
    const blockNumber = await provider.getBlockNumber();
    const blk = await provider.getBlock("latest");
    if (!blk) return null;
    const age = Math.floor(Date.now() / 1000) - Number(blk.timestamp);
    if (age > MAX_BLOCK_AGE_S) return null; // stale head — not live data
    return { name, url, provider, blockNumber, headAgeS: age };
  } catch {
    return null;
  }
}

/** Scan the pool from `startIdx` (inclusive) for the first fresh endpoint. */
async function connectFresh(startIdx) {
  for (let i = 0; i < RPC_POOL.length; i++) {
    const idx = (startIdx + i) % RPC_POOL.length;
    const [name, url] = RPC_POOL[idx];
    const cand = await probeRpc(name, url);
    if (cand) return { ...cand, idx };
  }
  return null;
}

function mkContracts(provider) {
  return {
    qsRouter:  new ethers.Contract(QUICKSWAP_ROUTER,   ROUTER_ABI,  provider),
    ssRouter:  new ethers.Contract(SUSHISWAP_ROUTER,   ROUTER_ABI,  provider),
    qsFactory: new ethers.Contract(QUICKSWAP_FACTORY,  FACTORY_ABI, provider),
    ssFactory: new ethers.Contract(SUSHISWAP_FACTORY, FACTORY_ABI, provider),
  };
}

/** Scanner state — current RPC + bound contracts; rotated on failures. */
function mkState() { return { idx: 0, rpc: null, ctx: null }; }

/** Advance to the next fresh RPC in the pool. Returns true on success. */
async function rotate(state, reason) {
  for (let hop = 0; hop < RPC_POOL.length; hop++) {
    state.idx = (state.idx + 1) % RPC_POOL.length;
    const cand = await connectFresh(state.idx);
    if (cand) {
      state.idx = cand.idx;
      state.rpc = cand;
      state.ctx = mkContracts(cand.provider);
      console.error(`  ↻ RPC rotated → [${cand.name}] (${reason})`);
      return true;
    }
  }
  return false;
}

/**
 * Run `fn(ctx)` against the current RPC; on error rotate and retry until the
 * whole pool has been tried. Throws only if every endpoint failed.
 */
async function withRotation(state, label, fn) {
  let lastErr;
  for (let attempt = 0; attempt <= RPC_POOL.length; attempt++) {
    try {
      return await fn(state.ctx);
    } catch (e) {
      lastErr = e;
      const ok = await rotate(state, `${label}: ${e.message?.slice(0, 80)}`);
      if (!ok) break;
    }
  }
  throw new Error(`${label} failed on all ${RPC_POOL.length} RPCs — last error: ${lastErr?.message}`);
}

// ─────────────────────────────────────────────────────────────────────────────
// Live data fetchers — NO silent fallbacks. Errors propagate to rotation.
// ─────────────────────────────────────────────────────────────────────────────

async function fetchChainlinkPrice(provider, feed, label) {
  const c = new ethers.Contract(feed, CL_ABI, provider);
  const [[, answer, , updatedAt], decimals] = await Promise.all([
    c.latestRoundData(),
    c.decimals(),
  ]);
  const age = Math.floor(Date.now() / 1000) - Number(updatedAt);
  if (age > MAX_ORACLE_AGE_S) {
    throw new Error(`Chainlink ${label} stale: age ${age}s > ${MAX_ORACLE_AGE_S}s — refusing stale price`);
  }
  return Number(answer) / 10 ** Number(decimals);
}

async function getPoolDepth(factory, tokenIn, tokenOut, decIn, decOut, priceIn, priceOut) {
  const pairAddr = await factory.getPair(tokenIn, tokenOut);
  if (!pairAddr || pairAddr === ethers.ZeroAddress) {
    // Genuine on-chain state: pool does not exist
    return { depthUsd: 0, reserveIn: 0n, reserveOut: 0n };
  }

  const pair = new ethers.Contract(pairAddr, PAIR_ABI, factory.runner);
  const [[r0, r1], t0] = await Promise.all([pair.getReserves(), pair.token0()]);

  const isToken0 = t0.toLowerCase() === tokenIn.toLowerCase();
  const resIn  = isToken0 ? r0 : r1;
  const resOut = isToken0 ? r1 : r0;

  const resInF  = parseFloat(ethers.formatUnits(resIn,  decIn));
  const resOutF = parseFloat(ethers.formatUnits(resOut, decOut));
  const depthUsd = priceIn  ? resInF  * priceIn
                 : priceOut ? resOutF * priceOut
                 : 0;

  return { depthUsd, reserveIn: resIn, reserveOut: resOut };
}

/** Real DEX quote via router getAmountsOut (includes pool fees). No simulation. */
async function getRouterQuote(router, tokenIn, tokenOut, amountIn) {
  const out = await router.getAmountsOut(amountIn, [tokenIn, tokenOut]);
  return out[1];
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-pair scan (real data only; throws on RPC failure so rotation can retry)
// ─────────────────────────────────────────────────────────────────────────────

async function scanPair(state, pair, env) {
  const { from, to, amount } = pair;
  const amountIn  = ethers.parseUnits(String(amount), from.decimals);
  const pairLabel = `${from.symbol}→${to.symbol}`;
  const priceIn   = from.usdPrice;
  const priceOut  = to.usdPrice;
  const { COL, results, gasCostUsd } = env;

  // ── 1. Fetch reserves + depth for both DEXes in parallel (live) ──────────
  const [qsDepth, ssDepth] = await Promise.all([
    getPoolDepth(state.ctx.qsFactory, from.addr, to.addr, from.decimals, to.decimals, priceIn, priceOut),
    getPoolDepth(state.ctx.ssFactory, from.addr, to.addr, from.decimals, to.decimals, priceIn, priceOut),
  ]);

  const qsDepthUsd = qsDepth.depthUsd;
  const ssDepthUsd = ssDepth.depthUsd;
  const maxDepth   = Math.max(qsDepthUsd, ssDepthUsd);

  // ── 2. Depth filter ────────────────────────────────────────────────────────
  if (maxDepth < MIN_EITHER_RESERVE_USD) {
    console.log(
      pad(pairLabel, COL[0]) +
      pad(`${amount} ${from.symbol}`, COL[1]) +
      pad("—", COL[2]) + pad("—", COL[3]) + pad("—", COL[4]) +
      pad("—", COL[5]) + pad("—", COL[6]) + pad("—", COL[7]) +
      "⚫ NO LIQUIDITY"
    );
    results.push({ pair: pairLabel, signal: "NO_LIQUIDITY", qsDepthUsd, ssDepthUsd });
    return;
  }

  // ── 3. Real router quotes (no CP-formula simulation fallback) ──────────────
  const qsOut = qsDepthUsd >= MIN_RESERVE_USD
    ? await getRouterQuote(state.ctx.qsRouter, from.addr, to.addr, amountIn)
    : null;
  const ssOut = ssDepthUsd >= MIN_RESERVE_USD
    ? await getRouterQuote(state.ctx.ssRouter, from.addr, to.addr, amountIn)
    : null;

  if (!qsOut && !ssOut) {
    console.log(
      pad(pairLabel, COL[0]) +
      pad(`${amount} ${from.symbol}`, COL[1]) +
      pad("—", COL[2]) + pad("—", COL[3]) + pad("—", COL[4]) +
      pad("—", COL[5]) + pad("—", COL[6]) + pad("—", COL[7]) +
      "⚫ QUOTE FAILED"
    );
    results.push({ pair: pairLabel, signal: "QUOTE_FAILED" });
    return;
  }

  const qsF = qsOut ? parseFloat(ethers.formatUnits(qsOut, to.decimals)) : null;
  const ssF = ssOut ? parseFloat(ethers.formatUnits(ssOut, to.decimals)) : null;

  // ── 4. Spread ──────────────────────────────────────────────────────────────
  const spreadPct = (qsF && ssF) ? pct(qsF, ssF) : null;

  if (spreadPct !== null && spreadPct < MIN_SPREAD_PCT) {
    console.log(
      pad(pairLabel, COL[0]) +
      pad(`${amount} ${from.symbol}`, COL[1]) +
      pad(`$${(qsDepthUsd/1000).toFixed(0)}K`, COL[2]) +
      pad(qsF?.toFixed(4) ?? "—", COL[3]) +
      pad(ssF?.toFixed(4) ?? "—", COL[4]) +
      pad(spreadPct.toFixed(4)+"%", COL[5]) +
      pad("—", COL[6]) + pad("—", COL[7]) +
      "⚪ FLAT"
    );
    results.push({ pair: pairLabel, signal: "FLAT", spreadPct, qsDepthUsd, ssDepthUsd });
    return;
  }

  // ── 5. USD spread value ────────────────────────────────────────────────────
  let spreadUsd = null;
  if (qsF !== null && ssF !== null) {
    const spreadUnits = Math.abs(qsF - ssF);
    const outPrice    = priceOut;
    if (outPrice) spreadUsd = spreadUnits * outPrice;
  }

  // ── 6. Net profit ──────────────────────────────────────────────────────────
  const loanNotionalUsd = priceIn ? amount * priceIn : null;
  const aaveFeeUsd      = loanNotionalUsd ? loanNotionalUsd * 0.0005 : null;
  const netProfit       = (spreadUsd !== null && gasCostUsd !== null && aaveFeeUsd !== null)
    ? spreadUsd - gasCostUsd - aaveFeeUsd
    : null;

  // ── 7. Slippage estimation ──────────────────────────────────────────────────
  // Estimate slippage as trade size / pool depth — rough but useful
  const tradeUsd      = priceIn ? amount * priceIn : 0;
  const sellSideDex   = (qsF && ssF && qsF > ssF) ? ssDepthUsd : qsDepthUsd;
  const slippageEst   = sellSideDex > 0 ? (tradeUsd / sellSideDex) * 100 : 99;
  const slippageCost  = spreadUsd !== null ? spreadUsd * (slippageEst / 100) : 0;

  // Adjust net profit for estimated slippage
  const netProfitAdj  = (netProfit !== null) ? netProfit - slippageCost : null;

  // ── 8. Phantom spread guard ──────────────────────────────────────────────
  // Stablecoin pairs (DAI↔USDC) with >20% spread are almost certainly phantom
  const isStablePair = (
    (from.symbol === "DAI" && to.symbol === "USDC") ||
    (from.symbol === "USDC" && to.symbol === "DAI")
  );
  const isPhantomStable = isStablePair && spreadPct !== null && spreadPct > 20;

  // ── 8b. Universal phantom guard ───────────────────────────────────────────
  // Compute spread vs LOAN NOTIONAL (not pool depth). >5% = phantom.
  const loanNotionalUsdCalc = priceIn ? amount * priceIn : 0;
  const spreadPctOfLoan = (spreadUsd !== null && loanNotionalUsdCalc > 0)
    ? (spreadUsd / loanNotionalUsdCalc) * 100 : 0;
  const isPhantomUniversal = spreadPctOfLoan > 5.0;  // 5% cap
  const isFlat = spreadPctOfLoan < 0.05;  // 0.05% floor

  // Unified phantom flag: stable OR universal — signal string and boolean
  // MUST always agree (fix for issues #93/#100/#102)
  const isPhantom = isPhantomUniversal || isPhantomStable;

  // ── 9. Tiered signal classification ──────────────────────────────────────
  const minDepthSide = Math.min(qsDepthUsd, ssDepthUsd);
  const depthOk      = minDepthSide >= MIN_RESERVE_USD;
  const depthWarning = !depthOk ? ` ⚠️ thin ($${(minDepthSide/1000).toFixed(0)}K)` : "";

  let signal;
  if (isPhantomUniversal) {
    signal = "👻 PHANTOM%";
  } else if (isPhantomStable) {
    signal = "👻 PHANTOM";
  } else if (isFlat) {
    signal = "⚪ FLAT";
  } else if (depthOk && netProfitAdj !== null && netProfitAdj > 2) {
    signal = "🟢 EXECUTE";
  } else if (!depthOk && netProfitAdj !== null && netProfitAdj > 2) {
    signal = "🟡 LOW DEPTH";
  } else if (netProfitAdj !== null && netProfitAdj > 0) {
    signal = "🟡 MARGINAL";
  } else if (netProfitAdj !== null) {
    signal = "🔴 UNPROFITABLE";
  } else if (spreadPct && spreadPct > 1) {
    signal = depthOk ? "🟡 CHECK" : "🟡 LOW DEPTH";
  } else {
    signal = "—";
  }

  const cheaperDex = qsF && ssF ? (qsF > ssF ? "QS" : "SS") : "—";

  results.push({
    pair: pairLabel, amount, signal, spreadPct, spreadPctOfLoan, spreadUsd, netProfit,
    netProfitAdj, slippageEst, isPhantom, isPhantomUniversal,
    qsDepthUsd, ssDepthUsd, cheaperDex, qsF, ssF,
  });

  console.log(
    pad(pairLabel,                                                          COL[0]) +
    pad(`${amount} ${from.symbol}`,                                        COL[1]) +
    pad(`$${(qsDepthUsd/1000).toFixed(0)}K / $${(ssDepthUsd/1000).toFixed(0)}K`, COL[2]) +
    pad(qsF !== null ? qsF.toFixed(4) : "N/A",                            COL[3]) +
    pad(ssF !== null ? ssF.toFixed(4) : "N/A",                            COL[4]) +
    pad(spreadPct !== null ? spreadPct.toFixed(4)+"%" : "N/A",            COL[5]) +
    pad(spreadUsd !== null ? "$"+spreadUsd.toFixed(2) : "N/A",            COL[6]) +
    pad(netProfitAdj !== null ? "$"+netProfitAdj.toFixed(2) : "N/A",      COL[7]) +
    signal + depthWarning
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────────────────────────

async function main() {
  // ── Connect: rotate RPC pool until a fresh endpoint is found ──────────────
  const state = mkState();
  const connected = await connectFresh(0);
  if (!connected) {
    throw new Error(`No fresh RPC endpoint available (head must be < ${MAX_BLOCK_AGE_S}s old). Pool: ${RPC_POOL.map(r => r[0]).join(", ")}`);
  }
  state.idx = connected.idx;
  state.rpc = connected;
  state.ctx = mkContracts(connected.provider);

  // ── Live prices (Chainlink, strict freshness) — rotate on failure ─────────
  const [maticUsd, ethUsd, btcUsd] = await Promise.all([
    withRotation(state, "Chainlink MATIC/USD", (ctx) => fetchChainlinkPrice(ctx.qsFactory.runner, CL_MATIC_USD, "MATIC/USD")),
    withRotation(state, "Chainlink ETH/USD",   (ctx) => fetchChainlinkPrice(ctx.qsFactory.runner, CL_ETH_USD,   "ETH/USD")),
    withRotation(state, "Chainlink BTC/USD",   (ctx) => fetchChainlinkPrice(ctx.qsFactory.runner, CL_BTC_USD,   "BTC/USD")),
  ]);

  // Patch token prices
  TOKENS.WMATIC.usdPrice = maticUsd;
  TOKENS.WETH.usdPrice   = ethUsd;

  // ── Gas (live fee data) ────────────────────────────────────────────────────
  const feeData = await withRotation(state, "fee data", (ctx) => ctx.qsFactory.runner.getFeeData());
  const gasPriceGwei = feeData.gasPrice
    ? parseFloat(ethers.formatUnits(feeData.gasPrice, "gwei"))
    : null;
  if (!gasPriceGwei) throw new Error("Live gas price unavailable — refusing to estimate with defaults");
  const GAS_UNITS    = 750_000;
  const gasCostMatic = parseFloat(ethers.formatUnits(feeData.gasPrice * BigInt(GAS_UNITS), 18));
  const gasCostUsd   = gasCostMatic * maticUsd;

  // ── Print header ────────────────────────────────────────────────────────────
  console.log("\n" + "═".repeat(120));
  console.log("  LIVE SPREAD SCANNER  —  Polygon Mainnet (real data only, rotating RPC)");
  console.log(`  Block: #${state.rpc.blockNumber}   |   ${new Date().toUTCString()}`);
  console.log(`  RPC: [${state.rpc.name}]  head age ${state.rpc.headAgeS}s  |  pool: ${RPC_POOL.map(r => r[0]).join(" → ")}`);
  console.log("═".repeat(120));
  console.log(`  MATIC $${maticUsd?.toFixed(4)}`+
              `   ETH $${ethUsd?.toFixed(0)}`+
              `   BTC $${btcUsd?.toFixed(0)}`+
              `   Gas ${gasPriceGwei.toFixed(1)} Gwei`+
              `   Est. tx cost $${gasCostUsd.toFixed(3)}`);
  console.log(`  Liquidity filter: skip pair if BOTH DEXes < $${MIN_RESERVE_USD.toLocaleString()} | universal phantom guard: spread >5% of loan`);
  console.log("─".repeat(120));

  const COL = [20, 14, 12, 14, 14, 12, 11, 10, 13];
  const HDR = ["Pair","Amount In","QS Depth","QS Out","SS Out","Spread %","Spread $","Net $","Signal"];
  console.log(HDR.map((h,i) => pad(h, COL[i])).join(""));
  console.log("─".repeat(120));

  const results = [];
  const env = { COL, results, gasCostUsd };

  for (const pair of SCAN_PAIRS) {
    try {
      await withRotation(state, `scan ${pair.from.symbol}→${pair.to.symbol} @${pair.amount}`, () =>
        scanPair(state, pair, env)
      );
    } catch (e) {
      // Every RPC failed for this pair — record honestly, no fabricated numbers
      const pairLabel = `${pair.from.symbol}→${pair.to.symbol}`;
      console.log(pad(pairLabel, COL[0]) + " ".repeat(COL[1]+COL[2]+COL[3]+COL[4]+COL[5]+COL[6]+COL[7]) + "❌ RPC_ERROR");
      results.push({ pair: pairLabel, amount: pair.amount, signal: "RPC_ERROR", error: e.message?.slice(0, 200) });
    }
  }

  // ── Summary ─────────────────────────────────────────────────────────────────
  console.log("═".repeat(120));
  console.log("\n  SUMMARY");
  console.log("─".repeat(60));

  const executable  = results.filter(r => r.signal === "🟢 EXECUTE");
  const lowDepth    = results.filter(r => r.signal === "🟡 LOW DEPTH");
  const marginal    = results.filter(r => r.signal === "🟡 MARGINAL");
  const phantom     = results.filter(r => r.signal.startsWith("👻 PHANTOM"));
  const rpcErrors   = results.filter(r => r.signal === "RPC_ERROR");

  if (executable.length) {
    console.log("  🟢 Execute now:");
    for (const r of executable) {
      console.log(`     ${pad(r.pair,18)} cheaper: ${r.cheaperDex}   spread $${r.spreadUsd?.toFixed(2)}   net ~$${r.netProfitAdj?.toFixed(2)} (slip ${r.slippageEst?.toFixed(1)}%)   QS $${(r.qsDepthUsd/1000).toFixed(0)}K / SS $${(r.ssDepthUsd/1000).toFixed(0)}K`);
    }
  }
  if (lowDepth.length) {
    console.log("  🟡 Promising — depth below threshold:");
    for (const r of lowDepth) {
      console.log(`     ${pad(r.pair,18)} spread $${r.spreadUsd?.toFixed(2)}   adj net ~$${r.netProfitAdj?.toFixed(2)}   QS $${(r.qsDepthUsd/1000).toFixed(0)}K / SS $${(r.ssDepthUsd/1000).toFixed(0)}K`);
    }
  }
  if (marginal.length) {
    console.log("  🟡 Marginal (adj for slippage):");
    for (const r of marginal) {
      console.log(`     ${pad(r.pair,18)} net ~$${r.netProfitAdj?.toFixed(2)}   slip est ${r.slippageEst?.toFixed(1)}%`);
    }
  }
  if (phantom.length) {
    console.log("  👻 Phantom spreads (spread >5% of loan notional — thin pools, not real arb):");
    for (const r of phantom) {
      console.log(`     ${pad(r.pair,18)} spread ${r.spreadPct?.toFixed(1)}% — SS $${(r.ssDepthUsd/1000).toFixed(0)}K depth likely empty`);
    }
  }
  if (rpcErrors.length) {
    console.log("  ❌ RPC errors (all endpoints failed — NOT simulated):");
    for (const r of rpcErrors) {
      console.log(`     ${pad(r.pair,18)} ${r.error}`);
    }
  }
  if (!executable.length && !lowDepth.length && !marginal.length && !rpcErrors.length) {
    console.log("  🔴 No profitable opportunities at current spreads and gas.");
  }

  console.log(`\n  Pairs scanned: ${results.length}`);
  console.log(`  RPC in use:    [${state.rpc.name}]  (rotated on failure)`);
  console.log(`  Depth filter:  skip < $${MIN_RESERVE_USD.toLocaleString()} per DEX side`);
  console.log(`  Gas:           ${gasPriceGwei.toFixed(1)} Gwei  |  est. tx $${gasCostUsd?.toFixed(3) ?? "?"}`);
  console.log(`  Timestamp:     ${new Date().toISOString()}`);
  console.log("═".repeat(120) + "\n");
}

main().catch(err => {
  console.error("❌ Scan failed:", err.message);
  process.exit(1);
});
