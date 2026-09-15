const { ethers } = require("ethers");
const RPCS = [
  ["primary", process.env.POLYGON_RPC_URL],
  ["publicnode", "https://polygon-bor-rpc.publicnode.com"],
];
const QS_ROUTER = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";
const SS_ROUTER = "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506";
const QS_FACTORY = "0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32";
const SS_FACTORY = "0xc35DADB65012eC5796536bD9864eD8773aBc74C4";
const WMATIC = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
const USDC = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
const CL_MATIC = "0xAB594600376Ec9fD91F8e885dADF0CE036862dE0";
const R_ABI = ["function getAmountsOut(uint256,address[]) view returns (uint256[])"];
const F_ABI = ["function getPair(address,address) view returns (address)"];
const P_ABI = ["function getReserves() view returns (uint112,uint112,uint32)","function token0() view returns (address)"];
const CL_ABI = ["function latestRoundData() view returns (uint80,int256,uint256,uint256,uint80)","function decimals() view returns (uint8)"];
const AMOUNT = 20_000n * 10n**18n; // 20K WMATIC

(async () => {
  for (const [name, url] of RPCS) {
    try {
      const p = new ethers.JsonRpcProvider(url, undefined, { staticNetwork: true });
      const bn = await p.getBlockNumber();
      const blk = await p.getBlock("latest");
      const age = Math.floor(Date.now()/1000) - Number(blk.timestamp);
      if (age > 120) { console.log(`${name}: STALE head (${age}s) — skipping`); continue; }
      const qsR = new ethers.Contract(QS_ROUTER, R_ABI, p);
      const ssR = new ethers.Contract(SS_ROUTER, R_ABI, p);
      const cl = new ethers.Contract(CL_MATIC, CL_ABI, p);
      const [qsOut, ssOut, [,maticAns,,updatedAt], dec] = await Promise.all([
        qsR.getAmountsOut(AMOUNT, [WMATIC, USDC]),
        ssR.getAmountsOut(AMOUNT, [WMATIC, USDC]),
        cl.latestRoundData(), cl.decimals(),
      ]);
      const maticUsd = Number(maticAns)/10**Number(dec);
      const oAge = Math.floor(Date.now()/1000) - Number(updatedAt);
      const qsF = Number(qsOut[1])/1e6, ssF = Number(ssOut[1])/1e6;
      // pool state
      const ssPair = await new ethers.Contract(SS_FACTORY, F_ABI, p).getPair(WMATIC, USDC);
      const qsPair = await new ethers.Contract(QS_FACTORY, F_ABI, p).getPair(WMATIC, USDC);
      const [ssRes, qsRes] = await Promise.all([
        new ethers.Contract(ssPair, P_ABI, p).getReserves(),
        new ethers.Contract(qsPair, P_ABI, p).getReserves(),
      ]);
      const ssTouched = Math.floor(Date.now()/1000) - Number(ssRes[2]);
      const qsTouched = Math.floor(Date.now()/1000) - Number(qsRes[2]);
      // profit math: buy on QS? SS out < QS out → QS gives MORE USDC for WMATIC.
      // Arb: borrow WMATIC (or use WETH route), swap on QS, ... sell side = SS (thin).
      const spreadUsd = Math.abs(qsF - ssF) * 1.0; // USDC out
      const loanUsd = 20000 * maticUsd;
      const aaveFee = loanUsd * 0.0005;
      const gasUsd = 0.020;
      const tradeUsd = 20000 * maticUsd;
      const sellDepth = Math.min(qsF > ssF ? 45000 : 30000, 999999);
      const slip = (tradeUsd / sellDepth) * 100;
      const net = spreadUsd - aaveFee - gasUsd - spreadUsd*(slip/100);
      console.log(`${name} | blk ${bn} (age ${age}s) | CL MATIC $${maticUsd.toFixed(4)} (feed age ${oAge}s)`);
      console.log(`  QS out: ${qsF.toFixed(2)} USDC | SS out: ${ssF.toFixed(2)} USDC | spread $${spreadUsd.toFixed(2)}`);
      console.log(`  QS pair last trade: ${qsTouched}s ago | SS pair last trade: ${ssTouched}s ago`);
      console.log(`  loan $${loanUsd.toFixed(0)} | aave fee $${aaveFee.toFixed(2)} | gas $${gasUsd.toFixed(3)} | slip est ${slip.toFixed(1)}% | NET adj $${net.toFixed(2)}`);
    } catch (e) { console.log(`${name} ERROR: ${e.message}`); }
  }
})();
