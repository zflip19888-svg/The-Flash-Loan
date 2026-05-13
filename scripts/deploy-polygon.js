/**
 * @file deploy-polygon.js
 * @notice Deployment script for Polygon mainnet.
 *
 * Deploys (in order):
 *   1. TwapOracle          — two-snapshot TWAP oracle
 *   2. PriceOraclePolygon  — aggregates QuickSwap / SushiSwap / Chainlink prices
 *   3. FlashLoanSecure     — primary arbitrage contract (Aave v3 flash loans)
 *
 * Run:
 *   npx hardhat run scripts/deploy-polygon.js --network polygon
 *
 * Dry-run (no broadcast):
 *   DRY_RUN=true npx hardhat run scripts/deploy-polygon.js --network polygon
 *
 * Output:
 *   output/addresses-mainnet.json
 */

const { ethers } = require("hardhat");
const fs   = require("fs");
const path = require("path");

// ─────────────────────────────────────────────────────────────────────────────
// Polygon Mainnet Addresses (all verified on-chain)
// ─────────────────────────────────────────────────────────────────────────────

const AAVE_POOL_PROVIDER  = "0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb";
const QUICKSWAP_ROUTER    = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";
const QUICKSWAP_FACTORY   = "0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32";
const SUSHISWAP_ROUTER    = "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506";
const SUSHISWAP_FACTORY   = "0xc35DADB65012eC5796536bD9864eD8773aBc74C4";

// ── Tokens ────────────────────────────────────────────────────────────────────
const WMATIC  = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
const USDC    = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
const WETH    = "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619";
const WBTC    = "0x1bfd67037b42cf73acf2047067bd4f2c47d9bfd6";
const DAI     = "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063";

// ── Chainlink USD feeds on Polygon (from docs.chain.link) ─────────────────────
const CL_MATIC_USD = "0xAB594600376Ec9fD91F8e885dADF0CE036862dE0";
const CL_USDC_USD  = "0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7";
const CL_ETH_USD   = "0xF9680D99D6C9589e2a93a78A04A279e509205945";
const CL_BTC_USD   = "0xc907E116054Ad103354f2D350FD2514433D57F6f";
const CL_DAI_USD   = "0x4746DeC9e833A82EC7C2C1356372CcF2cfcD2F3D";

