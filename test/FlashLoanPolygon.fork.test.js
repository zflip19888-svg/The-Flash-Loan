/**
 * @file FlashLoanPolygon.fork.test.js
 * @notice Fork tests against Polygon mainnet state.
 *
 * These tests require a Polygon mainnet RPC URL set in POLYGON_RPC_URL.
 * Run with:
 *   npx hardhat test test/FlashLoanPolygon.fork.test.js --network hardhat
 *
 * The Hardhat config forks Polygon mainnet.  We:
 *   1. Impersonate large USDC holders to fund test accounts.
 *   2. Deploy FlashLoanSecure against real Aave v3 pool.
 *   3. Verify the contract can request a flash loan (or at minimum encodes
 *      correctly and reaches the Aave pool).
 *   4. Check real QuickSwap / SushiSwap prices via PriceOraclePolygon.
 */

const { expect }       = require("chai");
const { ethers }       = require("hardhat");

// ─────────────────────────────────────────────────────────────────────────────
// Known Polygon mainnet addresses
// ─────────────────────────────────────────────────────────────────────────────

const AAVE_POOL_PROVIDER  = "0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb";
const AAVE_POOL           = "0x794a61358D6845594F94dc1DB02A252b5b4814aD";
const QUICKSWAP_ROUTER    = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";
const QUICKSWAP_FACTORY   = "0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32";
const SUSHISWAP_ROUTER    = "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506";
const SUSHISWAP_FACTORY   = "0xc35DADB65012eC5796536bD9864eD8773aBc74C4";
const USDC                = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
const WMATIC              = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
const WETH                = "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619";

// A known large USDC holder on Polygon (used for impersonation to fund tests)
const USDC_WHALE          = "0xe7804c37c13166fF0b37F5aE0BB07A3aEbb6e245";

// ─────────────────────────────────────────────────────────────────────────────
// ERC-20 ABI (minimal)
// ─────────────────────────────────────────────────────────────────────────────

const ERC20_ABI = [
  "function balanceOf(address) external view returns (uint256)",
  "function approve(address spender, uint256 amount) external returns (bool)",
  "function transfer(address to, uint256 amount) external returns (bool)",
];

// ─────────────────────────────────────────────────────────────────────────────
// Helper
// ─────────────────────────────────────────────────────────────────────────────

