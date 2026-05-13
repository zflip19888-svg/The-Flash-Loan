/**
 * @file opportunity-log.ts
 * @notice Appends every scanned opportunity (executed or not) to a rotating
 *         JSONL file: logs/opportunities-YYYY-MM-DD.jsonl
 *
 * Each line is a self-contained JSON record — easy to pipe into jq, grep,
 * or import into a spreadsheet.
 */

import * as fs   from "fs";
import * as path from "path";
import { logError } from "./logger";

export interface OpportunityRecord {
  ts:            string;   // ISO timestamp
  block:         number;
  pair:          string;
  qsDepthUsd:    number;
  ssDepthUsd:    number;
  spreadUsd:     number;
  gasCostUsd:    number;
  aaveFeeUsd:    number;
  netProfitUsd:  number;
  cheaperDex:    string;
  executed:      boolean;
  txHash?:       string;
  txStatus?:     "success" | "reverted" | "pending";
  error?:        string;
}

const LOG_DIR = path.resolve(__dirname, "../../logs");

function logPath(): string {
  const date = new Date().toISOString().slice(0, 10);
  return path.join(LOG_DIR, `opportunities-${date}.jsonl`);
}

export function writeOpportunity(record: OpportunityRecord): void {
  try {
    if (!fs.existsSync(LOG_DIR)) fs.mkdirSync(LOG_DIR, { recursive: true });
    fs.appendFileSync(logPath(), JSON.stringify(record) + "\n", "utf8");
  } catch (err) {
    logError("OpportunityLog: write failed", err);
  }
}

/** Read all records from today's log file (for the status report). */
export function readTodayLog(): OpportunityRecord[] {
  try {
    const raw = fs.readFileSync(logPath(), "utf8");
    return raw
      .split("\n")
      .filter(Boolean)
      .map((l) => JSON.parse(l) as OpportunityRecord);
  } catch {
    return [];
  }
}
