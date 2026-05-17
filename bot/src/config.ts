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

import { config } from "dotenv";
import * as path  from "path";

config({ path: path.resolve(__dirname, "../../.env") });

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
  FLASH_LOAN_ADDRESS:   optionalEnv("FLASH_LOAN_ADDRESS"),
  PRICE_ORACLE_ADDRESS: optionalEnv("PRICE_ORACLE_ADDRESS"),
  LOG_LEVEL:            optionalEnv("LOG_LEVEL", "info"),
} as const;

// ─────────────────────────────────────────────────────────────────────────────
// Risk parameters
// ─────────────────────────────────────────────────────────────────────────────

export const MIN_PROFIT_USD      = 5.0;
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

export const TOKEN_PAIRS: TokenPair[] = [
  {
    name:       "USDC/WMATIC",
    tokenIn:    "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
    tokenOut:   "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
    loanAmount: 50_000n * 10n ** 6n,
  },
  {
    name:       "WMATIC/USDC",
    tokenIn:    "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
    tokenOut:   "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
    loanAmount: 50_000n * 10n ** 18n,
  },
  {
    name:       "WETH/USDC",
    tokenIn:    "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619",
    tokenOut:   "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
    loanAmount: 10n * 10n ** 18n,
  },
  {
    name:       "USDC/WETH",
    tokenIn:    "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
    tokenOut:   "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619",
    loanAmount: 20_000n * 10n ** 6n,
  },
  {
    name:       "DAI/USDC",
    tokenIn:    "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063",
    tokenOut:   "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
    loanAmount: 50_000n * 10n ** 18n,
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
