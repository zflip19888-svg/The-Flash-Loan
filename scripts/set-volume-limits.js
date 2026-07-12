/**
 * set-volume-limits.js
 * Run ONCE after funding the wallet — sets circuit-breaker limits on FlashLoanSecure.
 * Usage: node scripts/set-volume-limits.js
 */
require("dotenv").config();
const { ethers } = require("ethers");

const FLASH_LOAN = process.env.FLASH_LOAN_ADDRESS || "0xBafc19Fd23714bD2F3256C20a6036a5B31A9DbD8";
const WETH  = "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619";
const USDC  = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
const WMATIC= "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";

const ABI = ["function setDailyVolumeLimit(address asset, uint256 limit) external"];

async function main() {
  const provider = new ethers.JsonRpcProvider(process.env.POLYGON_RPC_URL);
  const wallet   = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
  const fl       = new ethers.Contract(FLASH_LOAN, ABI, wallet);
  const fee      = await provider.getFeeData();

  console.log("Setting daily volume limits on FlashLoanSecure...");
  console.log("Wallet:", wallet.address);

  const limits = [
    { asset: WETH,   label: "WETH",   limit: ethers.parseEther("500"),          // 500 WETH/day
      dec: 18 },
    { asset: USDC,   label: "USDC",   limit: ethers.parseUnits("1000000", 6),   // 1M USDC/day
      dec: 6 },
    { asset: WMATIC, label: "WMATIC", limit: ethers.parseEther("5000000"),      // 5M WMATIC/day
      dec: 18 },
  ];

  for (const { asset, label, limit, dec } of limits) {
    process.stdout.write(`  setDailyVolumeLimit(${label}, ${ethers.formatUnits(limit, dec)})... `);
    try {
      const tx = await fl.setDailyVolumeLimit(asset, limit, {
        gasPrice: fee.gasPrice,
        gasLimit: 100_000n,
      });
      const receipt = await tx.wait(1);
      console.log(`✅ tx: ${receipt.hash}`);
    } catch (e) {
      console.log(`❌ ${e.message.slice(0,80)}`);
    }
  }
  console.log("\nDone. Bot circuit breakers are now armed.");
}

main().catch(console.error);
