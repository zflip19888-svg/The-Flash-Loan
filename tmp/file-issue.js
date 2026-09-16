#!/usr/bin/env node
const fs = require('fs');
const https = require('https');

const anomalies = JSON.parse(fs.readFileSync('tmp/anomalies.json', 'utf8'));
const token = process.env.GITHUB_TOKEN_3 || '';

if (!token) {
  console.log('❌ GITHUB_TOKEN_3 not set');
  process.exit(1);
}

// Build issue body
let anomalyText = '';
anomalies.forEach((a, i) => {
  anomalyText += `\n${i+1}. **[${a.severity}] ${a.type}**\n`;
  anomalyText += `   - ${a.description}\n`;
});

const body = `### Daily Anomaly Report — 2026-07-18

**Summary:** ${anomalies.length} anomalies detected across opportunity logs (2026-05-17 through 2026-07-17)

**Findings:**
${anomalyText}

**Context:**
- Log directory: logs/
- Most recent log: opportunities-2026-07-17.jsonl (7 scans, all stale)
- Scanner gap: No logs for 27 days (Jun 16 – Jul 11), plus missing Jul 16 and Jul 18
- Scan counts this week: Jul 12 (8), Jul 13 (1), Jul 14 (4), Jul 15 (5), Jul 17 (7)
- No log exists for today (Jul 18) yet

**Recommended actions:**
1. Fix integer overflow in spread/profit calculation for cross-pair routes (WETH→WMATIC)
2. Add oracle staleness check — reject signals where depth/spread values don't change across blocks
3. Filter out zero-liquidity pairs (ss_depth_usd=0) before flagging signals
4. Add stablecoin peg validation — flag DAI↔USDC spreads >2% as suspicious
5. Fix execution logging — failed/pending txs should not be marked executed=true
6. Deduplicate scan entries with identical timestamp+block
7. Add slippage guard — reject EXECUTE when slippagePct > spreadPct
8. Investigate scanner inactivity gap (Jun 16 – Jul 11)
`;

const options = {
  hostname: 'api.github.com',
  path: '/repos/zflip19888-svg/The-Flash-Loan/issues',
  method: 'POST',
  headers: {
    'Authorization': 'Bearer ' + token,
    'Accept': 'application/vnd.github.v3+json',
    'User-Agent': 'bot-anomaly-reporter',
    'Content-Type': 'application/json'
  }
};

const payload = {
  title: '[Bot Alert] Daily Anomaly Report — 8 anomalies found (2026-07-18)',
  body: body,
  labels: ['bot-alert', 'anomaly'],
  assignees: ['zflip19888-svg']
};

const req = https.request(options, (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    try {
      const result = JSON.parse(data);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        console.log('✅ GitHub issue filed successfully');
        console.log('   Issue #' + result.number + ': ' + result.html_url);
      } else {
        console.log('❌ Failed: HTTP ' + res.statusCode);
        console.log('   ' + (result.message || 'Unknown error'));
        if (result.errors) console.log('   ' + JSON.stringify(result.errors));
      }
    } catch(e) {
      console.log('Response code: ' + res.statusCode);
      console.log('Raw: ' + data.substring(0, 500));
    }
  });
});

req.on('error', e => {
  console.log('❌ Request failed: ' + e.message);
});

req.write(JSON.stringify(payload));
req.end();
