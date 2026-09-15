const { ethers } = require("ethers");
const p = new ethers.JsonRpcProvider(process.env.POLYGON_RPC_URL, undefined, { staticNetwork: true });
const SS_ROUTER = "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506";
const QS_ROUTER = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";
const WMATIC = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
const USDC = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
const AAVE_POOL = "0x794a61358D6845594F94dc1DB02A252b5b4814aD";
const WMATIC_ATOKEN = "0x6d805e7d0768fda0048b0dd1b0a412312e76499a"; // Aave v3 Pol WMATIC aToken
const R_ABI = ["function getAmountsOut(uint256,address[]) view returns (uint256[])"];
const ER_ABI = ["function balanceOf(address) view returns (uint256)"];
const A_ABI = ["function getReserveData(address) view returns (tuple(uint256 configuration,uint256 liquidityIndex,uint128 currentLiquidityRate,uint128 currentVariableBorrowRate,uint128 currentStableBorrowRate,uint40 lastUpdateTimestamp,uint16 id,address aTokenAddress,address stableDebtTokenAddress,address variableDebtTokenAddress,address interestRateStrategyAddress))"];
const clABI = ["function latestRoundData() view returns (uint80,int256,uint256,uint256,uint80)","function decimals() view returns (uint8)"];

(async () => {
  const bn = await p.getBlockNumber();
  const cl = new ethers.Contract("0xAB594600376Ec9fD91F8e885dADF0CE036862dE0", clABI, p);
  const [,ans,,] = await cl.latestRoundData();
  const dec = await cl.decimals();
  const maticUsd = Number(ans)/10**Number(dec);
  const qs = new ethers.Contract(QS_ROUTER, R_ABI, p);
  const ss = new ethers.Contract(SS_ROUTER, R_ABI, p);
  console.log(`blk ${bn} | MATIC $${maticUsd.toFixed(4)}\n`);
  console.log("size(WMATIC) | L1 QS->USDC | L2 SS->WMATIC | gross WMATIC | gross $ | fee$ | gas$ | NET $");
  for (const s of [200, 500, 1000, 2000, 3000, 5000, 10000, 20000]) {
    const amt = BigInt(s) * 10n**18n;
    const usdcOut = (await qs.getAmountsOut(amt, [WMATIC, USDC]))[1];
    const back = (await ss.getAmountsOut(usdcOut, [USDC, WMATIC]))[1];
    const gross = Number(back)/1e18 - s;
    const grossUsd = gross * maticUsd;
    const fee = s * maticUsd * 0.0005;
    const net = grossUsd - fee - 0.020;
    console.log(`${String(s).padStart(6)} | ${(Number(usdcOut)/1e6).toFixed(2)} | ${(Number(back)/1e18).toFixed(2)} | ${(gross>=0?'+':'')}${gross.toFixed(2)} | ${(grossUsd>=0?'+':'')}$${grossUsd.toFixed(2)} | $${fee.toFixed(2)} | $0.020 | ${net>=0?'+':''}$${net.toFixed(2)}`);
  }
  // Aave WMATIC borrow check
  const aave = new ethers.Contract(AAVE_POOL, A_ABI, p);
  const rd = await aave.getReserveData(WMATIC);
  const config = rd.configuration;
  const borrowDisabled = (config >> 48n & 1n) === 1n;
  const at = new ethers.Contract(WMATIC_ATOKEN, ER_ABI, p);
  const aaveLiq = Number(await at.balanceOf(AAVE_POOL))/1e18;
  console.log(`\nAave v3 WMATIC: borrow-disabled(bit48)=${borrowDisabled} | aToken underlying in pool ~${aaveLiq.toFixed(0)} WMATIC | lastUpdate ${Number(rd.lastUpdateTimestamp)}`);
})();
