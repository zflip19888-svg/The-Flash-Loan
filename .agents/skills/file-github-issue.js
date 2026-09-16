#!/usr/bin/env node
const fs = require('fs');
const https = require('https');

const anomalies = JSON.parse(fs.readFileSync('/tmp/anomalies.json', 'utf8'));
const token = process.env.GITHUB_TOKEN_2 || '';

if (!token) {
  console.log('❌ GITHUB_TOKEN_2 not set');
  process.exit(1);
}

// Build issue body
let anomalyText = '';
anomalies.forEach((a, i) => {
  anomalyText += `\n${i+1}. **[${a.severity}] ${a.type}**\n`;
  anomalyText += `   - ${a.description}\n`;
  if (a.scans_found !== undefined) {
    anomalyText += `   - Found ${a.scans_found} scans (expected >= 5)\n`;
  }
  if (a.scans_today !== undefined) {
    anomalyText += `   - 7-day avg: ${a.avg_scans_7d.toFixed(1)} scans/day; today: ${a.scans_today}\n`;
  }
});

const body = `### Daily Anomaly Report — 2026-07-13

**Summary:** ${anomalies.length} anomalies detected in bot scanner

**Findings:**
${anomalyText}

**Context:**
- Today's log: logs/opportunities-2026-07-13.jsonl (1 scan)
- 7-day average: 5.3 scans/day
- Current blocker: Wallet gas insufficient (0.011 MATIC, needs 5+) + circuit breaker limits at 0

**Next steps:**
1. Fund wallet with 5+ MATIC
2. Run node scripts/set-volume-limits.js to enable execution
3. Monitor for recovery in next scan cycle
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
  title: '[Bot Alert] Daily Anomaly — Scanner Inactivity (2026-07-13)',
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
      }
    } catch(e) {
      console.log('Response code: ' + res.statusCode);
    }
  });
});

req.on('error', e => {
  console.log('❌ Request failed: ' + e.message);
});

req.write(JSON.stringify(payload));
req.end();
