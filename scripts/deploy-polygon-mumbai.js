/**
 * @file deploy-polygon-mumbai.js
 * @notice Deployment script for Mumbai testnet.
 *
 * Deploys:
 *   1. MockOracle        — Chainlink mock for testing
 *   2. PriceOraclePolygon — aggregates QuickSwap / SushiSwap / Chainlink prices
 *   3. FlashLoanSecure   — primary arbitrage contract (Aave v3 flash loans)
 *
 * Run:
 *   npx hardhat run scripts/deploy-polygon-mumbai.js --network mumbai
 *
 * Output:
 *   output/addresses-mumbai.json
 */

const { ethers } = require("hardhat");
const fs         = require("fs");
const path       = require("path");

// ─────────────────────────────────────────────────────────────────────────────
// Mumbai / Testnet addresses
// NOTE: Some of these are placeholder addresses.  Replace with live Mumbai
// deployments when they become available.
// ─────────────────────────────────────────────────────────────────────────────

// Aave v3 PoolAddressesProvider on Mumbai
const AAVE_POOL_PROVIDER_MUMBAI = "0x5343b5bA672Ae99d627A1C87866b8E53F47Db2E6";

// QuickSwap V2 router on Mumbai (same binary, different liquidity)
const QUICKSWAP_ROUTER_MUMBAI   = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";
const QUICKSWAP_FACTORY_MUMBAI  = "0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32";

// SushiSwap on Mumbai
const SUSHISWAP_ROUTER_MUMBAI   = "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506";
const SUSHISWAP_FACTORY_MUMBAI  = "0xc35DADB65012eC5796536bD9864eD8773aBc74C4";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(`\n🚀 Deploying to Mumbai with account: ${deployer.address}`);
  console.log(`   Balance: ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))} MATIC\n`);

  // ── 1. MockOracle ──────────────────────────────────────────────────────────
  console.log("1️⃣  Deploying MockOracle...");
  const MockOracle   = await ethers.getContractFactory("MockOracle");
  // Initial price: $1.00 USD represented with 8 decimals = 100_000_000
  const mockOracle   = await MockOracle.deploy(100_000_000n, 8);
  await mockOracle.waitForDeployment();
  const mockOracleAddress = await mockOracle.getAddress();
  console.log(`   ✅ MockOracle deployed at: ${mockOracleAddress}\n`);

  // ── 2. PriceOraclePolygon ──────────────────────────────────────────────────
  console.log("2️⃣  Deploying PriceOraclePolygon...");
  const PriceOraclePolygon = await ethers.getContractFactory("PriceOraclePolygon");

  // Pre-register MockOracle as a feed for a dummy token address (WMATIC placeholder)
  // In production substitute with real Chainlink feed addresses.
  const WMATIC_MUMBAI = "0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889"; // Wrapped MATIC on Mumbai
  const priceOracle = await PriceOraclePolygon.deploy(
    QUICKSWAP_ROUTER_MUMBAI,
    SUSHISWAP_ROUTER_MUMBAI,
    QUICKSWAP_FACTORY_MUMBAI,
    SUSHISWAP_FACTORY_MUMBAI,
    [WMATIC_MUMBAI],          // initial feed tokens
    [mockOracleAddress]       // corresponding Chainlink feeds (mock for testnet)
  );
  await priceOracle.waitForDeployment();
  const priceOracleAddress = await priceOracle.getAddress();
  console.log(`   ✅ PriceOraclePolygon deployed at: ${priceOracleAddress}\n`);

  // ── 3. FlashLoanSecure ─────────────────────────────────────────────────────
  console.log("3️⃣  Deploying FlashLoanSecure...");
  const FlashLoanSecure = await ethers.getContractFactory("FlashLoanSecure");
  const flashLoan = await FlashLoanSecure.deploy(
    AAVE_POOL_PROVIDER_MUMBAI,
    priceOracleAddress,
    deployer.address           // owner
  );
  await flashLoan.waitForDeployment();
  const flashLoanAddress = await flashLoan.getAddress();
  console.log(`   ✅ FlashLoanSecure deployed at: ${flashLoanAddress}\n`);

  // ── 4. Write output ────────────────────────────────────────────────────────
  const outputDir = path.join(__dirname, "..", "output");
  if (!fs.existsSync(outputDir)) fs.mkdirSync(outputDir, { recursive: true });

  const addresses = {
    network:      "mumbai",
    chainId:      80001,
    flashLoan:    flashLoanAddress,
    priceOracle:  priceOracleAddress,
    mockOracle:   mockOracleAddress,
    deployedAt:   new Date().toISOString(),
    deployer:     deployer.address,
  };

  const outPath = path.join(outputDir, "addresses-mumbai.json");
  fs.writeFileSync(outPath, JSON.stringify(addresses, null, 2));
  console.log(`📄 Addresses written to: ${outPath}`);
  console.log(JSON.stringify(addresses, null, 2));

  // ── 5. Verify hint ─────────────────────────────────────────────────────────
  console.log("\n💡 To verify on Polygonscan (Mumbai):");
  console.log(`   npx hardhat verify --network mumbai ${flashLoanAddress} "${AAVE_POOL_PROVIDER_MUMBAI}" "${priceOracleAddress}" "${deployer.address}"`);
}

main().catch((err) => {
  console.error("❌ Deployment failed:", err);
  process.exitCode = 1;
});
