/**
 * @file config.ts
 * @notice Central configuration for the arbitrage bot.
 *
 * Modes:
 *   Scan-only  — POLYGON_RPC_URL only required. Bot scans + logs, never sends tx.
 *   Live       — Also requires PRIVATE_KEY, FLASH_LOAN_ADDRESS, PRICE_ORACLE_ADDRESS.
 *
 * Start the bot:
 *   DRY_RUN=true npm run start     — scan-only, no tx
 *   npm run start                  — live execution (requires full .env)
 */


// Load .env locally if present — Railway injects vars directly so this is a no-op in production
try { require("dotenv").config({ path: require("path").resolve(__dirname, "../../.env") }); } catch (_) {}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

function requireEnv(key: string): string {
  const v = process.env[key];
  if (!v || v.trim() === "") {
    throw new Error(`Missing required env var: ${key}. Check your .env file.`);
  }
  return v.trim();
}

function optionalEnv(key: string, fallback = ""): string {
  return (process.env[key] ?? fallback).trim();
}

// ─────────────────────────────────────────────────────────────────────────────
// Environment
// ─────────────────────────────────────────────────────────────────────────────

export const ENV = {
  POLYGON_RPC_URL:      requireEnv("POLYGON_RPC_URL"),
  POLYGON_WS_URL:       optionalEnv("POLYGON_WS_URL"),
  // Optional — only needed for live execution
  PRIVATE_KEY:          optionalEnv("PRIVATE_KEY"),
  FLASH_LOAN_ADDRESS:   optionalEnv("FLASH_LOAN_ADDRESS",   "0xBafc19Fd23714bD2F3256C20a6036a5B31A9DbD8"),
  PRICE_ORACLE_ADDRESS: optionalEnv("PRICE_ORACLE_ADDRESS", "0xbBaf624eDe7A57141ADFF779dBf474c9527faD9f"),
  LOG_LEVEL:            optionalEnv("LOG_LEVEL", "info"),
} as const;

// ─────────────────────────────────────────────────────────────────────────────
// Risk parameters
// ─────────────────────────────────────────────────────────────────────────────

export const MIN_PROFIT_USD      = 2.0;
export const MAX_GAS_GWEI        = 350;
export const MAX_DAILY_LOSS_USD  = 100;
export const ESTIMATED_GAS_UNITS = 750_000;
export const MAX_RETRIES         = 3;
export const RETRY_BASE_DELAY_MS = 1_000;

// ─────────────────────────────────────────────────────────────────────────────
// Token pairs
// ─────────────────────────────────────────────────────────────────────────────

export interface TokenPair {
  name:       string;
  tokenIn:    string;
  tokenOut:   string;
  loanAmount: bigint;
}

// ─────────────────────────────────────────────────────────────────────────────
// Flash loan asset routing
// NOTE: Aave v3 Polygon has USDC borrowing DISABLED as of 2026-07-11.
//       All USDC-based pairs now borrow WETH and route through WETH→USDC
//       swap before the arbitrage leg. WETH borrowing is fully enabled
//       with 9,440 ETH ($17M) available.
// ─────────────────────────────────────────────────────────────────────────────

export const TOKEN_PAIRS: TokenPair[] = [
  // ── WETH-borrowed pairs (Aave v3 WETH borrowing enabled) ──────────────────

  // Borrow WETH → swap to USDC on QS → swap to WMATIC on SS → repay WETH
  {
    name:        "WETH→USDC→WMATIC",
    tokenIn:     "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619", // borrow WETH
    tokenOut:    "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270", // end in WMATIC
    loanAmount:  10n * 10n ** 18n,                             // 10 WETH (~$18K)
  },

  // Borrow WETH → swap to USDC on QS → swap to WMATIC on SS → swap back to WETH
  {
    name:        "WETH/USDC",
    tokenIn:     "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619", // borrow WETH
    tokenOut:    "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", // end in USDC
    loanAmount:  10n * 10n ** 18n,                             // 10 WETH (~$18K)
  },

  // ── Native WETH pairs (unchanged — always worked) ─────────────────────────

  {
    name:        "WETH/USDC",
    tokenIn:     "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619",
    tokenOut:    "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
    loanAmount:  10n * 10n ** 18n,
  },
  {
    name:        "USDC/WETH",
    tokenIn:     "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619", // borrow WETH, swap to USDC first
    tokenOut:    "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619",
    loanAmount:  15n * 10n ** 18n,                             // 15 WETH (~$27K ≈ $25K USDC)
  },

  // ── WMATIC pairs via WETH borrow ───────────────────────────────────────────
  {
    name:        "WMATIC/USDC",
    tokenIn:     "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
    tokenOut:    "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
    loanAmount:  50_000n * 10n ** 18n,
  },
];

// ─────────────────────────────────────────────────────────────────────────────
// ABIs
// ─────────────────────────────────────────────────────────────────────────────

export const FLASH_LOAN_ABI = [
  "function initiateFlashLoan(address asset, uint256 amount, bytes calldata params) external",
  "function paused() external view returns (bool)",
  "function owner() external view returns (address)",
  "function dailyVolumeUsed(address asset) external view returns (uint256)",
  "function dailyVolumeLimit(address asset) external view returns (uint256)",
] as const;

export const PRICE_ORACLE_ABI = [
  "function getQuickSwapPrice(address tokenIn, address tokenOut, uint256 amountIn) external view returns (uint256)",
  "function getSushiSwapPrice(address tokenIn, address tokenOut, uint256 amountIn) external view returns (uint256)",
  "function getArbitrageSpread(address tokenIn, address tokenOut, uint256 amount) external view returns (uint256 spread, address cheaperDex, address expensiveDex)",
] as const;

export const TWAP_ORACLE_ABI = [
  "function consult(address pair, address tokenIn, uint256 amountIn) external view returns (uint256 amountOut)",
  "function getWindowInfo(address pair) external view returns (uint256 window, bool isReady, uint256 lastUpdate)",
  "function update(address pair) external",
] as const;
