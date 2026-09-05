## 🚨 Bot Anomaly Report — Opportunity Log Audit

**Date:** 2026-09-05  
**Scanner:** Polygon Mainnet Spread Scanner  
**Audit Scope:** `logs/opportunities-2026-09-04.jsonl` + conversation log `opportunities-2026-09-04.jsonl` + historical comparison (June–July 2026)

---

### Anomaly 1: Phantom Detection Failure on Sept 4 Log

**Severity: Critical**

The file `/app/logs/opportunities-2026-09-04.jsonl` contains 5 records, ALL flagged as `"🟢 EXECUTE"` with `"phantom": false` and `"isPhantom": false`. However, the conversation log (same date, next-day scan at block 93252795) correctly flags the **identical pairs** as `"👻 PHANTOM%"` with `"phantom": true` / `"isPhantomUniversal": true`.

| Pair | Sept 4 Signal | Sept 4 Spread% | Sept 5 Signal | Sept 5 Spread% |
|------|--------------|----------------|---------------|----------------|
| WETH→USDC (10) | 🟢 EXECUTE | 28.81% | 👻 PHANTOM% | 28.68% |
| WETH→USDC (15) | 🟢 EXECUTE | 37.52% | 👻 PHANTOM% | 37.37% |
| WETH→WMATIC (10) | 🟢 EXECUTE | 22.68% | 👻 PHANTOM% | 22.32% |
| WMATIC→USDC (20K) | 🟢 EXECUTE | 3.34% | 👻 PHANTOM% | 5.10% |
| WMATIC→USDC (50K) | 🟢 EXECUTE | 8.05% | 👻 PHANTOM% | 8.18% |

Historical context: WETH→USDC spreads in June 2026 logs were 0.44–14.79%. A **37% spread on WETH→USDC is astronomically unrealistic** and must always be flagged as phantom. The Sept 4 scan completely failed to apply phantom detection, exposing the bot to potential execution of fake arbitrage opportunities.

---

### Anomaly 2: Contradictory Phantom Fields

**Severity: Medium**

The Sept 5 conversation log records contain contradictory fields:
```json
"isPhantom": false,
"isPhantomUniversal": true,
"phantom": true
```

Three separate boolean fields exist for the same concept. `isPhantom` is `false` while `phantom` and `isPhantomUniversal` are `true`. This indicates redundant/overlapping detection logic that is not properly synchronized — different code paths set different fields, creating ambiguity for downstream consumers.

---

### Anomaly 3: Scanner Inactivity Gap (55 Days)

**Severity: High**

Log files in `/app/logs/` show:
- Last July entry: `opportunities-2026-07-11.jsonl`
- Next entry: `opportunities-2026-09-04.jsonl`

**Gap: ~55 days (July 11 → September 4, 2026).** No opportunity logs were written for nearly two months. Either the scanner stopped running, crashed silently, or logs failed to write. This means any arbitrage opportunities during this period were completely missed.

---

### Anomaly 4: Severely Reduced Scan Frequency

**Severity: Medium**

The Sept 4 log contains only **1 scan** (block 93195345 at 05:00:51 UTC). The Sept 5 log contains only **1 scan** (block 93252795 at 04:57:06 UTC). 

Historical logs (e.g., June 20) show scans every ~2 seconds across consecutive blocks — the scanner used to run in a tight loop. Scanning once per day means the bot is sampling a single 2-second window out of 86,400 seconds/day (~0.002% coverage).

---

### Anomaly 5: DAI Phantom Spread Detection Inconsistency

**Severity: Medium**

DAI→USDC and USDC→DAI pairs (stablecoin-to-stablecoin) show inconsistent phantom detection across dates:

| Date | Spread% | Signal | Note |
|------|---------|--------|------|
| June 4 | 35.5% | VERIFY DEPTH ⚠️ shallow | Not flagged as phantom |
| June 20 | 17.0% | EXECUTE | Not flagged at all (17% on stablecoins!) |
| July 10 | 35.7% | PHANTOM ✅ | Correctly flagged, "SS $15K pool imbalance" |

Same pairs, wildly different detection outcomes. A stablecoin-to-stablecoin spread above 2-3% is always suspicious; 17%+ should always be phantom. The June 20 log letting DAI→USDC through as EXECUTE is a critical miss.

---

### Anomaly 6: WBTC→USDC Zero-Liquidity Pair (Historical)

**Severity: Low (suppressed but still displayed)**

In the June 4 scan output, WBTC→USDC showed SushiSwap depth of **$0K** but was still displayed with a 98% spread and "VERIFY DEPTH ⚠️ shallow" signal instead of being filtered out entirely. A zero-liquidity pool should never produce a signal opinion — it should be silently skipped.

---

### Summary of Recommended Fixes

1. **Phantom detection regression** — audit why Sept 4 scan missed phantom flagging that Sept 5 correctly caught. Likely a code path that bypasses `isPhantomUniversal` check.
2. **Unify phantom boolean fields** — collapse `isPhantom`, `phantom`, `isPhantomUniversal` into a single field. Today's contradictory values will cause bugs.
3. **Investigate 55-day scanner outage** — add heartbeat/health monitoring so silent scanner death is caught immediately.
4. **Restore scan loop frequency** — 1 scan/day is insufficient. Restore continuous or sub-minute scanning.
5. **Standardize DAI phantom threshold** — any stablecoin-to-stablecoin spread >3% should trigger phantom flag automatically.
6. **Filter zero-liquidity pairs entirely** — $0 depth on either side should suppress the pair from output, not show as "VERIFY DEPTH."

---

*This issue was automatically filed by the Bot Anomaly GitHub Issue Reporter automation.*
