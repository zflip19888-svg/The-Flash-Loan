/**
 * Size sweep for WMATIC→USDC on Polygon mainnet.
 * Uses the same quote math as scripts/live-spread-scan.js (router getAmountsOut,
 * constant-product fallback, gas + Aave 0.05% fee, slippage-adjusted net).
 */
require("dotenv").config();
const { ethers } = require("ethers");

const RPC_URL = process.env.POLYGON_RPC_URL || "https://1rpc.io/matic";
const QUICKSWAP_ROUTER  = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";
const SUSHISWAP_ROUTER  = "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506";
const QUICKSWAP_FACTORY = "0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32";
const SUSHISWAP_FACTORY = "0xc35DADB65012eC5796536bD9864eD8773aBc74C4";
const CL_MATIC_USD      = "0xAB594600376Ec9fD91F8e885dADF0CE036862dE0";

const WMATIC = { addr: "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270", decimals: 18 };
const USDC   = { addr: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", decimals: 6 };

const SIZES = [5_000, 10_000, 15_000, 20_000, 25_000, 30_000, 35_000, 40_000, 50_000, 60_000];

const ROUTER_ABI  = ["function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts)"];
const FACTORY_ABI = ["function getPair(address tokenA, address tokenB) external view returns (address pair)"];
const PAIR_ABI    = ["function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast)", "function token0() external view returns (address)"];
const CL_ABI      = ["function latestRoundData() external view returns (uint80,int256,uint256,uint256,uint80)", "function decimals() external view returns (uint8)"];

function pad(str, len) { return String(str).padEnd(len); }

async function fetchMaticPrice(provider) {
  const c = new ethers.Contract(CL_MATIC_USD, CL_ABI, provider);
  const [[, answer, , updatedAt], decimals] = await Promise.all([c.latestRoundData(), c.decimals()]);
  const age = Math.floor(Date.now() / 1000) - Number(updatedAt);
  if (age > 3600) return null;
  return Number(answer) / 10 ** Number(decimals);
}

async function main() {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const blockNumber = await provider.getBlockNumber();
  const feeData = await provider.getFeeData();
  const maticUsd = await fetchMaticPrice(provider);
  const gasPriceGwei = feeData.gasPrice ? parseFloat(ethers.formatUnits(feeData.gasPrice, "gwei")) : 100;
  const GAS_UNITS = 750_000;
  const gasCostUsd = maticUsd
    ? parseFloat(ethers.formatUnits(feeData.gasPrice * BigInt(GAS_UNITS), 18)) * maticUsd
    : null;

  const qsRouter = new ethers.Contract(QUICKSWAP_ROUTER, ROUTER_ABI, provider);
  const ssRouter = new ethers.Contract(SUSHISWAP_ROUTER, ROUTER_ABI, provider);
  const qsFactory = new ethers.Contract(QUICKSWAP_FACTORY, FACTORY_ABI, provider);
  const ssFactory = new ethers.Contract(SUSHISWAP_FACTORY, FACTORY_ABI, provider);

  // Pool depths (USD, both sides)
  async function depth(factory) {
    const pairAddr = await factory.getPair(WMATIC.addr, USDC.addr);
    if (!pairAddr || pairAddr === ethers.ZeroAddress) return 0;
    const pair = new ethers.Contract(pairAddr, PAIR_ABI, factory.runner);
    const [[r0, r1], t0] = await Promise.all([pair.getReserves(), pair.token0()]);
    const resIn = t0.toLowerCase() === WMATIC.addr.toLowerCase() ? r0 : r1;
    return parseFloat(ethers.formatUnits(resIn, WMATIC.decimals)) * maticUsd;
  }
  const [qsDepthUsd, ssDepthUsd] = await Promise.all([depth(qsFactory), depth(ssFactory)]);

  console.log("\n" + "═".repeat(110));
  console.log("  WMATIC→USDC SIZE SWEEP  —  Polygon Mainnet");
  console.log(`  Block: #${blockNumber}   |   ${new Date().toUTCString()}`);
  console.log(`  MATIC $${maticUsd?.toFixed(4) ?? "?"}   Gas ${gasPriceGwei.toFixed(1)} Gwei   tx ~$${gasCostUsd.toFixed(3)}`);
  console.log(`  QS depth $${(qsDepthUsd/1000).toFixed(0)}K   SS depth $${(ssDepthUsd/1000).toFixed(0)}K`);
  console.log("═".repeat(110));
  console.log(
    pad("Size", 12) + pad("Trade $", 10) + pad("QS Out", 12) + pad("SS Out", 12) +
    pad("Spread %", 10) + pad("Gross $", 10) + pad("Net $", 10) + pad("Slip %", 8) + "Net Adj $"
  );
  console.log("─".repeat(110));

  const rows = [];
  for (const size of SIZES) {
    const amountIn = ethers.parseUnits(String(size), WMATIC.decimals);
    const [qsOutRaw, ssOutRaw] = await Promise.all([
      qsRouter.getAmountsOut(amountIn, [WMATIC.addr, USDC.addr]).then(o => o[1]).catch(() => null),
      ssRouter.getAmountsOut(amountIn, [WMATIC.addr, USDC.addr]).then(o => o[1]).catch(() => null),
    ]);
    const qsF = qsOutRaw ? parseFloat(ethers.formatUnits(qsOutRaw, USDC.decimals)) : null;
    const ssF = ssOutRaw ? parseFloat(ethers.formatUnits(ssOutRaw, USDC.decimals)) : null;
    if (!qsF || !ssF) { console.log(pad(String(size), 12) + "QUOTE FAILED"); continue; }

    const spreadPct   = Math.abs(qsF - ssF) / Math.max(qsF, ssF) * 100;
    const spreadUsd    = Math.abs(qsF - ssF); // USDC out, price = $1
    const tradeUsd     = size * maticUsd;
    const aaveFeeUsd   = tradeUsd * 0.0005;
    const net          = spreadUsd - gasCostUsd - aaveFeeUsd;
    const sellSideDex  = qsF > ssF ? ssDepthUsd : qsDepthUsd;
    const slippageEst  = sellSideDex > 0 ? (tradeUsd / sellSideDex) * 100 : 99;
    const netAdj       = net - spreadUsd * (slippageEst / 100);

    rows.push({ size, spreadPct, spreadUsd, net, slippageEst, netAdj, qsF, ssF, tradeUsd });
    console.log(
      pad(`${(size/1000).toFixed(0)}K`, 12) +
      pad(`$${Math.round(tradeUsd).toLocaleString()}`, 10) +
      pad(qsF.toFixed(2), 12) + pad(ssF.toFixed(2), 12) +
      pad(spreadPct.toFixed(3) + "%", 10) +
      pad(`$${spreadUsd.toFixed(2)}`, 10) +
      pad(`$${net.toFixed(2)}`, 10) +
      pad(slippageEst.toFixed(1) + "%", 8) +
      `$${netAdj.toFixed(2)}`
    );
  }

  const best = rows.reduce((a, b) => (b.netAdj > a.netAdj ? b : a), rows[0]);
  console.log("─".repeat(110));
  console.log(`  OPTIMAL SIZE: ${(best.size/1000).toFixed(0)}K WMATIC  →  net adj ~$${best.netAdj.toFixed(2)}  (spread ${best.spreadPct.toFixed(2)}%, slip est ${best.slippageEst.toFixed(1)}%)`);
  console.log(`  Thresholds: net adj > $2.00 profitable | slippage est < 5% (phantom guard)`);
  const under5 = rows.filter(r => r.slippageEst < 5 && r.netAdj > 2);
  if (under5.length) {
    const bestGuarded = under5.reduce((a, b) => (b.netAdj > a.netAdj ? b : a), under5[0]);
    console.log(`  BEST UNDER 5% SLIP GUARD: ${(bestGuarded.size/1000).toFixed(0)}K → ~$${bestGuarded.netAdj.toFixed(2)}`);
  } else {
    console.log("  NO size passes both the profit floor and the 5% slippage guard.");
  }
  console.log("═".repeat(110) + "\n");
}

main().catch(e => { console.error("SWEEP FAILED:", e.message); process.exit(1); });
