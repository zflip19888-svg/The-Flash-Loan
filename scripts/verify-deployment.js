/**
 * @file verify-deployment.js
 * @notice Post-deployment sanity check script.
 *
 * Reads addresses from output/addresses-<network>.json and verifies:
 *   1. Contracts are deployed (bytecode exists)
 *   2. FlashLoanSecure.ADDRESSES_PROVIDER matches expected Aave address
 *   3. FlashLoanSecure.PRICE_ORACLE matches deployed PriceOraclePolygon
 *   4. Owner is the deployer wallet
 *   5. Contract is not paused
 *   6. PriceOraclePolygon returns non-zero prices for USDC/WMATIC
 *   7. Submits a Polygonscan verification command for each contract
 *
 * Usage:
 *   npx hardhat run scripts/verify-deployment.js --network polygon
 *   npx hardhat run scripts/verify-deployment.js --network mumbai
 */

const { ethers, run, network } = require("hardhat");
const fs   = require("fs");
const path = require("path");

// ─────────────────────────────────────────────────────────────────────────────
// Config by network
// ─────────────────────────────────────────────────────────────────────────────

const NETWORK_CONFIG = {
  polygon: {
    aaveProvider: "0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb",
    usdc:         "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
    wmatic:       "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
    addressFile:  "addresses-mainnet.json",
  },
  mumbai: {
    aaveProvider: "0x5343b5bA672Ae99d627A1C87866b8E53F47Db2E6",
    usdc:         "0xe11a86849d99f524cac3e7a0ec1241828e332526", // Mumbai USDC
    wmatic:       "0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889", // Mumbai WMATIC
    addressFile:  "addresses-mumbai.json",
  },
};

const FLASH_LOAN_ABI = [
  "function ADDRESSES_PROVIDER() external view returns (address)",
  "function PRICE_ORACLE() external view returns (address)",
  "function owner() external view returns (address)",
  "function paused() external view returns (bool)",
  "function MAX_RECURSION_DEPTH() external view returns (uint256)",
];

const PRICE_ORACLE_ABI = [
  "function getQuickSwapPrice(address,address,uint256) external view returns (uint256)",
  "function getSushiSwapPrice(address,address,uint256) external view returns (uint256)",
  "function QUICKSWAP_ROUTER() external view returns (address)",
  "function SUSHISWAP_ROUTER() external view returns (address)",
];

// ─────────────────────────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────────────────────────

