const { JsonRpcProvider, Contract } = require('ethers');
require('dotenv').config();

const RPC = process.env.POLYGON_RPC_URL;
const provider = new JsonRpcProvider(RPC);

const QUICKSWAP_ROUTER = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";
const SUSHISWAP_ROUTER = "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506";

const ROUTER_ABI = [
  'function getAmountsOut(uint amountIn, address[] path) view returns (uint[] amounts)'
];

const WMATIC = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
const USDC   = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";

async function main() {
  const qs = new Contract(QUICKSWAP_ROUTER, ROUTER_ABI, provider);
  const ss = new Contract(SUSHISWAP_ROUTER, ROUTER_ABI, provider);
  const path = [WMATIC, USDC];
  const MATIC_PRICE = 0.0748;

  const sizes = [5000, 7500, 10000, 12500, 15000, 17500, 20000, 25000, 30000, 35000, 40000];

  console.log('═'.repeat(110));
  console.log('  WMATIC→USDC SIZE SWEEP — Polygon Mainnet');
  const block = await provider.getBlockNumber();
  console.log('  Block: #' + block + '   |   ' + new Date().toUTCString());
  console.log('═'.repeat(110));
  console.log('Size(WMATIC)  USD Val     QS Out(USDC)   SS Out(USDC)   Spread $   Spread %   Slip %    Net $      Signal');
  console.log('─'.repeat(110));

  let bestNet = 0, bestSize = 0;

  for (const size of sizes) {
    try {
      const amountIn = BigInt(size) * BigInt(10) ** BigInt(18);
      const qsAmounts = await qs.getAmountsOut(amountIn, path);
      const ssAmounts = await ss.getAmountsOut(amountIn, path);

      const qsOut = Number(qsAmounts[1]) / 1e6;
      const ssOut = Number(ssAmounts[1]) / 1e6;
      const usdIn = size * MATIC_PRICE;

      const spread = qsOut - ssOut;
      const spreadPct = (spread / qsOut) * 100;
      const slippagePct = Math.abs(spread / qsOut) * 100;

      const feeCost = (qsOut * 0.003) + (ssOut * 0.003);
      const gasCost = 0.032;
      const net = spread - feeCost - gasCost;

      let signal;
      if (net > 5 && slippagePct < 15) signal = '🟢 EXECUTE';
      else if (net > 0 && slippagePct < 25) signal = '🟡 MARGINAL';
      else signal = '👻 PHANTOM';

      if (net > bestNet) { bestNet = net; bestSize = size; }

      console.log(
        String(size).padStart(8) + '    ' +
        ('$' + usdIn.toFixed(0)).padStart(7) + '   ' +
        qsOut.toFixed(2).padStart(12) + '   ' +
        ssOut.toFixed(2).padStart(12) + '   ' +
        ('$' + spread.toFixed(2)).padStart(8) + '   ' +
        (spreadPct.toFixed(2) + '%').padStart(7) + '   ' +
        (slippagePct.toFixed(1) + '%').padStart(6) + '   ' +
        ('$' + net.toFixed(2)).padStart(8) + '   ' + signal
      );
    } catch (e) {
      console.log(String(size).padStart(8) + '   ERROR: ' + e.message.substring(0, 70));
    }
  }
  console.log('═'.repeat(110));
  console.log('  ★ Optimal size: ' + bestSize + ' WMATIC (~$' + (bestSize * MATIC_PRICE).toFixed(0) + ') → net $' + bestNet.toFixed(2));
  console.log('  Net = spread - 0.3% fees (both legs) - $0.032 gas');
  console.log('═'.repeat(110));
}

main().catch(e => { console.error(e); process.exit(1); });
