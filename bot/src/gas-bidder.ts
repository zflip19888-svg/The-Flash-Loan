/**
 * @file gas-bidder.ts
 * @notice Dynamic gas bidding engine.
 *
 * Tracks the chain's base fee + recent priority fees from the latest blocks
 * and computes a competitive bid that is:
 *   - Capped by MAX_GAS_GWEI (config)
 *   - Boosted by a configurable urgency multiplier during HOT HMM regime
 *   - Reduced during COLD regime
 *
 * Also estimates "competitor bid" by sampling the 75th percentile priority fee
 * from the last N blocks.
 */

import { ethers, JsonRpcProvider, formatUnits } from "ethers";
import { logDebug } from "./logger";
import { MAX_GAS_GWEI } from "./config";

export type Regime = "COLD" | "WARM" | "HOT";

interface BlockFee {
  blockNumber: number;
  baseFeeGwei: number;
  priorityFeeGwei: number;  // 75th percentile of txn in block
  gasUsedRatio: number;
}

export class GasBidder {
  private history: BlockFee[] = [];
  private readonly windowSize: number;
  private lastBid: { baseFee: number; priorityFee: number; totalGwei: number; competitorEstimate: number } | null = null;

  constructor(windowSize = 20) {
    this.windowSize = windowSize;
  }

  /** Refresh internal state from the latest N blocks. */
  async refresh(provider: JsonRpcProvider): Promise<void> {
    try {
      const latest = await provider.getBlock("latest", true);
      if (!latest) return;
      const startBlock = Math.max(0, latest.number - this.windowSize + 1);

      const blocks = await Promise.all(
        Array.from({ length: latest.number - startBlock + 1 }, (_, i) =>
          provider.getBlock(startBlock + i, true)
        )
      );

      this.history = [];
      for (const rawBlock of blocks) {
        if (!rawBlock) continue;
        const block: any = rawBlock;
        const baseFeeGwei = Number(formatUnits((block.baseFeePerGas ?? block.baseFee ?? 0n), "gwei"));
        const txns: any[] = block.prefetchedTransactions ?? block.transactions ?? [];
        const priorities = txns
          .filter((t: any) => t && t.maxPriorityFeePerGas != null)
          .map((t: any) => Number(formatUnits(t.maxPriorityFeePerGas ?? 0n, "gwei")))
          .sort((a: number, b: number) => a - b);

        const p75 = priorities.length > 0
          ? priorities[Math.floor(priorities.length * 0.75)]
          : 30; // default ~30 gwei if no txns to sample
        this.history.push({
          blockNumber: block.number,
          baseFeeGwei,
          priorityFeeGwei: p75,
          gasUsedRatio: block.gasUsed && block.gasLimit ? Number(block.gasUsed) / Number(block.gasLimit) : 0,
        });
      }
      logDebug(`gas-bidder: refreshed ${this.history.length} blocks`);
    } catch (e) {
      logDebug(`gas-bidder: refresh failed — ${(e as Error).message}`);
    }
  }

  /**
   * Compute a competitive gas bid.
   * @param regime — current HMM regime
   * @param urgencyBoost — extra multiplier applied to priority fee (default 1.0)
   */
  computeBid(regime: Regime, urgencyBoost = 1.0): {
    baseFee: number;
    priorityFee: number;
    totalGwei: number;
    competitorEstimate: number;
    capped: boolean;
  } {
    if (this.history.length === 0) {
      return {
        baseFee: 30,
        priorityFee: 35,
        totalGwei: 65,
        competitorEstimate: 35,
        capped: false,
      };
    }

    const latest = this.history[this.history.length - 1];
    const recent = this.history.slice(-10);
    const avgP75 = recent.reduce((s, b) => s + b.priorityFeeGwei, 0) / recent.length;

    let regimeMultiplier = 1.0;
    if (regime === "HOT") regimeMultiplier = 1.25;   // bid more aggressively
    if (regime === "COLD") regimeMultiplier = 0.75;  // bid conservatively

    // EIP-1559: total = baseFee + priorityFee
    const baseFee = latest.baseFeeGwei;
    const priorityFee = Math.max(1, avgP75 * regimeMultiplier * urgencyBoost);
    const competitorEstimate = avgP75;
    let totalGwei = baseFee + priorityFee;
    let capped = false;
    if (totalGwei > MAX_GAS_GWEI) {
      totalGwei = MAX_GAS_GWEI;
      capped = true;
    }

    this.lastBid = { baseFee, priorityFee, totalGwei, competitorEstimate };
    return { baseFee, priorityFee, totalGwei, competitorEstimate, capped };
  }

  /** Recent history snapshot for dashboard. */
  snapshot(): BlockFee[] {
    return [...this.history];
  }

  getLastBid() { return this.lastBid; }
}

let bidder: GasBidder | null = null;
export function getGasBidder(): GasBidder {
  if (!bidder) bidder = new GasBidder();
  return bidder;
}
