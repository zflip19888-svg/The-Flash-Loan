/**
 * @file live-spread-scan.js
 * @notice Live spread scanner — queries real QuickSwap & SushiSwap reserves
 *         directly via public Polygon RPC. No wallet, no gas, read-only.
 *
 * Run:
 *   node scripts/live-spread-scan.js
 *   RPC=https://your-node.com node scripts/live-spread-scan.js
 */

const { ethers } = require("ethers");

// ─────────────────────────────────────────────────────────────────────────────
// Config
// ─────────────────────────────────────────────────────────────────────────────

// Public Polygon RPCs (tried in order)
const PUBLIC_RPCS = [
  "https://polygon-rpc.com",
  "https://rpc-mainnet.matic.network",
  "https://rpc.ankr.com/polygon",
  "https://1rpc.io/matic",
];

const RPC_URL = process.env.RPC || process.env.POLYGON_RPC_URL || null;

const QUICKSWAP_ROUTER  = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";
const SUSHISWAP_ROUTER  = "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506";
const QUICKSWAP_FACTORY = "0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32";
const SUSHISWAP_FACTORY = "0xc35DADB65012eC5796536bD9864eD8773aBc74C4";
const CL_MATIC_USD      = "0xAB594600376Ec9fD91F8e885dADF0CE036862dE0";

