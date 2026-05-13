/**
 * @file deploy-polygon-mumbai.js
 * @notice Deployment script for Polygon Mumbai testnet (or Amoy testnet).
 *
 * NOTE: Polygon Mumbai (80001) is deprecated as of Q1 2024. Polygon Amoy (80002)
 *       is the current testnet. This script supports both via the NETWORK env var
 *       but defaults to mumbai for backward compat with existing .env files.
 *
 * Deploys (in order):
 *   1. MockOracle          — substitutes Chainlink on testnet
 *   2. TwapOracle          — two-snapshot TWAP oracle
 *   3. PriceOraclePolygon  — aggregates QuickSwap / SushiSwap / Chainlink prices
 *   4. FlashLoanSecure     — primary arbitrage contract
 *
 * Run:
 *   npx hardhat run scripts/deploy-polygon-mumbai.js --network mumbai
 *
 * Dry-run (no broadcast):
 *   DRY_RUN=true npx hardhat run scripts/deploy-polygon-mumbai.js --network mumbai
 *
 * Output:
 *   output/addresses-mumbai.json
 */

const { ethers } = require("hardhat");
const fs   = require("fs");
const path = require("path");

// ─────────────────────────────────────────────────────────────────────────────
// Testnet addresses
// ─────────────────────────────────────────────────────────────────────────────

const CONFIG = {
  mumbai: {
    chainId:          80001,
    aaveProvider:     "0x5343b5bA672Ae99d627A1C87866b8E53F47Db2E6",
    quickswapRouter:  "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff",
    quickswapFactory: "0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32",
    sushiswapRouter:  "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506",
    sushiswapFactory: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
    wmatic:           "0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889",
    outputFile:       "addresses-mumbai.json",
  },
  amoy: {
    chainId:          80002,
    // Aave v3 is not deployed on Amoy yet — use a known placeholder
    aaveProvider:     "0xeb7A892BB04A8f836bDEeBbf60897A7Af1Bf5d7F",
    quickswapRouter:  "0x0000000000000000000000000000000000000001",
    quickswapFactory: "0x0000000000000000000000000000000000000001",
    sushiswapRouter:  "0x0000000000000000000000000000000000000001",
    sushiswapFactory: "0x0000000000000000000000000000000000000001",
    wmatic:           "0x0ae690aad8663aab12a671a6a0d74242332de85f",
    outputFile:       "addresses-amoy.json",
  },
};

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

const DRY_RUN = process.env.DRY_RUN === "true";

async function deploy(factory, args = [], label = "") {
  if (DRY_RUN) {
    const fake = `0x${Math.random().toString(16).slice(2).padEnd(40, "0")}`;
    console.log(`   [DRY-RUN] ${label}: ${fake}`);
    return { getAddress: async () => fake, waitForDeployment: async () => {} };
  }
  const contract = await factory.deploy(...args);
  await contract.waitForDeployment();
  const addr = await contract.getAddress();
  console.log(`   ✅ ${label}: ${addr}`);
  return contract;
}

// ─────────────────────────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────────────────────────

async function main() {
  const netName = process.env.DEPLOY_NETWORK || "mumbai";
  const cfg     = CONFIG[netName];
  if (!cfg) throw new Error(`Unknown network config: ${netName}`);

  const [deployer] = await ethers.getSigners();
  const balance    = await ethers.provider.getBalance(deployer.address);

  console.log(`\n🚀 Deploying to ${netName}${DRY_RUN ? " [DRY-RUN]" : ""}`);
  console.log(`   Account: ${deployer.address}`);
  console.log(`   Balance: ${ethers.formatEther(balance)} MATIC\n`);

  if (!DRY_RUN && balance < ethers.parseEther("0.1")) {
    throw new Error(`Insufficient MATIC balance: ${ethers.formatEther(balance)}. Need at least 0.1 MATIC for gas.`);
  }

  // ── 1. MockOracle ──────────────────────────────────────────────────────────
  console.log("1️⃣  Deploying MockOracle…");
  const MockOracle     = await ethers.getContractFactory("MockOracle");
  const mockOracle     = await deploy(MockOracle, [100_000_000n, 8], "MockOracle");
  const mockOracleAddr = await mockOracle.getAddress();

  // ── 2. TwapOracle ──────────────────────────────────────────────────────────
  console.log("\n2️⃣  Deploying TwapOracle…");
  const TwapOracle     = await ethers.getContractFactory("TwapOracle");
  const twapOracle     = await deploy(TwapOracle, [], "TwapOracle");
  const twapOracleAddr = await twapOracle.getAddress();

  // ── 3. PriceOraclePolygon ──────────────────────────────────────────────────
  console.log("\n3️⃣  Deploying PriceOraclePolygon…");
  const PriceOraclePolygon = await ethers.getContractFactory("PriceOraclePolygon");
  const priceOracle = await deploy(
    PriceOraclePolygon,
    [
      cfg.quickswapRouter,
      cfg.sushiswapRouter,
      cfg.quickswapFactory,
      cfg.sushiswapFactory,
      [cfg.wmatic],        // register WMATIC with the mock Chainlink oracle
      [mockOracleAddr],
    ],
    "PriceOraclePolygon"
  );
  const priceOracleAddr = await priceOracle.getAddress();

  // ── 4. FlashLoanSecure ─────────────────────────────────────────────────────
  console.log("\n4️⃣  Deploying FlashLoanSecure…");
  const FlashLoanSecure = await ethers.getContractFactory("FlashLoanSecure");
  const flashLoan = await deploy(
    FlashLoanSecure,
    [cfg.aaveProvider, priceOracleAddr, deployer.address],
    "FlashLoanSecure"
  );
  const flashLoanAddr = await flashLoan.getAddress();

  // ── 5. Write output ────────────────────────────────────────────────────────
  const outputDir = path.join(__dirname, "..", "output");
  if (!fs.existsSync(outputDir)) fs.mkdirSync(outputDir, { recursive: true });

  const addresses = {
    network:      netName,
    chainId:      cfg.chainId,
    flashLoan:    flashLoanAddr,
    priceOracle:  priceOracleAddr,
    twapOracle:   twapOracleAddr,
    mockOracle:   mockOracleAddr,
    deployedAt:   new Date().toISOString(),
    deployer:     deployer.address,
    dryRun:       DRY_RUN,
  };

  const outPath = path.join(outputDir, cfg.outputFile);
  fs.writeFileSync(outPath, JSON.stringify(addresses, null, 2));

  console.log(`\n📄 Addresses written to: ${outPath}`);
  console.log(JSON.stringify(addresses, null, 2));

  // ── 6. Post-deploy config steps ────────────────────────────────────────────
  if (!DRY_RUN) {
    console.log("\n📋 Post-deploy checklist:");
    console.log(`   1. Add these to your .env:`);
    console.log(`      FLASH_LOAN_ADDRESS=${flashLoanAddr}`);
    console.log(`      PRICE_ORACLE_ADDRESS=${priceOracleAddr}`);
    console.log(`\n   2. Get Mumbai test MATIC: https://faucet.polygon.technology`);
    console.log(`\n   3. Run sanity check:`);
    console.log(`      npm run verify:mumbai`);
    console.log(`\n   4. (Optional) Verify on Polygonscan Mumbai:`);
    console.log(`      npx hardhat verify --network mumbai ${flashLoanAddr} \\`);
    console.log(`        "${cfg.aaveProvider}" "${priceOracleAddr}" "${deployer.address}"`);
  }
}

main().catch((err) => {
  console.error("\n❌ Deployment failed:", err.message);
  process.exitCode = 1;
});
