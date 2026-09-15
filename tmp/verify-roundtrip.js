const { ethers } = require("ethers");
const p = new ethers.JsonRpcProvider(process.env.POLYGON_RPC_URL, undefined, { staticNetwork: true });
const SS_ROUTER = "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506";
const QS_ROUTER = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";
const WMATIC = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
const USDC = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
const AAVE_POOL = "0x794a61358D6845594F94dc1DB02A252b5b4814aD";
const R_ABI = ["function getAmountsOut(uint256,address[]) view returns (uint256[])"];
const A_ABI = ["function getReserveData(address) view returns (tuple(uint256 configuration,uint256 liquidityIndex,uint128 currentLiquidityRate,uint128 currentVariableBorrowRate,uint128 currentStableBorrowRate,uint40 lastUpdateTimestamp,uint16 id,address aTokenAddress,address stableDebtTokenAddress,address variableDebtTokenAddress,address interestRateStrategyAddress,uint128 accruedToTreasury,uint128 unbacked,uint128 accruedToTreasuryScaled))",
               "function getAvailableLiquidity(address) view returns (uint256)"];
const R_ABI2 = "function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts)";

(async () => {
  const bn = await p.getBlockNumber();
  const qsOut = (await new ethers.Contract(QS_ROUTER, [R_ABI2], p).getAmountsOut(20000n*10n**18n, [WMATIC, USDC]))[1];
  // Round trip: sell 20K WMATIC on QS for USDC, then buy WMATIC back on SS
  const ssBack = (await new ethers.Contract(SS_ROUTER, [R_ABI2], p).getAmountsOut(qsOut, [USDC, WMATIC]))[1];
  const qsOutF = Number(qsOut)/1e6;
  const backF = Number(ssBack)/1e18;
  console.log(`blk ${bn} | Leg1 QS: 20000 WMATIC -> ${qsOutF.toFixed(2)} USDC | Leg2 SS: ${qsOutF.toFixed(2)} USDC -> ${backF.toFixed(2)} WMATIC`);
  console.log(`gross WMATIC profit: ${(backF-20000).toFixed(2)} WMATIC (need > loan + fee)`);
  // Aave WMATIC availability
  const aave = new ethers.Contract(AAVE_POOL, A_ABI, p);
  const liq = await aave.getAvailableLiquidity(WMATIC);
  const rd = await aave.getReserveData(WMATIC);
  const config = rd.configuration;
  const borrowingDisabled = (config >> 48n & 0x1n) === 1n; // bit 48 = borrowing disabled per v3
  console.log(`Aave WMATIC avail liq: ${Number(liq)/1e18} WMATIC | borrow-disabled flag(bit48): ${borrowingDisabled} | lastUpdate: ${Number(rd.lastUpdateTimestamp)}`);
})();