const TOKENS = {
  USDC:  { addr: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", decimals: 6,  symbol: "USDC"  },
  WMATIC:{ addr: "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270", decimals: 18, symbol: "WMATIC"},
  WETH:  { addr: "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619", decimals: 18, symbol: "WETH"  },
  DAI:   { addr: "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063", decimals: 18, symbol: "DAI"   },
  WBTC:  { addr: "0x1bfd67037b42cf73acf2047067bd4f2c47d9bfd6", decimals: 8,  symbol: "WBTC"  },
};

const PAIRS = [
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

function fmt(val, decimals, displayDecimals = 6) {
  return parseFloat(ethers.formatUnits(val, decimals)).toFixed(displayDecimals);
}

function pct(a, b) {
  // spread % of the larger price
  const diff = Math.abs(a - b);
  const base = Math.max(a, b);
  return base === 0 ? 0 : (diff / base) * 100;
}

function pad(str, len) {
  return String(str).padEnd(len, " ");
}

// ─────────────────────────────────────────────────────────────────────────────
// RPC connection — try multiple providers
// ─────────────────────────────────────────────────────────────────────────────

async function connectProvider() {
  const urls = RPC_URL ? [RPC_URL, ...PUBLIC_RPCS] : PUBLIC_RPCS;
  for (const url of urls) {
    try {
      const p = new ethers.JsonRpcProvider(url);
      const block = await Promise.race([
        p.getBlockNumber(),
        new Promise((_, rej) => setTimeout(() => rej(new Error("timeout")), 5000)),
      ]);
      console.log(`✅ Connected: ${url}  (block #${block})\n`);
      return p;
    } catch {
      console.log(`   ⚠️  ${url} — unreachable, trying next…`);
    }
  }
  throw new Error("All RPC endpoints failed. Set RPC=https://... env var.");
}

// ─────────────────────────────────────────────────────────────────────────────
// Price queries
// ─────────────────────────────────────────────────────────────────────────────

async function getAmountOut(router, tokenIn, tokenOut, amountIn) {
  try {
    const amounts = await router.getAmountsOut(amountIn, [tokenIn, tokenOut]);
    return amounts[1];
  } catch {
    return null;
  }
}

async function getReservePrices(factory, tokenIn, tokenOut, amountIn, decIn, decOut) {
  try {
    const pairAddr = await factory.getPair(tokenIn, tokenOut);
    if (!pairAddr || pairAddr === ethers.ZeroAddress) return null;

    const pairContract = new ethers.Contract(pairAddr, PAIR_ABI, factory.runner);
    const [r0, r1] = await pairContract.getReserves();
    const t0 = await pairContract.token0();

    let resIn, resOut;
    if (t0.toLowerCase() === tokenIn.toLowerCase()) {
      resIn = r0; resOut = r1;
    } else {
      resIn = r1; resOut = r0;
    }

    if (resIn === 0n || resOut === 0n) return null;

    // Constant product: amountOut = (amountIn * resOut) / (resIn + amountIn)
    const amtOut = (amountIn * resOut) / (resIn + amountIn);
    return amtOut;
  } catch {
    return null;
  }
}

async function getMaticUsd(provider) {
  try {
    const feed = new ethers.Contract(CL_MATIC_USD, CL_ABI, provider);
    const [[, answer, , updatedAt], decimals] = await Promise.all([
      feed.latestRoundData(),
      feed.decimals(),
    ]);
    const age = Math.floor(Date.now() / 1000) - Number(updatedAt);
    if (age > 3600) return null;
    return Number(answer) / 10 ** Number(decimals);
  } catch {
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────────────────────────

async function main() {
  console.log("═══════════════════════════════════════════════════════════════");
  console.log("  LIVE SPREAD SCANNER — Polygon Mainnet");
  console.log(`  ${new Date().toUTCString()}`);
  console.log("═══════════════════════════════════════════════════════════════\n");

  const provider = await connectProvider();

  const qsRouter  = new ethers.Contract(QUICKSWAP_ROUTER,  ROUTER_ABI,  provider);
  const ssRouter  = new ethers.Contract(SUSHISWAP_ROUTER,  ROUTER_ABI,  provider);
  const qsFactory = new ethers.Contract(QUICKSWAP_FACTORY, FACTORY_ABI, provider);
  const ssFactory = new ethers.Contract(SUSHISWAP_FACTORY, FACTORY_ABI, provider);

  const maticUsd = await getMaticUsd(provider);
  if (maticUsd) {
    console.log(`📡 Chainlink MATIC/USD: $${maticUsd.toFixed(4)}`);
  } else {
    console.log("📡 Chainlink MATIC/USD: unavailable");
  }

  const gasPrice  = await provider.getFeeData();
  const gasPriceGwei = gasPrice.gasPrice
    ? parseFloat(ethers.formatUnits(gasPrice.gasPrice, "gwei")).toFixed(1)
    : "?";
  console.log(`⛽ Gas price: ${gasPriceGwei} Gwei`);
  console.log();

  // Estimate gas cost of one flash loan execution
  const GAS_UNITS = 750_000;
  const gasCostMatic = gasPrice.gasPrice
    ? parseFloat(ethers.formatUnits(gasPrice.gasPrice * BigInt(GAS_UNITS), 18))
    : null;
  const gasCostUsd = gasCostMatic && maticUsd ? gasCostMatic * maticUsd : null;

  // ─────────────────────────────────────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────────────────────────────────────
  console.log(
    pad("Pair", 18) +
    pad("Amount In", 14) +
    pad("QuickSwap Out", 18) +
    pad("SushiSwap Out", 18) +
    pad("Spread %", 12) +
    pad("Spread USD", 14) +
    "Signal"
  );
  console.log("─".repeat(110));

  const results = [];

  for (const pair of PAIRS) {
    const { from, to, amount } = pair;
    const amountIn = ethers.parseUnits(String(amount), from.decimals);

    const [qsOut, ssOut] = await Promise.all([
      getAmountOut(qsRouter, from.addr, to.addr, amountIn),
      getAmountOut(ssRouter, from.addr, to.addr, amountIn),
    ]);

    // Fallback to reserve-based estimate if router failed
    const qsAmt = qsOut ?? await getReservePrices(qsFactory, from.addr, to.addr, amountIn, from.decimals, to.decimals);
    const ssAmt = ssOut ?? await getReservePrices(ssFactory, from.addr, to.addr, amountIn, from.decimals, to.decimals);

    const pairName = `${from.symbol}→${to.symbol}`;

    if (!qsAmt && !ssAmt) {
      console.log(pad(pairName, 18) + pad(`${amount} ${from.symbol}`, 14) + "No liquidity on either DEX");
      continue;
    }

    const qsF = qsAmt ? parseFloat(ethers.formatUnits(qsAmt, to.decimals)) : null;
    const ssF = ssAmt ? parseFloat(ethers.formatUnits(ssAmt, to.decimals)) : null;

    const spreadPct = qsF && ssF ? pct(qsF, ssF) : null;

    // Estimate spread USD value
    let spreadUsd = null;
    if (qsF && ssF) {
      const spreadUnits = Math.abs(qsF - ssF);
      if (to.symbol === "USDC" || to.symbol === "DAI") {
        spreadUsd = spreadUnits;
      } else if (to.symbol === "WMATIC" && maticUsd) {
        spreadUsd = spreadUnits * maticUsd;
      } else if (to.symbol === "WETH" && maticUsd) {
        // rough ETH price from MATIC price
        spreadUsd = null; // ETH price not fetched separately yet
      }
    }

    // Aave fee: 0.05% of loan
    const aaveFeePct = 0.0005;
    const loanValueUsd = from.symbol === "USDC" || from.symbol === "DAI"
      ? amount
      : from.symbol === "WMATIC" && maticUsd
        ? amount * maticUsd
        : null;
    const aaveFeeUsd = loanValueUsd ? loanValueUsd * aaveFeePct : null;

    const netProfit = spreadUsd !== null && gasCostUsd !== null && aaveFeeUsd !== null
      ? spreadUsd - gasCostUsd - aaveFeeUsd
      : null;

    // Signal
    let signal = "—";
    if (netProfit !== null) {
      if (netProfit > 5) signal = "🟢 EXECUTE";
      else if (netProfit > 0) signal = "🟡 MARGINAL";
      else signal = "🔴 UNPROFITABLE";
    } else if (spreadPct && spreadPct > 0.1) {
      signal = "🟡 CHECK";
    }

    const cheaperDex = qsF && ssF ? (qsF > ssF ? "QuickSwap" : "SushiSwap") : "—";
    const biggerDex  = qsF && ssF ? (qsF > ssF ? "SushiSwap" : "QuickSwap") : "—";

    results.push({
      pair: pairName, amount, from: from.symbol, to: to.symbol,
      qsOut: qsF, ssOut: ssF, spreadPct, spreadUsd, netProfit,
      cheaperDex, biggerDex, signal,
    });

    const qsStr  = qsF  !== null ? qsF.toFixed(to.decimals > 6 ? 4 : 4)  : "N/A";
    const ssStr  = ssF  !== null ? ssF.toFixed(to.decimals > 6 ? 4 : 4)  : "N/A";
    const spdStr = spreadPct !== null ? spreadPct.toFixed(4) + "%" : "N/A";
    const usdStr = spreadUsd !== null ? "$" + spreadUsd.toFixed(2) : "N/A";

    console.log(
      pad(pairName, 18) +
      pad(`${amount} ${from.symbol}`, 14) +
      pad(qsStr, 18) +
      pad(ssStr, 18) +
      pad(spdStr, 12) +
      pad(usdStr, 14) +
      signal
    );
  }

  console.log("─".repeat(110));

  // ─────────────────────────────────────────────────────────────────────────
  // Summary
  // ─────────────────────────────────────────────────────────────────────────
  console.log();
  console.log("═══════════════════════════════════════════════════════════════");
  console.log("  SUMMARY");
  console.log("═══════════════════════════════════════════════════════════════");
  console.log(`  Gas price:        ${gasPriceGwei} Gwei`);
  if (gasCostUsd) console.log(`  Est. tx cost:     $${gasCostUsd.toFixed(3)} (${GAS_UNITS.toLocaleString()} gas units)`);
  console.log();

  const executable = results.filter(r => r.netProfit !== null && r.netProfit > 5);
  const marginal   = results.filter(r => r.netProfit !== null && r.netProfit > 0 && r.netProfit <= 5);

  if (executable.length > 0) {
    console.log(`  🟢 Executable opportunities (net profit > $5):`);
    for (const r of executable) {
      console.log(`     ${r.pair}  |  ${r.cheaperDex} cheaper  |  spread $${r.spreadUsd?.toFixed(2)}  |  net ~$${r.netProfit?.toFixed(2)}`);
    }
  } else {
    console.log(`  🔴 No executable opportunities at current spreads / gas.`);
  }

  if (marginal.length > 0) {
    console.log(`\n  🟡 Marginal (profitable but < $5):`);
    for (const r of marginal) {
      console.log(`     ${r.pair}  |  spread $${r.spreadUsd?.toFixed(2)}  |  net ~$${r.netProfit?.toFixed(2)}`);
    }
  }

  console.log();
  console.log(`  Pairs scanned:    ${results.length}`);
  console.log(`  Timestamp:        ${new Date().toISOString()}`);
  console.log("═══════════════════════════════════════════════════════════════");
}

main().catch(err => {
  console.error("❌ Scan failed:", err.message);
  process.exit(1);
});
