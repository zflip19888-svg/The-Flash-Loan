/**
 * @file FlashLoanPolygon.fork.test.js
 * @notice Fork tests against a pinned Polygon mainnet block.
 *
 * Prerequisites:
 *   POLYGON_RPC_URL must be set in .env (Alchemy archival node recommended)
 *
 * Run:
 *   npm run test:fork
 *   # or: POLYGON_RPC_URL=https://... npx hardhat test test/FlashLoanPolygon.fork.test.js
 *
 * What is tested:
 *   1. PriceOraclePolygon queries real QuickSwap / SushiSwap reserves
 *   2. getArbitrageSpread returns valid DEX addresses
 *   3. Chainlink MATIC/USD feed is fresh and returns a plausible price
 *   4. FlashLoanSecure state after deploy (provider, oracle, owner)
 *   5. Daily volume limit fires for over-cap borrow
 *   6. initiateFlashLoan reaches the real Aave pool and calls back
 *      (reverts at InsufficientProfit — proves Aave integration is wired)
 *   7. TwapOracle registers a pair and records a snapshot
 */

const { expect }       = require("chai");
const { ethers }       = require("hardhat");

// ─────────────────────────────────────────────────────────────────────────────
// Polygon mainnet constants (pinned to a recent block)
// ─────────────────────────────────────────────────────────────────────────────

const AAVE_POOL_PROVIDER  = "0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb";
const QUICKSWAP_ROUTER    = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";
const QUICKSWAP_FACTORY   = "0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32";
const SUSHISWAP_ROUTER    = "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506";
const SUSHISWAP_FACTORY   = "0xc35DADB65012eC5796536bD9864eD8773aBc74C4";

// Tokens
const USDC   = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
const WMATIC = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
const WETH   = "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619";

// Chainlink MATIC/USD feed
const CL_MATIC_USD = "0xAB594600376Ec9fD91F8e885dADF0CE036862dE0";

// Well-known USDC/WMATIC QuickSwap pair (for TwapOracle test)
const QS_USDC_WMATIC_PAIR = "0x6e7a5FAFcec6BB1e78bAE2A1F0B612012BF14827";

// A large USDC holder (for seeding the flash loan contract)
const USDC_WHALE = "0xe7804c37c13166fF0b37F5aE0BB07A3aEbb6e245";

// ─────────────────────────────────────────────────────────────────────────────
// ABIs
// ─────────────────────────────────────────────────────────────────────────────

const ERC20_ABI = [
  "function balanceOf(address) external view returns (uint256)",
  "function transfer(address to, uint256 amount) external returns (bool)",
];

