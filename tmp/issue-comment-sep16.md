## Scheduled Anomaly Scan — Sep 16, 2026 04:59 UTC (block #93,886,504)

Fresh scan data: `logs/opportunities-2026-09-16.jsonl` — 5 records, MATIC $0.0918, Gas 276.2 Gwei.

### All 4 previously reported anomalies CONFIRMED STILL PRESENT

#### 1. Round-trip profitability bug — UNPATCHED
`WMATIC→USDC 20000` still signals 🟢 EXECUTE with netProfitAdj $59.09. As verified live on Sep 15 (two independent RPCs), the actual round-trip execution of this trade loses ~$99 net at every size 200–20K WMATIC. The scanner's one-way `getAmountsOut` comparison fundamentally overstates profit on imbalanced-depth pairs.

**Risk**: A live execution of this signal would lose ~$99 — the entire $100 daily loss cap in a single tx.

#### 2. Phantom guard nondeterminism — UNPATCHED
| Date | WMATIC→USDC 50K | WMATIC→USDC 20K | WETH→USDC 10K |
|------|-----------------|-----------------|----------------|
| Sep 14 | 🟢 EXECUTE (8.3%) | 🟢 EXECUTE (3.5%) | 🟢 EXECUTE (28.9%) |
| Sep 15 | 👻 PHANTOM (8.2%) | 🟢 EXECUTE (3.4%) | 👻 PHANTOM (28.9%) |
| Sep 16 | 👻 PHANTOM (8.0%) | 🟢 EXECUTE (3.4%) | 👻 PHANTOM (27.8%) |

Sep 14 flagged ALL 5 as EXECUTE (incl. 37.7% spread). Sep 15/16 correctly phantom-flag the high-spread pairs but the threshold behavior is inconsistent across runs for the same pair — the guard flips verdicts day-to-day with similar pool states.

#### 3. Structured phantom field mismatch — UNPATCHED
Sep 16: 4/5 records have signal `👻 PHANTOM%` but ALL 5 records still have `isPhantom: false, phantom: false`. No consumer filtering on `phantom === false` will correctly exclude phantom pairs.

#### 4. Scanner inactivity gaps — PARTIALLY IMPROVED
- **New**: Sep 16 has its own file ✅ (`opportunities-2026-09-16.jsonl`)
- **Still missing**: Sep 05, 10, 13, 15 as daily files
- **Sep 15 data confirmed appended to Sep 14 file** (6 records from date 2026-09-15 in `opportunities-2026-09-14.jsonl`)
- Previous ~19h scanner stall (reported Sep 15 18:40 UTC) appears resolved — new scan ran today at 04:59 UTC

### Clear this scan
- ✅ No DAI phantom spreads (0 DAI pairs)
- ✅ No zero-liquidity pairs
- ✅ No stale oracle signals (gas/feed data present and fresh)
- ✅ Scanner resumed after previous stall

### Severity: HIGH
The round-trip profitability bug (anomaly #1) remains the most critical — it is an active misfire risk. Until patched, automated live execution should be halted.
