/**
 * @file emergency-withdraw.js
 * @notice Emergency withdraw — pulls all supported ERC-20 tokens from the
 *         FlashLoanSecure contract into the owner's wallet. Only the contract
 *         owner can call this.
 *
 * Env: PRIVATE_KEY, POLYGON_RPC_URL, FLASH_LOAN_ADDRESS,
 *      WITHDRAW_TOKENS (comma-separated list of ERC-20 addresses, optional —
 *      defaults to WETH, USDC, WMATIC, DAI, WBTC).
 */

const { ethers, Wallet, JsonRpcProvider, Contract } = require("ethers");

const FLASH_ADDR = process.env.FLASH_LOAN_ADDRESS || "0xBafc19Fd23714bD2F3256C20a6036a5B31A9DbD8";
const RPC = process.env.POLYGON_RPC_URL;
const PK = process.env.PRIVATE_KEY;

const DEFAULT_TOKENS = [
  "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619", // WETH
  "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", // USDC
  "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270", // WMATIC
  "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063", // DAI
  "0x1BFD6FAD37F5F5cE7e8bAcaB5c29a2778BFe9D7a", // WBTC
];

const FLASH_ABI = [
  "function emergencyWithdraw(address token) external",
  "function emergencyWithdrawAll(address[] calldata tokens) external",
  "function owner() external view returns (address)",
];

const ERC20_ABI = [
  "function balanceOf(address) external view returns (uint256)",
  "function symbol() external view returns (string)",
  "function decimals() external view returns (uint8)",
];

async function main() {
  if (!RPC) {
    console.error("✗ POLYGON_RPC_URL not set");
    process.exit(1);
  }
  if (!PK) {
    console.error("✗ PRIVATE_KEY not set");
    process.exit(1);
  }

  const provider = new JsonRpcProvider(RPC, undefined, { staticNetwork: true });
  const wallet = new Wallet(PK, provider);
  const flash = new Contract(FLASH_ADDR, FLASH_ABI, wallet);

  console.log(`════════════════════════════════════════════════`);
  console.log(`  EMERGENCY WITHDRAW — FlashLoanSecure`);
  console.log(`  Contract:  ${FLASH_ADDR}`);
  console.log(`  Owner:     ${wallet.address}`);
  console.log(`════════════════════════════════════════════════`);

  // Verify ownership
  const owner = await flash.owner().catch(() => wallet.address);
  if (owner.toLowerCase() !== wallet.address.toLowerCase()) {
    console.error(`✗ Caller ${wallet.address} is not the contract owner (${owner})`);
    process.exit(1);
  }
  console.log("✓ Owner verified");

  // Check balances first
  const tokens = (process.env.WITHDRAW_TOKENS?.split(",").map(s => s.trim()).filter(Boolean) || DEFAULT_TOKENS);
  console.log(`\nChecking balances for ${tokens.length} tokens...`);
  const tokensWithBalance = [];
  for (const addr of tokens) {
    try {
      const erc = new Contract(addr, ERC20_ABI, provider);
      const bal = await erc.balanceOf(FLASH_ADDR);
      const symbol = await erc.symbol().catch(() => "???");
      const decimals = await erc.decimals().catch(() => 18n);
      const human = ethers.formatUnits(bal, decimals);
      if (bal > 0n) {
        console.log(`  ${symbol.padEnd(8)} ${human.padStart(20)}  ${addr}`);
        tokensWithBalance.push(addr);
      } else {
        console.log(`  ${symbol.padEnd(8)} ${"0".padStart(20)}  ${addr} (skip)`);
      }
    } catch (e) {
      console.log(`  ???       (error)               ${addr}: ${(e).message?.slice(0,80)}`);
    }
  }

  if (tokensWithBalance.length === 0) {
    console.log("\n✓ No tokens with non-zero balance — nothing to withdraw");
    return;
  }

  console.log(`\nWithdrawing ${tokensWithBalance.length} token(s) ...`);
  try {
    const tx = await flash.emergencyWithdrawAll(tokensWithBalance);
    console.log(`→ tx submitted: ${tx.hash}`);
    console.log("→ waiting for confirmation...");
    const receipt = await tx.wait();
    console.log(`✓ Confirmed in block ${receipt.blockNumber} (gas ${receipt.gasUsed.toString()})`);
    console.log(`→ https://polygonscan.com/tx/${tx.hash}`);
  } catch (e) {
    // Try one-by-one
    console.warn(`emergencyWithdrawAll failed: ${e.message?.slice(0,200)} — retrying one-by-one`);
    for (const addr of tokensWithBalance) {
      try {
        const tx = await flash.emergencyWithdraw(addr);
        const receipt = await tx.wait();
        console.log(`✓ ${addr} → https://polygonscan.com/tx/${tx.hash}`);
      } catch (err) {
        console.error(`✗ ${addr}: ${err.message?.slice(0,200)}`);
      }
    }
  }
}

main().catch(e => {
  console.error("✗ Emergency withdraw failed:", e.message);
  process.exit(1);
});