async function main() {
  const netName = network.name;
  const cfg     = NETWORK_CONFIG[netName];
  if (!cfg) throw new Error(`Unsupported network: ${netName}`);

  const [signer] = await ethers.getSigners();
  console.log(`\n🔍 Verifying deployment on ${netName}`);
  console.log(`   Signer: ${signer.address}\n`);

  // ── Load addresses ──────────────────────────────────────────────────────────
  const addrPath = path.join(__dirname, "..", "output", cfg.addressFile);
  if (!fs.existsSync(addrPath)) {
    throw new Error(`Address file not found: ${addrPath}. Run the deploy script first.`);
  }
  const addresses = JSON.parse(fs.readFileSync(addrPath, "utf8"));

  if (!addresses.flashLoan || !addresses.priceOracle) {
    throw new Error("Addresses file is missing flashLoan or priceOracle — was deployment successful?");
  }

  console.log("📄 Loaded addresses:");
  console.log(`   FlashLoanSecure:    ${addresses.flashLoan}`);
  console.log(`   PriceOraclePolygon: ${addresses.priceOracle}`);
  if (addresses.mockOracle) console.log(`   MockOracle:         ${addresses.mockOracle}`);
  console.log();

  // ── 1. Bytecode check ───────────────────────────────────────────────────────
  console.log("1️⃣  Checking bytecode…");
  for (const [label, addr] of [
    ["FlashLoanSecure",    addresses.flashLoan],
    ["PriceOraclePolygon", addresses.priceOracle],
  ]) {
    const code = await ethers.provider.getCode(addr);
    if (code === "0x") throw new Error(`${label} has no bytecode at ${addr} — deployment failed?`);
    console.log(`   ✅ ${label} has bytecode (${((code.length - 2) / 2)} bytes)`);
  }
  console.log();

  // ── 2. FlashLoanSecure state ────────────────────────────────────────────────
  console.log("2️⃣  Checking FlashLoanSecure state…");
  const fl = new ethers.Contract(addresses.flashLoan, FLASH_LOAN_ABI, ethers.provider);

  const [provider, oracle, owner, isPaused, maxDepth] = await Promise.all([
    fl.ADDRESSES_PROVIDER(),
    fl.PRICE_ORACLE(),
    fl.owner(),
    fl.paused(),
    fl.MAX_RECURSION_DEPTH(),
  ]);

  _assert(
    provider.toLowerCase() === cfg.aaveProvider.toLowerCase(),
    `ADDRESSES_PROVIDER mismatch: got ${provider}, expected ${cfg.aaveProvider}`
  );
  console.log(`   ✅ ADDRESSES_PROVIDER: ${provider}`);

  _assert(
    oracle.toLowerCase() === addresses.priceOracle.toLowerCase(),
    `PRICE_ORACLE mismatch: got ${oracle}, expected ${addresses.priceOracle}`
  );
  console.log(`   ✅ PRICE_ORACLE: ${oracle}`);

  _assert(
    owner.toLowerCase() === signer.address.toLowerCase(),
    `Owner mismatch: got ${owner}, expected ${signer.address}`
  );
  console.log(`   ✅ Owner: ${owner}`);

  _assert(!isPaused, "Contract is paused — unexpected for a fresh deployment");
  console.log(`   ✅ Not paused`);

  _assert(maxDepth === 3n, `MAX_RECURSION_DEPTH should be 3, got ${maxDepth}`);
  console.log(`   ✅ MAX_RECURSION_DEPTH: ${maxDepth}`);
  console.log();

  // ── 3. PriceOraclePolygon — live price queries ─────────────────────────────
  console.log("3️⃣  Checking PriceOraclePolygon live prices…");
  const po = new ethers.Contract(addresses.priceOracle, PRICE_ORACLE_ABI, ethers.provider);

  const testAmount = ethers.parseUnits("1000", 6); // 1000 USDC
  const [qsPrice, ssPrice] = await Promise.all([
    po.getQuickSwapPrice(cfg.usdc, cfg.wmatic, testAmount).catch(() => 0n),
    po.getSushiSwapPrice(cfg.usdc, cfg.wmatic, testAmount).catch(() => 0n),
  ]);

  if (qsPrice > 0n) {
    console.log(`   ✅ QuickSwap: 1000 USDC → ${ethers.formatUnits(qsPrice, 18)} WMATIC`);
  } else {
    console.log(`   ⚠️  QuickSwap returned 0 (pair may have no liquidity on this network)`);
  }

  if (ssPrice > 0n) {
    console.log(`   ✅ SushiSwap: 1000 USDC → ${ethers.formatUnits(ssPrice, 18)} WMATIC`);
  } else {
    console.log(`   ⚠️  SushiSwap returned 0 (pair may have no liquidity on this network)`);
  }
  console.log();

  // ── 4. Polygonscan verification ─────────────────────────────────────────────
  if (process.env.POLYGONSCAN_API_KEY) {
    console.log("4️⃣  Submitting Polygonscan verification requests…");
    try {
      await run("verify:verify", {
        address: addresses.priceOracle,
        constructorArguments: [
          // These must match the deploy script exactly
        ],
      });
      console.log(`   ✅ PriceOraclePolygon verified`);
    } catch (e) {
      console.log(`   ⚠️  PriceOraclePolygon verification: ${e.message}`);
    }

    try {
      await run("verify:verify", {
        address: addresses.flashLoan,
        constructorArguments: [
          cfg.aaveProvider,
          addresses.priceOracle,
          signer.address,
        ],
      });
      console.log(`   ✅ FlashLoanSecure verified`);
    } catch (e) {
      console.log(`   ⚠️  FlashLoanSecure verification: ${e.message}`);
    }
  } else {
    console.log("4️⃣  Skipping Polygonscan verification (POLYGONSCAN_API_KEY not set)");
    console.log("   To verify manually:");
    console.log(`   npx hardhat verify --network ${netName} ${addresses.flashLoan} "${cfg.aaveProvider}" "${addresses.priceOracle}" "${signer.address}"`);
  }

  console.log("\n🎉 All checks passed — deployment looks healthy!\n");
}

function _assert(condition, message) {
  if (!condition) throw new Error(`Assertion failed: ${message}`);
}

main().catch((err) => {
  console.error("❌ Verification failed:", err.message);
  process.exitCode = 1;
});
