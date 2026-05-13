/**
 * @file config.ts
 * @notice Central configuration for the arbitrage bot.
 *
 * All values are read from environment variables (set in root .env).
 * Start the bot with:
 *   cd bot && npm run start
 */

import { config } from "dotenv";
import * as path  from "path";

// Load root .env
config({ path: path.resolve(__dirname, "../../.env") });

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

function requireEnv(key: string): string {
  const v = process.env[key];
  if (!v || v.trim() === "") {
    throw new Error(`Missing required environment variable: ${key}. Check your .env file.`);
  }
  return v.trim();
}

function optionalEnv(key: string, fallback: string): string {
  return (process.env[key] ?? fallback).trim();
}

// ─────────────────────────────────────────────────────────────────────────────
// Validated environment
// ─────────────────────────────────────────────────────────────────────────────

export const ENV = {
  POLYGON_RPC_URL:      requireEnv("POLYGON_RPC_URL"),
  POLYGON_WS_URL:       optionalEnv("POLYGON_WS_URL", ""),
  PRIVATE_KEY:          requireEnv("PRIVATE_KEY"),
  FLASH_LOAN_ADDRESS:   requireEnv("FLASH_LOAN_ADDRESS"),
  PRICE_ORACLE_ADDRESS: requireEnv("PRICE_ORACLE_ADDRESS"),
  LOG_LEVEL:            optionalEnv("LOG_LEVEL", "info"),
} as const;

// ─────────────────────────────────────────────────────────────────────────────
// Risk management parameters
// ─────────────────────────────────────────────────────────────────────────────

/** Minimum estimated net profit (USD) to execute a trade */
export const MIN_PROFIT_USD = 5.0;

/** Maximum gas price (Gwei) — skip block if gas is above this */
export const MAX_GAS_GWEI = 350;

/** Maximum cumulative daily loss (USD) before the bot halts */
export const MAX_DAILY_LOSS_USD = 100;

/** Estimated gas units consumed per flash loan execution */
export const ESTIMATED_GAS_UNITS = 750_000;

/** Max retry attempts on transient RPC/network errors */
export const MAX_RETRIES = 3;

/** Base delay (ms) for exponential back-off: delay = BASE * 2^attempt */
export const RETRY_BASE_DELAY_MS = 1_000;

// ─────────────────────────────────────────────────────────────────────────────
// Token pairs to scan
// ─────────────────────────────────────────────────────────────────────────────

export interface TokenPair {
  name:       string;
  tokenIn:    string;
  tokenOut:   string;
  /** Flash loan amount in tokenIn's native units (18 decimals unless USDC = 6) */
  loanAmount: bigint;
}

export const TOKEN_PAIRS: TokenPair[] = [
  {
    name:       "USDC/WMATIC",
    tokenIn:    "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", // USDC (6 dec)
    tokenOut:   "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270", // WMATIC (18 dec)
    loanAmount: 50_000n * 10n ** 6n,   // $50,000 USDC
  },
  {
    name:       "WMATIC/USDC",
    tokenIn:    "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270", // WMATIC (18 dec)
    tokenOut:   "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", // USDC (6 dec)
    loanAmount: 50_000n * 10n ** 18n,  // 50,000 WMATIC
  },
  {
    name:       "WETH/USDC",
    tokenIn:    "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619", // WETH (18 dec)
    tokenOut:   "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", // USDC (6 dec)
    loanAmount: 10n * 10n ** 18n,      // 10 WETH
  },
  {
    name:       "USDC/WETH",
    tokenIn:    "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", // USDC (6 dec)
    tokenOut:   "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619", // WETH (18 dec)
    loanAmount: 20_000n * 10n ** 6n,   // $20,000 USDC
  },
  {
    name:       "DAI/USDC",
    tokenIn:    "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063", // DAI (18 dec)
    tokenOut:   "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", // USDC (6 dec)
    loanAmount: 50_000n * 10n ** 18n,  // 50,000 DAI
  },
];

// ─────────────────────────────────────────────────────────────────────────────
// Contract ABIs (minimal — only methods the bot calls directly)
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
