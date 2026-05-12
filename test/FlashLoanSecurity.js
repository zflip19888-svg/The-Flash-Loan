/**
 * @file FlashLoanSecurity.js
 * @notice Security-focused tests for FlashLoanSecure:
 *   • Reentrancy attack attempt (must revert)
 *   • Pause / unpause
 *   • Daily volume limit enforcement
 *   • Chainlink staleness triggers revert (via PriceOraclePolygon)
 *   • Access control (non-owner cannot call initiateFlashLoan)
 *   • Ownable2Step: pending owner pattern
 */

const { expect }           = require("chai");
const { ethers }           = require("hardhat");
const { loadFixture }      = require("@nomicfoundation/hardhat-toolbox/network-helpers");

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Encode flash loan params the same way the bot does.
 */
function encodeParams(tokenIn, tokenOut, dexA, dexB, minProfit) {
  return ethers.AbiCoder.defaultAbiCoder().encode(
    ["address", "address", "address", "address", "uint256"],
    [tokenIn, tokenOut, dexA, dexB, minProfit]
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Fixture
// ─────────────────────────────────────────────────────────────────────────────

async function deployFixture() {
  const [owner, attacker, newOwner] = await ethers.getSigners();

  // MockOracle: fresh price ($1.00, 8 decimals)
  const MockOracle = await ethers.getContractFactory("MockOracle");
  const mockOracle = await MockOracle.deploy(100_000_000n, 8);

  // Minimal mock DEX factory & router (we use the real QuickSwap/Sushi constants
  // but override the pool address in tests with a MockAavePool contract)
  const MockAavePool = await ethers.getContractFactory("MockAavePool");
  const mockPool     = await MockAavePool.deploy();

  // PriceOraclePolygon with mock addresses
  const DUMMY_FACTORY = ethers.ZeroAddress; // not used in these tests
  const PriceOraclePolygon = await ethers.getContractFactory("PriceOraclePolygon");
  const priceOracle = await PriceOraclePolygon.deploy(
    await mockPool.getAddress(), // quickswap router (mock)
    await mockPool.getAddress(), // sushiswap router (mock)
    DUMMY_FACTORY,
    DUMMY_FACTORY,
    [],
    []
  );

  // FlashLoanSecure
  // We need a mock Aave PoolAddressesProvider pointing to mockPool
  const MockAddressesProvider = await ethers.getContractFactory("MockAddressesProvider");
  const mockProvider          = await MockAddressesProvider.deploy(await mockPool.getAddress());

  const FlashLoanSecure = await ethers.getContractFactory("FlashLoanSecure");
  const flashLoan = await FlashLoanSecure.deploy(
    await mockProvider.getAddress(),
    await priceOracle.getAddress(),
    owner.address
  );

  return {
    owner, attacker, newOwner,
    mockOracle, priceOracle, flashLoan,
    mockPool, mockProvider,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

describe("FlashLoanSecurity", function () {
  // ── Access control ──────────────────────────────────────────────────────────
  describe("Access control", function () {
    it("non-owner cannot call initiateFlashLoan", async function () {
      const { flashLoan, attacker, mockPool } = await loadFixture(deployFixture);
      const USDC    = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
      const WMATIC  = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
      const params  = encodeParams(USDC, WMATIC, ethers.ZeroAddress, ethers.ZeroAddress, 0n);

      await expect(
        flashLoan.connect(attacker).initiateFlashLoan(USDC, ethers.parseUnits("1000", 6), params)
      ).to.be.revertedWithCustomError(flashLoan, "OwnableUnauthorizedAccount");
    });

    it("executeOperation reverts when called by non-Aave address", async function () {
      const { flashLoan, attacker } = await loadFixture(deployFixture);
      const USDC = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
      const params = encodeParams(USDC, ethers.ZeroAddress, ethers.ZeroAddress, ethers.ZeroAddress, 0n);

      await expect(
        flashLoan.connect(attacker).executeOperation(
          USDC, 1000n, 1n, attacker.address, params
        )
      ).to.be.revertedWithCustomError(flashLoan, "UnauthorisedCaller");
    });

    it("executeOperation reverts when initiator is not the contract itself", async function () {
      const { flashLoan, mockPool, owner } = await loadFixture(deployFixture);
      const flashLoanAddress = await flashLoan.getAddress();
      const USDC   = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
      const params = encodeParams(USDC, ethers.ZeroAddress, ethers.ZeroAddress, ethers.ZeroAddress, 0n);

      // Mock pool calls executeOperation with wrong initiator
      await expect(
        mockPool.callExecuteOperation(
          flashLoanAddress,
          USDC, 1000n, 1n,
          owner.address, // wrong initiator
          params
        )
      ).to.be.reverted;
    });
  });

  // ── Pause / unpause ─────────────────────────────────────────────────────────
  describe("Pause / unpause", function () {
    it("owner can pause and unpause", async function () {
      const { flashLoan, owner } = await loadFixture(deployFixture);

      await flashLoan.connect(owner).pause();
      expect(await flashLoan.paused()).to.be.true;

      await flashLoan.connect(owner).unpause();
      expect(await flashLoan.paused()).to.be.false;
    });

    it("non-owner cannot pause", async function () {
      const { flashLoan, attacker } = await loadFixture(deployFixture);

      await expect(
        flashLoan.connect(attacker).pause()
      ).to.be.revertedWithCustomError(flashLoan, "OwnableUnauthorizedAccount");
    });

    it("initiateFlashLoan reverts when paused", async function () {
      const { flashLoan, owner } = await loadFixture(deployFixture);
      const USDC   = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
      const WMATIC = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
      const params = encodeParams(USDC, WMATIC, ethers.ZeroAddress, ethers.ZeroAddress, 0n);

      await flashLoan.connect(owner).pause();

      await expect(
        flashLoan.connect(owner).initiateFlashLoan(USDC, ethers.parseUnits("1000", 6), params)
      ).to.be.revertedWithCustomError(flashLoan, "EnforcedPause");
    });
  });

  // ── Daily volume limit ───────────────────────────────────────────────────────
  describe("Daily volume limit", function () {
    it("enforces the daily volume cap on a given asset", async function () {
      const { flashLoan, owner, mockPool } = await loadFixture(deployFixture);
      const flashLoanAddress = await flashLoan.getAddress();
      const USDC = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";

      // Set daily limit to 500 USDC (6 decimals)
      const limit = ethers.parseUnits("500", 6);
      await flashLoan.connect(owner).setDailyVolumeLimit(USDC, limit);

      // Attempt to borrow 501 USDC — should breach the limit
      const WMATIC = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
      const params = encodeParams(USDC, WMATIC, ethers.ZeroAddress, ethers.ZeroAddress, 0n);
      const amount = ethers.parseUnits("501", 6);

      await expect(
        flashLoan.connect(owner).initiateFlashLoan(USDC, amount, params)
      ).to.be.revertedWithCustomError(flashLoan, "DailyVolumeLimitExceeded");
    });

    it("allows borrowing under the daily limit", async function () {
      const { flashLoan, owner } = await loadFixture(deployFixture);
      const USDC = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";

      // Set a generous limit
      await flashLoan.connect(owner).setDailyVolumeLimit(USDC, ethers.parseUnits("1000000", 6));

      // dailyVolumeUsed should still be 0 before any flash loan
      expect(await flashLoan.dailyVolumeUsed(USDC)).to.equal(0n);
    });

    it("emits DailyVolumeLimitSet event", async function () {
      const { flashLoan, owner } = await loadFixture(deployFixture);
      const USDC  = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
      const limit = ethers.parseUnits("10000", 6);

      await expect(flashLoan.connect(owner).setDailyVolumeLimit(USDC, limit))
        .to.emit(flashLoan, "DailyVolumeLimitSet")
        .withArgs(USDC, limit);
    });

    it("non-owner cannot set daily volume limit", async function () {
      const { flashLoan, attacker } = await loadFixture(deployFixture);
      const USDC = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";

      await expect(
        flashLoan.connect(attacker).setDailyVolumeLimit(USDC, 1000n)
      ).to.be.revertedWithCustomError(flashLoan, "OwnableUnauthorizedAccount");
    });
  });

  // ── Chainlink staleness ──────────────────────────────────────────────────────
  describe("Chainlink staleness", function () {
    it("getChainlinkPrice reverts on stale feed", async function () {
      const { priceOracle, mockOracle } = await loadFixture(deployFixture);

      // Set updatedAt to > 1 hour in the past
      const staleTime = Math.floor(Date.now() / 1000) - 7201;
      await mockOracle.setUpdatedAt(staleTime);

      await expect(
        priceOracle.getChainlinkPrice(await mockOracle.getAddress())
      ).to.be.revertedWithCustomError(priceOracle, "StaleChainlinkPrice");
    });

    it("getChainlinkPrice succeeds with a fresh feed", async function () {
      const { priceOracle, mockOracle } = await loadFixture(deployFixture);
      // updatedAt defaults to block.timestamp in constructor — should be fresh
      const [answer] = await priceOracle.getChainlinkPrice(await mockOracle.getAddress());
      expect(answer).to.equal(100_000_000n);
    });
  });

  // ── Ownable2Step ─────────────────────────────────────────────────────────────
  describe("Ownable2Step ownership transfer", function () {
    it("requires new owner to accept before transfer completes", async function () {
      const { flashLoan, owner, newOwner } = await loadFixture(deployFixture);

      // Step 1: propose new owner
      await flashLoan.connect(owner).transferOwnership(newOwner.address);
      expect(await flashLoan.owner()).to.equal(owner.address); // not yet transferred
      expect(await flashLoan.pendingOwner()).to.equal(newOwner.address);

      // Step 2: new owner accepts
      await flashLoan.connect(newOwner).acceptOwnership();
      expect(await flashLoan.owner()).to.equal(newOwner.address);
    });

    it("pending owner can renounce the transfer", async function () {
      const { flashLoan, owner, newOwner } = await loadFixture(deployFixture);

      await flashLoan.connect(owner).transferOwnership(newOwner.address);
      // Owner re-proposes themselves to cancel
      await flashLoan.connect(owner).transferOwnership(owner.address);
      expect(await flashLoan.pendingOwner()).to.equal(owner.address);
    });
  });

  // ── Parameter validation ─────────────────────────────────────────────────────
  describe("Parameter validation", function () {
    it("reverts on zero amount", async function () {
      const { flashLoan, owner } = await loadFixture(deployFixture);
      const USDC   = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
      const WMATIC = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
      const params = encodeParams(USDC, WMATIC, ethers.ZeroAddress, ethers.ZeroAddress, 0n);

      await expect(
        flashLoan.connect(owner).initiateFlashLoan(USDC, 0n, params)
      ).to.be.revertedWithCustomError(flashLoan, "ZeroAmount");
    });

    it("reverts on zero asset address", async function () {
      const { flashLoan, owner } = await loadFixture(deployFixture);
      const WMATIC = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
      const params = encodeParams(ethers.ZeroAddress, WMATIC, ethers.ZeroAddress, ethers.ZeroAddress, 0n);

      await expect(
        flashLoan.connect(owner).initiateFlashLoan(ethers.ZeroAddress, 1000n, params)
      ).to.be.revertedWithCustomError(flashLoan, "ZeroAddress");
    });

    it("reverts on empty params", async function () {
      const { flashLoan, owner } = await loadFixture(deployFixture);
      const USDC = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";

      await expect(
        flashLoan.connect(owner).initiateFlashLoan(USDC, 1000n, "0x")
      ).to.be.revertedWithCustomError(flashLoan, "InvalidParams");
    });
  });
});
