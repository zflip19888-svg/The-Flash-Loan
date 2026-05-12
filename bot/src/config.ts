/**
 * @file config.ts
 * @notice Central configuration for the flash loan arbitrage bot.
 *         All tuneable parameters live here — import this module throughout the bot.
 */

import * as dotenv from "dotenv";
import path from "path";

dotenv.config({ path: path.resolve(__dirname, "..", ".env") });

// ─────────────────────────────────────────────────────────────────────────────
// Environment variables (validated at startup)
// ─────────────────────────────────────────────────────────────────────────────

function requireEnv(name: string): string {
  const val = process.env[name];
  if (!val || val.trim() === "") {
    throw new Error(`[Config] Missing required environment variable: ${name}`);
  }
  return val.trim();
}

export const ENV = {
  POLYGON_RPC_URL:       requireEnv("POLYGON_RPC_URL"),
  POLYGON_WS_URL:        requireEnv("POLYGON_WS_URL"),
  PRIVATE_KEY:           requireEnv("PRIVATE_KEY"),
  FLASH_LOAN_ADDRESS:    requireEnv("FLASH_LOAN_ADDRESS"),
  PRICE_ORACLE_ADDRESS:  requireEnv("PRICE_ORACLE_ADDRESS"),
  POLYGONSCAN_API_KEY:   process.env.POLYGONSCAN_API_KEY ?? "",
};

// ─────────────────────────────────────────────────────────────────────────────
// Well-known Polygon token addresses
// ─────────────────────────────────────────────────────────────────────────────

export const TOKENS = {
  WMATIC : "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
  USDC   : "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
  WETH   : "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619",
} as const;

// ─────────────────────────────────────────────────────────────────────────────
// DEX router addresses
// ─────────────────────────────────────────────────────────────────────────────

export const DEX = {
  QUICKSWAP: "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff",
  SUSHISWAP: "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506",
} as const;

// ─────────────────────────────────────────────────────────────────────────────
// Token pairs to scan on every block
// Each pair is [tokenIn, tokenOut]
// ─────────────────────────────────────────────────────────────────────────────

export interface TokenPair {
  name:     string;
  tokenIn:  string;
  tokenOut: string;
  /** Flash loan borrow amount expressed in tokenIn's native decimals */
  loanAmount: bigint;
}

export const TOKEN_PAIRS: TokenPair[] = [
  {
    name:       "WMATIC/USDC",
    tokenIn:    TOKENS.WMATIC,
    tokenOut:   TOKENS.USDC,
    loanAmount: 100_000n * 10n ** 18n,   // 100,000 WMATIC
  },
  {
    name:       "WETH/USDC",
    tokenIn:    TOKENS.WETH,
    tokenOut:   TOKENS.USDC,
    loanAmount: 50n * 10n ** 18n,        // 50 WETH ≈ $100k
  },
  {
    name:       "WETH/WMATIC",
    tokenIn:    TOKENS.WETH,
    tokenOut:   TOKENS.WMATIC,
    loanAmount: 50n * 10n ** 18n,        // 50 WETH
  },
];

// ─────────────────────────────────────────────────────────────────────────────
// Risk & profitability parameters
// ─────────────────────────────────────────────────────────────────────────────

/** Minimum net profit in USD to trigger execution */
export const MIN_PROFIT_USD = 5;

/** Skip execution if gas price exceeds this (in Gwei) */
export const MAX_GAS_GWEI = 500;

/** Halt bot if total daily losses exceed this in USD */
export const MAX_DAILY_LOSS_USD = 500;

/** Estimated gas units for a full arbitrage transaction (used for profit calc) */
export const ESTIMATED_GAS_UNITS = 500_000;

/** Flash loan borrow amount expressed in USD (target) */
export const FLASH_LOAN_AMOUNT_USD = 100_000;

// ─────────────────────────────────────────────────────────────────────────────
// Polling & retry
// ─────────────────────────────────────────────────────────────────────────────

/** How often to poll for new blocks when WebSocket is unavailable (ms) */
export const POLL_INTERVAL_MS = 12_000;

/** Maximum number of execution retries on transient failure */
export const MAX_RETRIES = 2;

/** Base back-off delay for retries (ms) — doubled on each retry */
export const RETRY_BASE_DELAY_MS = 2_000;

// ─────────────────────────────────────────────────────────────────────────────
// ABIs (minimal — only methods called by the bot)
// ─────────────────────────────────────────────────────────────────────────────

export const FLASH_LOAN_ABI = [
  "function initiateFlashLoan(address asset, uint256 amount, bytes calldata params) external",
  "event ArbitrageExecuted(uint256 indexed profit, address indexed asset, address dexA, address dexB, uint256 timestamp)",
] as const;

export const PRICE_ORACLE_ABI = [
  "function getArbitrageSpread(address tokenA, address tokenB, uint256 amount) external view returns (uint256 spread, address cheaperDex, address expensiveDex)",
  "function getQuickSwapPrice(address tokenA, address tokenB, uint256 amount) external view returns (uint256)",
  "function getSushiSwapPrice(address tokenA, address tokenB, uint256 amount) external view returns (uint256)",
] as const;
