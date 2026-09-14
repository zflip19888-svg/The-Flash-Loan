const { ethers } = require("ethers");
const RPCS = [
  ["alchemy",   process.env.POLYGON_RPC_URL],
  ["publicnode","https://polygon-bor-rpc.publicnode.com"],
  ["drpc",      "https://polygon.drpc.org"],
  ["1rpc",      "https://1rpc.io/matic"],
];
const SS_FACTORY = "0xc35DADB65012eC5796536bD9864eD8773aBc74C4";
const QS_FACTORY = "0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32";
const WETH = "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619";
const USDC = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
const FACTORY_ABI = ["function getPair(address,address) view returns (address)"];
const PAIR_ABI = ["function getReserves() view returns (uint112,uint112,uint32)"];

(async () => {
  for (const [name, url] of RPCS) {
    try {
      const p = new ethers.JsonRpcProvider(url, undefined, { staticNetwork: true });
      const bn = await p.getBlockNumber();
      const blk = await p.getBlock("latest");
      const ssF = new ethers.Contract(SS_FACTORY, FACTORY_ABI, p);
      const ssPair = await ssF.getPair(WETH, USDC);
      const qsF = new ethers.Contract(QS_FACTORY, FACTORY_ABI, p);
      const qsPair = await qsF.getPair(WETH, USDC);
      const ssP = new ethers.Contract(ssPair, PAIR_ABI, p);
      const qsP = new ethers.Contract(qsPair, PAIR_ABI, p);
      const [ssR, qsR] = await Promise.all([ssP.getReserves(), qsP.getReserves()]);
      const ssTs = Number(ssR[2]); const qsTs = Number(qsR[2]);
      const nowTs = Number(blk.timestamp);
      // USDC is token0 (lower address? 0x2791... < 0x7ceB... yes USDC is token0)
      const usdcDec = 1e6, wethDec = 1e18;
      const ssDepth = (Number(ssR[0])/usdcDec*2).toFixed(0);   // token0=USDC
      const qsDepth = (Number(qsR[0])/usdcDec*2).toFixed(0);
      console.log(`${name.padEnd(11)} blk ${bn} | SS pair ${ssPair} WETH ${Number(ssR[1])/1e18} USDC ${Number(ssR[0])/1e6} (~$${(Number(ssR[0])/1e6*2/1000).toFixed(1)}K depth) lastTouch ${nowTs-ssTs}s ago | QS WETH ${Number(qsR[1])/1e18} USDC ${Number(qsR[0])/1e6} (~$${(Number(qsR[0])/1e6*2/1000).toFixed(0)}K depth) lastTouch ${nowTs-qsTs}s ago`);
    } catch (e) { console.log(`${name.padEnd(11)} ERROR: ${e.message}`); }
  }
})();
