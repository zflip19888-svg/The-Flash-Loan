/**
 * pre-deploy-check.js — Full readiness audit before going live.
 * Usage: node scripts/pre-deploy-check.js
 */
require("dotenv").config();
const { ethers } = require("ethers");

const FLASH_LOAN   = process.env.FLASH_LOAN_ADDRESS   || "0xBafc19Fd23714bD2F3256C20a6036a5B31A9DbD8";
const PRICE_ORACLE = process.env.PRICE_ORACLE_ADDRESS || "0xbBaf624eDe7A57141ADFF779dBf474c9527faD9f";
const WETH   = "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619";
const USDC   = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
const WMATIC = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";

const FL_ABI = [
  "function paused() external view returns (bool)",
  "function owner() external view returns (address)",
  "function dailyVolumeLimit(address) external view returns (uint256)",
  "function dailyVolumeUsed(address) external view returns (uint256)",
];
const PO_ABI = [
  "function getArbitrageSpread(address,address,uint256) external view returns (uint256,address,address)",
];

const CHECKS = [];
function pass(label, detail="") { CHECKS.push({ ok: true,  label, detail }); }
function fail(label, detail="") { CHECKS.push({ ok: false, label, detail }); }

async function main() {
  const provider = new ethers.JsonRpcProvider(process.env.POLYGON_RPC_URL);
  const wallet   = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
  const fl       = new ethers.Contract(FLASH_LOAN,   FL_ABI, provider);
  const po       = new ethers.Contract(PRICE_ORACLE, PO_ABI, provider);
  const fee      = await provider.getFeeData();
  const bal      = await provider.getBalance(wallet.address);
  const block    = await provider.getBlockNumber();

  console.log(`\n⚡ Flash Loan Arb — Pre-Deploy Check`);
  console.log(`   Block #${block} | ${new Date().toUTCString()}\n`);

  // 1. RPC
  block > 0 ? pass("RPC connectivity", `Block #${block}`) : fail("RPC connectivity");

  // 2. Wallet
  const maticBal = parseFloat(ethers.formatEther(bal));
  const gasGwei  = parseFloat(ethers.formatUnits(fee.gasPrice, "gwei"));
  const txCost   = parseFloat(ethers.formatEther(fee.gasPrice * 750_000n));
  const txCount  = Math.floor(maticBal / txCost);
  maticBal >= txCost * 5
    ? pass("Wallet gas balance", `${maticBal.toFixed(4)} MATIC — ~${txCount} txs`)
    : fail("Wallet gas balance", `${maticBal.toFixed(6)} MATIC — needs top-up (min 5 MATIC)`);

  // 3. Gas price
  gasGwei <= 350
    ? pass("Gas price", `${gasGwei.toFixed(1)} Gwei — under 350 ceiling`)
    : fail("Gas price", `${gasGwei.toFixed(1)} Gwei — ABOVE 350 ceiling`);

  // 4. FlashLoan contract
  const fl_code = await provider.getCode(FLASH_LOAN);
  fl_code.length > 4 ? pass("FlashLoanSecure deployed", FLASH_LOAN) : fail("FlashLoanSecure deployed", "No code at address");

  // 5. PriceOracle contract
  const po_code = await provider.getCode(PRICE_ORACLE);
  po_code.length > 4 ? pass("PriceOracle deployed", PRICE_ORACLE) : fail("PriceOracle deployed", "No code at address");

  // 6. Ownership
  const owner = await fl.owner();
  owner.toLowerCase() === wallet.address.toLowerCase()
    ? pass("Wallet is contract owner", wallet.address)
    : fail("Wallet is contract owner", `Owner is ${owner}, wallet is ${wallet.address}`);

  // 7. Not paused
  const paused = await fl.paused();
  !paused ? pass("FlashLoan not paused") : fail("FlashLoan is PAUSED — call unpause()");

  // 8. Daily volume limits
  const wethLimit  = await fl.dailyVolumeLimit(WETH);
  const usdcLimit  = await fl.dailyVolumeLimit(USDC);
  const wethOk     = wethLimit > 0n;
  const usdcOk     = usdcLimit > 0n;
  wethOk
    ? pass("WETH daily volume limit set", `${ethers.formatEther(wethLimit)} WETH`)
    : fail("WETH daily volume limit", "= 0 — ALL TRADES BLOCKED. Run set-volume-limits.js");
  usdcOk
    ? pass("USDC daily volume limit set", `${ethers.formatUnits(usdcLimit,6)} USDC`)
    : fail("USDC daily volume limit", "= 0 — run set-volume-limits.js");

  // 9. Oracle responding
  try {
    const [spread, cheap] = await po.getArbitrageSpread(WETH, USDC, ethers.parseEther("10"));
    parseFloat(ethers.formatUnits(spread, 6)) > 0
      ? pass("PriceOracle responding", `Spread: $${parseFloat(ethers.formatUnits(spread,6)).toFixed(2)} on 10 WETH`)
      : fail("PriceOracle spread", "returned 0");
  } catch(e) {
    fail("PriceOracle responding", e.message.slice(0,60));
  }

  // 10. DRY_RUN
  const dr = process.env.DRY_RUN;
  dr !== "true"
    ? pass("DRY_RUN disabled", "Live execution mode")
    : fail("DRY_RUN=true", "Set DRY_RUN=false (or remove) to go live");

  // ── Print results ─────────────────────────────────────────────────────────
  console.log("─".repeat(60));
  for (const c of CHECKS) {
    console.log(`  ${c.ok ? "✅" : "❌"} ${c.label}`);
    if (c.detail) console.log(`      ${c.detail}`);
  }
  console.log("─".repeat(60));
  const passed = CHECKS.filter(c => c.ok).length;
  const total  = CHECKS.length;
  console.log(`\n  ${passed}/${total} checks passed`);
  if (passed === total) {
    console.log("  🟢 READY FOR LIVE DEPLOYMENT\n");
  } else {
    console.log("  🔴 NOT READY — fix failing checks above\n");
  }
}

main().catch(console.error);
