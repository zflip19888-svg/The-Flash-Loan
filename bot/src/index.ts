/**
 * @file index.ts
 * @notice Entry point for the Flash Loan Arbitrage Bot.
 *
 * Start:
 *   cd bot && npm run start
 *   # or in dev watch mode:
 *   cd bot && npm run dev
 */

import { ArbitrageScanner } from "./scanner";
import { logInfo, logError } from "./logger";

async function main() {
  logInfo("=================================================");
  logInfo("  Flash Loan Arbitrage Bot — Polygon");
  logInfo("=================================================");

  const scanner = new ArbitrageScanner();

  // Graceful shutdown
  const shutdown = async (signal: string) => {
    logInfo(`Received ${signal} — shutting down gracefully…`);
    await scanner.stop();
    process.exit(0);
  };

  process.on("SIGINT",  () => shutdown("SIGINT"));
  process.on("SIGTERM", () => shutdown("SIGTERM"));

  process.on("unhandledRejection", (reason) => {
    logError("Unhandled promise rejection", reason instanceof Error ? reason : new Error(String(reason)));
  });

  process.on("uncaughtException", (err) => {
    logError("Uncaught exception — shutting down", err);
    process.exit(1);
  });

  await scanner.start();
}

main().catch((err) => {
  logError("Fatal startup error", err);
  process.exit(1);
});
