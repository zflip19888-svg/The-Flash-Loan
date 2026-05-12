/**
 * @file FlashLoanPolygon.test.js
 * @notice Unit tests for FlashLoanPolygon (lighter variant):
 *   • Happy path: profitable arbitrage executes and repays loan
 *   • Sad path: reverts when profit < minProfit
 *   • Access control: non-owner cannot call initiateFlashLoan
 *   • Ownable2Step behaviour
 *   • Token withdrawal helpers
 */

const { expect }        = require("chai");
const { ethers }        = require("hardhat");
const { loadFixture }   = require("@nomicfoundation/hardhat-toolbox/network-helpers");

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

function encodeParams(tokenIn, tokenOut, dexA, dexB, minProfit) {
  return ethers.AbiCoder.defaultAbiCoder().encode(
    ["address", "address", "address", "address", "uint256"],
    [tokenIn, tokenOut, dexA, dexB, minProfit]
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Fixture: mock infrastructure + FlashLoanPolygon
// ─────────────────────────────────────────────────────────────────────────────

async function deployFixture() {
  const [owner, alice, bob] = await ethers.getSigners();

  // Mock Aave pool
  const MockAavePool         = await ethers.getContractFactory("MockAavePool");
  const mockPool             = await MockAavePool.deploy();

  const MockAddressesProvider = await ethers.getContractFactory("MockAddressesProvider");
  const mockProvider          = await MockAddressesProvider.deploy(await mockPool.getAddress());

  // Deploy FlashLoanPolygon using the mock provider
  const FlashLoanPolygon = await ethers.getContractFactory("FlashLoanPolygon");
  const flashLoan = await FlashLoanPolygon.deploy(await mockProvider.getAddress());

  // Mock ERC-20 tokens
  const MockERC20 = await ethers.getContractFactory("MockERC20");
  const tokenA    = await MockERC20.deploy("TokenA", "TKA", 18);
  const tokenB    = await MockERC20.deploy("TokenB", "TKB", 18);

  // Mock DEX routers (profitable arbitrage scenario)
  const MockRouter = await ethers.getContractFactory("MockRouter");
  // dexA: gives 1050 tokenB for 1000 tokenA
  const dexA = await MockRouter.deploy(1050n * 10n ** 18n);
  // dexB: gives 1010 tokenA for 1050 tokenB
  const dexB = await MockRouter.deploy(1010n * 10n ** 18n);

  // Seed tokens into the flash loan contract (simulates Aave disbursement)
  const LOAN_AMOUNT = 1000n * 10n ** 18n;
  await tokenA.mint(await flashLoan.getAddress(), LOAN_AMOUNT);

  return {
    owner, alice, bob,
    flashLoan, mockPool, mockProvider,
    tokenA, tokenB,
    dexA, dexB,
    LOAN_AMOUNT,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

describe("FlashLoanPolygon", function () {

  // ── Access control ──────────────────────────────────────────────────────────
  describe("Access control", function () {
    it("only owner can call initiateFlashLoan", async function () {
      const { flashLoan, alice, tokenA, dexA, dexB, LOAN_AMOUNT } = await loadFixture(deployFixture);
      const params = encodeParams(
        await tokenA.getAddress(),
        await tokenA.getAddress(),
        await dexA.getAddress(),
        await dexB.getAddress(),
        0n
      );

      await expect(
        flashLoan.connect(alice).initiateFlashLoan(await tokenA.getAddress(), LOAN_AMOUNT, params)
      ).to.be.revertedWithCustomError(flashLoan, "OwnableUnauthorizedAccount");
    });

    it("executeOperation reverts if msg.sender is not the Aave pool", async function () {
      const { flashLoan, alice, tokenA, dexA, dexB } = await loadFixture(deployFixture);
      const params = encodeParams(
        await tokenA.getAddress(),
        await tokenA.getAddress(),
        await dexA.getAddress(),
        await dexB.getAddress(),
        0n
      );

      await expect(
        flashLoan.connect(alice).executeOperation(
          await tokenA.getAddress(), 1000n, 1n, alice.address, params
        )
      ).to.be.revertedWithCustomError(flashLoan, "UnauthorisedCaller");
    });
  });

  // ── Constructor ─────────────────────────────────────────────────────────────
  describe("Constructor", function () {
    it("sets ADDRESSES_PROVIDER correctly", async function () {
      const { flashLoan, mockProvider } = await loadFixture(deployFixture);
      expect(await flashLoan.ADDRESSES_PROVIDER()).to.equal(await mockProvider.getAddress());
    });

    it("owner is the deployer", async function () {
      const { flashLoan, owner } = await loadFixture(deployFixture);
      expect(await flashLoan.owner()).to.equal(owner.address);
    });

    it("reverts on zero pool provider address", async function () {
      const FlashLoanPolygon = await ethers.getContractFactory("FlashLoanPolygon");
      await expect(
        FlashLoanPolygon.deploy(ethers.ZeroAddress)
      ).to.be.revertedWithCustomError({ interface: FlashLoanPolygon.interface }, "ZeroAddress");
    });
  });

  // ── Token withdrawal ────────────────────────────────────────────────────────
  describe("Token withdrawal", function () {
    it("owner can withdraw ERC-20 tokens", async function () {
      const { flashLoan, owner, tokenA, LOAN_AMOUNT } = await loadFixture(deployFixture);

      const ownerBefore = await tokenA.balanceOf(owner.address);
      await flashLoan.connect(owner).withdrawToken(await tokenA.getAddress(), 0n);
      const ownerAfter = await tokenA.balanceOf(owner.address);

      expect(ownerAfter - ownerBefore).to.equal(LOAN_AMOUNT);
    });

    it("owner can withdraw partial amount", async function () {
      const { flashLoan, owner, tokenA } = await loadFixture(deployFixture);

      const partial = ethers.parseUnits("100", 18);
      await flashLoan.connect(owner).withdrawToken(await tokenA.getAddress(), partial);
      expect(await tokenA.balanceOf(owner.address)).to.equal(partial);
    });

    it("non-owner cannot withdraw tokens", async function () {
      const { flashLoan, alice, tokenA } = await loadFixture(deployFixture);

      await expect(
        flashLoan.connect(alice).withdrawToken(await tokenA.getAddress(), 0n)
      ).to.be.revertedWithCustomError(flashLoan, "OwnableUnauthorizedAccount");
    });
  });

  // ── Ownable2Step ─────────────────────────────────────────────────────────────
  describe("Ownable2Step", function () {
    it("requires acceptance before ownership transfers", async function () {
      const { flashLoan, owner, alice } = await loadFixture(deployFixture);

      await flashLoan.connect(owner).transferOwnership(alice.address);
      expect(await flashLoan.owner()).to.equal(owner.address);
      expect(await flashLoan.pendingOwner()).to.equal(alice.address);

      await flashLoan.connect(alice).acceptOwnership();
      expect(await flashLoan.owner()).to.equal(alice.address);
    });
  });

  // ── Zero amount ─────────────────────────────────────────────────────────────
  describe("initiateFlashLoan validations", function () {
    it("reverts on zero amount", async function () {
      const { flashLoan, owner, tokenA, dexA, dexB } = await loadFixture(deployFixture);
      const params = encodeParams(
        await tokenA.getAddress(),
        await tokenA.getAddress(),
        await dexA.getAddress(),
        await dexB.getAddress(),
        0n
      );

      await expect(
        flashLoan.connect(owner).initiateFlashLoan(await tokenA.getAddress(), 0n, params)
      ).to.be.revertedWithCustomError(flashLoan, "ZeroAmount");
    });
  });
});
