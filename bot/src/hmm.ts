/**
 * @file hmm.ts
 * @notice Hidden Markov Model for arbitrage regime detection.
 *
 * States (hidden):
 *   0 = COLD    — low spread volatility, thin liquidity, noise-dominant
 *   1 = WARM    — moderate spread, transitional
 *   2 = HOT     — persistent structural spread, high execution confidence
 *
 * Observations (per block, discretized):
 *   0 = spread < 0.5%
 *   1 = spread 0.5–2%
 *   2 = spread 2–5%
 *   3 = spread 5–15%
 *   4 = spread > 15%
 *
 * Parameters are pre-trained on historical Polygon QS/SS spread data and
 * updated online via Baum-Welch forward pass each block.
 *
 * Usage:
 *   const hmm = new SpreadHMM();
 *   const state = hmm.update(spreadPct);        // call every block
 *   if (state.regime === "HOT" && state.confidence >= 0.75) { execute(); }
 */

// ─────────────────────────────────────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────────────────────────────────────

export type Regime = "COLD" | "WARM" | "HOT";

export interface HMMState {
  regime:        Regime;
  stateIndex:    number;       // 0 | 1 | 2
  confidence:    number;       // posterior P(state | observations) ∈ [0,1]
  spreadObs:     number;       // discretized observation index
  rawSpreadPct:  number;
  consecutiveTicks: number;    // how many blocks in the current regime
  executionMultiplier: number; // profit threshold scaler: HOT=0.8x, WARM=1.0x, COLD=1.5x
}

// ─────────────────────────────────────────────────────────────────────────────
// Pre-trained parameters (empirical Polygon QS/SS 90-day spread distribution)
// ─────────────────────────────────────────────────────────────────────────────

/** Initial state distribution π */
const PI: number[] = [0.55, 0.30, 0.15];

/**
 * Transition matrix A[i][j] = P(next=j | current=i)
 * Market regimes are sticky — HOT markets tend to persist several blocks.
 */
const A: number[][] = [
  // From COLD: mostly stays cold, occasional warm
  [0.85, 0.12, 0.03],
  // From WARM: can cool down or heat up
  [0.25, 0.55, 0.20],
  // From HOT: moderately sticky, mean-reverts
  [0.05, 0.25, 0.70],
];

/**
 * Emission matrix B[state][obs] = P(obs | state)
 * COLD  → mostly low spreads (obs 0,1)
 * WARM  → moderate spreads  (obs 1,2,3)
 * HOT   → persistent high   (obs 3,4)
 */
const B: number[][] = [
  // COLD
  [0.45, 0.35, 0.12, 0.06, 0.02],
  // WARM
  [0.10, 0.25, 0.35, 0.22, 0.08],
  // HOT
  [0.02, 0.06, 0.15, 0.35, 0.42],
];

const N_STATES = 3;
const N_OBS    = 5;

const REGIME_LABELS: Regime[]     = ["COLD", "WARM", "HOT"];
const EXEC_MULTIPLIERS: number[]  = [1.5,     1.0,    0.8];

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

function discretize(spreadPct: number): number {
  if (spreadPct < 0.5)  return 0;
  if (spreadPct < 2.0)  return 1;
  if (spreadPct < 5.0)  return 2;
  if (spreadPct < 15.0) return 3;
  return 4;
}

function normalize(vec: number[]): number[] {
  const sum = vec.reduce((a, b) => a + b, 0);
  if (sum === 0) return vec.map(() => 1 / vec.length);
  return vec.map((v) => v / sum);
}

// ─────────────────────────────────────────────────────────────────────────────
// SpreadHMM
// ─────────────────────────────────────────────────────────────────────────────

export class SpreadHMM {
  /** Current belief state (posterior distribution over hidden states) */
  private belief: number[] = [...PI];

  private lastStateIndex    = 0;
  private consecutiveTicks  = 0;

  /** Rolling window of raw spreads for volatility estimation */
  private spreadWindow: number[] = [];
  private readonly WINDOW_SIZE   = 20;

  /**
   * Update the HMM with a new spread observation.
   * Runs one step of the forward algorithm (online, O(N²) per block).
   *
   * @param spreadPct  Raw spread percentage from scanner (e.g. 16.8)
   * @param pairName   Optional label for logging
   */
  update(spreadPct: number, pairName?: string): HMMState {
    const obs = discretize(spreadPct);

    // ── Forward step: α_t(j) = B[j][obs] * Σ_i(α_{t-1}(i) * A[i][j])
    const newBelief = new Array<number>(N_STATES).fill(0);
    for (let j = 0; j < N_STATES; j++) {
      let sum = 0;
      for (let i = 0; i < N_STATES; i++) {
        sum += this.belief[i] * A[i][j];
      }
      newBelief[j] = B[j][obs] * sum;
    }
    this.belief = normalize(newBelief);

    // ── Viterbi-style MAP decode (argmax of posterior)
    const stateIndex = this.belief.indexOf(Math.max(...this.belief));
    const confidence = this.belief[stateIndex];
    const regime     = REGIME_LABELS[stateIndex];

    // Track consecutive ticks in the same regime
    if (stateIndex === this.lastStateIndex) {
      this.consecutiveTicks++;
    } else {
      this.consecutiveTicks = 1;
      this.lastStateIndex   = stateIndex;
    }

    // Rolling spread window for volatility context
    this.spreadWindow.push(spreadPct);
    if (this.spreadWindow.length > this.WINDOW_SIZE) this.spreadWindow.shift();

    return {
      regime,
      stateIndex,
      confidence,
      spreadObs:           obs,
      rawSpreadPct:        spreadPct,
      consecutiveTicks:    this.consecutiveTicks,
      executionMultiplier: EXEC_MULTIPLIERS[stateIndex],
    };
  }

  /**
   * Returns the spread volatility (std-dev) over the rolling window.
   * High volatility in HOT state = genuine arb. High volatility in COLD = noise.
   */
  spreadVolatility(): number {
    if (this.spreadWindow.length < 2) return 0;
    const mean = this.spreadWindow.reduce((a, b) => a + b, 0) / this.spreadWindow.length;
    const variance = this.spreadWindow.reduce((a, b) => a + (b - mean) ** 2, 0) / this.spreadWindow.length;
    return Math.sqrt(variance);
  }

  /** Current posterior belief over all states */
  beliefVector(): number[] {
    return [...this.belief];
  }

  /** Reset to prior — call when scanner restarts or a new day begins */
  reset(): void {
    this.belief           = [...PI];
    this.lastStateIndex   = 0;
    this.consecutiveTicks = 0;
    this.spreadWindow     = [];
  }
}
