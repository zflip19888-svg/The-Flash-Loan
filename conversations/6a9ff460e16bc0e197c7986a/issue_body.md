## Bot Anomaly Report — 2026-09-08 (Scheduled Check)

**Log analyzed:** `logs/opportunities-2026-09-07.jsonl` (scanned at block #93,425,555 — Sep 8 04:56 UTC)
**Previous report:** #89

---

### Anomalies (9 total: 3 stale, 5 scanner gaps, 1 DAI missing)

#### 🔴 1. Stale SushiSwap oracle — Day 6

WETH pair spreads remain frozen across Sep 4 → Sep 6 → Sep 7 scans. Day-over-day drift is under 0.31%, confirming the oracle feed is still stale.

| Pair | Amount | Sep 4 spread | Sep 6 spread | Sep 7 spread | Drift (6→7) | SS Depth Sep7 |
|------|--------|-------------|-------------|-------------|-------------|---------------|
| WETH→USDC | 10 | 28.8066% | 28.8780% | 28.8127% | 0.065% | $57,000 |
| WETH→USDC | 15 | 37.5200% | 37.6075% | 37.5276% | 0.080% | $57,000 |
| WETH→WMATIC | 10 | 22.6785% | 22.1914% | 22.4920% | 0.301% | $59,000 |

WETH→USDC SS depth: Sep 6 = $57,071, Sep 7 = $57,000 → **0.13% change** across one full day. Real market depth on a live DEX does not move that little.

**Good news:** Unlike the Sep 6 log (where WETH pairs were incorrectly tagged `isPhantom=false`), the Sep 7 log correctly flags all WETH pairs as `isPhantom=true`/`phantom=true`. The phantom guard fix reported in #87 appears to be working for the daily log.

**Status:** Still unresolved. 6th consecutive day (Sep 1 → 4 → 6 → 7).

#### 🟡 2. Scanner gaps — 5 missing logs

| Date | Status |
|------|--------|
| 2026-09-01 | ❌ MISSING |
| 2026-09-02 | ❌ MISSING |
| 2026-09-03 | ❌ MISSING |
| 2026-09-05 | ❌ MISSING |
| 2026-09-08 | ❌ MISSING (today's log not yet generated — expected Sep 9 04:56 UTC) |

Sep 1–3 and Sep 5 gaps remain unexplained. Today's gap (Sep 8) is expected — the daily scan runs at 04:56 UTC and today's log was not yet produced at time of this check.

#### 🟡 3. DAI/USDC pairs still missing from scanner

No DAI pairs appear in the Sep 7 log. A DAI de-peg event would go completely undetected. Same as reported in #88 and #89.

---

### Non-anomalies (confirmations)

- ✅ **Phantom guard working in daily log:** WETH entries now correctly tagged `isPhantom=true` (Sep 6 had them as false). Regression reported in #85/#86 is resolved for the daily scan path.
- ✅ **WMATIC→USDC 20K:** Spread 3.44%, slippage 4.3%, net ~$61. Only trustworthy signal. Under 5% guard.
- ✅ **WMATIC→USDC 50K:** Spread 8.18%, slippage 10.7%. Over 5% guard — still shows EXECUTE. Consider adding a slippage-based suppress.
- ✅ **No executed trades:** All entries `dryRun=true`, `executed=false`. Daily loss $0 (within max loss $100 guard).
- ⚠️ **live-spread-scan.js** still lacks the universal phantom guard (reported #88). Manual scans will show 🟢 EXECUTE on stale WETH signals.

---

### Open action items (carried from #88/#89)

1. **Verify SushiSwap RPC endpoint** — check if the oracle contract or RPC is returning cached/stale reserves
2. **Patch live-spread-scan.js** with `isPhantomUniversal` check to match the daily log's phantom guard
3. **Re-add DAI/USDC** pair to scanner config
4. **Investigate Sep 1–3 and Sep 5 scanner gaps**
