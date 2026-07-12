/**
 * @file hmm.ts
 * @notice 3-regime Hidden Markov Model (HMM) for spread-based market regime detection.
 *
 * Regimes:
 *   COLD — low volatility / no spread (block execution, 1.5× profit threshold)
 *   WARM — normal market (1.0× threshold)
 *   HOT  — elevated spreads / high activity (0.8× threshold — aggressive execution)
 *
 * Uses a simplified Viterbi-style belief propagation update (no full Baum-Welch
 * at runtime — weights are pre-trained on typical Polygon QuickSwap/SushiSwap
 * spread distributions).
 */

export type Regime = "COLD" | "WARM" | "HOT";

export interface HMMState {
  regime:             Regime;
  confidence:         number;   // 0–1 probability of current regime
  consecutiveTicks:   number;   // how many consecutive ticks in this regime
  spreadObs:          number;   // last spread observation (%)
  executionMultiplier: number;  // profit threshold multiplier (COLD=1.5, WARM=1.0, HOT=0.8)
}

// ── Emission parameters (Gaussian μ, σ per regime) ──────────────────────────
const EMISSION: Record<Regime, { mu: number; sigma: number }> = {
  COLD: { mu:  0.05, sigma: 0.10 },
  WARM: { mu:  5.00, sigma: 3.00 },
  HOT:  { mu: 20.00, sigma: 8.00 },
};

// ── Transition matrix  P[from][to] ───────────────────────────────────────────
const TRANSITION: Record<Regime, Record<Regime, number>> = {
  COLD: { COLD: 0.85, WARM: 0.13, HOT: 0.02 },
  WARM: { COLD: 0.10, WARM: 0.80, HOT: 0.10 },
  HOT:  { COLD: 0.02, WARM: 0.20, HOT: 0.78 },
};

// ── Multipliers per regime ────────────────────────────────────────────────────
const MULTIPLIER: Record<Regime, number> = {
  COLD: 1.5,
  WARM: 1.0,
  HOT:  0.8,
};

const REGIMES: Regime[] = ["COLD", "WARM", "HOT"];

function gaussian(x: number, mu: number, sigma: number): number {
  const z = (x - mu) / sigma;
  return Math.exp(-0.5 * z * z) / (sigma * Math.sqrt(2 * Math.PI));
}

export class SpreadHMM {
  /** Current belief vector P(regime) — sums to 1 */
  private belief: Record<Regime, number> = { COLD: 0.60, WARM: 0.35, HOT: 0.05 };

  private currentRegime: Regime       = "COLD";
  private consecutiveTicks: number    = 0;
  private spreadHistory: number[]     = [];

  /**
   * Feed a new spread observation (%) and get the updated regime state.
   */
  update(spreadPct: number, _pairName?: string): HMMState {
    this.spreadHistory.push(spreadPct);
    if (this.spreadHistory.length > 50) this.spreadHistory.shift();

    // ── 1. Predict: propagate belief through transition matrix ────────────────
    const predicted: Record<Regime, number> = { COLD: 0, WARM: 0, HOT: 0 };
    for (const to of REGIMES) {
      for (const from of REGIMES) {
        predicted[to] += this.belief[from] * TRANSITION[from][to];
      }
    }

    // ── 2. Update: multiply by emission likelihood ────────────────────────────
    const updated: Record<Regime, number> = { COLD: 0, WARM: 0, HOT: 0 };
    let norm = 0;
    for (const r of REGIMES) {
      const { mu, sigma } = EMISSION[r];
      updated[r] = predicted[r] * gaussian(spreadPct, mu, sigma);
      norm += updated[r];
    }

    // Normalise (avoid div/0)
    if (norm < 1e-300) {
      // Flat reset if observation is so extreme it kills all likelihoods
      this.belief = { COLD: 0.33, WARM: 0.34, HOT: 0.33 };
    } else {
      for (const r of REGIMES) {
        this.belief[r] = updated[r] / norm;
      }
    }

    // ── 3. MAP decode — pick highest-probability regime ───────────────────────
    let bestRegime: Regime = "COLD";
    let bestProb   = 0;
    for (const r of REGIMES) {
      if (this.belief[r] > bestProb) {
        bestProb   = this.belief[r];
        bestRegime = r;
      }
    }

    if (bestRegime === this.currentRegime) {
      this.consecutiveTicks++;
    } else {
      this.currentRegime    = bestRegime;
      this.consecutiveTicks = 1;
    }

    return {
      regime:              this.currentRegime,
      confidence:          bestProb,
      consecutiveTicks:    this.consecutiveTicks,
      spreadObs:           spreadPct,
      executionMultiplier: MULTIPLIER[this.currentRegime],
    };
  }

  /** Exponentially-weighted volatility of recent spreads */
  spreadVolatility(alpha = 0.1): number {
    if (this.spreadHistory.length < 2) return 0;
    let variance = 0;
    let mean     = this.spreadHistory[0];
    for (let i = 1; i < this.spreadHistory.length; i++) {
      mean     = alpha * this.spreadHistory[i] + (1 - alpha) * mean;
      const d  = this.spreadHistory[i] - mean;
      variance = alpha * d * d + (1 - alpha) * variance;
    }
    return Math.sqrt(variance);
  }

  /** Current belief vector as array [COLD, WARM, HOT] */
  beliefVector(): number[] {
    return REGIMES.map((r) => this.belief[r]);
  }
}
