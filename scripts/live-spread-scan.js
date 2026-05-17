/**
 * @file live-spread-scan.js
 * @notice Live spread scanner with liquidity depth filtering.
 *
 * Skips any pair where either DEX has < MIN_RESERVE_USD liquidity on either
 * side — prevents phantom spreads caused by shallow/empty pools.
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

const RPC_URL = process.env.POLYGON_RPC_URL || "https://1rpc.io/matic";

/** Skip a DEX side if USD reserve depth is below this */
const MIN_RESERVE_USD = 40_000;

/** Skip a pair entirely if BOTH DEXes have reserve < this (no market) */
const MIN_EITHER_RESERVE_USD = 10_000;

/** Minimum spread % to bother estimating profit */
const MIN_SPREAD_PCT = 0.05;

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
  WBTC:  { addr: "0x1bfd67037b42cf73acf2047067bd4f2c47d9bfd6", decimals: 8,  symbol: "WBTC",  usdPrice: null },
};

const SCAN_PAIRS = [
  { from: TOKENS.USDC,   to: TOKENS.WMATIC, amount: 10_000 },
  { from: TOKENS.WMATIC, to: TOKENS.USDC,   amount: 20_000 },
  { from: TOKENS.USDC,   to: TOKENS.WETH,   amount: 10_000 },
  { from: TOKENS.WETH,   to: TOKENS.USDC,   amount: 5      },
  { from: TOKENS.DAI,    to: TOKENS.USDC,   amount: 10_000 },
  { from: TOKENS.USDC,   to: TOKENS.DAI,    amount: 10_000 },
  { from: TOKENS.WBTC,   to: TOKENS.USDC,   amount: 0.2    },
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

async function fetchChainlinkPrice(provider, feed) {
  try {
    const c = new ethers.Contract(feed, CL_ABI, provider);
    const [[, answer, , updatedAt], decimals] = await Promise.all([
      c.latestRoundData(), c.decimals(),
    ]);
    const age = Math.floor(Date.now() / 1000) - Number(updatedAt);
    if (age > 3600) return null;
    return Number(answer) / 10 ** Number(decimals);
  } catch { return null; }
}

// ─────────────────────────────────────────────────────────────────────────────
// Core: fetch pair reserves + compute USD depth
// ─────────────────────────────────────────────────────────────────────────────

async function getPoolDepth(factory, tokenIn, tokenOut, decIn, decOut, priceIn, priceOut) {
  try {
    const pairAddr = await factory.getPair(tokenIn, tokenOut);
    if (!pairAddr || pairAddr === ethers.ZeroAddress) return { depthUsd: 0, reserveIn: 0n, reserveOut: 0n };

    const pair = new ethers.Contract(pairAddr, PAIR_ABI, factory.runner);
    const [[r0, r1], t0] = await Promise.all([pair.getReserves(), pair.token0()]);

    const isToken0 = t0.toLowerCase() === tokenIn.toLowerCase();
    const resIn  = isToken0 ? r0 : r1;
    const resOut = isToken0 ? r1 : r0;

    // USD value of tokenIn side
    const resInF   = parseFloat(ethers.formatUnits(resIn,  decIn));
    const resOutF  = parseFloat(ethers.formatUnits(resOut, decOut));
    const depthUsd = priceIn  ? resInF  * priceIn
                   : priceOut ? resOutF * priceOut
                   : 0;

    return { depthUsd, reserveIn: resIn, reserveOut: resOut, resInF, resOutF };
  } catch {
    return { depthUsd: 0, reserveIn: 0n, reserveOut: 0n };
  }
}

// Quote using constant-product formula against on-chain reserves (no slippage model needed)
function cpQuote(amountIn, reserveIn, reserveOut) {
  if (reserveIn === 0n || reserveOut === 0n) return null;
  const num = amountIn * reserveOut;
  const den = reserveIn + amountIn;
  return num / den;
}

async function getRouterQuote(router, tokenIn, tokenOut, amountIn) {
  try {
    const out = await router.getAmountsOut(amountIn, [tokenIn, tokenOut]);
    return out[1];
  } catch { return null; }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────────────────────────

async function main() {
  const provider = new ethers.JsonRpcProvider(RPC_URL);

  // Verify connection
  const [blockNumber, feeData] = await Promise.all([
    provider.getBlockNumber(),
    provider.getFeeData(),
  ]);

  // Fetch live prices
  const [maticUsd, ethUsd, btcUsd] = await Promise.all([
    fetchChainlinkPrice(provider, CL_MATIC_USD),
    fetchChainlinkPrice(provider, CL_ETH_USD),
    fetchChainlinkPrice(provider, CL_BTC_USD),
  ]);

  // Patch token prices
  TOKENS.WMATIC.usdPrice = maticUsd;
  TOKENS.WETH.usdPrice   = ethUsd;
  TOKENS.WBTC.usdPrice   = btcUsd;

  const gasPriceGwei = feeData.gasPrice
    ? parseFloat(ethers.formatUnits(feeData.gasPrice, "gwei"))
    : 100;
  const GAS_UNITS    = 750_000;
  const gasCostMatic = feeData.gasPrice
    ? parseFloat(ethers.formatUnits(feeData.gasPrice * BigInt(GAS_UNITS), 18))
    : null;
  const gasCostUsd   = gasCostMatic && maticUsd ? gasCostMatic * maticUsd : null;

  // Contracts
  const qsRouter  = new ethers.Contract(QUICKSWAP_ROUTER,  ROUTER_ABI,  provider);
  const ssRouter  = new ethers.Contract(SUSHISWAP_ROUTER,  ROUTER_ABI,  provider);
  const qsFactory = new ethers.Contract(QUICKSWAP_FACTORY, FACTORY_ABI, provider);
  const ssFactory = new ethers.Contract(SUSHISWAP_FACTORY, FACTORY_ABI, provider);

  // ── Print header ────────────────────────────────────────────────────────────
  console.log("\n" + "═".repeat(120));
  console.log("  LIVE SPREAD SCANNER  —  Polygon Mainnet");
  console.log(`  Block: #${blockNumber}   |   ${new Date().toUTCString()}`);
  console.log("═".repeat(120));
  console.log(`  MATIC $${maticUsd?.toFixed(4) ?? "?"}`+
              `   ETH $${ethUsd?.toFixed(0) ?? "?"}`+
              `   BTC $${btcUsd?.toFixed(0) ?? "?"}`+
              `   Gas ${gasPriceGwei.toFixed(1)} Gwei`+
              `   Est. tx cost ${gasCostUsd ? "$"+gasCostUsd.toFixed(3) : "?"}`);
  console.log(`  Liquidity filter: skip if depth < $${MIN_RESERVE_USD.toLocaleString()} on either DEX side`);
  console.log("─".repeat(120));

  const COL = [20, 14, 12, 14, 14, 12, 11, 10, 13];
  const HDR = ["Pair","Amount In","QS Depth","QS Out","SS Out","Spread %","Spread $","Net $","Signal"];
  console.log(HDR.map((h,i) => pad(h, COL[i])).join(""));
  console.log("─".repeat(120));

  const results = [];

  for (const pair of SCAN_PAIRS) {
    const { from, to, amount } = pair;
    const amountIn  = ethers.parseUnits(String(amount), from.decimals);
    const pairLabel = `${from.symbol}→${to.symbol}`;
    const priceIn   = from.usdPrice;
    const priceOut  = to.usdPrice;

    // ── 1. Fetch reserves + depth for both DEXes in parallel ──────────────────
    const [qsDepth, ssDepth] = await Promise.all([
      getPoolDepth(qsFactory, from.addr, to.addr, from.decimals, to.decimals, priceIn, priceOut),
      getPoolDepth(ssFactory, from.addr, to.addr, from.decimals, to.decimals, priceIn, priceOut),
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
      continue;
    }

    // ── 3. Get quotes ──────────────────────────────────────────────────────────
    // Use router quote where depth is sufficient, else mark N/A
    const [qsRouterOut, ssRouterOut] = await Promise.all([
      qsDepthUsd >= MIN_RESERVE_USD ? getRouterQuote(qsRouter, from.addr, to.addr, amountIn) : Promise.resolve(null),
      ssDepthUsd >= MIN_RESERVE_USD ? getRouterQuote(ssRouter, from.addr, to.addr, amountIn) : Promise.resolve(null),
    ]);

    // Fallback to CP formula if router call failed but depth is present
    const qsOut = qsRouterOut
      ?? (qsDepth.reserveIn > 0n ? cpQuote(amountIn, qsDepth.reserveIn, qsDepth.reserveOut) : null);
    const ssOut = ssRouterOut
      ?? (ssDepth.reserveIn > 0n ? cpQuote(amountIn, ssDepth.reserveIn, ssDepth.reserveOut) : null);

    if (!qsOut && !ssOut) {
      console.log(
        pad(pairLabel, COL[0]) +
        pad(`${amount} ${from.symbol}`, COL[1]) +
        pad("—", COL[2]) + pad("—", COL[3]) + pad("—", COL[4]) +
        pad("—", COL[5]) + pad("—", COL[6]) + pad("—", COL[7]) +
        "⚫ QUOTE FAILED"
      );
      results.push({ pair: pairLabel, signal: "QUOTE_FAILED" });
      continue;
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
      continue;
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

    // ── 7. Depth-adjusted viability ────────────────────────────────────────────
    // Even if spread looks good, flag if the thinner DEX has < MIN_RESERVE_USD
    const depthWarning = (qsDepthUsd < MIN_RESERVE_USD || ssDepthUsd < MIN_RESERVE_USD)
      ? " ⚠️ shallow" : "";

    // Signal
    let signal;
    if (depthWarning && netProfit !== null && netProfit > 5) {
      signal = "🟡 VERIFY DEPTH";
    } else if (netProfit !== null && netProfit > 5) {
      signal = "🟢 EXECUTE";
    } else if (netProfit !== null && netProfit > 0) {
      signal = "🟡 MARGINAL";
    } else if (netProfit !== null) {
      signal = "🔴 UNPROFITABLE";
    } else if (spreadPct && spreadPct > 1) {
      signal = depthWarning ? "🟡 VERIFY DEPTH" : "🟡 CHECK";
    } else {
      signal = "—";
    }

    const cheaperDex = qsF && ssF ? (qsF > ssF ? "QS" : "SS") : "—";

    results.push({
      pair: pairLabel, amount, signal, spreadPct, spreadUsd, netProfit,
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
      pad(netProfit !== null ? "$"+netProfit.toFixed(2) : "N/A",            COL[7]) +
      signal + depthWarning
    );
  }

  // ── Summary ─────────────────────────────────────────────────────────────────
  console.log("═".repeat(120));
  console.log("\n  SUMMARY");
  console.log("─".repeat(60));

  const executable  = results.filter(r => r.signal === "🟢 EXECUTE");
  const verifyDepth = results.filter(r => r.signal === "🟡 VERIFY DEPTH");
  const marginal    = results.filter(r => r.signal === "🟡 MARGINAL");

  if (executable.length) {
    console.log("  🟢 Execute:");
    for (const r of executable) {
      console.log(`     ${pad(r.pair,18)} cheaper: ${r.cheaperDex}   spread $${r.spreadUsd?.toFixed(2)}   net ~$${r.netProfit?.toFixed(2)}   QS depth $${(r.qsDepthUsd/1000).toFixed(0)}K / SS $${(r.ssDepthUsd/1000).toFixed(0)}K`);
    }
  }
  if (verifyDepth.length) {
    console.log("  🟡 Verify depth before executing:");
    for (const r of verifyDepth) {
      console.log(`     ${pad(r.pair,18)} spread $${r.spreadUsd?.toFixed(2)}   QS $${(r.qsDepthUsd/1000).toFixed(0)}K / SS $${(r.ssDepthUsd/1000).toFixed(0)}K`);
    }
  }
  if (marginal.length) {
    console.log("  🟡 Marginal:");
    for (const r of marginal) {
      console.log(`     ${pad(r.pair,18)} net ~$${r.netProfit?.toFixed(2)}`);
    }
  }
  if (!executable.length && !verifyDepth.length && !marginal.length) {
    console.log("  🔴 No profitable opportunities at current spreads and gas.");
  }

  console.log(`\n  Pairs scanned: ${results.length}`);
  console.log(`  Depth filter:  skip < $${MIN_RESERVE_USD.toLocaleString()} per DEX side`);
  console.log(`  Gas:           ${gasPriceGwei.toFixed(1)} Gwei  |  est. tx $${gasCostUsd?.toFixed(3) ?? "?"}`);
  console.log(`  Timestamp:     ${new Date().toISOString()}`);
  console.log("═".repeat(120) + "\n");
}

main().catch(err => {
  console.error("❌ Scan failed:", err.message);
  process.exit(1);
});
