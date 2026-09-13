/**
 * scan-and-log.js — Runs the live spread scan and outputs JSONL to logs/opportunities-YYYY-MM-DD.jsonl
 * Based on scripts/live-spread-scan.js from zflip19888-svg/The-Flash-Loan
 */
require("dotenv").config();
const fs = require("fs");
const path = require("path");
const { ethers } = require("ethers");

// ─── Config ──────────────────────────────────────────────────────────────────
const RPC_URL = process.env.POLYGON_RPC_URL || "https://1rpc.io/matic";
const MIN_RESERVE_USD = 15_000;
const MIN_EITHER_RESERVE_USD = 15_000;
const MIN_SPREAD_PCT = 0.02;

const QUICKSWAP_ROUTER  = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";
const SUSHISWAP_ROUTER  = "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506";
const QUICKSWAP_FACTORY = "0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32";
const SUSHISWAP_FACTORY = "0xc35DADB65012eC5796536bD9864eD8773aBc74C4";
const CL_MATIC_USD      = "0xAB594600376Ec9fD91F8e885dADF0CE036862dE0";
const CL_ETH_USD        = "0xF9680D99D6C9589e2a93a78A04A279e509205945";
const CL_BTC_USD        = "0xc907E116054Ad103354f2D350FD2514433D57F6f";

