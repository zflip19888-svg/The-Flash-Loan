/**
 * @file index.ts
 * @notice Entry point for the Flash Loan Arbitrage Bot.
 *
 * Starts the ArbitrageScanner and registers process signal handlers for
 * graceful shutdown.
 *
 * Usage:
 *   npm start         → runs compiled JS
 *   npm run dev       → ts-node-dev hot-reload
 */

import { ArbitrageScanner } from "./scanner";
import { logInfo, logError } from "./logger";

// ─────────────────────────────────────────────────────────────────────────────
// Bootstrap
// ─────────────────────────────────────────────────────────────────────────────

async function main(): Promise<void> {
  logInfo("═══════════════════════════════════════════");
  logInfo("  Flash Loan Arbitrage Bot — Polygon");
  logInfo("  Aave v3 | QuickSwap | SushiSwap");
  logInfo("═══════════════════════════════════════════");

  const scanner = new ArbitrageScanner();

  // ── Graceful shutdown ──────────────────────────────────────────────────────
  const shutdown = async (signal: string) => {
    logInfo(`Received ${signal} — shutting down gracefully…`);
    await scanner.stop();
    process.exit(0);
  };

  process.on("SIGINT",  () => shutdown("SIGINT"));
  process.on("SIGTERM", () => shutdown("SIGTERM"));

  // ── Unhandled promise rejections ───────────────────────────────────────────
  process.on("unhandledRejection", (reason) => {
    logError("Unhandled promise rejection", reason as Error);
  });

  process.on("uncaughtException", (err) => {
    logError("Uncaught exception", err);
    process.exit(1);
  });

  // ── Start ──────────────────────────────────────────────────────────────────
  await scanner.start();
}

main().catch((err) => {
  logError("Fatal startup error", err);
  process.exit(1);
});