// ── Well-known QuickSwap V2 pairs (for TwapOracle pre-registration) ───────────
const QS_USDC_WMATIC = "0x6e7a5FAFcec6BB1e78bAE2A1F0B612012BF14827";
const QS_WETH_USDC   = "0x853ee4b2a13f8a742d64c8f088be7ba2131f670d";

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
  if (!DRY_RUN && !process.env.PRIVATE_KEY) {
    throw new Error("PRIVATE_KEY not set — refusing mainnet deployment. Set it in .env or use DRY_RUN=true.");
  }

  const [deployer] = await ethers.getSigners();
  const balance    = await ethers.provider.getBalance(deployer.address);

  console.log(`\n🚀 Deploying to Polygon Mainnet${DRY_RUN ? " [DRY-RUN]" : ""}`);
  console.log(`   Account: ${deployer.address}`);
  console.log(`   Balance: ${ethers.formatEther(balance)} MATIC\n`);

  if (!DRY_RUN && balance < ethers.parseEther("0.5")) {
    throw new Error(`Low MATIC balance (${ethers.formatEther(balance)}). Need at least 0.5 MATIC for mainnet deployment gas.`);
  }

  // ── 1. TwapOracle ──────────────────────────────────────────────────────────
  console.log("1️⃣  Deploying TwapOracle…");
  const TwapOracleFactory = await ethers.getContractFactory("TwapOracle");
  const twapOracle        = await deploy(TwapOracleFactory, [], "TwapOracle");
  const twapOracleAddr    = await twapOracle.getAddress();

  // ── 2. PriceOraclePolygon ──────────────────────────────────────────────────
  console.log("\n2️⃣  Deploying PriceOraclePolygon…");
  const PriceOracleFactory = await ethers.getContractFactory("PriceOraclePolygon");
  const priceOracle = await deploy(
    PriceOracleFactory,
    [
      QUICKSWAP_ROUTER,
      SUSHISWAP_ROUTER,
      QUICKSWAP_FACTORY,
      SUSHISWAP_FACTORY,
      [WMATIC, USDC,       WETH,       WBTC,       DAI      ],
      [CL_MATIC_USD, CL_USDC_USD, CL_ETH_USD, CL_BTC_USD, CL_DAI_USD],
    ],
    "PriceOraclePolygon"
  );
  const priceOracleAddr = await priceOracle.getAddress();

  // ── 3. FlashLoanSecure ─────────────────────────────────────────────────────
  console.log("\n3️⃣  Deploying FlashLoanSecure…");
  const FlashLoanFactory = await ethers.getContractFactory("FlashLoanSecure");
  const flashLoan = await deploy(
    FlashLoanFactory,
    [AAVE_POOL_PROVIDER, priceOracleAddr, deployer.address],
    "FlashLoanSecure"
  );
  const flashLoanAddr = await flashLoan.getAddress();

  // ── 4. Pre-register TwapOracle pairs (non-critical — skip if revert) ───────
  if (!DRY_RUN) {
    console.log("\n4️⃣  Pre-registering TWAP pairs…");
    try {
      const tx1 = await twapOracle.registerPair(QS_USDC_WMATIC);
      await tx1.wait(1);
      console.log(`   ✅ QS USDC/WMATIC pair registered: ${QS_USDC_WMATIC}`);
    } catch (e) {
      console.log(`   ⚠️  QS USDC/WMATIC register failed (non-critical): ${e.message}`);
    }
    try {
      const tx2 = await twapOracle.registerPair(QS_WETH_USDC);
      await tx2.wait(1);
      console.log(`   ✅ QS WETH/USDC pair registered: ${QS_WETH_USDC}`);
    } catch (e) {
      console.log(`   ⚠️  QS WETH/USDC register failed (non-critical): ${e.message}`);
    }
  } else {
    console.log("\n4️⃣  [DRY-RUN] Skipping TwapOracle pair registration");
  }

  // ── 5. Write output ────────────────────────────────────────────────────────
  const outputDir = path.join(__dirname, "..", "output");
  if (!fs.existsSync(outputDir)) fs.mkdirSync(outputDir, { recursive: true });

  const addresses = {
    network:       "polygon-mainnet",
    chainId:       137,
    flashLoan:     flashLoanAddr,
    priceOracle:   priceOracleAddr,
    twapOracle:    twapOracleAddr,
    mockOracle:    null,
    tokens:        { WMATIC, USDC, WETH, WBTC, DAI },
    chainlinkFeeds: {
      MATIC_USD: CL_MATIC_USD,
      USDC_USD:  CL_USDC_USD,
      ETH_USD:   CL_ETH_USD,
      BTC_USD:   CL_BTC_USD,
      DAI_USD:   CL_DAI_USD,
    },
    deployedAt: new Date().toISOString(),
    deployer:   deployer.address,
    dryRun:     DRY_RUN,
  };

  const outPath = path.join(outputDir, "addresses-mainnet.json");
  fs.writeFileSync(outPath, JSON.stringify(addresses, null, 2));

  console.log(`\n📄 Addresses written to: ${outPath}`);
  console.log(JSON.stringify(addresses, null, 2));

  // ── 6. Post-deploy checklist ───────────────────────────────────────────────
  if (!DRY_RUN) {
    console.log("\n📋 Post-deploy checklist:");
    console.log(`   1. Add to your .env:`);
    console.log(`      FLASH_LOAN_ADDRESS=${flashLoanAddr}`);
    console.log(`      PRICE_ORACLE_ADDRESS=${priceOracleAddr}`);
    console.log(`\n   2. Run sanity check:`);
    console.log(`      npm run verify:check`);
    console.log(`\n   3. Verify on Polygonscan:`);
    console.log(`      npx hardhat verify --network polygon ${flashLoanAddr} \\`);
    console.log(`        "${AAVE_POOL_PROVIDER}" "${priceOracleAddr}" "${deployer.address}"`);
    console.log(`\n   4. Start the bot (after filling .env):`);
    console.log(`      cd bot && npm run start`);
  }
}

main().catch((err) => {
  console.error("\n❌ Deployment failed:", err.message);
  process.exitCode = 1;
});