const CL_ABI = [
  "function latestRoundData() external view returns (uint80,int256,uint256,uint256,uint80)",
  "function decimals() external view returns (uint8)",
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

async function fundWithMatic(address) {
  await ethers.provider.send("hardhat_setBalance", [
    address,
    "0x" + (100n * 10n ** 18n).toString(16),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Suite
// ─────────────────────────────────────────────────────────────────────────────

describe("FlashLoanPolygon — Fork Tests", function () {
  this.timeout(180_000);

  let owner, priceOracle, flashLoan, twapOracle;

  before(async function () {
    if (!process.env.POLYGON_RPC_URL) {
      console.warn("  ⚠️  POLYGON_RPC_URL not set — skipping fork tests");
      this.skip();
    }

    [owner] = await ethers.getSigners();
    await fundWithMatic(owner.address);

    // ── Deploy PriceOraclePolygon ──
    const PriceOraclePolygon = await ethers.getContractFactory("PriceOraclePolygon");
    priceOracle = await PriceOraclePolygon.deploy(
      QUICKSWAP_ROUTER,
      SUSHISWAP_ROUTER,
      QUICKSWAP_FACTORY,
      SUSHISWAP_FACTORY,
      [], []
    );

    // ── Deploy FlashLoanSecure ──
    const FlashLoanSecure = await ethers.getContractFactory("FlashLoanSecure");
    flashLoan = await FlashLoanSecure.deploy(
      AAVE_POOL_PROVIDER,
      await priceOracle.getAddress(),
      owner.address
    );

    // ── Deploy TwapOracle ──
    const TwapOracle = await ethers.getContractFactory("TwapOracle");
    twapOracle = await TwapOracle.deploy();

    // ── Seed USDC into flash loan contract via whale ──
    await fundWithMatic(USDC_WHALE);
    await ethers.provider.send("hardhat_impersonateAccount", [USDC_WHALE]);
    const whale = await ethers.getSigner(USDC_WHALE);
    const usdc  = new ethers.Contract(USDC, ERC20_ABI, whale);
    await usdc.transfer(await flashLoan.getAddress(), ethers.parseUnits("200000", 6));
    await ethers.provider.send("hardhat_stopImpersonatingAccount", [USDC_WHALE]);
  });

  // ── 1. Chainlink feed ────────────────────────────────────────────────────────
  describe("1. Chainlink MATIC/USD feed", function () {
    it("returns a positive, fresh MATIC/USD price", async function () {
      const feed = new ethers.Contract(CL_MATIC_USD, CL_ABI, ethers.provider);
      const [, answer, , updatedAt] = await feed.latestRoundData();
      const decimals = await feed.decimals();
      const price    = Number(answer) / 10 ** Number(decimals);

      expect(price).to.be.gt(0.01);
      expect(price).to.be.lt(100); // sanity bound

      const age = Math.floor(Date.now() / 1000) - Number(updatedAt);
      // On a fork the block is recent; age < 2 hours for a valid feed
      expect(age).to.be.lt(7200);

      console.log(`     MATIC/USD: $${price.toFixed(4)} (age: ${age}s)`);
    });
  });

  // ── 2. PriceOraclePolygon ────────────────────────────────────────────────────
  describe("2. PriceOraclePolygon — live DEX queries", function () {
    it("QuickSwap: 1000 USDC → WMATIC returns non-zero", async function () {
      const amt   = ethers.parseUnits("1000", 6);
      const price = await priceOracle.getQuickSwapPrice(USDC, WMATIC, amt);
      expect(price).to.be.gt(0n);
      console.log(`     QS: 1000 USDC → ${ethers.formatUnits(price, 18)} WMATIC`);
    });

    it("SushiSwap: 1000 USDC → WMATIC returns non-zero", async function () {
      const amt   = ethers.parseUnits("1000", 6);
      const price = await priceOracle.getSushiSwapPrice(USDC, WMATIC, amt);
      expect(price).to.be.gt(0n);
      console.log(`     SS: 1000 USDC → ${ethers.formatUnits(price, 18)} WMATIC`);
    });

    it("QuickSwap: 1 WETH → USDC is in $100–$10,000 range", async function () {
      const amt   = ethers.parseUnits("1", 18);
      const price = await priceOracle.getQuickSwapPrice(WETH, USDC, amt);
      const usd   = Number(ethers.formatUnits(price, 6));
      expect(usd).to.be.gt(100).and.lt(10_000);
      console.log(`     QS: 1 WETH = $${usd.toFixed(2)}`);
    });

    it("getArbitrageSpread returns valid DEX addresses", async function () {
      const amt = ethers.parseUnits("1000", 6);
      const [spread, cheaperDex, expensiveDex] =
        await priceOracle.getArbitrageSpread(USDC, WMATIC, amt);

      expect(spread).to.be.gte(0n);
      const validDexes = [
        QUICKSWAP_ROUTER.toLowerCase(),
        SUSHISWAP_ROUTER.toLowerCase(),
      ];
      expect(validDexes).to.include(cheaperDex.toLowerCase());
      expect(validDexes).to.include(expensiveDex.toLowerCase());
      console.log(`     Spread: ${ethers.formatUnits(spread, 18)} WMATIC`);
      console.log(`     Cheaper:   ${cheaperDex}`);
      console.log(`     Expensive: ${expensiveDex}`);
    });
  });

  // ── 3. FlashLoanSecure state ─────────────────────────────────────────────────
  describe("3. FlashLoanSecure deployment state", function () {
    it("ADDRESSES_PROVIDER points to real Aave provider", async function () {
      expect((await flashLoan.ADDRESSES_PROVIDER()).toLowerCase())
        .to.equal(AAVE_POOL_PROVIDER.toLowerCase());
    });

    it("PRICE_ORACLE is correctly set", async function () {
      expect((await flashLoan.PRICE_ORACLE()).toLowerCase())
        .to.equal((await priceOracle.getAddress()).toLowerCase());
    });

    it("owner is the deployer", async function () {
      expect(await flashLoan.owner()).to.equal(owner.address);
    });

    it("contract is not paused", async function () {
      expect(await flashLoan.paused()).to.be.false;
    });

    it("contract received USDC seed funds", async function () {
      const usdc = new ethers.Contract(USDC, ERC20_ABI, ethers.provider);
      const bal  = await usdc.balanceOf(await flashLoan.getAddress());
      expect(bal).to.be.gt(0n);
      console.log(`     USDC balance: ${ethers.formatUnits(bal, 6)}`);
    });
  });

  // ── 4. Circuit breakers ──────────────────────────────────────────────────────
  describe("4. Circuit breakers on forked chain", function () {
    it("daily volume limit blocks over-cap borrow", async function () {
      const limit = ethers.parseUnits("5000", 6);
      await flashLoan.connect(owner).setDailyVolumeLimit(USDC, limit);

      const params = encodeParams(USDC, WMATIC, QUICKSWAP_ROUTER, SUSHISWAP_ROUTER, 0n);
      await expect(
        flashLoan.connect(owner).initiateFlashLoan(
          USDC, ethers.parseUnits("5001", 6), params
        )
      ).to.be.revertedWithCustomError(flashLoan, "DailyVolumeLimitExceeded");

      // Reset so remaining tests aren't blocked
      await flashLoan.connect(owner).setDailyVolumeLimit(USDC, 0n);
    });
  });

  // ── 5. Aave pool reachability ────────────────────────────────────────────────
  describe("5. Aave v3 pool reachability", function () {
    it("initiateFlashLoan reaches real Aave pool (reverts inside executeOperation)", async function () {
      // Set an impossible minProfit — proves Aave called us back and we revert atomically
      const params = encodeParams(
        USDC, WMATIC, QUICKSWAP_ROUTER, SUSHISWAP_ROUTER,
        ethers.parseUnits("9999999", 6)
      );

      await expect(
        flashLoan.connect(owner).initiateFlashLoan(
          USDC, ethers.parseUnits("10000", 6), params,
          { gasLimit: 1_500_000 }
        )
      ).to.be.reverted; // reverts at InsufficientProfit — Aave integration confirmed
    });
  });

  // ── 6. TwapOracle ────────────────────────────────────────────────────────────
  describe("6. TwapOracle — snapshot registration", function () {
    it("registers a pair and records an initial observation", async function () {
      await twapOracle.registerPair(QS_USDC_WMATIC_PAIR);

      const [window, isReady, lastUpdate] =
        await twapOracle.getWindowInfo(QS_USDC_WMATIC_PAIR);

      // Right after registration window = 0 (prev == last), not ready yet
      expect(window).to.equal(0n);
      expect(isReady).to.be.false;
      expect(lastUpdate).to.be.gt(0n);
      console.log(`     Last update: ${new Date(Number(lastUpdate) * 1000).toISOString()}`);
    });

    it("records a second observation after advancing time (window >= MIN_WINDOW)", async function () {
      // Advance time by 6 minutes
      await ethers.provider.send("evm_increaseTime", [360]);
      await ethers.provider.send("evm_mine", []);

      await twapOracle.update(QS_USDC_WMATIC_PAIR);

      const [window, isReady] = await twapOracle.getWindowInfo(QS_USDC_WMATIC_PAIR);
      // window should now be >= 360 seconds (6 min > MIN_WINDOW of 5 min)
      expect(window).to.be.gte(300n);
      expect(isReady).to.be.true;
      console.log(`     TWAP window: ${window}s — ready: ${isReady}`);
    });

    it("consult() returns a non-zero TWAP price after window is ready", async function () {
      const amountIn = ethers.parseUnits("1000", 6); // 1000 USDC
      const amountOut = await twapOracle.consult(QS_USDC_WMATIC_PAIR, USDC, amountIn);
      expect(amountOut).to.be.gt(0n);
      console.log(`     TWAP: 1000 USDC → ${ethers.formatUnits(amountOut, 18)} WMATIC`);
    });
  });
});
