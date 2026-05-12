/**
 * @file deploy-polygon.js
 * @notice Deployment script for Polygon mainnet.
 *
 * Deploys:
 *   1. PriceOraclePolygon — aggregates QuickSwap / SushiSwap / Chainlink prices
 *   2. FlashLoanSecure    — primary arbitrage contract (Aave v3 flash loans)
 *
 * (No MockOracle on mainnet.)
 *
 * Run:
 *   npx hardhat run scripts/deploy-polygon.js --network polygon
 *
 * Output:
 *   output/addresses-mainnet.json
 */

const { ethers } = require("hardhat");
const fs         = require("fs");
const path       = require("path");

// ─────────────────────────────────────────────────────────────────────────────
// Polygon Mainnet Addresses
// ─────────────────────────────────────────────────────────────────────────────

const AAVE_POOL_PROVIDER  = "0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb";
const QUICKSWAP_ROUTER    = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";
const QUICKSWAP_FACTORY   = "0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32";
const SUSHISWAP_ROUTER    = "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506";
const SUSHISWAP_FACTORY   = "0xc35DADB65012eC5796536bD9864eD8773aBc74C4";

// Token addresses
const WMATIC = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
const USDC   = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
const WETH   = "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619";

// Chainlink USD price feeds on Polygon mainnet
// See: https://docs.chain.link/data-feeds/price-feeds/addresses?network=polygon
const CHAINLINK_WMATIC_USD = "0xAB594600376Ec9fD91F8e885dADF0CE036862dE0";
const CHAINLINK_USDC_USD   = "0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7";
const CHAINLINK_WETH_USD   = "0xF9680D99D6C9589e2a93a78A04A279e509205945";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(`\n🚀 Deploying to Polygon Mainnet with account: ${deployer.address}`);
  console.log(`   Balance: ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))} MATIC\n`);

  if (!process.env.PRIVATE_KEY) {
    throw new Error("PRIVATE_KEY env var not set — refusing mainnet deployment");
  }

  // ── 1. PriceOraclePolygon ──────────────────────────────────────────────────
  console.log("1️⃣  Deploying PriceOraclePolygon...");
  const PriceOraclePolygon = await ethers.getContractFactory("PriceOraclePolygon");
  const priceOracle = await PriceOraclePolygon.deploy(
    QUICKSWAP_ROUTER,
    SUSHISWAP_ROUTER,
    QUICKSWAP_FACTORY,
    SUSHISWAP_FACTORY,
    [WMATIC,                USDC,              WETH            ],
    [CHAINLINK_WMATIC_USD,  CHAINLINK_USDC_USD, CHAINLINK_WETH_USD]
  );
  await priceOracle.waitForDeployment();
  const priceOracleAddress = await priceOracle.getAddress();
  console.log(`   ✅ PriceOraclePolygon deployed at: ${priceOracleAddress}\n`);

  // ── 2. FlashLoanSecure ─────────────────────────────────────────────────────
  console.log("2️⃣  Deploying FlashLoanSecure...");
  const FlashLoanSecure = await ethers.getContractFactory("FlashLoanSecure");
  const flashLoan = await FlashLoanSecure.deploy(
    AAVE_POOL_PROVIDER,
    priceOracleAddress,
    deployer.address
  );
  await flashLoan.waitForDeployment();
  const flashLoanAddress = await flashLoan.getAddress();
  console.log(`   ✅ FlashLoanSecure deployed at: ${flashLoanAddress}\n`);

  // ── 3. Write output ────────────────────────────────────────────────────────
  const outputDir = path.join(__dirname, "..", "output");
  if (!fs.existsSync(outputDir)) fs.mkdirSync(outputDir, { recursive: true });

  const addresses = {
    network:      "polygon-mainnet",
    chainId:      137,
    flashLoan:    flashLoanAddress,
    priceOracle:  priceOracleAddress,
    mockOracle:   null,
    deployedAt:   new Date().toISOString(),
    deployer:     deployer.address,
  };

  const outPath = path.join(outputDir, "addresses-mainnet.json");
  fs.writeFileSync(outPath, JSON.stringify(addresses, null, 2));
  console.log(`📄 Addresses written to: ${outPath}`);
  console.log(JSON.stringify(addresses, null, 2));

  // ── 4. Verify hints ────────────────────────────────────────────────────────
  console.log("\n💡 To verify on Polygonscan:");
  console.log(`   npx hardhat verify --network polygon ${priceOracleAddress} \\`);
  console.log(`     "${QUICKSWAP_ROUTER}" "${SUSHISWAP_ROUTER}" "${QUICKSWAP_FACTORY}" "${SUSHISWAP_FACTORY}" \\`);
  console.log(`     '["${WMATIC}","${USDC}","${WETH}"]' \\`);
  console.log(`     '["${CHAINLINK_WMATIC_USD}","${CHAINLINK_USDC_USD}","${CHAINLINK_WETH_USD}"]'`);
  console.log(`\n   npx hardhat verify --network polygon ${flashLoanAddress} \\`);
  console.log(`     "${AAVE_POOL_PROVIDER}" "${priceOracleAddress}" "${deployer.address}"`);
}

main().catch((err) => {
  console.error("❌ Deployment failed:", err);
  process.exitCode = 1;
});
