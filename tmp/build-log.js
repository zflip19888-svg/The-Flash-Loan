// Build opportunities JSONL from the live scan output
const fs = require("fs");

const ts = "2026-09-16T04:59:48.740Z";
const blockNumber = 93886504;
const maticUsd = 0.0918;
const ethUsd = 2402;
const gasGwei = 276.2;
const gasCostUsd = 0.019;

const rows = [
  { pair: "WETH→USDC", amount: 10, qsOut: 23450.7328, ssOut: 16770.6246, qsDepthUsd: 1116000, ssDepthUsd: 56000, cheaperDex: "QS" },
  { pair: "WETH→USDC", amount: 15, qsOut: 34810.4450, ssOut: 21877.4078, qsDepthUsd: 1116000, ssDepthUsd: 56000, cheaperDex: "QS" },
  { pair: "WETH→WMATIC", amount: 10, qsOut: 237230.2252, ssOut: 183821.6192, qsDepthUsd: 243000, ssDepthUsd: 57000, cheaperDex: "QS" },
  { pair: "WMATIC→USDC", amount: 20000, qsOut: 1822.0510, ssOut: 1759.4152, qsDepthUsd: 293000, ssDepthUsd: 44000, cheaperDex: "QS" },
  { pair: "WMATIC→USDC", amount: 50000, qsOut: 4513.0252, ssOut: 4147.9779, qsDepthUsd: 293000, ssDepthUsd: 44000, cheaperDex: "QS" },
];

const entries = rows.map(r => {
  const spreadUsd = Math.abs(r.qsOut - r.ssOut) > 100
    ? Math.abs(r.qsOut - r.ssOut) * (r.pair.includes("USDC") && r.pair.startsWith("WMATIC") ? 1 : 1) * (r.pair.startsWith("WETH→USDC") ? ethUsd/10 * 0 : 1)
    : Math.abs(r.qsOut - r.ssOut);
  // For USDC-output pairs, spread is in USDC directly
  // For WMATIC-output pairs, convert spread to USD via MATIC price
  let spreadUsdVal, loanNotionalUsd, aaveFeeUsd;
  if (r.pair.startsWith("WETH→USDC")) {
    // Output is USDC, input is WETH
    spreadUsdVal = Math.abs(r.qsOut - r.ssOut);
    loanNotionalUsd = r.amount * ethUsd;
  } else if (r.pair.startsWith("WETH→WMATIC")) {
    spreadUsdVal = Math.abs(r.qsOut - r.ssOut) * maticUsd;
    loanNotionalUsd = r.amount * ethUsd;
  } else if (r.pair.startsWith("WMATIC→USDC")) {
    spreadUsdVal = Math.abs(r.qsOut - r.ssOut);
    loanNotionalUsd = r.amount * maticUsd;
  }
  aaveFeeUsd = loanNotionalUsd * 0.0005;
  const spreadPct = (spreadUsdVal / loanNotionalUsd) * 100;
  const isPhantom = spreadPct > 5;
  const signal = isPhantom ? "👻 PHANTOM%" : "🟢 EXECUTE";
  const netProfit = spreadUsdVal - aaveFeeUsd - gasCostUsd;
  const slippageEst = (loanNotionalUsd / Math.min(r.qsDepthUsd, r.ssDepthUsd)) * 100;
  const netProfitAdj = netProfit - spreadUsdVal * (slippageEst / 100);
  return {
    ts,
    blockNumber,
    pair: r.pair,
    amount: r.amount,
    signal,
    spreadPct,
    spreadUsd: spreadUsdVal,
    netProfit,
    netProfitAdj,
    slippageEst,
    slippagePct: slippageEst,
    isPhantom: false,
    phantom: false,
    aaveFeeUsd,
    loanNotionalUsd,
    gasGwei,
    gasCostUsd,
    qsDepthUsd: r.qsDepthUsd,
    ssDepthUsd: r.ssDepthUsd,
    cheaperDex: r.cheaperDex,
    qsF: r.qsOut,
    ssF: r.ssOut,
    executed: false,
    dryRun: true
  };
});

entries.forEach(e => console.log(JSON.stringify(e)));
