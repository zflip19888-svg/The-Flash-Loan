/**
 * @file index.ts
 * @notice Entry point for the Flash Loan Arbitrage Bot.
 *
 * Start modes:
 *   npm run start              — live execution (requires PRIVATE_KEY + FLASH_LOAN_ADDRESS)
 *   DRY_RUN=true npm run start — scan only, log opportunities, never send tx
 *   npm run dev                — ts-node-dev watch mode (implies DRY_RUN unless set)
 *
 * Logs:
 *   stdout      — structured JSON (piped to console or log aggregator)
 *   logs/       — opportunities-YYYY-MM-DD.jsonl (one record per viable opportunity)
 */

import { ScanLoop } from "./loop";
import { logInfo, logError } from "./logger";

async function main() {
  const dryRun = process.env.DRY_RUN === "true";

  logInfo("=============================================");
  logInfo("  Flash Loan Arbitrage Bot — Polygon Mainnet");
  logInfo(`  Mode: ${dryRun ? "DRY-RUN (scan only)" : "LIVE"}`);
  logInfo("=============================================");

  const loop = new ScanLoop();

  const shutdown = async (sig: string) => {
    logInfo(`${sig} received — shutting down`);
    await loop.stop();
    process.exit(0);
  };

  process.on("SIGINT",  () => shutdown("SIGINT"));
  process.on("SIGTERM", () => shutdown("SIGTERM"));

  process.on("unhandledRejection", (reason) => {
    logError("Unhandled rejection", reason instanceof Error ? reason : new Error(String(reason)));
  });

  process.on("uncaughtException", (err) => {
    logError("Uncaught exception", err);
    process.exit(1);
  });

  await loop.start();
}

main().catch((err) => {
  logError("Fatal startup error", err);
  process.exit(1);
});