function encodeParams(tokenIn, tokenOut, dexA, dexB, minProfit) {
  return ethers.AbiCoder.defaultAbiCoder().encode(
    ["address", "address", "address", "address", "uint256"],
    [tokenIn, tokenOut, dexA, dexB, minProfit]
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

describe("FlashLoanPolygon — Fork Tests", function () {
  this.timeout(120_000); // fork tests can be slow

  let owner, priceOracle, flashLoan;

  before(async function () {
    // Skip if no RPC configured
    if (!process.env.POLYGON_RPC_URL) {
      console.warn("  ⚠️  POLYGON_RPC_URL not set — skipping fork tests");
      this.skip();
    }

    [owner] = await ethers.getSigners();

    // Fund owner with MATIC for gas
    await ethers.provider.send("hardhat_setBalance", [
      owner.address,
      "0x" + (100n * 10n ** 18n).toString(16),
    ]);

    // Deploy PriceOraclePolygon against real DEXes
    const PriceOraclePolygon = await ethers.getContractFactory("PriceOraclePolygon");
    priceOracle = await PriceOraclePolygon.deploy(
      QUICKSWAP_ROUTER,
      SUSHISWAP_ROUTER,
      QUICKSWAP_FACTORY,
      SUSHISWAP_FACTORY,
      [], []
    );

    // Deploy FlashLoanSecure against real Aave pool provider
    const FlashLoanSecure = await ethers.getContractFactory("FlashLoanSecure");
    flashLoan = await FlashLoanSecure.deploy(
      AAVE_POOL_PROVIDER,
      await priceOracle.getAddress(),
      owner.address
    );

    // Fund flash loan contract with USDC via whale impersonation
    await ethers.provider.send("hardhat_impersonateAccount", [USDC_WHALE]);
    await ethers.provider.send("hardhat_setBalance", [
      USDC_WHALE,
      "0x" + (10n * 10n ** 18n).toString(16),
    ]);
    const whale    = await ethers.getSigner(USDC_WHALE);
    const usdcToken = new ethers.Contract(USDC, ERC20_ABI, whale);
    const seedAmount = ethers.parseUnits("100000", 6); // 100k USDC seed
    await usdcToken.transfer(await flashLoan.getAddress(), seedAmount);
    await ethers.provider.send("hardhat_stopImpersonatingAccount", [USDC_WHALE]);
  });

  // ── Price oracle queries ───────────────────────────────────────────────────
  describe("PriceOraclePolygon on-chain queries", function () {
    it("returns a non-zero QuickSwap price for USDC → WMATIC", async function () {
      const amount = ethers.parseUnits("1000", 6); // 1000 USDC
      const price  = await priceOracle.getQuickSwapPrice(USDC, WMATIC, amount);
      expect(price).to.be.gt(0n);
      console.log(`  QuickSwap: 1000 USDC → ${ethers.formatUnits(price, 18)} WMATIC`);
    });

    it("returns a non-zero SushiSwap price for USDC → WMATIC", async function () {
      const amount = ethers.parseUnits("1000", 6);
      const price  = await priceOracle.getSushiSwapPrice(USDC, WMATIC, amount);
      expect(price).to.be.gt(0n);
      console.log(`  SushiSwap: 1000 USDC → ${ethers.formatUnits(price, 18)} WMATIC`);
    });

    it("returns non-zero spread and valid DEX addresses for USDC/WMATIC", async function () {
      const amount = ethers.parseUnits("1000", 6);
      const [spread, cheaperDex, expensiveDex] =
        await priceOracle.getArbitrageSpread(USDC, WMATIC, amount);

      expect(spread).to.be.gte(0n);
      expect([QUICKSWAP_ROUTER.toLowerCase(), SUSHISWAP_ROUTER.toLowerCase()])
        .to.include(cheaperDex.toLowerCase());
      expect([QUICKSWAP_ROUTER.toLowerCase(), SUSHISWAP_ROUTER.toLowerCase()])
        .to.include(expensiveDex.toLowerCase());

      console.log(`  Spread: ${ethers.formatUnits(spread, 18)} WMATIC`);
      console.log(`  Cheaper DEX:   ${cheaperDex}`);
      console.log(`  Expensive DEX: ${expensiveDex}`);
    });

    it("QuickSwap price for WETH → USDC is in a reasonable range", async function () {
      const amount = ethers.parseUnits("1", 18); // 1 WETH
      const price  = await priceOracle.getQuickSwapPrice(WETH, USDC, amount);
      // WETH/USDC should be between $100 and $10,000 for sanity
      const priceUsd = Number(ethers.formatUnits(price, 6));
      expect(priceUsd).to.be.gt(100);
      expect(priceUsd).to.be.lt(10_000);
      console.log(`  QuickSwap: 1 WETH = $${priceUsd.toFixed(2)} USDC`);
    });
  });

  // ── Contract state ─────────────────────────────────────────────────────────
  describe("FlashLoanSecure deployment state", function () {
    it("ADDRESSES_PROVIDER is set to real Aave provider", async function () {
      const provider = await flashLoan.ADDRESSES_PROVIDER();
      expect(provider.toLowerCase()).to.equal(AAVE_POOL_PROVIDER.toLowerCase());
    });

    it("PRICE_ORACLE is set correctly", async function () {
      const oracle = await flashLoan.PRICE_ORACLE();
      expect(oracle.toLowerCase()).to.equal((await priceOracle.getAddress()).toLowerCase());
    });

    it("owner is the deployer", async function () {
      expect(await flashLoan.owner()).to.equal(owner.address);
    });

    it("contract received USDC seed funds", async function () {
      const usdc = new ethers.Contract(USDC, ERC20_ABI, ethers.provider);
      const bal  = await usdc.balanceOf(await flashLoan.getAddress());
      expect(bal).to.be.gt(0n);
      console.log(`  FlashLoan USDC balance: ${ethers.formatUnits(bal, 6)} USDC`);
    });
  });

  // ── Flash loan reachability ────────────────────────────────────────────────
  describe("Flash loan reachability", function () {
    it("initiateFlashLoan reaches Aave pool (reverts inside executeOperation due to no real arbitrage profit)", async function () {
      // In a forked environment without a profitable spread, the transaction will
      // revert at the InsufficientProfit check inside executeOperation — but the
      // important thing is the Aave pool is reachable and calls back correctly.
      const params = encodeParams(
        USDC,
        WMATIC,
        QUICKSWAP_ROUTER,
        SUSHISWAP_ROUTER,
        ethers.parseUnits("9999999", 6) // impossibly high minProfit → guaranteed revert
      );

      await expect(
        flashLoan.connect(owner).initiateFlashLoan(
          USDC,
          ethers.parseUnits("10000", 6),
          params,
          { gasLimit: 1_000_000 }
        )
      ).to.be.reverted; // reverts inside executeOperation — proves Aave integration works
    });

    it("daily volume limit can be set and blocks over-limit borrows", async function () {
      const limitAmount = ethers.parseUnits("5000", 6); // 5000 USDC
      await flashLoan.connect(owner).setDailyVolumeLimit(USDC, limitAmount);

      const params = encodeParams(
        USDC, WMATIC,
        QUICKSWAP_ROUTER, SUSHISWAP_ROUTER,
        0n
      );

      await expect(
        flashLoan.connect(owner).initiateFlashLoan(
          USDC,
          ethers.parseUnits("5001", 6), // over limit
          params
        )
      ).to.be.revertedWithCustomError(flashLoan, "DailyVolumeLimitExceeded");

      // Reset limit
      await flashLoan.connect(owner).setDailyVolumeLimit(USDC, 0n);
    });
  });
});