const TOKENS = {
  USDC:   { addr: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", decimals: 6,  symbol: "USDC",   usdPrice: 1.0 },
  WMATIC: { addr: "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270", decimals: 18, symbol: "WMATIC", usdPrice: null },
  WETH:   { addr: "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619", decimals: 18, symbol: "WETH",   usdPrice: null },
  DAI:    { addr: "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063", decimals: 18, symbol: "DAI",    usdPrice: 1.0 },
};

const SCAN_PAIRS = [
  { from: TOKENS.WETH,   to: TOKENS.USDC,   amount: 10,     label: 'WETH→USDC (borrow WETH)' },
  { from: TOKENS.WETH,   to: TOKENS.USDC,   amount: 15,     label: 'WETH→USDC (15 ETH)' },
  { from: TOKENS.WETH,   to: TOKENS.WMATIC, amount: 10,     label: 'WETH→USDC→WMATIC (via WETH borrow)' },
  { from: TOKENS.WMATIC, to: TOKENS.USDC,   amount: 30_000,  label: 'WMATIC→USDC' },
  { from: TOKENS.WMATIC, to: TOKENS.USDC,   amount: 50_000,  label: 'WMATIC→USDC (50K)' },
];

// ─── ABIs ─────────────────────────────────────────────────────────────────────
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

// ─── Helpers ──────────────────────────────────────────────────────────────────
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

async function getPoolDepth(factory, tokenIn, tokenOut, decIn, decOut, priceIn, priceOut) {
  try {
    const pairAddr = await factory.getPair(tokenIn, tokenOut);
    if (!pairAddr || pairAddr === ethers.ZeroAddress) return { depthUsd: 0, reserveIn: 0n, reserveOut: 0n };
    const pair = new ethers.Contract(pairAddr, PAIR_ABI, factory.runner);
    const [[r0, r1], t0] = await Promise.all([pair.getReserves(), pair.token0()]);
    const isToken0 = t0.toLowerCase() === tokenIn.toLowerCase();
    const resIn  = isToken0 ? r0 : r1;
    const resOut = isToken0 ? r1 : r0;
    const resInF  = parseFloat(ethers.formatUnits(resIn, decIn));
    const resOutF = parseFloat(ethers.formatUnits(resOut, decOut));
    const depthUsd = priceIn ? resInF * priceIn : priceOut ? resOutF * priceOut : 0;
    return { depthUsd, reserveIn: resIn, reserveOut: resOut };
  } catch {
    return { depthUsd: 0, reserveIn: 0n, reserveOut: 0n };
  }
}

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

// ─── Main ─────────────────────────────────────────────────────────────────────
async function main() {
  const provider = new ethers.JsonRpcProvider(RPC_URL);

  const [blockNumber, feeData] = await Promise.all([
    provider.getBlockNumber(),
    provider.getFeeData(),
  ]);

  const [maticUsd, ethUsd, btcUsd] = await Promise.all([
    fetchChainlinkPrice(provider, CL_MATIC_USD),
    fetchChainlinkPrice(provider, CL_ETH_USD),
    fetchChainlinkPrice(provider, CL_BTC_USD),
  ]);

  TOKENS.WMATIC.usdPrice = maticUsd;
  TOKENS.WETH.usdPrice  = ethUsd;

  const gasPriceGwei = feeData.gasPrice
    ? parseFloat(ethers.formatUnits(feeData.gasPrice, "gwei"))
    : 100;
  const GAS_UNITS = 750_000;
  const gasCostMatic = feeData.gasPrice
    ? parseFloat(ethers.formatUnits(feeData.gasPrice * BigInt(GAS_UNITS), 18))
    : null;
  const gasCostUsd = gasCostMatic && maticUsd ? gasCostMatic * maticUsd : null;

  const qsRouter  = new ethers.Contract(QUICKSWAP_ROUTER, ROUTER_ABI, provider);
  const ssRouter  = new ethers.Contract(SUSHISWAP_ROUTER, ROUTER_ABI, provider);
  const qsFactory = new ethers.Contract(QUICKSWAP_FACTORY, FACTORY_ABI, provider);
  const ssFactory = new ethers.Contract(SUSHISWAP_FACTORY, FACTORY_ABI, provider);

  const ts = new Date().toISOString();
  const results = [];

  for (const pair of SCAN_PAIRS) {
    const { from, to, amount } = pair;
    const amountIn  = ethers.parseUnits(String(amount), from.decimals);
    const pairLabel = `${from.symbol}→${to.symbol}`;
    const priceIn   = from.usdPrice;
    const priceOut  = to.usdPrice;

    const [qsDepth, ssDepth] = await Promise.all([
      getPoolDepth(qsFactory, from.addr, to.addr, from.decimals, to.decimals, priceIn, priceOut),
      getPoolDepth(ssFactory, from.addr, to.addr, from.decimals, to.decimals, priceIn, priceOut),
    ]);

    const qsDepthUsd = qsDepth.depthUsd;
    const ssDepthUsd = ssDepth.depthUsd;
    const maxDepth   = Math.max(qsDepthUsd, ssDepthUsd);

    if (maxDepth < MIN_EITHER_RESERVE_USD) {
      results.push({ ts, blockNumber, pair: pairLabel, amount, signal: "⚫ NO_LIQUIDITY",
        spreadPct: 0, spreadUsd: 0, netProfit: 0, netProfitAdj: 0, executed: false, dryRun: true });
      continue;
    }

    const [qsRouterOut, ssRouterOut] = await Promise.all([
      qsDepthUsd >= MIN_RESERVE_USD ? getRouterQuote(qsRouter, from.addr, to.addr, amountIn) : Promise.resolve(null),
      ssDepthUsd >= MIN_RESERVE_USD ? getRouterQuote(ssRouter, from.addr, to.addr, amountIn) : Promise.resolve(null),
    ]);

    const qsOut = qsRouterOut
      ?? (qsDepth.reserveIn > 0n ? cpQuote(amountIn, qsDepth.reserveIn, qsDepth.reserveOut) : null);
    const ssOut = ssRouterOut
      ?? (ssDepth.reserveIn > 0n ? cpQuote(amountIn, ssDepth.reserveIn, ssDepth.reserveOut) : null);

    if (!qsOut && !ssOut) {
      results.push({ ts, blockNumber, pair: pairLabel, amount, signal: "⚫ QUOTE_FAILED",
        spreadPct: 0, spreadUsd: 0, netProfit: 0, netProfitAdj: 0, executed: false, dryRun: true });
      continue;
    }

    const qsF = qsOut ? parseFloat(ethers.formatUnits(qsOut, to.decimals)) : null;
    const ssF = ssOut ? parseFloat(ethers.formatUnits(ssOut, to.decimals)) : null;

    const spreadPct = (qsF && ssF) ? pct(qsF, ssF) : null;

    if (spreadPct !== null && spreadPct < MIN_SPREAD_PCT) {
      const loanNotionalUsd = priceIn ? amount * priceIn : 0;
      const aaveFeeUsd = loanNotionalUsd * 0.0005;
      results.push({ ts, blockNumber, pair: pairLabel, amount, signal: "⚪ FLAT",
        spreadPct, spreadPctOfLoan: 0, spreadUsd: 0, netProfit: null, netProfitAdj: null,
        slippageEst: 0, slippagePct: 0, isPhantom: false, phantom: false,
        aaveFeeUsd, loanNotionalUsd, gasGwei: gasPriceGwei, gasCostUsd,
        qsDepthUsd, ssDepthUsd, cheaperDex: "—", qsF, ssF, executed: false, dryRun: true });
      continue;
    }

    let spreadUsd = null;
    if (qsF !== null && ssF !== null) {
      spreadUsd = Math.abs(qsF - ssF) * (priceOut || 0);
    }

    const loanNotionalUsd = priceIn ? amount * priceIn : null;
    const aaveFeeUsd = loanNotionalUsd ? loanNotionalUsd * 0.0005 : null;
    const netProfit = (spreadUsd !== null && gasCostUsd !== null && aaveFeeUsd !== null)
      ? spreadUsd - gasCostUsd - aaveFeeUsd : null;

    const tradeUsd = priceIn ? amount * priceIn : 0;
    const sellSideDex = (qsF && ssF && qsF > ssF) ? ssDepthUsd : qsDepthUsd;
    const slippageEst = sellSideDex > 0 ? (tradeUsd / sellSideDex) * 100 : 99;
    const slippageCost = spreadUsd !== null ? spreadUsd * (slippageEst / 100) : 0;
    const netProfitAdj = (netProfit !== null) ? netProfit - slippageCost : null;

    const loanNotionalUsdCalc = priceIn ? amount * priceIn : 0;
    const spreadPctOfLoan = (spreadUsd !== null && loanNotionalUsdCalc > 0)
      ? (spreadUsd / loanNotionalUsdCalc) * 100 : 0;
    const isPhantomUniversal = spreadPctOfLoan > 5.0;
    const isFlat = spreadPctOfLoan < 0.05;

    const isStablePair = (
      (from.symbol === "DAI" && to.symbol === "USDC") ||
      (from.symbol === "USDC" && to.symbol === "DAI")
    );
    const isPhantom = isStablePair && spreadPct !== null && spreadPct > 20;

    const minDepthSide = Math.min(qsDepthUsd, ssDepthUsd);
    const depthOk = minDepthSide >= MIN_RESERVE_USD;

    let signal;
    if (isPhantomUniversal) {
      signal = "👻 PHANTOM%";
    } else if (isPhantom) {
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
      ts, blockNumber, pair: pairLabel, amount, signal,
      spreadPct, spreadPctOfLoan, spreadUsd, netProfit, netProfitAdj,
      slippageEst, slippagePct: slippageEst,
      isPhantom, phantom: isPhantom,
      aaveFeeUsd, loanNotionalUsd,
      gasGwei: gasPriceGwei, gasCostUsd,
      qsDepthUsd, ssDepthUsd,
      cheaperDex, qsF, ssF,
      executed: false, dryRun: true,
    });
  }

  // Print summary
  console.log(`\n  Scan complete — Block #${blockNumber} | ${ts}`);
  console.log(`  MATIC $${maticUsd?.toFixed(4) ?? "?"}  ETH $${ethUsd?.toFixed(0) ?? "?"}  Gas ${gasPriceGwei.toFixed(1)} Gwei`);
  console.log(`  Pairs scanned: ${results.length}`);
  for (const r of results) {
    console.log(`    ${r.signal}  ${(r.pair || '').padEnd(14)}  spread ${r.spreadPct?.toFixed(2) ?? 'N/A'}%  net $${r.netProfitAdj?.toFixed(2) ?? 'N/A'}`);
  }

  const executable = results.filter(r => r.signal === "🟢 EXECUTE");
  const phantom = results.filter(r => r.signal?.includes("PHANTOM"));
  console.log(`\n  🟢 Executable: ${executable.length}  👻 Phantom: ${phantom.length}`);
  console.log(`  Non-executable: ${results.length - executable.length}\n`);

  // Write JSONL — use UTC date for filename
  const utcDate = new Date().toISOString().slice(0, 10);
  const filename = `logs/opportunities-${utcDate}.jsonl`;
  fs.mkdirSync(path.dirname(filename), { recursive: true });
  const jsonl = results.map(r => JSON.stringify(r)).join("\n") + "\n";
  fs.writeFileSync(filename, jsonl);
  console.log(`  Wrote ${results.length} entries to ${filename}`);

  return { filename, results, blockNumber, maticUsd, ethUsd, gasPriceGwei, executable, phantom };
}

main().catch(err => {
  console.error("❌ Scan failed:", err.message);
  process.exit(1);
});
