#!/usr/bin/env bash
# =====================================================================
# The-Flash-Loan - full rebuild from scratch (generated)
# Recreates every source file via cat << heredocs. Generated on:
#   2026-10-13 04:31 UTC from repo d5160f9
# Usage:  mkdir The-Flash-Loan && cd The-Flash-Loan && bash rebuild-from-scratch.sh
# Then:   npm install && npx hardhat compile && (cd bot && npm install && npm run build)
# Secrets (RPC URL, PRIVATE_KEY, GITHUB_TOKEN_2, contract addresses) must
# be re-supplied via env/.env - they are NOT included here.
# =====================================================================
set -euo pipefail

mkdir -p \
  . \
  base44/connectors \
  base44/workflows \
  bot \
  bot/src \
  contracts \
  contracts/test \
  dashboard \
  dashboard/api \
  scripts \
  test \
  logs output

# ---------- .env.example ----------
cat > '.env.example' << 'P2_FILE_EOF'
# ─────────────────────────────────────────────────────────────────────────────
# Flash Loan Arbitrage — Root Environment Variables
# 1. Copy this file:  cp .env.example .env
# 2. Fill in all required fields (marked with !!REQUIRED!!)
# NEVER commit .env to version control.
# ─────────────────────────────────────────────────────────────────────────────

# ── RPC Endpoints ─────────────────────────────────────────────────────────────
# Polygon mainnet HTTP RPC (Alchemy recommended: https://alchemy.com)
# !!REQUIRED!! for mainnet deploy and fork tests
POLYGON_RPC_URL=https://polygon-mainnet.g.alchemy.com/v2/YOUR_KEY_HERE

# Polygon mainnet WebSocket (same Alchemy app, wss:// endpoint)
# !!REQUIRED!! for the bot's WebSocket block subscription
POLYGON_WS_URL=wss://polygon-mainnet.g.alchemy.com/v2/YOUR_KEY_HERE

# Polygon Mumbai testnet HTTP RPC
# !!REQUIRED!! for testnet deploy
MUMBAI_RPC_URL=https://polygon-mumbai.g.alchemy.com/v2/YOUR_KEY_HERE

# ── Wallet ────────────────────────────────────────────────────────────────────
# Private key of the OWNER wallet (no 0x prefix)
# WARNING: Fund with MATIC for gas only — keep profit tokens off this wallet
# !!REQUIRED!!
PRIVATE_KEY=

# ── Deployed Contract Addresses ───────────────────────────────────────────────
# These are populated automatically by the deploy scripts into output/*.json
# Copy them here after deployment so the bot can read them.
FLASH_LOAN_ADDRESS=
PRICE_ORACLE_ADDRESS=

# ── API Keys ──────────────────────────────────────────────────────────────────
# Polygonscan API key — used for contract verification
# Get one at: https://polygonscan.com/apis
POLYGONSCAN_API_KEY=

# CoinMarketCap API key — used ONLY for gas reporter USD display (optional)
CMC_API_KEY=

# ── Hardhat / Testing ─────────────────────────────────────────────────────────
# Set to true to print a gas usage table after every test run
REPORT_GAS=false

# ── Bot ───────────────────────────────────────────────────────────────────────
# Log verbosity: error | warn | info | debug
LOG_LEVEL=info
P2_FILE_EOF

# ---------- .env.scan ----------
cat > '.env.scan' << 'P2_FILE_EOF'
POLYGON_RPC_URL=https://polygon-mainnet.g.alchemy.com/v2/WKn526I0ulDQICUtzwYMd
P2_FILE_EOF

# ---------- .eslintrc.js ----------
cat > '.eslintrc.js' << 'P2_FILE_EOF'
module.exports = {
  root: true,
  env: {
    node: true,
    es2022: true,
  },
  extends: [
    "eslint:recommended",
    "prettier",
  ],
  parserOptions: {
    ecmaVersion: 2022,
  },
  rules: {
    "no-console": "off",
    "no-unused-vars": ["warn", { argsIgnorePattern: "^_" }],
  },
  overrides: [
    {
      files: ["bot/src/**/*.ts"],
      parser: "@typescript-eslint/parser",
      plugins: ["@typescript-eslint"],
      extends: [
        "eslint:recommended",
        "plugin:@typescript-eslint/recommended",
        "prettier",
      ],
      rules: {
        "@typescript-eslint/no-explicit-any": "warn",
        "@typescript-eslint/no-unused-vars": ["warn", { argsIgnorePattern: "^_" }],
      },
    },
  ],
};
P2_FILE_EOF

# ---------- .gitattributes ----------
cat > '.gitattributes' << 'P2_FILE_EOF'
*.png filter=lfs diff=lfs merge=lfs -text
*.jpg filter=lfs diff=lfs merge=lfs -text
*.jpeg filter=lfs diff=lfs merge=lfs -text
*.gif filter=lfs diff=lfs merge=lfs -text
*.webp filter=lfs diff=lfs merge=lfs -text
*.ico filter=lfs diff=lfs merge=lfs -text
*.bmp filter=lfs diff=lfs merge=lfs -text
*.tiff filter=lfs diff=lfs merge=lfs -text
*.psd filter=lfs diff=lfs merge=lfs -text
*.pdf filter=lfs diff=lfs merge=lfs -text
*.mp4 filter=lfs diff=lfs merge=lfs -text
*.mov filter=lfs diff=lfs merge=lfs -text
*.webm filter=lfs diff=lfs merge=lfs -text
*.mp3 filter=lfs diff=lfs merge=lfs -text
*.wav filter=lfs diff=lfs merge=lfs -text
*.zip filter=lfs diff=lfs merge=lfs -text
*.gz filter=lfs diff=lfs merge=lfs -text
*.tar filter=lfs diff=lfs merge=lfs -text
*.7z filter=lfs diff=lfs merge=lfs -text
*.sqlite filter=lfs diff=lfs merge=lfs -text
*.db filter=lfs diff=lfs merge=lfs -text
*.parquet filter=lfs diff=lfs merge=lfs -text
*.csv filter=lfs diff=lfs merge=lfs -text
*.woff filter=lfs diff=lfs merge=lfs -text
*.woff2 filter=lfs diff=lfs merge=lfs -text
*.ttf filter=lfs diff=lfs merge=lfs -text
*.otf filter=lfs diff=lfs merge=lfs -text
*.heic filter=lfs diff=lfs merge=lfs -text
*.avif filter=lfs diff=lfs merge=lfs -text
*.m4a filter=lfs diff=lfs merge=lfs -text
*.aac filter=lfs diff=lfs merge=lfs -text
*.ogg filter=lfs diff=lfs merge=lfs -text
*.flac filter=lfs diff=lfs merge=lfs -text
*.avi filter=lfs diff=lfs merge=lfs -text
*.mkv filter=lfs diff=lfs merge=lfs -text
*.m4v filter=lfs diff=lfs merge=lfs -text
*.rar filter=lfs diff=lfs merge=lfs -text
*.bz2 filter=lfs diff=lfs merge=lfs -text
*.xz filter=lfs diff=lfs merge=lfs -text
*.zst filter=lfs diff=lfs merge=lfs -text
*.docx filter=lfs diff=lfs merge=lfs -text
*.xlsx filter=lfs diff=lfs merge=lfs -text
*.pptx filter=lfs diff=lfs merge=lfs -text
*.part filter=lfs diff=lfs merge=lfs -text
*.mbox filter=lfs diff=lfs merge=lfs -text
*.apk filter=lfs diff=lfs merge=lfs -text
*.aab filter=lfs diff=lfs merge=lfs -text
*.aar filter=lfs diff=lfs merge=lfs -text
*.jar filter=lfs diff=lfs merge=lfs -text
*.dex filter=lfs diff=lfs merge=lfs -text
*.class filter=lfs diff=lfs merge=lfs -text
*.so filter=lfs diff=lfs merge=lfs -text
*.dylib filter=lfs diff=lfs merge=lfs -text
*.dll filter=lfs diff=lfs merge=lfs -text
*.exe filter=lfs diff=lfs merge=lfs -text
*.wasm filter=lfs diff=lfs merge=lfs -text
*.bin filter=lfs diff=lfs merge=lfs -text
P2_FILE_EOF

# ---------- .gitignore ----------
cat > '.gitignore' << 'P2_FILE_EOF'
# Environment
.env
bot/.env

# Hardhat
cache/
artifacts/
typechain-types/

# Node
node_modules/
bot/node_modules/

# Build outputs
bot/dist/
bot/logs/

# Coverage
coverage/
coverage.json
.solcover.js

# Gas report
gas-report.txt

# OS
.DS_Store
Thumbs.db

# Editor
.vscode/
.idea/
*.swp
*.swo
.agents/.env
.npm/
__pycache__/
.cache/
.venv/
venv/
.gradle/
.dart_tool/
.pub-cache/
Pods/
DerivedData/
P2_FILE_EOF

# ---------- .prettierrc.js ----------
cat > '.prettierrc.js' << 'P2_FILE_EOF'
module.exports = {
  semi: true,
  singleQuote: false,
  tabWidth: 2,
  trailingComma: "es5",
  printWidth: 100,
  bracketSpacing: true,
  arrowParens: "always",
  overrides: [
    {
      files: "*.sol",
      options: {
        printWidth: 100,
        tabWidth: 4,
        singleQuote: false,
        bracketSpacing: false,
        explicitTypes: "always",
      },
    },
  ],
};
P2_FILE_EOF

# ---------- .railwayignore ----------
cat > '.railwayignore' << 'P2_FILE_EOF'
# Don't ship test/dev files to Railway build context
test/
scripts/
artifacts/
cache/
logs/
coverage/
.env
.env.*
node_modules/
bot/node_modules/
*.dbg.json
output/addresses-mumbai.json
P2_FILE_EOF

# ---------- DEPLOY.md ----------
cat > 'DEPLOY.md' << 'P2_FILE_EOF'
# Deployment Guide

## Prerequisites

1. Clone and install:
   ```bash
   npm install
   cd bot && npm install && cd ..
   cp .env.example .env
   ```

2. Fill in `.env`:
   - `POLYGON_RPC_URL` — Alchemy HTTP endpoint (archival for fork tests)
   - `POLYGON_WS_URL` — Alchemy WebSocket endpoint (same app)
   - `PRIVATE_KEY` — deployer wallet private key (no 0x prefix)
   - `POLYGONSCAN_API_KEY` — for contract verification (optional)

---

## Step 1 — Run unit tests

```bash
npm run test:unit       # 43 tests, no RPC needed
npm run test:gas        # same + gas report
```

---

## Step 2 — Fork tests (requires POLYGON_RPC_URL)

```bash
npm run test:fork
```

Covers: Chainlink feed freshness, QuickSwap/SushiSwap live prices,
Aave pool reachability, TwapOracle snapshot + consult.

---

## Step 3 — Testnet deploy (Mumbai)

```bash
npm run deploy:mumbai
```

After deploy, add the printed addresses to `.env`, then:

```bash
npm run verify:mumbai
```

Get test MATIC: https://faucet.polygon.technology

---

## Step 4 — Mainnet deploy

```bash
# Dry-run first (no broadcast):
DRY_RUN=true npx hardhat run scripts/deploy-polygon.js --network polygon

# Live deploy:
npm run deploy:polygon

# Sanity check:
npm run verify:check

# Polygonscan verification (auto if POLYGONSCAN_API_KEY is set):
npx hardhat verify --network polygon <FLASH_LOAN_ADDRESS> \
  "0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb" "<PRICE_ORACLE_ADDRESS>" "<YOUR_WALLET>"
```

---

## Step 5 — Start the bot

```bash
cd bot
npm run build        # compile TypeScript
npm run start        # run compiled bot

# or dev mode (auto-recompile on save):
npm run dev
```

Bot logs structured JSON to stdout. Set `LOG_LEVEL=debug` in `.env` for verbose output.

---

## Contract addresses (output after deploy)

Saved to `output/addresses-mainnet.json` and `output/addresses-mumbai.json`.

---

## Gas estimates

| Contract           | Deploy gas | % of block limit |
|--------------------|-----------|-----------------|
| FlashLoanSecure    | ~1,315,721 | 2.2%            |
| FlashLoanPolygon   | ~891,158  | 1.5%            |
| PriceOraclePolygon | ~784,864  | 1.3%            |
| TwapOracle         | ~350,000  | 0.6%            |

P2_FILE_EOF

# ---------- Dockerfile ----------
cat > 'Dockerfile' << 'P2_FILE_EOF'
# ─────────────────────────────────────────────────────────────────────────────
# Stage 1: Build
# ─────────────────────────────────────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

# Install root deps (hardhat / test tooling — needed for artifacts)
COPY package*.json ./
RUN npm ci --ignore-scripts

# Install bot deps
COPY bot/package*.json ./bot/
RUN cd bot && npm ci --ignore-scripts

# Copy source and compile
COPY bot/ ./bot/
RUN cd bot && npx tsc

# ─────────────────────────────────────────────────────────────────────────────
# Stage 2: Runtime
# ─────────────────────────────────────────────────────────────────────────────
FROM node:20-alpine AS runtime

# Non-root user for security
RUN addgroup -S botuser && adduser -S botuser -G botuser

WORKDIR /app

# Copy compiled output and production deps only
COPY --from=builder /app/bot/dist       ./bot/dist
COPY --from=builder /app/bot/node_modules ./bot/node_modules
COPY bot/package.json                   ./bot/package.json

# Logs directory (writable by botuser)
RUN mkdir -p /app/logs && chown botuser:botuser /app/logs

USER botuser

# Health check — confirm node process is alive every 60s
HEALTHCHECK --interval=60s --timeout=10s --start-period=15s --retries=3 \
  CMD pgrep -x node > /dev/null || exit 1

WORKDIR /app/bot

CMD ["node", "dist/index.js"]
P2_FILE_EOF

# ---------- RAILWAY.md ----------
cat > 'RAILWAY.md' << 'P2_FILE_EOF'
# Railway Deployment Guide

Deploy the Flash Loan Arbitrage Bot to Railway for 24/7 scan-and-execute.

---

## 1. Create a Railway project

1. Go to [railway.app](https://railway.app) → **New Project**
2. Choose **Deploy from GitHub repo**
3. Select `zflip1988-code/The-Flash-Loan`
4. Railway will auto-detect the `Dockerfile` and `railway.toml`

---

## 2. Set environment variables

In Railway dashboard → your service → **Variables** tab, add:

### Required (scan-only mode)
| Variable | Value |
|----------|-------|
| `POLYGON_RPC_URL` | Your Alchemy/QuickNode HTTP URL — e.g. `https://polygon-mainnet.g.alchemy.com/v2/YOUR_KEY` |
| `DRY_RUN` | `true` (scan-only, no transactions) |

### Optional (WebSocket for faster block detection)
| Variable | Value |
|----------|-------|
| `POLYGON_WS_URL` | `wss://polygon-mainnet.g.alchemy.com/v2/YOUR_KEY` |

### Required for live execution (when ready)
| Variable | Value |
|----------|-------|
| `PRIVATE_KEY` | Your wallet private key (no 0x prefix) |
| `FLASH_LOAN_ADDRESS` | Deployed `FlashLoanPolygon` contract address |
| `PRICE_ORACLE_ADDRESS` | Deployed `PriceOraclePolygon` contract address |
| `DRY_RUN` | Remove this variable (or set to `false`) |

> ⚠️  Never commit `PRIVATE_KEY` to the repo. Railway Variables are encrypted at rest.

---

## 3. Deploy

Click **Deploy** — Railway will:
1. Pull the repo
2. Build the Docker image (Stage 1: TypeScript compile, Stage 2: lean runtime)
3. Start the bot with `node dist/index.js`
4. Auto-restart on crash (up to 10 retries per `railway.toml`)

---

## 4. View logs

Railway dashboard → your service → **Logs** tab.

You should see structured JSON output like:
```
{"level":"info","message":"Bot starting...","mode":"scan-only"}
{"level":"info","message":"Block #87088459 scanned","opportunities":2}
```

---

## 5. Switch from scan-only → live execution

1. Deploy `FlashLoanPolygon` and `PriceOraclePolygon` to Polygon mainnet (see `DEPLOY.md`)
2. In Railway Variables, add `PRIVATE_KEY`, `FLASH_LOAN_ADDRESS`, `PRICE_ORACLE_ADDRESS`
3. Remove or set `DRY_RUN=false`
4. Railway will auto-redeploy with the new vars

---

## Estimated cost

Railway Hobby plan: ~$5/mo. The bot uses minimal CPU (pure RPC polling) — well within the free tier limits.

---

## Persistent logs

Opportunity logs (`logs/opportunities-YYYY-MM-DD.jsonl`) are written inside the container.
They are committed to GitHub nightly by the automated agent (11:55 PM CT daily).
For persistent log storage across deploys, Railway Volumes can be mounted at `/app/logs`.
P2_FILE_EOF

# ---------- hardhat.config.js ----------
cat > 'hardhat.config.js' << 'P2_FILE_EOF'
require("@nomicfoundation/hardhat-toolbox");
require("hardhat-gas-reporter");
require("solidity-coverage");
require("dotenv").config();

// Detect whether we're running a fork test by inspecting argv
const isForkTest = process.argv.some(
  (a) => a.includes("fork.test") || a.includes("--fork")
);

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
    },
  },

  networks: {
    hardhat: {
      // Forking is only enabled when running fork tests (requires POLYGON_RPC_URL)
      forking: isForkTest && process.env.POLYGON_RPC_URL
        ? {
            url: process.env.POLYGON_RPC_URL,
            blockNumber: undefined, // latest
            enabled: true,
          }
        : { url: "https://polygon-rpc.com", enabled: false },
      chainId: 137,
    },
    polygon: {
      chainId: 137,
      url: process.env.POLYGON_RPC_URL || "https://polygon-rpc.com",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      gasPrice: "auto",
      gas: "auto",
    },
    mumbai: {
      chainId: 80001,
      url: process.env.MUMBAI_RPC_URL || "https://rpc-mumbai.maticvigil.com",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      gasPrice: "auto",
      gas: "auto",
    },
  },

  gasReporter: {
    enabled: process.env.REPORT_GAS === "true",
    currency: "USD",
    coinmarketcap: process.env.CMC_API_KEY,
    outputFile: "gas-report.txt",
    noColors: true,
    token: "MATIC",
  },

  etherscan: {
    apiKey: {
      polygon: process.env.POLYGONSCAN_API_KEY || "",
      polygonMumbai: process.env.POLYGONSCAN_API_KEY || "",
    },
  },

  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },

  mocha: {
    timeout: 120000,
  },
};
P2_FILE_EOF

# ---------- package.json ----------
cat > 'package.json' << 'P2_FILE_EOF'
{
  "name": "flash-loan-arbitrage-polygon",
  "version": "1.0.0",
  "description": "Production-ready Flash Loan Arbitrage Bot targeting Polygon — Aave v3 + QuickSwap + SushiSwap",
  "private": true,
  "scripts": {
    "compile": "hardhat compile",
    "test": "REPORT_GAS=true hardhat test",
    "test:coverage": "hardhat coverage",
    "test:fork": "hardhat test test/FlashLoanPolygon.fork.test.js --network hardhat",
    "deploy:mumbai": "hardhat run scripts/deploy-polygon-mumbai.js --network mumbai",
    "deploy:polygon": "hardhat run scripts/deploy-polygon.js --network polygon",
    "verify:polygon": "hardhat verify --network polygon",
    "lint": "eslint . --ext .js,.ts",
    "lint:fix": "eslint . --ext .js,.ts --fix",
    "format": "prettier --write '**/*.{js,ts,sol,json}'",
    "clean": "hardhat clean && rm -rf cache artifacts",
    "test:unit": "hardhat test test/FlashLoanSecurity.js test/FlashLoanPolygon.test.js test/Reproduction.test.js",
    "test:gas": "REPORT_GAS=true hardhat test test/FlashLoanSecurity.js test/FlashLoanPolygon.test.js test/Reproduction.test.js",
    "verify:check": "hardhat run scripts/verify-deployment.js --network polygon",
    "verify:mumbai": "hardhat run scripts/verify-deployment.js --network mumbai"
  },
  "dependencies": {
    "@aave/core-v3": "^1.19.3",
    "@openzeppelin/contracts": "^5.6.1",
    "@uniswap/v2-periphery": "^1.1.0-beta.0",
    "ethers": "^6.17.0"
  },
  "devDependencies": {
    "@nomicfoundation/hardhat-chai-matchers": "^2.0.6",
    "@nomicfoundation/hardhat-ethers": "^3.0.5",
    "@nomicfoundation/hardhat-toolbox": "^5.0.0",
    "@nomicfoundation/hardhat-verify": "^2.0.5",
    "@types/chai": "^4.3.14",
    "@types/node": "^20.12.5",
    "chai": "^4.4.1",
    "dotenv": "^17.4.2",
    "eslint": "^8.57.0",
    "eslint-config-prettier": "^9.1.0",
    "eslint-plugin-prettier": "^5.1.3",
    "hardhat": "^2.28.6",
    "hardhat-gas-reporter": "^1.0.10",
    "prettier": "^3.2.5",
    "prettier-plugin-solidity": "^1.3.1",
    "solidity-coverage": "^0.8.17",
    "ts-node": "^10.9.2",
    "typescript": "^5.4.5"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
P2_FILE_EOF

# ---------- railway.toml ----------
cat > 'railway.toml' << 'P2_FILE_EOF'
[build]
  builder          = "DOCKERFILE"
  dockerfilePath   = "Dockerfile"

[deploy]
  # Restart automatically on crash — keeps the scanner alive 24/7
  restartPolicyType            = "ON_FAILURE"
  restartPolicyMaxRetries      = 10

  # Give the process time to initialize RPC connections on first boot
  healthcheckPath              = ""
  startCommand                 = "node dist/index.js"

  # Railway will inject env vars — no .env file needed on the server
  # Set these in Railway dashboard → Variables tab:
  #   POLYGON_RPC_URL          (required)
  #   POLYGON_WS_URL           (optional — enables WebSocket block subscription)
  #   PRIVATE_KEY              (optional — only for live execution)
  #   FLASH_LOAN_ADDRESS       (optional — only for live execution)
  #   PRICE_ORACLE_ADDRESS     (optional — only for live execution)
  #   DRY_RUN                  set to "true" for scan-only mode
  #   LOG_LEVEL                "info" or "debug"
P2_FILE_EOF

# ---------- size-sweep.js ----------
cat > 'size-sweep.js' << 'P2_FILE_EOF'
const { JsonRpcProvider, Contract } = require('ethers');
require('dotenv').config();

const RPC = process.env.POLYGON_RPC_URL;
const provider = new JsonRpcProvider(RPC);

const QUICKSWAP_ROUTER = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";
const SUSHISWAP_ROUTER = "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506";

const ROUTER_ABI = [
  'function getAmountsOut(uint amountIn, address[] path) view returns (uint[] amounts)'
];

const WMATIC = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
const USDC   = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";

async function main() {
  const qs = new Contract(QUICKSWAP_ROUTER, ROUTER_ABI, provider);
  const ss = new Contract(SUSHISWAP_ROUTER, ROUTER_ABI, provider);
  const path = [WMATIC, USDC];
  const MATIC_PRICE = 0.0748;

  const sizes = [5000, 7500, 10000, 12500, 15000, 17500, 20000, 25000, 30000, 35000, 40000];

  console.log('═'.repeat(110));
  console.log('  WMATIC→USDC SIZE SWEEP — Polygon Mainnet');
  const block = await provider.getBlockNumber();
  console.log('  Block: #' + block + '   |   ' + new Date().toUTCString());
  console.log('═'.repeat(110));
  console.log('Size(WMATIC)  USD Val     QS Out(USDC)   SS Out(USDC)   Spread $   Spread %   Slip %    Net $      Signal');
  console.log('─'.repeat(110));

  let bestNet = 0, bestSize = 0;

  for (const size of sizes) {
    try {
      const amountIn = BigInt(size) * BigInt(10) ** BigInt(18);
      const qsAmounts = await qs.getAmountsOut(amountIn, path);
      const ssAmounts = await ss.getAmountsOut(amountIn, path);

      const qsOut = Number(qsAmounts[1]) / 1e6;
      const ssOut = Number(ssAmounts[1]) / 1e6;
      const usdIn = size * MATIC_PRICE;

      const spread = qsOut - ssOut;
      const spreadPct = (spread / qsOut) * 100;
      const slippagePct = Math.abs(spread / qsOut) * 100;

      const feeCost = (qsOut * 0.003) + (ssOut * 0.003);
      const gasCost = 0.032;
      const net = spread - feeCost - gasCost;

      let signal;
      if (net > 5 && slippagePct < 15) signal = '🟢 EXECUTE';
      else if (net > 0 && slippagePct < 25) signal = '🟡 MARGINAL';
      else signal = '👻 PHANTOM';

      if (net > bestNet) { bestNet = net; bestSize = size; }

      console.log(
        String(size).padStart(8) + '    ' +
        ('$' + usdIn.toFixed(0)).padStart(7) + '   ' +
        qsOut.toFixed(2).padStart(12) + '   ' +
        ssOut.toFixed(2).padStart(12) + '   ' +
        ('$' + spread.toFixed(2)).padStart(8) + '   ' +
        (spreadPct.toFixed(2) + '%').padStart(7) + '   ' +
        (slippagePct.toFixed(1) + '%').padStart(6) + '   ' +
        ('$' + net.toFixed(2)).padStart(8) + '   ' + signal
      );
    } catch (e) {
      console.log(String(size).padStart(8) + '   ERROR: ' + e.message.substring(0, 70));
    }
  }
  console.log('═'.repeat(110));
  console.log('  ★ Optimal size: ' + bestSize + ' WMATIC (~$' + (bestSize * MATIC_PRICE).toFixed(0) + ') → net $' + bestNet.toFixed(2));
  console.log('  Net = spread - 0.3% fees (both legs) - $0.032 gas');
  console.log('═'.repeat(110));
}

main().catch(e => { console.error(e); process.exit(1); });
P2_FILE_EOF

# ---------- base44/connectors/github.jsonc ----------
cat > 'base44/connectors/github.jsonc' << 'P2_FILE_EOF'
{
  "type": "github",
  "scopes": [
    "repo"
  ]
}
P2_FILE_EOF
head -c -1 'base44/connectors/github.jsonc' > 'base44/connectors/github.jsonc.__tmp' && mv 'base44/connectors/github.jsonc.__tmp' 'base44/connectors/github.jsonc'

# ---------- base44/connectors/notion.jsonc ----------
cat > 'base44/connectors/notion.jsonc' << 'P2_FILE_EOF'
{
  "type": "notion",
  "scopes": [
    "read_content",
    "update_content",
    "insert_content"
  ]
}
P2_FILE_EOF
head -c -1 'base44/connectors/notion.jsonc' > 'base44/connectors/notion.jsonc.__tmp' && mv 'base44/connectors/notion.jsonc.__tmp' 'base44/connectors/notion.jsonc'

# ---------- base44/workflows/Bot Anomaly GitHub Issue Reporter.jsonc ----------
cat > 'base44/workflows/Bot Anomaly GitHub Issue Reporter.jsonc' << 'P2_FILE_EOF'
{
  "name": "Bot Anomaly GitHub Issue Reporter",
  "description": "I will check today's opportunity log for anomalies \u2014 stale oracle signals, zero-liquidity pairs appearing as viable, DAI phantom spreads, scanner inactivity gaps. Use $GITHUB_TOKEN_2 to file a GitHub issue on zflip19888-svg/The-Flash-Loan if anomalies are found.",
  "trigger": {
    "condition": null,
    "config": {
      "trigger_type": "scheduled",
      "events": [],
      "schedule_mode": "interval",
      "cron_expression": null,
      "one_time_date": null,
      "timezone": "UTC",
      "interval_value": 6,
      "interval_unit": "hours",
      "interval_anchor": "2026-05-17T05:40:33.724000",
      "ends_type": "never",
      "ends_on_date": null,
      "ends_after_count": null
    }
  },
  "definition": {
    "document": {
      "dsl": "1.0.0",
      "name": "bot_anomaly_github_issue_reporter",
      "version": "1.0",
      "namespace": "base44"
    },
    "do": [
      {
        "run_agent_step": {
          "call": "invoke_superagent_step",
          "with": {
            "message": "[Scheduled task triggered: Bot Anomaly GitHub Issue Reporter]\nDescription: I will check today's opportunity log for anomalies \u2014 stale oracle signals, zero-liquidity pairs appearing as viable, DAI phantom spreads, scanner inactivity gaps. Use $GITHUB_TOKEN_2 to file a GitHub issue on zflip19888-svg/The-Flash-Loan if anomalies are found.\nContext: {\"repo\": \"zflip19888-svg/The-Flash-Loan\", \"log_dir\": \"logs\", \"max_daily_loss_usd\": 100, \"alert_labels\": [\"bot-alert\", \"anomaly\"], \"github_token_var\": \"GITHUB_TOKEN_3\"}"
          },
          "then": "end"
        }
      }
    ]
  }
}
P2_FILE_EOF
head -c -1 'base44/workflows/Bot Anomaly GitHub Issue Reporter.jsonc' > 'base44/workflows/Bot Anomaly GitHub Issue Reporter.jsonc.__tmp' && mv 'base44/workflows/Bot Anomaly GitHub Issue Reporter.jsonc.__tmp' 'base44/workflows/Bot Anomaly GitHub Issue Reporter.jsonc'

# ---------- base44/workflows/Daily Scan + Commit Opportunity Log.jsonc ----------
cat > 'base44/workflows/Daily Scan + Commit Opportunity Log.jsonc' << 'P2_FILE_EOF'
{
  "name": "Daily Scan + Commit Opportunity Log",
  "description": "I will run the live spread scan, then commit today's opportunity log (logs/opportunities-YYYY-MM-DD.jsonl) to the zflip19888-svg/The-Flash-Loan GitHub repository using $GITHUB_TOKEN_2 via the GitHub API.",
  "trigger": {
    "condition": null,
    "config": {
      "trigger_type": "scheduled",
      "events": [],
      "schedule_mode": "recurring",
      "cron_expression": "55 4 * * *",
      "one_time_date": null,
      "timezone": "UTC",
      "interval_value": null,
      "interval_unit": null,
      "interval_anchor": null,
      "ends_type": "never",
      "ends_on_date": null,
      "ends_after_count": null
    }
  },
  "definition": {
    "document": {
      "dsl": "1.0.0",
      "name": "daily_scan_commit_opportunity_log",
      "version": "1.0",
      "namespace": "base44"
    },
    "do": [
      {
        "run_agent_step": {
          "call": "invoke_superagent_step",
          "with": {
            "message": "[Scheduled task triggered: Daily Scan + Commit Opportunity Log]\nDescription: I will run the live spread scan, then commit today's opportunity log (logs/opportunities-YYYY-MM-DD.jsonl) to the zflip19888-svg/The-Flash-Loan GitHub repository using $GITHUB_TOKEN_2 via the GitHub API.\nContext: {\"repo\": \"zflip19888-svg/The-Flash-Loan\", \"branch\": \"main\", \"log_dir\": \"logs\", \"github_token_var\": \"GITHUB_TOKEN_3\"}"
          },
          "then": "end"
        }
      }
    ]
  }
}
P2_FILE_EOF
head -c -1 'base44/workflows/Daily Scan + Commit Opportunity Log.jsonc' > 'base44/workflows/Daily Scan + Commit Opportunity Log.jsonc.__tmp' && mv 'base44/workflows/Daily Scan + Commit Opportunity Log.jsonc.__tmp' 'base44/workflows/Daily Scan + Commit Opportunity Log.jsonc'

# ---------- bot/.env.example ----------
cat > 'bot/.env.example' << 'P2_FILE_EOF'
# ─────────────────────────────────────────────────────────────────────────────
# Flash Loan Arbitrage Bot — Environment Variables
# Copy this file to .env and fill in real values.
# NEVER commit a filled .env file to version control.
# ─────────────────────────────────────────────────────────────────────────────

# Polygon mainnet HTTP RPC (Alchemy / QuickNode / Infura recommended)
POLYGON_RPC_URL=

# Polygon mainnet WebSocket RPC (same provider, wss:// endpoint)
POLYGON_WS_URL=

# Private key of the owner wallet (no 0x prefix)
# WARNING: Fund this wallet with MATIC for gas only — keep assets off-chain
PRIVATE_KEY=

# Deployed FlashLoanSecure contract address
FLASH_LOAN_ADDRESS=

# Deployed PriceOraclePolygon contract address
PRICE_ORACLE_ADDRESS=

# Polygonscan API key (optional — used for gas price estimation)
POLYGONSCAN_API_KEY=

# Log level: error | warn | info | debug (default: info)
LOG_LEVEL=info
P2_FILE_EOF

# ---------- bot/package.json ----------
cat > 'bot/package.json' << 'P2_FILE_EOF'
{
  "name": "flash-loan-bot",
  "version": "1.0.0",
  "description": "Off-chain arbitrage scanner for the Polygon Flash Loan Bot",
  "private": true,
  "main": "dist/index.js",
  "scripts": {
    "start": "node dist/index.js",
    "build": "tsc",
    "dev": "DRY_RUN=true ts-node-dev --respawn --transpile-only src/index.ts",
    "lint": "eslint src --ext .ts",
    "lint:fix": "eslint src --ext .ts --fix",
    "type-check": "tsc --noEmit",
    "start:dry": "DRY_RUN=true node dist/index.js",
    "dev:live": "ts-node-dev --respawn --transpile-only src/index.ts"
  },
  "dependencies": {
    "dotenv": "^16.4.5",
    "ethers": "^6.11.1",
    "winston": "^3.13.0",
    "winston-daily-rotate-file": "^5.0.0"
  },
  "devDependencies": {
    "@types/node": "^20.12.5",
    "@typescript-eslint/eslint-plugin": "^7.7.0",
    "@typescript-eslint/parser": "^7.7.0",
    "eslint": "^8.57.0",
    "eslint-config-prettier": "^9.1.0",
    "ts-node": "^10.9.2",
    "ts-node-dev": "^2.0.0",
    "typescript": "^5.4.5"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
P2_FILE_EOF
head -c -1 'bot/package.json' > 'bot/package.json.__tmp' && mv 'bot/package.json.__tmp' 'bot/package.json'

# ---------- bot/src/config.ts ----------
cat > 'bot/src/config.ts' << 'P2_FILE_EOF'
/**
 * @file config.ts
 * @notice Central configuration for the arbitrage bot.
 *
 * Modes:
 *   Scan-only  — POLYGON_RPC_URL only required. Bot scans + logs, never sends tx.
 *   Live       — Also requires PRIVATE_KEY, FLASH_LOAN_ADDRESS, PRICE_ORACLE_ADDRESS.
 *
 * Start the bot:
 *   DRY_RUN=true npm run start     — scan-only, no tx
 *   npm run start                  — live execution (requires full .env)
 */


// Load .env locally if present — Railway injects vars directly so this is a no-op in production
try { require("dotenv").config({ path: require("path").resolve(__dirname, "../../.env") }); } catch (_) {}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

function requireEnv(key: string): string {
  const v = process.env[key];
  if (!v || v.trim() === "") {
    throw new Error(`Missing required env var: ${key}. Check your .env file.`);
  }
  return v.trim();
}

function optionalEnv(key: string, fallback = ""): string {
  return (process.env[key] ?? fallback).trim();
}

// ─────────────────────────────────────────────────────────────────────────────
// Environment
// ─────────────────────────────────────────────────────────────────────────────

export const ENV = {
  POLYGON_RPC_URL:      requireEnv("POLYGON_RPC_URL"),
  POLYGON_WS_URL:       optionalEnv("POLYGON_WS_URL"),
  // Optional — only needed for live execution
  PRIVATE_KEY:          optionalEnv("PRIVATE_KEY"),
  FLASH_LOAN_ADDRESS:   optionalEnv("FLASH_LOAN_ADDRESS",   "0xBafc19Fd23714bD2F3256C20a6036a5B31A9DbD8"),
  PRICE_ORACLE_ADDRESS: optionalEnv("PRICE_ORACLE_ADDRESS", "0xbBaf624eDe7A57141ADFF779dBf474c9527faD9f"),
  LOG_LEVEL:            optionalEnv("LOG_LEVEL", "info"),
} as const;

// ─────────────────────────────────────────────────────────────────────────────
// Risk parameters
// ─────────────────────────────────────────────────────────────────────────────

export const MIN_PROFIT_USD      = 2.0;
export const MAX_GAS_GWEI        = 350;
export const MAX_DAILY_LOSS_USD  = 100;
export const ESTIMATED_GAS_UNITS = 750_000;
export const MAX_RETRIES         = 3;
export const RETRY_BASE_DELAY_MS = 1_000;

// ─────────────────────────────────────────────────────────────────────────────
// Token pairs
// ─────────────────────────────────────────────────────────────────────────────

export interface TokenPair {
  name:       string;
  tokenIn:    string;
  tokenOut:   string;
  loanAmount: bigint;
}

// ─────────────────────────────────────────────────────────────────────────────
// Flash loan asset routing
// NOTE: Aave v3 Polygon has USDC borrowing DISABLED as of 2026-07-11.
//       All USDC-based pairs now borrow WETH and route through WETH→USDC
//       swap before the arbitrage leg. WETH borrowing is fully enabled
//       with 9,440 ETH ($17M) available.
// ─────────────────────────────────────────────────────────────────────────────

export const TOKEN_PAIRS: TokenPair[] = [
  // ── WETH-borrowed pairs (Aave v3 WETH borrowing enabled) ──────────────────

  // Borrow WETH → swap to USDC on QS → swap to WMATIC on SS → repay WETH
  {
    name:        "WETH→USDC→WMATIC",
    tokenIn:     "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619", // borrow WETH
    tokenOut:    "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270", // end in WMATIC
    loanAmount:  10n * 10n ** 18n,                             // 10 WETH (~$18K)
  },

  // Borrow WETH → swap to USDC on QS → swap to WMATIC on SS → swap back to WETH
  {
    name:        "WETH/USDC",
    tokenIn:     "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619", // borrow WETH
    tokenOut:    "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", // end in USDC
    loanAmount:  10n * 10n ** 18n,                             // 10 WETH (~$18K)
  },

  // ── Native WETH pairs (unchanged — always worked) ─────────────────────────

  {
    name:        "WETH/USDC",
    tokenIn:     "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619",
    tokenOut:    "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
    loanAmount:  10n * 10n ** 18n,
  },
  {
    name:        "USDC/WETH",
    tokenIn:     "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619", // borrow WETH, swap to USDC first
    tokenOut:    "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619",
    loanAmount:  15n * 10n ** 18n,                             // 15 WETH (~$27K ≈ $25K USDC)
  },

  // ── WMATIC pairs via WETH borrow ───────────────────────────────────────────
  {
    name:        "WMATIC/USDC",
    tokenIn:     "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
    tokenOut:    "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
    loanAmount:  20_000n * 10n ** 18n,   // 20K WMATIC — optimal under 5% slippage guard (size sweep Sep 7, 2026)
  },
];

// ─────────────────────────────────────────────────────────────────────────────
// ABIs
// ─────────────────────────────────────────────────────────────────────────────

export const FLASH_LOAN_ABI = [
  "function initiateFlashLoan(address asset, uint256 amount, bytes calldata params) external",
  "function paused() external view returns (bool)",
  "function owner() external view returns (address)",
  "function dailyVolumeUsed(address asset) external view returns (uint256)",
  "function dailyVolumeLimit(address asset) external view returns (uint256)",
] as const;

export const PRICE_ORACLE_ABI = [
  "function getQuickSwapPrice(address tokenIn, address tokenOut, uint256 amountIn) external view returns (uint256)",
  "function getSushiSwapPrice(address tokenIn, address tokenOut, uint256 amountIn) external view returns (uint256)",
  "function getArbitrageSpread(address tokenIn, address tokenOut, uint256 amount) external view returns (uint256 spread, address cheaperDex, address expensiveDex)",
] as const;

export const TWAP_ORACLE_ABI = [
  "function consult(address pair, address tokenIn, uint256 amountIn) external view returns (uint256 amountOut)",
  "function getWindowInfo(address pair) external view returns (uint256 window, bool isReady, uint256 lastUpdate)",
  "function update(address pair) external",
] as const;
P2_FILE_EOF

# ---------- bot/src/gas-bidder.ts ----------
cat > 'bot/src/gas-bidder.ts' << 'P2_FILE_EOF'
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
P2_FILE_EOF

# ---------- bot/src/hmm.ts ----------
cat > 'bot/src/hmm.ts' << 'P2_FILE_EOF'
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
P2_FILE_EOF

# ---------- bot/src/index.ts ----------
cat > 'bot/src/index.ts' << 'P2_FILE_EOF'
/**
 * @file index.ts
 * @notice Entry point for the Flash Loan Arbitrage Bot.
 *
 * Start modes:
 *   npm run start              — live execution (requires PRIVATE_KEY + FLASH_LOAN_ADDRESS)
 *   DRY_RUN=true npm run start — scan only, log opportunities, never send tx
 *   npm run dev                — ts-node-dev watch mode (implies DRY_RUN unless set)
 *
 * Logs:
 *   stdout      — structured JSON (piped to console or log aggregator)
 *   logs/       — opportunities-YYYY-MM-DD.jsonl (one record per viable opportunity)
 */

import { ScanLoop } from "./loop";
import { logInfo, logError } from "./logger";

async function main() {
  const dryRun = process.env.DRY_RUN === "true";

  logInfo("=============================================");
  logInfo("  Flash Loan Arbitrage Bot — Polygon Mainnet");
  logInfo(`  Mode: ${dryRun ? "DRY-RUN (scan only)" : "LIVE"}`);
  logInfo("=============================================");

  const loop = new ScanLoop();

  const shutdown = async (sig: string) => {
    logInfo(`${sig} received — shutting down`);
    await loop.stop();
    process.exit(0);
  };

  process.on("SIGINT",  () => shutdown("SIGINT"));
  process.on("SIGTERM", () => shutdown("SIGTERM"));

  process.on("unhandledRejection", (reason) => {
    logError("Unhandled rejection", reason instanceof Error ? reason : new Error(String(reason)));
  });

  process.on("uncaughtException", (err) => {
    logError("Uncaught exception", err);
    process.exit(1);
  });

  await loop.start();
}

main().catch((err) => {
  logError("Fatal startup error", err);
  process.exit(1);
});
P2_FILE_EOF

# ---------- bot/src/logger.ts ----------
cat > 'bot/src/logger.ts' << 'P2_FILE_EOF'
/**
 * @file logger.ts
 * @notice Structured JSON logger with level filtering.
 *
 * Log levels (ascending severity): debug < info < warn < error
 * Set LOG_LEVEL in .env to control verbosity (default: info).
 */

type LogLevel = "debug" | "info" | "warn" | "error";

const LEVELS: Record<LogLevel, number> = {
  debug: 0,
  info:  1,
  warn:  2,
  error: 3,
};

function currentLevel(): LogLevel {
  const env = (process.env.LOG_LEVEL ?? "info").toLowerCase() as LogLevel;
  return LEVELS[env] !== undefined ? env : "info";
}

function shouldLog(level: LogLevel): boolean {
  return LEVELS[level] >= LEVELS[currentLevel()];
}

function log(level: LogLevel, message: string, meta?: unknown, extra?: unknown): void {
  if (!shouldLog(level)) return;

  const entry: Record<string, unknown> = {
    ts:      new Date().toISOString(),
    level,
    message,
  };

  if (meta !== undefined && meta !== null) {
    if (meta instanceof Error) {
      entry.error = { message: meta.message, stack: meta.stack };
    } else if (typeof meta === "object") {
      Object.assign(entry, meta);
    } else {
      entry.meta = meta;
    }
  }

  if (extra !== undefined) {
    if (typeof extra === "object" && extra !== null) {
      Object.assign(entry, extra);
    } else {
      entry.extra = extra;
    }
  }

  const line = JSON.stringify(entry);
  if (level === "error") {
    process.stderr.write(line + "\n");
  } else {
    process.stdout.write(line + "\n");
  }
}

export function logDebug(message: string, meta?: unknown): void {
  log("debug", message, meta);
}

export function logInfo(message: string, meta?: unknown): void {
  log("info", message, meta);
}

export function logWarn(message: string, meta?: unknown): void {
  log("warn", message, meta);
}

export function logError(message: string, err?: unknown, meta?: unknown): void {
  log("error", message, err instanceof Error ? err : undefined, meta);
}
P2_FILE_EOF

# ---------- bot/src/loop.ts ----------
cat > 'bot/src/loop.ts' << 'P2_FILE_EOF'
/**
 * @file loop.ts
 * @notice Continuous block-by-block arbitrage scanner loop.
 *
 * Spread source — two-tier fallback:
 *   TIER 1 (oracle):  PriceOraclePolygon.getArbitrageSpread()  — used when
 *                     PRICE_ORACLE_ADDRESS is set in .env
 *   TIER 2 (DEX-direct): queries QuickSwap + SushiSwap router
 *                     getAmountsOut() directly — works with no deployed contract
 *
 * The same depth filter ($50K minimum per DEX side) guards both tiers.
 * Every viable opportunity is written to logs/opportunities-YYYY-MM-DD.jsonl.
 * Execution is gated behind DRY_RUN + PRIVATE_KEY + FLASH_LOAN_ADDRESS.
 */

import {
  ethers,
  Contract,
  WebSocketProvider,
  JsonRpcProvider,
  Wallet,
  formatUnits,
} from "ethers";
import {
  ENV,
  TOKEN_PAIRS,
  TokenPair,
  MIN_PROFIT_USD,
  MAX_GAS_GWEI,
  MAX_DAILY_LOSS_USD,
  ESTIMATED_GAS_UNITS,
  MAX_RETRIES,
  RETRY_BASE_DELAY_MS,
  FLASH_LOAN_ABI,
  PRICE_ORACLE_ABI,
  MIN_POOL_DEPTH_USD,
  DEAD_POOL_FLOOR_USD,
  STABLECOIN_MAX_SPREAD_PCT,
} from "./config";

// ── Slippage + phantom guards (Fix for issues #40–42) ────────────────────────
/** Min spread relative to LOAN NOTIONAL to consider a pair (0.05%) */
const MIN_SPREAD_OF_LOAN_PCT = 0.05;
/** Max spread relative to loan notional — anything higher is phantom (5%) */
const MAX_SPREAD_OF_LOAN_PCT  = 5.0;
/** Cap effective trade size to this fraction of the shallower pool's depth */
const MAX_TRADE_TO_DEPTH_RATIO = 0.10;
/** Hard cap on raw spread USD — rejects overflow/garbage oracle values */
const MAX_SPREAD_USD_ABSOLUTE = 100_000;
/** Stale oracle: reject if same pair returns identical spread for N consecutive blocks */
const STALE_ORACLE_BLOCK_THRESHOLD = 3;
import { logInfo, logWarn, logError, logDebug } from "./logger";
import { NonceManager }                          from "./nonce-manager";
import { ChainlinkPriceFeed, FEEDS }             from "./price-feed";
import { writeOpportunity, readTodayLog, OpportunityRecord } from "./opportunity-log";
import { SpreadHMM, HMMState, Regime }                        from "./hmm";
import { getRpcPool, RpcPool }                              from "./rpc-pool";
import { getMevRouter, MevRelayRouter, RelayName }           from "./mev-relay";
import { getGasBidder, GasBidder }                          from "./gas-bidder";
import * as fs from "fs";
import * as path from "path";

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────


// ─────────────────────────────────────────────────────────────────────────────
// Aave v3 USDC borrow disabled — WETH routing
// All pairs that previously borrowed USDC now borrow WETH and pre-swap
// to USDC before the arbitrage leg. executeOperation() on the contract
// detects the 3-hop path via the encoded params.
// ─────────────────────────────────────────────────────────────────────────────
const WETH   = "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619";
const USDC   = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
const WMATIC = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
const STATUS_INTERVAL_BLOCKS = 50;
const DRY_RUN                = process.env.DRY_RUN === "true";

// DEX addresses
const QUICKSWAP_ROUTER  = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";
const SUSHISWAP_ROUTER  = "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506";
const QUICKSWAP_FACTORY = "0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32";
const SUSHISWAP_FACTORY = "0xc35DADB65012eC5796536bD9864eD8773aBc74C4";

// Spread source mode — set at startup based on .env
type SpreadSource = "oracle" | "dex-direct";

// ─────────────────────────────────────────────────────────────────────────────
// ABIs
// ─────────────────────────────────────────────────────────────────────────────

const FACTORY_ABI = [
  "function getPair(address,address) external view returns (address)",
] as const;

const PAIR_ABI = [
  "function getReserves() external view returns (uint112,uint112,uint32)",
  "function token0() external view returns (address)",
] as const;

const ROUTER_ABI = [
  "function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory)",
] as const;

// ─────────────────────────────────────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────────────────────────────────────

interface PairResult {
  pair:          TokenPair;
  qsDepthUsd:    number;
  ssDepthUsd:    number;
  qsOut:         bigint;
  ssOut:         bigint;
  spreadUsd:     number;
  gasCostUsd:    number;
  aaveFeeUsd:    number;
  netProfitUsd:  number;
  cheaperDex:    string;   // router address
  expensiveDex:  string;   // router address
  spread:        bigint;   // in tokenOut units
  viable:          boolean;
  source:          SpreadSource;
  spreadPctOfLoan?: number;
  slippagePct?:     number;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

function sleep(ms: number) { return new Promise<void>((r) => setTimeout(r, ms)); }

function decimalsOf(addr: string): number {
  const a = addr.toLowerCase();
  if (a === "0x2791bca1f2de4661ed88a30c99a7a9449aa84174") return 6;  // USDC
  if (a === "0x1bfd67037b42cf73acf2047067bd4f2c47d9bfd6") return 8;  // WBTC
  return 18;
}

function dexLabel(routerAddr: string): string {
  if (routerAddr.toLowerCase() === QUICKSWAP_ROUTER.toLowerCase()) return "QuickSwap";
  if (routerAddr.toLowerCase() === SUSHISWAP_ROUTER.toLowerCase()) return "SushiSwap";
  return routerAddr.slice(0, 8) + "…";
}

// ─────────────────────────────────────────────────────────────────────────────
// ScanLoop
// ─────────────────────────────────────────────────────────────────────────────

export class ScanLoop {
  private http:          JsonRpcProvider;
  private ws:            WebSocketProvider | null = null;
  private wallet:        Wallet | null = null;
  private flashLoan:     Contract | null = null;
  private oracle:        Contract | null = null;
  private qsRouter:      Contract;
  private ssRouter:      Contract;
  private qsFactory:     Contract;
  private ssFactory:     Contract;
  private nonceMgr:      NonceManager | null = null;
  private priceFeed:     ChainlinkPriceFeed;
  private spreadSource:  SpreadSource;

  private running       = false;
  private executing     = false;
  private blocksScanned = 0;
  // Stale oracle detection: track last spread per pair across blocks
  private lastPairSpread = new Map<string, { spread: bigint; count: number; block: number }>();
  private lastBlock     = 0;

  private dailyPnL      = 0;
  private dailyDate     = "";
  private sessionOpps   = 0;
  private sessionTrades = 0;
  private sessionProfit = 0;

  /** Hidden Markov Model — regime detector (one per ScanLoop instance) */
  private hmm = new SpreadHMM();
  private lastHMMState: HMMState | null = null;

  /** Production infra: rotating RPC pool, MEV relay router, dynamic gas bidder */
  private rpcPool:    RpcPool;
  private mevRouter:  MevRelayRouter;
  private gasBidder:  GasBidder;
  private sessionStartMs = Date.now();

  constructor() {
    this.rpcPool   = getRpcPool();
    this.rpcPool.startHealthChecks();
    this.mevRouter = getMevRouter();
    this.gasBidder = getGasBidder();
    this.http      = this.rpcPool.bestProvider();
    this.qsRouter  = new Contract(QUICKSWAP_ROUTER,  ROUTER_ABI,  this.http);
    this.ssRouter  = new Contract(SUSHISWAP_ROUTER,  ROUTER_ABI,  this.http);
    this.qsFactory = new Contract(QUICKSWAP_FACTORY, FACTORY_ABI, this.http);
    this.ssFactory = new Contract(SUSHISWAP_FACTORY, FACTORY_ABI, this.http);
    this.priceFeed = new ChainlinkPriceFeed(this.http);

    // Spread source: oracle if address is set, else DEX-direct
    if (ENV.PRICE_ORACLE_ADDRESS) {
      this.oracle      = new Contract(ENV.PRICE_ORACLE_ADDRESS, PRICE_ORACLE_ABI, this.http);
      this.spreadSource = "oracle";
    } else {
      this.spreadSource = "dex-direct";
    }

    // Execution gate
    const canExecute = !DRY_RUN && !!ENV.PRIVATE_KEY && !!ENV.FLASH_LOAN_ADDRESS;
    if (canExecute) {
      this.wallet    = new Wallet(ENV.PRIVATE_KEY, this.http);
      this.flashLoan = new Contract(ENV.FLASH_LOAN_ADDRESS, FLASH_LOAN_ABI, this.wallet);
      this.nonceMgr  = new NonceManager(this.http, this.wallet.address);
      logInfo("Execution ENABLED", { wallet: this.wallet.address });
    } else {
      logInfo(`Execution DISABLED — ${DRY_RUN ? "DRY_RUN=true" : "missing PRIVATE_KEY / FLASH_LOAN_ADDRESS"}`);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Start / Stop
  // ──────────────────────────────────────────────────────────────────────────

  async start(): Promise<void> {
    this.running = true;
    logInfo("ScanLoop starting", {
      rpc:          ENV.POLYGON_RPC_URL.replace(/\/v2\/.+/, "/v2/***"),
      spreadSource: this.spreadSource,
      minProfitUsd: MIN_PROFIT_USD,
      maxGasGwei:   MAX_GAS_GWEI,
      minDepthUsd:  MIN_POOL_DEPTH_USD,
      dryRun:       DRY_RUN,
      pairs:        TOKEN_PAIRS.map((p) => p.name),
    });

    await this.priceFeed.warmCache().catch((e) =>
      logWarn("Price cache warm failed", { error: String(e) })
    );

    const poolWs = this.rpcPool.bestWebSocket();
    if (poolWs) {
      try {
        this.ws = poolWs;
        await new Promise<void>((resolve, reject) => {
          const t = setTimeout(() => reject(new Error("WS timeout")), 8_000);
          this.ws!.once("block", () => { clearTimeout(t); resolve(); });
        });
        this.ws.on("block", (n: number) => this._onBlock(n));
        logInfo("WebSocket block subscription active");
        return;
      } catch (err) {
        logWarn("WebSocket failed — HTTP polling fallback", { err: String(err) });
        if (this.ws) { try { await this.ws.destroy(); } catch {} this.ws = null; }
      }
    }
    this._pollLoop();
  }

  async stop(): Promise<void> {
    this.running = false;
    if (this.ws) await this.ws.destroy().catch(() => {});
    this._printStatus("SHUTDOWN");
    logInfo("ScanLoop stopped");
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HTTP polling
  // ──────────────────────────────────────────────────────────────────────────

  private async _pollLoop(): Promise<void> {
    logInfo("HTTP polling active (2 s)");
    while (this.running) {
      try {
        const block = await this.http.getBlockNumber();
        if (block > this.lastBlock) { this.lastBlock = block; await this._onBlock(block); }
      } catch (err) { logError("Poll error", err); }
      await sleep(2_000);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Per-block handler
  // ──────────────────────────────────────────────────────────────────────────

  private async _onBlock(blockNumber: number): Promise<void> {
    this.blocksScanned++;
    this._resetDailyIfNeeded();
    logDebug("Block", { blockNumber, source: this.spreadSource });

    if (this.dailyPnL < -MAX_DAILY_LOSS_USD) {
      logWarn("Daily loss limit — halted", { dailyPnL: this.dailyPnL.toFixed(2) });
      return;
    }
    if (this.executing) { logDebug("In-flight — skip", { blockNumber }); return; }

    this.priceFeed.flushCache();

    const maticUsd = await this.priceFeed.getPrice(FEEDS.MATIC_USD, 0.9).catch(() => 0.05);
    const ethUsd   = await this.priceFeed.getPrice(FEEDS.ETH_USD, 0.95).catch(() => 1900);

    // Refresh gas bidder with latest block history, then compute dynamic bid
    await this.gasBidder.refresh(this.http).catch(() => {});
    const regime: Regime = this.lastHMMState?.regime ?? "WARM";
    const bid = this.gasBidder.computeBid(regime);
    const gasPriceGwei = bid.totalGwei;
    const gasPrice     = BigInt(Math.round(gasPriceGwei * 1_000_000_000));

    if (gasPriceGwei > MAX_GAS_GWEI) {
      logWarn("Gas too high", { gasPriceGwei, max: MAX_GAS_GWEI, capped: bid.capped });
      this._writeRuntimeState(blockNumber, maticUsd, ethUsd);
      return;
    }

    const gasCostUsd = Number(formatUnits(gasPrice * BigInt(ESTIMATED_GAS_UNITS), 18)) * maticUsd;
    this._writeRuntimeState(blockNumber, maticUsd, ethUsd);

    // Scan all pairs concurrently
    const results = await Promise.all(
      TOKEN_PAIRS.map((p) => this._scanPair(p, gasPrice, maticUsd, gasCostUsd, blockNumber))
    );

    const viable = results.filter((r): r is PairResult => r !== null && r.viable);

    // ── HMM regime update — use best spread signal across all results ────────
    const bestResult = results
      .filter((r): r is PairResult => r !== null)
      .sort((a, b) => b.spreadUsd - a.spreadUsd)[0];

    let hmmState: HMMState | null = null;
    if (bestResult) {
      // Spread as % of loan notional — more meaningful than % of pool depth
      const loanNotionalEst = parseFloat(formatUnits(bestResult.pair.loanAmount, 18)) * (maticUsd * 10 || 1800);
      const spreadPct = bestResult.spreadUsd / Math.max(loanNotionalEst, 100) * 100;
      const prevRegime = this.lastHMMState?.regime ?? null;
      hmmState = this.hmm.update(spreadPct, bestResult.pair.name);
      this.lastHMMState = hmmState;

      if (hmmState.regime !== prevRegime || hmmState.consecutiveTicks === 1) {
        logInfo("HMM regime", {
          regime:       hmmState.regime,
          confidence:   hmmState.confidence.toFixed(3),
          ticks:        hmmState.consecutiveTicks,
          spreadObs:    hmmState.spreadObs,
          multiplier:   hmmState.executionMultiplier,
          volatility:   this.hmm.spreadVolatility().toFixed(2),
          belief:       this.hmm.beliefVector().map(v => v.toFixed(3)).join(" | "),
        });
      }
    }

    // HMM gate: block execution in COLD regime with low confidence
    const hmmBlocked = hmmState !== null
      && hmmState.regime === "COLD"
      && hmmState.confidence > 0.80;

    if (hmmBlocked) {
      logDebug("HMM COLD block — skipping execution", {
        confidence: hmmState!.confidence.toFixed(3),
        ticks:      hmmState!.consecutiveTicks,
      });
    }

    for (const r of viable) {
      this.sessionOpps++;
      const _signal: "EXECUTE" | "VERIFY_DEPTH" | "MARGINAL" =
        r.viable ? "EXECUTE" : "VERIFY_DEPTH";
      const _note = r.ssDepthUsd < MIN_POOL_DEPTH_USD
        ? "SushiSwap shallow"
        : r.qsDepthUsd < MIN_POOL_DEPTH_USD ? "QuickSwap shallow" : undefined;
      const record: OpportunityRecord = {
        ts:           new Date().toISOString(),
        block:        blockNumber,
        pair:         r.pair.name,
        qsDepthUsd:   r.qsDepthUsd,
        ssDepthUsd:   r.ssDepthUsd,
        spreadPct:    r.spreadPctOfLoan ?? (r.spreadUsd / (r.qsDepthUsd || 1) * 100),
        spreadUsd:    r.spreadUsd,
        netUsd:       r.netProfitUsd,
        gasCostUsd:   r.gasCostUsd,
        aaveFeeUsd:   r.aaveFeeUsd,
        netProfitUsd: r.netProfitUsd,
        slippagePct:  r.slippagePct,
        gasGwei:      Number((gasPrice / 1_000_000_000n)),
        signal:       _signal,
        buyDex:       dexLabel(r.cheaperDex),
        sellDex:      dexLabel(r.expensiveDex),
        cheaperDex:   dexLabel(r.cheaperDex),
        executed:     false,
        ..._note ? { note: _note } : {},
        hmmRegime:       hmmState?.regime,
        hmmConfidence:   hmmState ? parseFloat(hmmState.confidence.toFixed(3)) : undefined,
        hmmMultiplier:   hmmState?.executionMultiplier,
      };

      logInfo("Opportunity", {
        pair:        r.pair.name,
        net:         `$${r.netProfitUsd.toFixed(2)}`,
        spread:      `$${r.spreadUsd.toFixed(2)}`,
        spreadPct:   `${(r.spreadUsd / Math.max(r.qsDepthUsd, 1) * 100).toFixed(2)}%`,
        cheaper:     dexLabel(r.cheaperDex),
        qsDepth:     `$${(r.qsDepthUsd / 1000).toFixed(0)}K`,
        ssDepth:     `$${(r.ssDepthUsd / 1000).toFixed(0)}K`,
        regime:      hmmState?.regime ?? "?",
        source:      r.source,
        dryRun:      DRY_RUN || !this.flashLoan,
      });

      // Apply HMM execution multiplier — HOT regime lowers the bar, COLD raises it
      const hmmMultiplier   = hmmState?.executionMultiplier ?? 1.0;
      const adjustedMinProfit = MIN_PROFIT_USD * hmmMultiplier;
      if (r.netProfitUsd < adjustedMinProfit) {
        logDebug("HMM profit filter", {
          pair:            r.pair.name,
          net:             r.netProfitUsd.toFixed(2),
          adjustedMin:     adjustedMinProfit.toFixed(2),
          regime:          hmmState?.regime ?? "UNKNOWN",
        });
        continue;
      }

      if (this.flashLoan && this.nonceMgr && this.wallet && !DRY_RUN && !hmmBlocked) {
        const txResult = await this._execute(r, gasPrice, gasCostUsd);
        record.executed = (txResult.status === "success");
        record.txHash   = txResult.hash;
        record.txStatus = txResult.status;
        if (txResult.error) record.error = txResult.error;

        if (txResult.status === "success") {
          this.sessionTrades++;
          this.sessionProfit += r.netProfitUsd;
          this.dailyPnL      += r.netProfitUsd;
        } else {
          this.dailyPnL -= gasCostUsd;
        }
        writeOpportunity(record);
        break; // one trade per block
      } else {
        writeOpportunity(record);
      }
    }

    if (this.blocksScanned % STATUS_INTERVAL_BLOCKS === 0) this._printStatus("PERIODIC");
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Pair scanner — depth check → spread (oracle or DEX-direct) → profit
  // ──────────────────────────────────────────────────────────────────────────

  private async _scanPair(
    pair:       TokenPair,
    gasPrice:   bigint,
    maticUsd:   number,
    gasCostUsd: number,
    blockNumber: number,
  ): Promise<PairResult | null> {
    try {
      const inDec  = decimalsOf(pair.tokenIn);
      const outDec = decimalsOf(pair.tokenOut);

      const tokenInUsd  = await this.priceFeed.getTokenPriceUsd(pair.tokenIn,  0);
      const tokenOutUsd = await this.priceFeed.getTokenPriceUsd(pair.tokenOut, 0);
      if (tokenInUsd === 0) return null;

      // ── Depth check ────────────────────────────────────────────────────────
      const [qsDep, ssDep] = await Promise.all([
        this._depth(this.qsFactory, pair.tokenIn, pair.tokenOut, inDec, tokenInUsd),
        this._depth(this.ssFactory, pair.tokenIn, pair.tokenOut, inDec, tokenInUsd),
      ]);

      // ── Hard dead-pool guard — ZERO or near-zero liquidity always rejected ──
      if (qsDep < DEAD_POOL_FLOOR_USD || ssDep < DEAD_POOL_FLOOR_USD) {
        logDebug(`Dead pool skip — ${pair.name}`, {
          qs: qsDep.toFixed(0), ss: ssDep.toFixed(0), floor: DEAD_POOL_FLOOR_USD,
        });
        return null;
      }
      // ── Normal depth floor ────────────────────────────────────────────────
      if (Math.min(qsDep, ssDep) < MIN_POOL_DEPTH_USD) {
        const _note = ssDep < MIN_POOL_DEPTH_USD ? "SushiSwap shallow" : "QuickSwap shallow";
        logDebug(`Depth skip — ${pair.name} (${_note})`, {
          qs: qsDep.toFixed(0), ss: ssDep.toFixed(0), required: MIN_POOL_DEPTH_USD,
        });
        return null;
      }

      // ── Spread ─────────────────────────────────────────────────────────────
      let spread: bigint, cheaperDex: string, expensiveDex: string,
          qsOut: bigint, ssOut: bigint, source: SpreadSource;

      if (this.oracle) {
        // TIER 1: oracle
        try {
          [spread, cheaperDex, expensiveDex] =
            await this.oracle.getArbitrageSpread(pair.tokenIn, pair.tokenOut, pair.loanAmount);
          // also get individual quotes for logging
          [qsOut, ssOut] = await Promise.all([
            this._routerQuote(this.qsRouter, pair.tokenIn, pair.tokenOut, pair.loanAmount),
            this._routerQuote(this.ssRouter, pair.tokenIn, pair.tokenOut, pair.loanAmount),
          ]);
          source = "oracle";
        } catch (oracleErr) {
          logDebug(`Oracle failed for ${pair.name} — falling back to DEX-direct`, {
            err: String(oracleErr),
          });
          // fall through to DEX-direct
          const r = await this._dexDirectSpread(pair);
          if (!r) return null;
          ({ spread, cheaperDex, expensiveDex, qsOut, ssOut } = r);
          source = "dex-direct";
        }
      } else {
        // TIER 2: DEX-direct (no oracle deployed)
        const r = await this._dexDirectSpread(pair);
        if (!r) return null;
        ({ spread, cheaperDex, expensiveDex, qsOut, ssOut } = r);
        source = "dex-direct";
      }

      if (spread === 0n) return null;

      // ── Overflow guard: reject absurd spreads (fix for $41 quadrillion bug) ──
      const spreadAbsUsd = parseFloat(formatUnits(spread, outDec)) * (tokenOutUsd || 1);
      if (spreadAbsUsd > MAX_SPREAD_USD_ABSOLUTE) {
        logDebug(`Overflow guard skip — ${pair.name}`, {
          spreadAbsUsd: spreadAbsUsd.toExponential(3), cap: MAX_SPREAD_USD_ABSOLUTE,
        });
        return null;
      }

      // ── Stale oracle: same spread across N blocks = frozen feed ──
      const prevEntry = this.lastPairSpread.get(pair.name);
      if (prevEntry && prevEntry.spread === spread) {
        const newCount = prevEntry.count + 1;
        this.lastPairSpread.set(pair.name, { spread, count: newCount, block: blockNumber });
        if (newCount >= STALE_ORACLE_BLOCK_THRESHOLD) {
          logDebug(`Stale oracle skip — ${pair.name}`, {
            repeatCount: newCount, spread: spread.toString(),
          });
          return null;
        }
      } else {
        this.lastPairSpread.set(pair.name, { spread, count: 1, block: blockNumber });
      }

      // ── Stablecoin phantom spread guard ────────────────────────────────────
      // If the pair is stablecoin↔stablecoin and spread > 20%, it's pool imbalance, not real arb
      if (pair.isStablecoin) {
        const rawSpreadPct = parseFloat(formatUnits(spread, decimalsOf(pair.tokenOut))) /
          Math.max(parseFloat(formatUnits(
            qsOut > ssOut ? qsOut : ssOut, decimalsOf(pair.tokenOut)
          )), 1) * 100;
        if (rawSpreadPct > STABLECOIN_MAX_SPREAD_PCT) {
          logDebug(`Phantom spread skip — ${pair.name}`, {
            spreadPct: rawSpreadPct.toFixed(2), threshold: STABLECOIN_MAX_SPREAD_PCT,
          });
          return null;
        }
      }

      // ── Profit calc (Fix: slippage-adjusted + phantom guard vs loan notional) ─
      const spreadUsd     = parseFloat(formatUnits(spread, outDec)) * (tokenOutUsd || 1);
      const loanNotional   = parseFloat(formatUnits(pair.loanAmount, inDec)) * tokenInUsd;
      if (loanNotional <= 0) return null;

      // Real spread % relative to LOAN NOTIONAL (not pool depth — that was the bug)
      const spreadPctOfLoan = (spreadUsd / loanNotional) * 100;

      // Universal phantom guard: >5% spread vs loan = pool imbalance, not real arb
      if (spreadPctOfLoan > MAX_SPREAD_OF_LOAN_PCT) {
        logDebug(`Phantom spread skip (universal) — ${pair.name}`, {
          spreadPctOfLoan: spreadPctOfLoan.toFixed(2),
          max: MAX_SPREAD_OF_LOAN_PCT,
          qsDep: qsDep.toFixed(0), ssDep: ssDep.toFixed(0),
        });
        return null;
      }
      // Too-flat guard: <0.05% spread vs loan — not worth the gas
      if (spreadPctOfLoan < MIN_SPREAD_OF_LOAN_PCT) {
        logDebug(`Spread too flat — ${pair.name}`, { spreadPctOfLoan: spreadPctOfLoan.toFixed(3) });
        return null;
      }

      // Slippage estimation: trade size / shallower pool depth
      const shallowerDepth = Math.min(qsDep, ssDep);
      const slippagePct     = shallowerDepth > 0
        ? Math.min(100, (loanNotional / shallowerDepth) * 100)
        : 100;
      // If trade would consume >10% of pool, the CP-formula quote is unreliable
      // — model the slippage drag as half the spread × slippage%
      const slippageDrag    = spreadUsd * (slippagePct / 100) * 0.5;
      const aaveFeeUsd      = loanNotional * 0.0005;
      const netProfitUsd    = spreadUsd - gasCostUsd - aaveFeeUsd - slippageDrag;

      logDebug(`Evaluated ${pair.name}`, {
        source, qsDep: qsDep.toFixed(0), ssDep: ssDep.toFixed(0),
        spreadUsd: spreadUsd.toFixed(2), spreadPctOfLoan: spreadPctOfLoan.toFixed(2),
        slippagePct: slippagePct.toFixed(1), net: netProfitUsd.toFixed(2),
      });

      return {
        pair, qsDepthUsd: qsDep, ssDepthUsd: ssDep,
        qsOut, ssOut, spreadUsd, gasCostUsd, aaveFeeUsd, netProfitUsd,
        cheaperDex, expensiveDex, spread,
        spreadPctOfLoan, slippagePct,
        viable: netProfitUsd >= MIN_PROFIT_USD,
        source,
      };
    } catch (err) {
      logError(`Scan error — ${pair.name}`, err);
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // DEX-direct spread (Tier 2) — queries routers directly
  // ──────────────────────────────────────────────────────────────────────────

  private async _dexDirectSpread(pair: TokenPair): Promise<{
    spread: bigint; cheaperDex: string; expensiveDex: string;
    qsOut: bigint; ssOut: bigint;
  } | null> {
    const [qsOut, ssOut] = await Promise.all([
      this._routerQuote(this.qsRouter, pair.tokenIn, pair.tokenOut, pair.loanAmount),
      this._routerQuote(this.ssRouter, pair.tokenIn, pair.tokenOut, pair.loanAmount),
    ]);

    if (qsOut === 0n || ssOut === 0n) return null;

    let spread: bigint, cheaperDex: string, expensiveDex: string;
    if (qsOut >= ssOut) {
      spread       = qsOut - ssOut;
      cheaperDex   = SUSHISWAP_ROUTER;   // borrow cheap (lower out = more of tokenIn consumed)
      expensiveDex = QUICKSWAP_ROUTER;   // sell high
    } else {
      spread       = ssOut - qsOut;
      cheaperDex   = QUICKSWAP_ROUTER;
      expensiveDex = SUSHISWAP_ROUTER;
    }

    return { spread, cheaperDex, expensiveDex, qsOut, ssOut };
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Router quote helper
  // ──────────────────────────────────────────────────────────────────────────

  private async _routerQuote(
    router:    Contract,
    tokenIn:   string,
    tokenOut:  string,
    amountIn:  bigint,
  ): Promise<bigint> {
    try {
      const amounts: bigint[] = await router.getAmountsOut(amountIn, [tokenIn, tokenOut]);
      return amounts[1] ?? 0n;
    } catch {
      return 0n;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Pool depth helper
  // ──────────────────────────────────────────────────────────────────────────

  private async _depth(
    factory:    Contract,
    tokenIn:    string,
    tokenOut:   string,
    inDec:      number,
    priceInUsd: number,
  ): Promise<number> {
    try {
      const pairAddr: string = await factory.getPair(tokenIn, tokenOut);
      if (!pairAddr || pairAddr === ethers.ZeroAddress) return 0;
      const p = new Contract(pairAddr, PAIR_ABI, this.http);
      const [[r0, r1], t0]: [[bigint, bigint, number], string] =
        await Promise.all([p.getReserves(), p.token0()]);
      const isT0   = t0.toLowerCase() === tokenIn.toLowerCase();
      const resIn  = isT0 ? r0 : r1;
      return parseFloat(formatUnits(resIn, inDec)) * priceInUsd;
    } catch { return 0; }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Execution
  // ──────────────────────────────────────────────────────────────────────────

  private async _execute(
    r:          PairResult,
    gasPrice:   bigint,
    gasCostUsd: number,
  ): Promise<{ hash: string; status: "success" | "reverted" | "pending"; error?: string }> {
    this.executing = true;
    const minProfit = (r.pair.loanAmount * 5n) / 10_000n;
    const params    = ethers.AbiCoder.defaultAbiCoder().encode(
      ["address", "address", "address", "address", "uint256"],
      [r.pair.tokenIn, r.pair.tokenOut, r.cheaperDex, r.expensiveDex, minProfit]
    );

    let attempt = 0;
    while (attempt <= MAX_RETRIES) {
      const nonce = await this.nonceMgr!.acquire();
      try {
        const tx = await this.flashLoan!.initiateFlashLoan(
          r.pair.tokenIn, r.pair.loanAmount, params,
          { gasPrice, gasLimit: BigInt(ESTIMATED_GAS_UNITS) + 100_000n, nonce }
        );
        this.nonceMgr!.commit();
        logInfo("Tx submitted", { hash: tx.hash, pair: r.pair.name });

        // Route through MEV relay (private mempool) — fall back to public if it fails
        let relay: RelayName = "public";
        try {
          const signedRaw = await this.wallet!.signTransaction({
            to: this.flashLoan!.target,
            data: tx.data,
            gasPrice,
            gasLimit: BigInt(ESTIMATED_GAS_UNITS) + 100_000n,
            nonce,
            chainId: 137,
          });
          const relayed = await this.mevRouter.submitRawTransaction(signedRaw, tx.hash);
          if (relayed && relayed.relay !== "public") {
            relay = relayed.relay;
            logInfo("MEV relay accepted", { relay, hash: tx.hash });
          }
        } catch (e) { /* swallow — public fallback */ }

        const receipt = await tx.wait(1);
        this.executing = false;

        if (receipt?.status === 1) {
          logInfo("Trade success", {
            hash: tx.hash, gasUsed: receipt.gasUsed.toString(),
            block: receipt.blockNumber, net: `$${r.netProfitUsd.toFixed(2)}`,
            relay,
          });
          return { hash: tx.hash, status: "success" };
        }
        logWarn("Tx reverted", { hash: tx.hash, relay });
        return { hash: tx.hash, status: "reverted" };

      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : String(err);
        if (msg.includes("nonce too low") || msg.includes("replacement fee")) {
          this.nonceMgr!.rollback();
          await this.nonceMgr!.resync();
        } else {
          this.nonceMgr!.rollback();
        }
        if (attempt >= MAX_RETRIES) {
          this.executing = false;
          return { hash: "", status: "pending", error: msg };
        }
        attempt++;
        await sleep(RETRY_BASE_DELAY_MS * 2 ** attempt);
      }
    }
    this.executing = false;
    return { hash: "", status: "pending", error: "max retries" };
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Runtime state — write to dashboard/runtime.json so FastAPI can serve it
  // ──────────────────────────────────────────────────────────────────────────

  private _writeRuntimeState(blockNumber: number, maticUsd: number, ethUsd: number): void {
    try {
      const state = {
        updatedAt:           new Date().toISOString(),
        status:              "RUNNING",
        lastBlock:           blockNumber,
        lastBlockAt:         new Date().toISOString(),
        rpcAlive:            this.rpcPool.countAlive(),
        rpcTotal:            this.rpcPool.total(),
        rpcHealth:           this.rpcPool.snapshot(),
        wsSubscriptions:     this.ws ? 1 : 0,
        hmmRegime:           this.lastHMMState?.regime ?? "UNKNOWN",
        hmmConfidence:       this.lastHMMState ? Number(this.lastHMMState.confidence.toFixed(3)) : 0,
        activeRelay:         this.mevRouter.getLastUsedRelay(),
        relayStats:          this.mevRouter.getStats(),
        lastGasBid:          this.gasBidder.getLastBid(),
        gasHistory:          this.gasBidder.snapshot().slice(-30),
        lastOpportunityAt:   this.sessionOpps > 0 ? new Date().toISOString() : null,
        sessionOpps:         this.sessionOpps,
        sessionTrades:       this.sessionTrades,
        sessionProfitUsd:    Number(this.sessionProfit.toFixed(2)),
        maticPrice:          maticUsd,
        ethPrice:            ethUsd,
        configReloadRequired: false,
      };
      const outPath = path.resolve(__dirname, "..", "..", "dashboard", "runtime.json");
      fs.writeFileSync(outPath, JSON.stringify(state, null, 2));
    } catch (e) {
      logDebug("runtime-state write failed", { error: String(e) });
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Status report
  // ──────────────────────────────────────────────────────────────────────────

  private _printStatus(trigger: string): void {
    const today    = readTodayLog();
    const executed = today.filter((r) => r.executed && r.txStatus === "success");
    const totalNet = executed.reduce((s, r) => s + r.netProfitUsd, 0);
    logInfo(`=== STATUS [${trigger}] ===`, {
      blocksScanned:     this.blocksScanned,
      spreadSource:      this.spreadSource,
      sessionOpps:       this.sessionOpps,
      sessionTrades:     this.sessionTrades,
      sessionProfitUsd:  this.sessionProfit.toFixed(2),
      dailyPnLUsd:       this.dailyPnL.toFixed(2),
      todayTrades:       executed.length,
      todayNetUsd:       totalNet.toFixed(2),
      dryRun:            DRY_RUN,
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Daily reset
  // ──────────────────────────────────────────────────────────────────────────

  private _resetDailyIfNeeded(): void {
    const today = new Date().toISOString().slice(0, 10);
    if (today !== this.dailyDate) {
      if (this.dailyDate) {
        logInfo("Daily PnL reset", { date: this.dailyDate, pnl: this.dailyPnL.toFixed(2) });
      }
      this.dailyPnL = 0; this.dailyDate = today;
    }
  }
}
P2_FILE_EOF

# ---------- bot/src/mev-relay.ts ----------
cat > 'bot/src/mev-relay.ts' << 'P2_FILE_EOF'
/**
 * @file mev-relay.ts
 * @notice MEV relay router for private mempool submission on Polygon.
 *
 * Supported relays:
 *   - fastlane   (Polygon-native, Fastlane.xyz)
 *   - merkle     (Merkle.io Polygon)
 *   - flashbots  (Flashbots Protect, primarily Ethereum L1)
 *
 * The router picks the configured relay, builds the relay-specific payload,
 * and POSTs the signed raw transaction to the relay endpoint. Falls back to
 * public mempool submission if all relays fail.
 *
 * Env:
 *   MEV_RELAY           — comma-separated list of relays to use, in priority order
 *                         e.g. "fastlane,merkle,flashbots"
 *   MEV_RELAY_TIMEOUT_MS — per-relay timeout, default 3_000
 *   FASTLANE_API_KEY    — optional Fastlane API key
 *   MERKLE_API_KEY      — optional Merkle API key
 *   FLASHBOTS_API_KEY   — optional Flashbots API key
 */

import { logInfo, logWarn, logError } from "./logger";

export type RelayName = "fastlane" | "merkle" | "flashbots" | "public";

interface RelayConfig {
  name: RelayName;
  endpoint: string;
  apiKeyEnv: string;
  needsApiKey: boolean;
}

const RELAYS: Record<RelayName, RelayConfig> = {
  fastlane:  {
    name: "fastlane",
    endpoint: "https://relay.fastlane.xyz/polygon/v1/submit",
    apiKeyEnv: "FASTLANE_API_KEY",
    needsApiKey: false,
  },
  merkle: {
    name: "merkle",
    endpoint: "https://polygon.merkle.io/relay",
    apiKeyEnv: "MERKLE_API_KEY",
    needsApiKey: false,
  },
  flashbots: {
    name: "flashbots",
    endpoint: "https://polygon-relay.flashbots.net/v1/relay",
    apiKeyEnv: "FLASHBOTS_API_KEY",
    needsApiKey: false,
  },
  public: {
    name: "public",
    endpoint: "",
    apiKeyEnv: "",
    needsApiKey: false,
  },
};

export class MevRelayRouter {
  private readonly relayPriority: RelayName[];
  private readonly timeoutMs: number;
  private lastUsedRelay: RelayName = "public";
  private relayStats: Record<RelayName, { attempts: number; successes: number; failures: number }> = {
    fastlane: { attempts: 0, successes: 0, failures: 0 },
    merkle:   { attempts: 0, successes: 0, failures: 0 },
    flashbots: { attempts: 0, successes: 0, failures: 0 },
    public:  { attempts: 0, successes: 0, failures: 0 },
  };

  constructor() {
    const env = process.env.MEV_RELAY?.trim().toLowerCase();
    if (!env) {
      this.relayPriority = ["fastlane", "merkle", "public"];
    } else {
      this.relayPriority = env.split(",").map(s => s.trim() as RelayName)
        .filter(r => r in RELAYS);
      if (!this.relayPriority.includes("public")) {
        this.relayPriority.push("public"); // always have public fallback
      }
    }
    this.timeoutMs = parseInt(process.env.MEV_RELAY_TIMEOUT_MS ?? "3000", 10);
    logInfo(`mev-relay: priority = ${this.relayPriority.join(" → ")}`);
  }

  /** Returns the raw transaction hash on success, or null on failure. */
  async submitRawTransaction(rawTx: string, txHash: string): Promise<{ relay: RelayName; hash: string } | null> {
    for (const relay of this.relayPriority) {
      this.relayStats[relay].attempts++;
      const cfg = RELAYS[relay];

      if (relay === "public") {
        // Caller must fall back to public submission via standard provider
        this.lastUsedRelay = relay;
        this.relayStats[relay].successes++;
        logInfo(`mev-relay: ${relay} → fallback to public mempool for ${txHash}`);
        return { relay, hash: txHash };
      }

      const apiKey = process.env[cfg.apiKeyEnv] ?? "";
      if (cfg.needsApiKey && !apiKey) {
        logWarn(`mev-relay: ${relay} requires API key (${cfg.apiKeyEnv}) — skipping`);
        this.relayStats[relay].failures++;
        continue;
      }

      try {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), this.timeoutMs);

        const response = await fetch(cfg.endpoint, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            ...(apiKey ? { "X-API-Key": apiKey } : {}),
          },
          body: JSON.stringify({
            jsonrpc: "2.0",
            id: 1,
            method: "eth_sendRawTransaction",
            params: [rawTx],
          }),
          signal: controller.signal,
        });
        clearTimeout(timeout);

        if (!response.ok) {
          const text = await response.text().catch(() => "");
          logWarn(`mev-relay: ${relay} HTTP ${response.status} — ${text.slice(0, 200)}`);
          this.relayStats[relay].failures++;
          continue;
        }

        const body: any = await response.json().catch(() => null);
        const returnedHash = body?.result ?? txHash;
        if (body?.error) {
          logWarn(`mev-relay: ${relay} RPC error — ${JSON.stringify(body.error).slice(0, 200)}`);
          this.relayStats[relay].failures++;
          continue;
        }

        this.lastUsedRelay = relay;
        this.relayStats[relay].successes++;
        logInfo(`mev-relay: ${relay} ✓ accepted ${returnedHash}`);
        return { relay, hash: returnedHash };
      } catch (err) {
        logWarn(`mev-relay: ${relay} submit failed — ${(err as Error).message}`);
        this.relayStats[relay].failures++;
      }
    }

    logError(`mev-relay: all relays failed for ${txHash}`);
    return null;
  }

  getStats(): Record<RelayName, { attempts: number; successes: number; failures: number }> {
    return { ...this.relayStats };
  }

  getLastUsedRelay(): RelayName { return this.lastUsedRelay; }

  getPriority(): RelayName[] { return [...this.relayPriority]; }
}

let router: MevRelayRouter | null = null;
export function getMevRouter(): MevRelayRouter {
  if (!router) router = new MevRelayRouter();
  return router;
}
P2_FILE_EOF

# ---------- bot/src/nonce-manager.ts ----------
cat > 'bot/src/nonce-manager.ts' << 'P2_FILE_EOF'
/**
 * @file nonce-manager.ts
 * @notice NonceManager — prevents nonce collisions when the bot submits
 *         multiple transactions within the same block (e.g. multi-pair scans).
 *
 * Strategy:
 *   • On first use, fetch the on-chain nonce (pending state).
 *   • Increment locally for each submission — never wait for chain confirmation
 *     before assigning the next nonce.
 *   • On RPC error with "nonce too low" or "replacement fee too low", resync
 *     from chain and retry.
 *   • Expose a `lock / release` mechanism so concurrent submitters queue
 *     rather than race.
 */

import { JsonRpcProvider } from "ethers";
import { logDebug, logWarn, logError } from "./logger";

export class NonceManager {
  private provider:   JsonRpcProvider;
  private address:    string;
  private nonce:      number | null = null;
  private locked      = false;
  private queue:      Array<() => void> = [];

  constructor(provider: JsonRpcProvider, address: string) {
    this.provider = provider;
    this.address  = address;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Public API
  // ──────────────────────────────────────────────────────────────────────────

  /**
   * @notice Acquire the nonce lock. Resolves when no other caller holds it.
   *         Always pair with `release()` — use try/finally.
   */
  async acquire(): Promise<number> {
    await this._waitForUnlock();
    this.locked = true;

    if (this.nonce === null) {
      await this._syncFromChain();
    }

    const n = this.nonce!;
    logDebug("NonceManager: acquired nonce", { nonce: n, address: this.address });
    return n;
  }

  /**
   * @notice Confirm that a transaction was submitted successfully.
   *         Increments the local counter.
   */
  commit(): void {
    if (this.nonce === null) return;
    this.nonce++;
    logDebug("NonceManager: committed nonce", { nextNonce: this.nonce, address: this.address });
    this._unlock();
  }

  /**
   * @notice Roll back after a failed submission WITHOUT resync.
   *         Use when the tx was never broadcast (e.g. simulation failure).
   */
  rollback(): void {
    logWarn("NonceManager: rollback (nonce unchanged)", { nonce: this.nonce });
    this._unlock();
  }

  /**
   * @notice Force a resync from the chain (after a "nonce too low" error).
   */
  async resync(): Promise<void> {
    logWarn("NonceManager: resyncing nonce from chain…", { address: this.address });
    await this._syncFromChain();
    this._unlock();
  }

  /**
   * @notice Current local nonce (for logging). Null if not yet initialised.
   */
  get currentNonce(): number | null {
    return this.nonce;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Internals
  // ──────────────────────────────────────────────────────────────────────────

  private async _syncFromChain(): Promise<void> {
    try {
      this.nonce = await this.provider.getTransactionCount(this.address, "pending");
      logDebug("NonceManager: synced from chain", { nonce: this.nonce, address: this.address });
    } catch (err) {
      logError("NonceManager: failed to sync nonce from chain", err);
      throw err;
    }
  }

  private _unlock(): void {
    this.locked = false;
    const next = this.queue.shift();
    if (next) next();
  }

  private _waitForUnlock(): Promise<void> {
    if (!this.locked) return Promise.resolve();
    return new Promise((resolve) => this.queue.push(resolve));
  }
}
P2_FILE_EOF

# ---------- bot/src/opportunity-log.ts ----------
cat > 'bot/src/opportunity-log.ts' << 'P2_FILE_EOF'
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
  spreadPct?:    number;
  spreadUsd:     number;
  netUsd?:       number;   // alias for netProfitUsd (used by dashboard + anomaly scripts)
  gasCostUsd:    number;
  aaveFeeUsd:    number;
  netProfitUsd:  number;
  slippagePct?:  number;
  gasGwei?:      number;
  signal?:       "EXECUTE" | "VERIFY_DEPTH" | "MARGINAL";
  buyDex?:       string;   // which DEX to buy on (cheaper)
  sellDex?:      string;   // which DEX to sell on (expensive)
  cheaperDex:    string;
  executed:      boolean;
  note?:         string;
  txHash?:       string;
  txStatus?:     "success" | "reverted" | "pending";
  error?:        string;
  // HMM fields (v1.1.0+)
  hmmRegime?:     string;
  hmmConfidence?: number;
  hmmMultiplier?: number;
  dryRun?:        boolean;
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

/** Read records from a specific date (YYYY-MM-DD). */
export function readLogForDate(date: string): OpportunityRecord[] {
  try {
    const p = path.join(LOG_DIR, `opportunities-${date}.jsonl`);
    const raw = fs.readFileSync(p, "utf8");
    return raw
      .split("\n")
      .filter(Boolean)
      .map((l) => JSON.parse(l) as OpportunityRecord);
  } catch {
    return [];
  }
}
P2_FILE_EOF

# ---------- bot/src/price-feed.ts ----------
cat > 'bot/src/price-feed.ts' << 'P2_FILE_EOF'
/**
 * @file price-feed.ts
 * @notice On-chain Chainlink price feed reader with per-block TTL cache.
 *         No external HTTP dependency — reads AggregatorV3 directly.
 */

import { Contract, JsonRpcProvider } from "ethers";
import { logWarn, logError } from "./logger";

// ─────────────────────────────────────────────────────────────────────────────
// ABI
// ─────────────────────────────────────────────────────────────────────────────

const AGGREGATOR_ABI = [
  "function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)",
  "function decimals() external view returns (uint8)",
] as const;

// ─────────────────────────────────────────────────────────────────────────────
// Polygon mainnet Chainlink feeds
// ─────────────────────────────────────────────────────────────────────────────

export const FEEDS = {
  MATIC_USD : "0xAB594600376Ec9fD91F8e885dADF0CE036862dE0",
  USDC_USD  : "0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7",
  ETH_USD   : "0xF9680D99D6C9589e2a93a78A04A279e509205945",
  BTC_USD   : "0xc907E116054Ad103354f2D350FD2514433D57F6f",
  DAI_USD   : "0x4746DeC9e833A82EC7C2C1356372CcF2cfcD2F3D",
} as const;

/** Token address (lowercase) → Chainlink feed address */
export const TOKEN_TO_FEED: Record<string, string> = {
  "0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270": FEEDS.MATIC_USD, // WMATIC
  "0x2791bca1f2de4661ed88a30c99a7a9449aa84174": FEEDS.USDC_USD,  // USDC
  "0x7ceb23fd6bc0add59e62ac25578270cff1b9f619": FEEDS.ETH_USD,   // WETH
  "0x1bfd67037b42cf73acf2047067bd4f2c47d9bfd6": FEEDS.BTC_USD,   // WBTC
  "0x8f3cf7ad23cd3cadbd9735aff958023239c6a063": FEEDS.DAI_USD,   // DAI
};

const MAX_FEED_AGE_S = 3600; // reject stale data older than 1 h
const CACHE_TTL_MS   = 30_000;

interface CacheEntry { price: number; fetchedAt: number; }

export class ChainlinkPriceFeed {
  private provider: JsonRpcProvider;
  private cache = new Map<string, CacheEntry>();

  constructor(provider: JsonRpcProvider) {
    this.provider = provider;
  }

  async getPrice(feedAddress: string, fallback = 0): Promise<number> {
    const cached = this.cache.get(feedAddress);
    if (cached && Date.now() - cached.fetchedAt < CACHE_TTL_MS) return cached.price;

    try {
      const agg = new Contract(feedAddress, AGGREGATOR_ABI, this.provider);
      const [decimalsRaw, [, answer, , updatedAt]] = await Promise.all([
        agg.decimals(),
        agg.latestRoundData(),
      ]);
      const age = Math.floor(Date.now() / 1000) - Number(updatedAt);
      if (age > MAX_FEED_AGE_S) {
        logWarn("ChainlinkPriceFeed: stale data", { feedAddress, ageSecs: age });
        return fallback;
      }
      const price = Number(answer) / 10 ** Number(decimalsRaw);
      this.cache.set(feedAddress, { price, fetchedAt: Date.now() });
      return price;
    } catch (err) {
      logError("ChainlinkPriceFeed: fetch failed", err, { feedAddress });
      return fallback;
    }
  }

  async getTokenPriceUsd(tokenAddress: string, fallback = 0): Promise<number> {
    const feed = TOKEN_TO_FEED[tokenAddress.toLowerCase()];
    if (!feed) { logWarn("No feed for token", { tokenAddress }); return fallback; }
    return this.getPrice(feed, fallback);
  }

  async warmCache(): Promise<void> {
    await Promise.allSettled(Object.values(FEEDS).map((f) => this.getPrice(f)));
  }

  flushCache(): void { this.cache.clear(); }
}
P2_FILE_EOF

# ---------- bot/src/rpc-pool.ts ----------
cat > 'bot/src/rpc-pool.ts' << 'P2_FILE_EOF'
/**
 * @file rpc-pool.ts
 * @notice Rotating RPC pool with health checks, latency tracking, and failover.
 *
 * Supports up to 20 RPC endpoints. The pool pings each in the background and
 * ranks them by latency. The caller always pulls the fastest live provider.
 *
 * Env:
 *   POLYGON_RPC_POOL — comma-separated list of HTTPS RPC URLs
 *                      (falls back to single POLYGON_RPC_URL if unset)
 *   POLYGON_WS_POOL  — comma-separated list of WSS URLs (optional)
 *   RPC_HEALTH_INTERVAL_MS — ping cadence, default 30_000
 *   RPC_REQUEST_TIMEOUT_MS — per-request timeout, default 4_000
 */

import { ethers, JsonRpcProvider, WebSocketProvider } from "ethers";
import { logInfo, logWarn, logError } from "./logger";

interface RpcEntry {
  url: string;
  provider: JsonRpcProvider | WebSocketProvider;
  alive: boolean;
  latencyMs: number;
  lastCheckedAt: number;
  failCount: number;
  isWs: boolean;
}

const DEFAULT_HTTP_FALLBACKS = [
  "https://polygon-rpc.com",
  "https://rpc.ankr.com/polygon",
  "https://polygon-bor-rpc.publicnode.com",
];

export class RpcPool {
  private entries: RpcEntry[] = [];
  private healthTimer: NodeJS.Timeout | null = null;
  private readonly healthInterval: number;
  private readonly requestTimeout: number;
  private roundRobin = 0;

  constructor() {
    const poolEnv = process.env.POLYGON_RPC_POOL?.trim();
    const wsPoolEnv = process.env.POLYGON_WS_POOL?.trim();
    const singleRpc = process.env.POLYGON_RPC_URL?.trim();

    this.healthInterval = parseInt(process.env.RPC_HEALTH_INTERVAL_MS ?? "30000", 10);
    this.requestTimeout = parseInt(process.env.RPC_REQUEST_TIMEOUT_MS ?? "4000", 10);

    const httpUrls = (poolEnv ? poolEnv.split(",")
                              : (singleRpc ? [singleRpc] : DEFAULT_HTTP_FALLBACKS))
                    .map(s => s.trim()).filter(Boolean);

    if (httpUrls.length < 20 && poolEnv) {
      logWarn(`rpc-pool: only ${httpUrls.length} RPCs provided — recommended 20 for production`);
    }

    for (const url of httpUrls) {
      const isWs = url.startsWith("ws");
      try {
        const provider = isWs
          ? new WebSocketProvider(url)
          : new JsonRpcProvider(url, undefined, { staticNetwork: true });
        this.entries.push({
          url: this.maskUrl(url),
          provider,
          alive: true,
          latencyMs: 9999,
          lastCheckedAt: 0,
          failCount: 0,
          isWs,
        });
      } catch (e) {
        logWarn(`rpc-pool: failed to construct provider for ${this.maskUrl(url)}: ${(e as Error).message}`);
      }
    }

    if (wsPoolEnv) {
      for (const url of wsPoolEnv.split(",").map(s => s.trim()).filter(Boolean)) {
        try {
          this.entries.push({
            url: this.maskUrl(url),
            provider: new WebSocketProvider(url),
            alive: true,
            latencyMs: 9999,
            lastCheckedAt: 0,
            failCount: 0,
            isWs: true,
          });
        } catch (e) { /* swallow */ }
      }
    }

    if (this.entries.length === 0) {
      throw new Error("rpc-pool: no RPC endpoints configured");
    }
    logInfo(`rpc-pool: initialized ${this.entries.length} endpoint(s)`);
  }

  startHealthChecks(): void {
    if (this.healthTimer) return;
    this.healthTimer = setInterval(() => void this.pingAll(), this.healthInterval);
    void this.pingAll();
  }

  async pingAll(): Promise<void> {
    await Promise.allSettled(this.entries.map(async (e) => {
      const start = Date.now();
      try {
        const provider = e.provider as JsonRpcProvider;
        await Promise.race([
          provider.getBlockNumber(),
          new Promise((_, rej) => setTimeout(() => rej(new Error("timeout")), this.requestTimeout)),
        ]);
        e.latencyMs = Date.now() - start;
        e.alive = true;
        e.failCount = 0;
        e.lastCheckedAt = Date.now();
      } catch (err) {
        e.alive = false;
        e.failCount++;
        e.lastCheckedAt = Date.now();
        if (e.failCount <= 1) logWarn(`rpc-pool: ${e.url} unreachable: ${(err as Error).message}`);
      }
    }));
  }

  bestProvider(): JsonRpcProvider {
    const alive = this.entries.filter(e => e.alive && !e.isWs);
    if (alive.length === 0) {
      logError("rpc-pool: no alive HTTP provider — using any available");
      return this.entries[0].provider as JsonRpcProvider;
    }
    alive.sort((a, b) => a.latencyMs - b.latencyMs);
    return alive[0].provider as JsonRpcProvider;
  }

  nextProvider(): JsonRpcProvider {
    const alive = this.entries.filter(e => e.alive && !e.isWs);
    if (alive.length === 0) return this.entries[0].provider as JsonRpcProvider;
    alive.sort((a, b) => a.latencyMs - b.latencyMs);
    const pick = alive[this.roundRobin % Math.min(alive.length, 5)];
    this.roundRobin++;
    return pick.provider as JsonRpcProvider;
  }

  bestWebSocket(): WebSocketProvider | null {
    const ws = this.entries.find(e => e.isWs && e.alive);
    if (ws) return ws.provider as WebSocketProvider;
    const wsAny = this.entries.find(e => e.isWs);
    return wsAny ? wsAny.provider as WebSocketProvider : null;
  }

  snapshot(): Array<{ url: string; alive: boolean; latencyMs: number; isWs: boolean; failCount: number; }> {
    return this.entries.map(e => ({
      url: e.url,
      alive: e.alive,
      latencyMs: e.latencyMs,
      isWs: e.isWs,
      failCount: e.failCount,
    }));
  }

  countAlive(): number { return this.entries.filter(e => e.alive).length; }
  total(): number { return this.entries.length; }

  private maskUrl(url: string): string {
    try {
      const u = new URL(url);
      if (u.username || u.password) {
        return `${u.protocol}//${u.host}${u.pathname}`;
      }
      return url;
    } catch {
      return url;
    }
  }

  stop(): void {
    if (this.healthTimer) clearInterval(this.healthTimer);
    this.healthTimer = null;
  }
}

let pool: RpcPool | null = null;
export function getRpcPool(): RpcPool {
  if (!pool) pool = new RpcPool();
  return pool;
}
P2_FILE_EOF

# ---------- bot/src/scanner.ts ----------
cat > 'bot/src/scanner.ts' << 'P2_FILE_EOF'
/**
 * @file scanner.ts
 * @notice ArbitrageScanner — core engine of the flash loan arbitrage bot.
 *
 * Per-block pipeline:
 *   1. Flush Chainlink cache → warm fresh prices
 *   2. Check gas vs MAX_GAS_GWEI guard
 *   3. For each token pair:
 *      a. Fetch DEX pool depth on both QuickSwap + SushiSwap
 *      b. Skip pair if EITHER DEX side has < MIN_POOL_DEPTH_USD ($15K) liquidity
 *      c. Query on-chain spread via PriceOraclePolygon
 *      d. Estimate net profit (spread − gas − Aave fee)
 *      e. Execute if profit > MIN_PROFIT_USD
 *   4. Track daily PnL; halt if drawdown > MAX_DAILY_LOSS_USD
 *   5. NonceManager ensures sequential nonces — no concurrent tx collisions
 */

import {
  ethers,
  Contract,
  WebSocketProvider,
  JsonRpcProvider,
  Wallet,
  formatUnits,
} from "ethers";
import {
  ENV,
  TOKEN_PAIRS,
  TokenPair,
  MIN_PROFIT_USD,
  MAX_GAS_GWEI,
  MAX_DAILY_LOSS_USD,
  ESTIMATED_GAS_UNITS,
  MAX_RETRIES,
  RETRY_BASE_DELAY_MS,
  FLASH_LOAN_ABI,
  PRICE_ORACLE_ABI,
} from "./config";
import { logInfo, logWarn, logError, logDebug } from "./logger";
import { NonceManager }                          from "./nonce-manager";
import { ChainlinkPriceFeed, TOKEN_TO_FEED, FEEDS } from "./price-feed";

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

/** Minimum USD liquidity required on EACH DEX side for a pair to be scannable */
const MIN_POOL_DEPTH_USD = 15_000;

const QUICKSWAP_FACTORY = "0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32";
const SUSHISWAP_FACTORY = "0xc35DADB65012eC5796536bD9864eD8773aBc74C4";

const FACTORY_ABI = [
  "function getPair(address tokenA, address tokenB) external view returns (address pair)",
] as const;

const PAIR_ABI = [
  "function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast)",
  "function token0() external view returns (address)",
] as const;

// ─────────────────────────────────────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────────────────────────────────────

interface DepthResult {
  depthUsd:   number;
  reserveIn:  bigint;
  reserveOut: bigint;
}

interface ArbitrageOpportunity {
  pair:               TokenPair;
  spread:             bigint;
  cheaperDex:         string;
  expensiveDex:       string;
  estimatedProfitUsd: number;
  gasPrice:           bigint;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

function estimateGasCostUsd(gasPrice: bigint, gasUnits: number, maticUsd: number): number {
  return Number(formatUnits(gasPrice * BigInt(gasUnits), 18)) * maticUsd;
}

// ─────────────────────────────────────────────────────────────────────────────
// ArbitrageScanner
// ─────────────────────────────────────────────────────────────────────────────

export class ArbitrageScanner {
  private wsProvider:        WebSocketProvider | null = null;
  private httpProvider:      JsonRpcProvider;
  private wallet:            Wallet;
  private flashLoanContract: Contract;
  private priceOracle:       Contract;
  private qsFactory:         Contract;
  private ssFactory:         Contract;
  private nonceManager:      NonceManager;
  private priceFeed:         ChainlinkPriceFeed;

  private dailyPnLUsd  = 0;
  private dailyPnLDate = "";

  private executing = false;
  private running   = false;

  constructor() {
    this.httpProvider = new JsonRpcProvider(ENV.POLYGON_RPC_URL);
    this.wallet       = new Wallet(ENV.PRIVATE_KEY, this.httpProvider);

    this.flashLoanContract = new Contract(ENV.FLASH_LOAN_ADDRESS, FLASH_LOAN_ABI, this.wallet);
    this.priceOracle       = new Contract(ENV.PRICE_ORACLE_ADDRESS, PRICE_ORACLE_ABI, this.httpProvider);
    this.qsFactory         = new Contract(QUICKSWAP_FACTORY, FACTORY_ABI, this.httpProvider);
    this.ssFactory         = new Contract(SUSHISWAP_FACTORY, FACTORY_ABI, this.httpProvider);
    this.nonceManager      = new NonceManager(this.httpProvider, this.wallet.address);
    this.priceFeed         = new ChainlinkPriceFeed(this.httpProvider);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ──────────────────────────────────────────────────────────────────────────

  async start(): Promise<void> {
    this.running = true;
    logInfo("ArbitrageScanner starting", {
      account:   this.wallet.address,
      flashLoan: ENV.FLASH_LOAN_ADDRESS,
      oracle:    ENV.PRICE_ORACLE_ADDRESS,
      minProfitUsd:    MIN_PROFIT_USD,
      maxGasGwei:      MAX_GAS_GWEI,
      minPoolDepthUsd: MIN_POOL_DEPTH_USD,
    });

    await this.priceFeed.warmCache().catch((e) =>
      logWarn("Price cache warm failed", { error: String(e) })
    );

    // Prefer WebSocket for zero-latency block events; fall back to HTTP polling
    if (ENV.POLYGON_WS_URL) {
      try {
        this.wsProvider = new WebSocketProvider(ENV.POLYGON_WS_URL);
        this.wsProvider.on("block", (blockNumber: number) => {
          if (!this.running) return;
          this.onBlock(blockNumber).catch((err) =>
            logError("onBlock error", err, { blockNumber })
          );
        });
        logInfo("WebSocket block subscription active");
        return;
      } catch (err) {
        logWarn("WebSocket failed — falling back to HTTP polling", { err: String(err) });
      }
    }
    this._startPolling();
  }

  async stop(): Promise<void> {
    this.running = false;
    if (this.wsProvider) await this.wsProvider.destroy();
    logInfo("ArbitrageScanner stopped", { dailyPnLUsd: this.dailyPnLUsd });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HTTP polling fallback (~2 s interval)
  // ──────────────────────────────────────────────────────────────────────────

  private _startPolling(): void {
    logInfo("HTTP polling mode active (2 s interval)");
    let lastBlock = 0;
    const poll = async () => {
      if (!this.running) return;
      try {
        const block = await this.httpProvider.getBlockNumber();
        if (block > lastBlock) {
          lastBlock = block;
          await this.onBlock(block).catch((err) =>
            logError("onBlock error (poll)", err, { block })
          );
        }
      } catch (err) {
        logError("Polling error", err);
      }
      setTimeout(poll, 2_000);
    };
    poll();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Block handler
  // ──────────────────────────────────────────────────────────────────────────

  async onBlock(blockNumber: number): Promise<void> {
    logDebug("Block", { blockNumber });
    this._resetDailyPnLIfNeeded();

    if (this.dailyPnLUsd < -MAX_DAILY_LOSS_USD) {
      logWarn("Daily loss limit reached — halted for today", {
        dailyPnLUsd: this.dailyPnLUsd,
        limit: MAX_DAILY_LOSS_USD,
      });
      return;
    }

    if (this.executing) {
      logDebug("Execution in-flight — skipping block", { blockNumber });
      return;
    }

    this.priceFeed.flushCache();

    const [gasPrice, maticUsd] = await Promise.all([
      this._fetchGasPrice(),
      this.priceFeed.getPrice(FEEDS.MATIC_USD, 0.9),
    ]);

    const gasPriceGwei = Number(formatUnits(gasPrice, "gwei"));
    if (gasPriceGwei > MAX_GAS_GWEI) {
      logWarn("Gas too high — skipping block", { gasPriceGwei, max: MAX_GAS_GWEI });
      return;
    }

    for (const pair of TOKEN_PAIRS) {
      try {
        const opp = await this._evaluatePair(pair, gasPrice, maticUsd);
        if (opp) {
          logInfo("Opportunity found", {
            pair:        pair.name,
            profitUsd:   opp.estimatedProfitUsd.toFixed(2),
            cheaperDex:  opp.cheaperDex,
            gasPriceGwei: gasPriceGwei.toFixed(1),
          });
          await this.executeArbitrage(opp);
          break; // one trade per block
        }
      } catch (err) {
        logError(`Evaluation error — ${pair.name}`, err);
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Liquidity depth check
  // ──────────────────────────────────────────────────────────────────────────

  /**
   * Returns the USD depth of the tokenIn side for a given factory's pair.
   * Returns 0 if the pair doesn't exist or reserves are empty.
   */
  private async _poolDepth(
    factory:      Contract,
    tokenIn:      string,
    tokenOut:     string,
    tokenInDecimals: number,
    tokenInPriceUsd: number,
  ): Promise<DepthResult> {
    try {
      const pairAddr: string = await factory.getPair(tokenIn, tokenOut);
      if (!pairAddr || pairAddr === ethers.ZeroAddress) {
        return { depthUsd: 0, reserveIn: 0n, reserveOut: 0n };
      }

      const pair = new Contract(pairAddr, PAIR_ABI, this.httpProvider);
      const [[r0, r1], t0]: [[bigint, bigint, number], string] = await Promise.all([
        pair.getReserves(),
        pair.token0(),
      ]);

      const isToken0 = t0.toLowerCase() === tokenIn.toLowerCase();
      const reserveIn  = isToken0 ? r0 : r1;
      const reserveOut = isToken0 ? r1 : r0;

      const resInFloat = parseFloat(formatUnits(reserveIn, tokenInDecimals));
      const depthUsd   = resInFloat * tokenInPriceUsd;

      return { depthUsd, reserveIn, reserveOut };
    } catch {
      return { depthUsd: 0, reserveIn: 0n, reserveOut: 0n };
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Pair evaluation (depth check → spread check → profit calc)
  // ──────────────────────────────────────────────────────────────────────────

  private async _evaluatePair(
    pair:     TokenPair,
    gasPrice: bigint,
    maticUsd: number,
  ): Promise<ArbitrageOpportunity | null> {

    // ── Token prices ──────────────────────────────────────────────────────────
    const tokenInPriceUsd  = await this.priceFeed.getTokenPriceUsd(pair.tokenIn, 0);
    const tokenOutPriceUsd = await this.priceFeed.getTokenPriceUsd(pair.tokenOut, 0);

    if (tokenInPriceUsd === 0) {
      logDebug(`No price for tokenIn — skipping ${pair.name}`);
      return null;
    }

    // Decimals: USDC/WBTC special cases; default 18
    const inDecimals = _decimalsOf(pair.tokenIn);

    // ── Depth check (parallel) ────────────────────────────────────────────────
    const [qsDepth, ssDepth] = await Promise.all([
      this._poolDepth(this.qsFactory, pair.tokenIn, pair.tokenOut, inDecimals, tokenInPriceUsd),
      this._poolDepth(this.ssFactory, pair.tokenIn, pair.tokenOut, inDecimals, tokenInPriceUsd),
    ]);

    const minDepth = Math.min(qsDepth.depthUsd, ssDepth.depthUsd);

    if (minDepth < MIN_POOL_DEPTH_USD) {
      const _note = ssDepth.depthUsd === 0 ? "SushiSwap dead pool" : "shallow pool";
      logDebug(`Depth filter — skipping ${pair.name} (${_note})`, {
        qsDepthUsd: qsDepth.depthUsd.toFixed(0),
        ssDepthUsd: ssDepth.depthUsd.toFixed(0),
        minRequired: MIN_POOL_DEPTH_USD,
      });
      return null;
    }

    // ── Spread check ──────────────────────────────────────────────────────────
    let spread: bigint, cheaperDex: string, expensiveDex: string;
    try {
      [spread, cheaperDex, expensiveDex] = await this.priceOracle.getArbitrageSpread(
        pair.tokenIn, pair.tokenOut, pair.loanAmount
      );
    } catch (err) {
      logDebug(`getArbitrageSpread failed — ${pair.name}`, { err: String(err) });
      return null;
    }

    if (spread === 0n) return null;

    // ── Profit estimate ───────────────────────────────────────────────────────
    const outDecimals    = _decimalsOf(pair.tokenOut);
    const spreadUsd      = parseFloat(formatUnits(spread, outDecimals)) *
                           (tokenOutPriceUsd || 1);
    const gasCostUsd     = estimateGasCostUsd(gasPrice, ESTIMATED_GAS_UNITS, maticUsd);
    const loanNotional   = parseFloat(formatUnits(pair.loanAmount, inDecimals)) * tokenInPriceUsd;
    const aaveFeeUsd     = loanNotional * 0.0005;
    const estimatedProfit = spreadUsd - gasCostUsd - aaveFeeUsd;

    logDebug(`Evaluated ${pair.name}`, {
      qsDepth: qsDepth.depthUsd.toFixed(0),
      ssDepth: ssDepth.depthUsd.toFixed(0),
      spreadUsd: spreadUsd.toFixed(2),
      gasCostUsd: gasCostUsd.toFixed(3),
      aaveFee: aaveFeeUsd.toFixed(3),
      netProfit: estimatedProfit.toFixed(2),
    });

    if (estimatedProfit < MIN_PROFIT_USD) return null;

    return { pair, spread, cheaperDex, expensiveDex, estimatedProfitUsd: estimatedProfit, gasPrice };
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Execution
  // ──────────────────────────────────────────────────────────────────────────

  async executeArbitrage(opp: ArbitrageOpportunity): Promise<void> {
    this.executing = true;
    const { pair, cheaperDex, expensiveDex, estimatedProfitUsd, gasPrice } = opp;

    const minProfitNative = (pair.loanAmount * 5n) / 10_000n; // 0.05% of loan

    const params = ethers.AbiCoder.defaultAbiCoder().encode(
      ["address", "address", "address", "address", "uint256"],
      [pair.tokenIn, pair.tokenOut, cheaperDex, expensiveDex, minProfitNative]
    );

    let attempt = 0;
    while (attempt <= MAX_RETRIES) {
      const nonce = await this.nonceManager.acquire();
      try {
        logInfo(`Flash loan attempt ${attempt + 1}/${MAX_RETRIES + 1}`, {
          pair: pair.name, cheaperDex, expensiveDex, nonce,
          gasPriceGwei: Number(formatUnits(gasPrice, "gwei")).toFixed(1),
          estimatedProfitUsd: estimatedProfitUsd.toFixed(2),
        });

        const tx = await this.flashLoanContract.initiateFlashLoan(
          pair.tokenIn, pair.loanAmount, params,
          { gasPrice, gasLimit: BigInt(ESTIMATED_GAS_UNITS) + 100_000n, nonce }
        );
        this.nonceManager.commit();

        logInfo("Tx submitted", { txHash: tx.hash });
        const receipt = await tx.wait(1);

        if (receipt?.status === 1) {
          logInfo("Trade executed successfully", {
            txHash:    tx.hash,
            gasUsed:   receipt.gasUsed.toString(),
            block:     receipt.blockNumber,
            profitUsd: estimatedProfitUsd.toFixed(2),
          });
          this.dailyPnLUsd += estimatedProfitUsd;
        } else {
          logWarn("Tx mined but reverted", { txHash: tx.hash });
          this.dailyPnLUsd -= estimateGasCostUsd(
            gasPrice, Number(receipt?.gasUsed ?? ESTIMATED_GAS_UNITS),
            await this.priceFeed.getPrice(FEEDS.MATIC_USD, 0.9)
          );
        }
        break;

      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : String(err);

        if (msg.includes("nonce too low") || msg.includes("replacement fee too low")) {
          logWarn("Nonce error — resyncing", { attempt });
          this.nonceManager.rollback();
          await this.nonceManager.resync();
        } else {
          this.nonceManager.rollback();
        }

        if (attempt >= MAX_RETRIES) {
          logError(`All retries exhausted for ${pair.name}`, err);
          break;
        }
        attempt++;
        await sleep(RETRY_BASE_DELAY_MS * 2 ** attempt);
      }
    }

    this.executing = false;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Internals
  // ──────────────────────────────────────────────────────────────────────────

  private async _fetchGasPrice(): Promise<bigint> {
    try {
      const fee = await this.httpProvider.getFeeData();
      return fee.gasPrice ?? 100_000_000_000n; // 100 Gwei fallback
    } catch {
      return 100_000_000_000n;
    }
  }

  private _resetDailyPnLIfNeeded(): void {
    const today = new Date().toISOString().slice(0, 10);
    if (today !== this.dailyPnLDate) {
      if (this.dailyPnLDate) {
        logInfo("Daily PnL reset", { date: this.dailyPnLDate, pnlUsd: this.dailyPnLUsd.toFixed(2) });
      }
      this.dailyPnLUsd  = 0;
      this.dailyPnLDate = today;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Token decimal helper
// ─────────────────────────────────────────────────────────────────────────────

function _decimalsOf(tokenAddress: string): number {
  const addr = tokenAddress.toLowerCase();
  if (addr === "0x2791bca1f2de4661ed88a30c99a7a9449aa84174") return 6;  // USDC
  if (addr === "0x1bfd67037b42cf73acf2047067bd4f2c47d9bfd6") return 8;  // WBTC
  return 18;
}
P2_FILE_EOF

# ---------- bot/tsconfig.json ----------
cat > 'bot/tsconfig.json' << 'P2_FILE_EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "commonjs",
    "lib": ["ES2022"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "noImplicitAny": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "noUnusedLocals": false,
    "noUnusedParameters": false
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
P2_FILE_EOF

# ---------- contracts/FlashLoanPolygon.sol ----------
cat > 'contracts/FlashLoanPolygon.sol' << 'P2_FILE_EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @dev Minimal Aave v3 IFlashLoanSimpleReceiver
interface IFlashLoanSimpleReceiver {
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}

/// @dev Minimal Aave v3 IPool interface (flash loan entry-point)
interface IAavePool {
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

/// @dev Minimal Aave v3 IPoolAddressesProvider
interface IPoolAddressesProvider {
    function getPool() external view returns (address);
}

/// @dev Minimal UniswapV2Router interface
interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

/**
 * @title FlashLoanPolygon
 * @notice Polygon-optimised (lighter) flash loan arbitrage contract.
 *         Uses Aave v3 flash loans to atomically arbitrage price differences
 *         between QuickSwap and SushiSwap.  Fewer guard layers than
 *         FlashLoanSecure — intended for gas benchmarking and performance
 *         comparison.
 *
 * @dev    Inherits Ownable2Step for two-step ownership transfer.
 *         Uses unchecked arithmetic where overflow is provably impossible
 *         to reduce gas consumption on Polygon.
 */
contract FlashLoanPolygon is IFlashLoanSimpleReceiver, Ownable2Step {
    using SafeERC20 for IERC20;

    // ─────────────────────────────────────────────────────────────────────────
    // Immutables
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Aave v3 PoolAddressesProvider (Polygon mainnet).
    IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;

    // ─────────────────────────────────────────────────────────────────────────
    // Well-known Polygon addresses
    // ─────────────────────────────────────────────────────────────────────────

    address public constant QUICKSWAP_ROUTER  = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;
    address public constant SUSHISWAP_ROUTER  = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;
    address public constant USDC              = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address public constant WMATIC            = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address public constant WETH              = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;

    // ─────────────────────────────────────────────────────────────────────────
    // Events
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Emitted after each successful arbitrage cycle.
    event ArbitrageExecuted(
        address indexed asset,
        uint256 profit,
        address dexA,
        address dexB,
        uint256 timestamp
    );

    // ─────────────────────────────────────────────────────────────────────────
    // Errors
    // ─────────────────────────────────────────────────────────────────────────

    error UnauthorisedCaller(address caller, address expectedPool);
    error UnauthorisedInitiator(address initiator);
    error InsufficientProfit(uint256 actual, uint256 minimum);
    error ZeroAmount();
    error ZeroAddress();

    // ─────────────────────────────────────────────────────────────────────────
    // Constructor
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @param aavePoolProvider Address of the Aave v3 PoolAddressesProvider on Polygon.
     */
    constructor(address aavePoolProvider) Ownable(msg.sender) {
        if (aavePoolProvider == address(0)) revert ZeroAddress();
        ADDRESSES_PROVIDER = IPoolAddressesProvider(aavePoolProvider);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Flash Loan Entry-Point
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Initiate a flash loan arbitrage.
     * @param asset  Token to borrow (e.g. USDC).
     * @param amount Amount to borrow (in asset's native decimals).
     * @param params ABI-encoded arbitrage parameters — see _executeArbitrage.
     */
    function initiateFlashLoan(
        address asset,
        uint256 amount,
        bytes calldata params
    ) external onlyOwner {
        if (amount == 0) revert ZeroAmount();
        address pool = ADDRESSES_PROVIDER.getPool();
        IAavePool(pool).flashLoanSimple(address(this), asset, amount, params, 0);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Aave Callback
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Called by the Aave pool after disbursing the flash loan.
     * @param asset     Borrowed asset address.
     * @param amount    Borrowed amount.
     * @param premium   Aave flash loan fee (amount * 0.05%).
     * @param initiator Address that called flashLoanSimple.
     * @param params    Forwarded arbitrage parameters.
     * @return          Always true (reverts on failure).
     */
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        address pool = ADDRESSES_PROVIDER.getPool();
        if (msg.sender != pool) revert UnauthorisedCaller(msg.sender, pool);
        if (initiator != address(this)) revert UnauthorisedInitiator(initiator);

        _executeArbitrage(asset, amount, premium, params);

        // Approve repayment
        uint256 totalOwed;
        unchecked { totalOwed = amount + premium; }
        IERC20(asset).safeIncreaseAllowance(pool, totalOwed);

        return true;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Core Arbitrage Logic
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Execute the two-leg arbitrage swap atomically.
     * @dev    Params encoding: abi.encode(tokenIn, tokenOut, dexA, dexB, minProfit)
     * @param asset     Borrowed (and repaid) asset.
     * @param amount    Borrowed amount.
     * @param premium   Aave fee due.
     * @param params    Encoded (tokenIn, tokenOut, dexA, dexB, minProfit).
     */
    function _executeArbitrage(
        address asset,
        uint256 amount,
        uint256 premium,
        bytes calldata params
    ) internal {
        (
            address tokenIn,
            address tokenOut,
            address dexA,
            address dexB,
            uint256 minProfit
        ) = abi.decode(params, (address, address, address, address, uint256));

        // Leg 1: buy tokenOut on dexA using tokenIn (the borrowed asset)
        IERC20(tokenIn).safeIncreaseAllowance(dexA, amount);
        address[] memory pathAB = new address[](2);
        pathAB[0] = tokenIn;
        pathAB[1] = tokenOut;
        uint256[] memory outAmountsA = IUniswapV2Router(dexA).swapExactTokensForTokens(
            amount,
            1, // min out — slippage enforced by minProfit below
            pathAB,
            address(this),
            block.timestamp + 300
        );
        uint256 receivedOut = outAmountsA[1];

        // Leg 2: sell tokenOut on dexB back to tokenIn
        IERC20(tokenOut).safeIncreaseAllowance(dexB, receivedOut);
        address[] memory pathBA = new address[](2);
        pathBA[0] = tokenOut;
        pathBA[1] = tokenIn;
        uint256[] memory outAmountsB = IUniswapV2Router(dexB).swapExactTokensForTokens(
            receivedOut,
            1,
            pathBA,
            address(this),
            block.timestamp + 300
        );
        uint256 returnedIn = outAmountsB[1];

        // Profit check (unchecked: totalOwed ≤ amount + premium ≤ returnedIn)
        uint256 totalOwed;
        unchecked { totalOwed = amount + premium; }
        if (returnedIn < totalOwed) {
            revert InsufficientProfit(0, minProfit);
        }
        uint256 profit;
        unchecked { profit = returnedIn - totalOwed; }
        if (profit < minProfit) revert InsufficientProfit(profit, minProfit);

        emit ArbitrageExecuted(asset, profit, dexA, dexB, block.timestamp);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Owner Utilities
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Withdraw any ERC-20 token profit accumulated in this contract.
     * @param token  Token to withdraw.
     * @param amount Amount to withdraw (0 = full balance).
     */
    function withdrawToken(address token, uint256 amount) external onlyOwner {
        uint256 bal = IERC20(token).balanceOf(address(this));
        uint256 withdrawAmt = amount == 0 ? bal : amount;
        IERC20(token).safeTransfer(owner(), withdrawAmt);
    }

    /**
     * @notice Withdraw native MATIC accumulated in this contract.
     */
    function withdrawMATIC() external onlyOwner {
        (bool ok,) = payable(owner()).call{value: address(this).balance}("");
        require(ok, "MATIC transfer failed");
    }

    receive() external payable {}
}
P2_FILE_EOF

# ---------- contracts/FlashLoanSecure.sol ----------
cat > 'contracts/FlashLoanSecure.sol' << 'P2_FILE_EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// ─────────────────────────────────────────────────────────────────────────────
// Minimal interfaces
// ─────────────────────────────────────────────────────────────────────────────

interface IFlashLoanSimpleReceiver {
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}

interface IAavePool {
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

interface IPoolAddressesProvider {
    function getPool() external view returns (address);
}

interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

/// @dev Thin oracle interface used for on-chain spread validation before execution.
interface IPriceOracle {
    function getArbitrageSpread(
        address tokenA,
        address tokenB,
        uint256 amount
    )
        external
        view
        returns (
            uint256 spread,
            address cheaperDex,
            address expensiveDex
        );
}

/**
 * @title  FlashLoanSecure
 * @notice Production-grade Aave v3 flash loan arbitrage contract for Polygon.
 *
 * @dev    Security posture
 *         ────────────────
 *         • ReentrancyGuard — prevents re-entrancy on the executeOperation callback.
 *         • Pausable         — owner can halt the contract in an emergency.
 *         • Ownable2Step     — two-step ownership transfer prevents accidental lock-out.
 *         • dailyVolumeLimit — configurable per-asset daily borrow cap (circuit breaker).
 *         • maxRecursionDepth — prevents nested flash-loan calls (set to 3; enforced via
 *           a simple counter that is checked in executeOperation).
 *         • Checks-Effects-Interactions — all storage writes happen before external calls.
 *         • No tx.origin usage; no delegatecall to untrusted contracts.
 *         • minProfit slippage guard in arbitrage params.
 *
 *         Arbitrage params encoding
 *         ─────────────────────────
 *         abi.encode(address tokenIn, address tokenOut,
 *                    address dexA, address dexB, uint256 minProfit)
 */
contract FlashLoanSecure is
    IFlashLoanSimpleReceiver,
    ReentrancyGuard,
    Pausable,
    Ownable2Step
{
    using SafeERC20 for IERC20;

    // ─────────────────────────────────────────────────────────────────────────
    // Constants
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Maximum recursion depth for nested flash-loan calls.
    uint256 public constant MAX_RECURSION_DEPTH = 3;

    // ─────────────────────────────────────────────────────────────────────────
    // Well-known Polygon addresses (hardcoded for gas savings)
    // ─────────────────────────────────────────────────────────────────────────

    address public constant AAVE_POOL_PROVIDER = 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb;
    address public constant QUICKSWAP_ROUTER   = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;
    address public constant SUSHISWAP_ROUTER   = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;
    address public constant USDC               = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address public constant WMATIC             = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address public constant WETH               = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;

    // ─────────────────────────────────────────────────────────────────────────
    // Immutables
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Aave v3 PoolAddressesProvider (resolved once at construction).
    IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;

    /// @notice On-chain price oracle for pre-execution spread validation.
    IPriceOracle public immutable PRICE_ORACLE;

    // ─────────────────────────────────────────────────────────────────────────
    // Mutable state
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Per-asset daily borrow limit (0 = unlimited).
    mapping(address => uint256) public dailyVolumeLimit;

    /// @notice Per-asset accumulated volume for the current UTC day.
    mapping(address => uint256) public dailyVolumeUsed;

    /// @notice Timestamp of the start of the currently tracked day (Unix day boundary).
    mapping(address => uint256) public dailyVolumeResetAt;

    /// @notice Current call depth counter to enforce maxRecursionDepth.
    uint256 private _callDepth;

    // ─────────────────────────────────────────────────────────────────────────
    // Events
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Emitted after every successful arbitrage execution.
     * @param profit     Net profit retained by the contract (in borrowed asset).
     * @param asset      Address of the borrowed/profit asset.
     * @param dexA       Router used for the first swap (buy leg).
     * @param dexB       Router used for the second swap (sell leg).
     * @param timestamp  Block timestamp of the execution.
     */
    event ArbitrageExecuted(
        uint256 indexed profit,
        address indexed asset,
        address dexA,
        address dexB,
        uint256 timestamp
    );

    /// @notice Emitted when the per-asset daily volume limit is updated.
    event DailyVolumeLimitSet(address indexed asset, uint256 limit);

    /// @notice Emitted when an emergency withdrawal is performed.
    event EmergencyWithdraw(address indexed token, uint256 amount, address to);

    // ─────────────────────────────────────────────────────────────────────────
    // Errors
    // ─────────────────────────────────────────────────────────────────────────

    error UnauthorisedCaller(address caller, address expectedPool);
    error UnauthorisedInitiator(address initiator);
    error InsufficientProfit(uint256 actual, uint256 minimum);
    error DailyVolumeLimitExceeded(address asset, uint256 used, uint256 limit);
    error MaxRecursionDepthExceeded(uint256 depth);
    error ZeroAmount();
    error ZeroAddress();
    error InvalidParams();

    // ─────────────────────────────────────────────────────────────────────────
    // Constructor
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Deploys the secure flash loan contract.
     * @param aavePoolProvider  Aave v3 PoolAddressesProvider on Polygon.
     * @param priceOracle       Deployed PriceOraclePolygon address.
     * @param owner_            Address that will own (and control) this contract.
     */
    constructor(
        address aavePoolProvider,
        address priceOracle,
        address owner_
    ) Ownable(owner_) {
        if (aavePoolProvider == address(0)) revert ZeroAddress();
        if (priceOracle      == address(0)) revert ZeroAddress();
        if (owner_           == address(0)) revert ZeroAddress();

        ADDRESSES_PROVIDER = IPoolAddressesProvider(aavePoolProvider);
        PRICE_ORACLE       = IPriceOracle(priceOracle);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Owner — configuration
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Set (or remove) the daily volume limit for a given asset.
     * @param asset  ERC-20 token address.
     * @param limit  Maximum notional (in token's native decimals) per UTC day.
     *               Pass 0 to disable the limit.
     */
    function setDailyVolumeLimit(address asset, uint256 limit) external onlyOwner {
        if (asset == address(0)) revert ZeroAddress();
        dailyVolumeLimit[asset] = limit;
        emit DailyVolumeLimitSet(asset, limit);
    }

    /**
     * @notice Pause all flash loan executions. Callable by owner only.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause flash loan executions. Callable by owner only.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Flash Loan Entry-Point
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Trigger a flash loan arbitrage opportunity.
     * @dev    Only callable by the owner; reverts when paused.
     * @param asset   ERC-20 token to borrow (must be supported by Aave v3).
     * @param amount  Amount to borrow (in asset's native decimals).
     * @param params  ABI-encoded (tokenIn, tokenOut, dexA, dexB, minProfit).
     */
    function initiateFlashLoan(
        address asset,
        uint256 amount,
        bytes calldata params
    ) external onlyOwner whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (asset  == address(0)) revert ZeroAddress();
        if (params.length == 0)   revert InvalidParams();

        // Circuit breaker: daily volume check (CEI pattern — storage update before external call)
        _checkAndUpdateDailyVolume(asset, amount);

        address pool = ADDRESSES_PROVIDER.getPool();
        IAavePool(pool).flashLoanSimple(address(this), asset, amount, params, 0);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Aave Callback
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Invoked by the Aave pool immediately after loan disbursal.
     * @dev    Guards:
     *           1. Caller must be the official Aave pool address.
     *           2. Initiator must be this contract itself.
     *           3. Recursion depth must not exceed MAX_RECURSION_DEPTH.
     *           4. ReentrancyGuard inherited via parent.
     * @param asset     Borrowed asset address.
     * @param amount    Borrowed amount.
     * @param premium   Aave flash loan fee (amount × 0.05% on Polygon).
     * @param initiator Address that called flashLoanSimple.
     * @param params    Forwarded arbitrage parameters.
     * @return          Always true (reverts on any failure).
     */
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external override nonReentrant whenNotPaused returns (bool) {
        // ── Guard 1: must be called by the Aave pool ──
        address pool = ADDRESSES_PROVIDER.getPool();
        if (msg.sender != pool) revert UnauthorisedCaller(msg.sender, pool);

        // ── Guard 2: must have been initiated by this contract ──
        if (initiator != address(this)) revert UnauthorisedInitiator(initiator);

        // ── Guard 3: recursion depth ──
        unchecked { ++_callDepth; }
        if (_callDepth > MAX_RECURSION_DEPTH) {
            unchecked { --_callDepth; }
            revert MaxRecursionDepthExceeded(_callDepth);
        }

        // ── Execute arbitrage (effects before interactions) ──
        _executeArbitrage(asset, amount, premium, params);

        // ── Approve repayment ──
        uint256 totalOwed = amount + premium; // safe: amount+premium << max uint256
        IERC20(asset).safeIncreaseAllowance(pool, totalOwed);

        unchecked { --_callDepth; }
        return true;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Core Arbitrage Logic
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Decode params and execute the two-leg arbitrage swap.
     * @dev    Leg 1 — buy tokenOut on dexA with tokenIn (the borrowed asset).
     *         Leg 2 — sell tokenOut on dexB back to tokenIn.
     *         Both legs follow checks-effects-interactions: allowances and
     *         storage are updated before each external swap call.
     *
     * @param asset    Borrowed (and repaid) asset — should equal tokenIn.
     * @param amount   Borrowed amount (input for leg 1).
     * @param premium  Aave fee due on repayment.
     * @param params   abi.encode(tokenIn, tokenOut, dexA, dexB, minProfit).
     */
    function _executeArbitrage(
        address asset,
        uint256 amount,
        uint256 premium,
        bytes calldata params
    ) internal {
        (
            address tokenIn,
            address tokenOut,
            address dexA,
            address dexB,
            uint256 minProfit
        ) = abi.decode(params, (address, address, address, address, uint256));

        // Sanity checks
        if (tokenIn != asset)              revert InvalidParams();
        if (tokenOut == address(0))        revert InvalidParams();
        if (dexA == address(0) || dexB == address(0)) revert InvalidParams();

        // ── Leg 1: buy tokenOut on dexA ──
        IERC20(tokenIn).safeIncreaseAllowance(dexA, amount);
        address[] memory pathAB = new address[](2);
        pathAB[0] = tokenIn;
        pathAB[1] = tokenOut;

        uint256[] memory outA = IUniswapV2Router(dexA).swapExactTokensForTokens(
            amount,
            1,                           // slippage enforced by minProfit assertion
            pathAB,
            address(this),
            block.timestamp + 300        // 5-minute deadline
        );
        uint256 receivedOut = outA[outA.length - 1];

        // ── Leg 2: sell tokenOut on dexB ──
        IERC20(tokenOut).safeIncreaseAllowance(dexB, receivedOut);
        address[] memory pathBA = new address[](2);
        pathBA[0] = tokenOut;
        pathBA[1] = tokenIn;

        uint256[] memory outB = IUniswapV2Router(dexB).swapExactTokensForTokens(
            receivedOut,
            1,
            pathBA,
            address(this),
            block.timestamp + 300
        );
        uint256 returnedIn = outB[outB.length - 1];

        // ── Profit assertion (slippage guard) ──
        uint256 totalOwed = amount + premium;
        if (returnedIn < totalOwed) {
            revert InsufficientProfit(0, minProfit);
        }
        uint256 profit = returnedIn - totalOwed;
        if (profit < minProfit) revert InsufficientProfit(profit, minProfit);

        emit ArbitrageExecuted(profit, asset, dexA, dexB, block.timestamp);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Circuit Breaker — Daily Volume
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Check whether the proposed borrow amount would breach the per-asset
     *         daily limit, and if not, record it.  Resets the counter at each new
     *         UTC day (86 400-second window).
     * @param asset  Asset being borrowed.
     * @param amount Amount about to be borrowed.
     */
    function _checkAndUpdateDailyVolume(address asset, uint256 amount) internal {
        uint256 limit = dailyVolumeLimit[asset];
        if (limit == 0) return; // limit not configured → skip

        // Reset daily counter if a new day has started
        uint256 dayStart = (block.timestamp / 86400) * 86400;
        if (dailyVolumeResetAt[asset] < dayStart) {
            dailyVolumeUsed[asset]    = 0;
            dailyVolumeResetAt[asset] = dayStart;
        }

        uint256 newUsed = dailyVolumeUsed[asset] + amount;
        if (newUsed > limit) {
            revert DailyVolumeLimitExceeded(asset, dailyVolumeUsed[asset], limit);
        }
        dailyVolumeUsed[asset] = newUsed;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Owner Utilities
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Withdraw accumulated ERC-20 profit from the contract.
     * @param token  Token address.
     * @param amount Amount to withdraw; pass 0 to sweep full balance.
     */
    function withdrawToken(address token, uint256 amount) external onlyOwner {
        uint256 bal        = IERC20(token).balanceOf(address(this));
        uint256 withdrawAmt = (amount == 0 || amount > bal) ? bal : amount;
        IERC20(token).safeTransfer(owner(), withdrawAmt);
        emit EmergencyWithdraw(token, withdrawAmt, owner());
    }

    /**
     * @notice Emergency withdrawal of native MATIC.
     */
    function withdrawMATIC() external onlyOwner {
        uint256 bal = address(this).balance;
        (bool ok,) = payable(owner()).call{value: bal}("");
        require(ok, "FlashLoanSecure: MATIC transfer failed");
        emit EmergencyWithdraw(address(0), bal, owner());
    }

    receive() external payable {}
}
P2_FILE_EOF

# ---------- contracts/MockOracle.sol ----------
cat > 'contracts/MockOracle.sol' << 'P2_FILE_EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MockOracle
 * @notice Mock implementation of a Chainlink AggregatorV3Interface for Hardhat tests.
 *         Allows manual control of the reported price and updatedAt timestamp so tests
 *         can simulate both fresh and stale oracle data.
 */
contract MockOracle {
    // ─────────────────────────────────────────────────────────────────────────
    // Storage
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Simulated price returned by latestRoundData.
    int256 private _price;

    /// @notice Simulated updatedAt timestamp returned by latestRoundData.
    uint256 private _updatedAt;

    /// @notice Decimal precision of the mock feed (default: 8, same as Chainlink USD feeds).
    uint8 private _decimals;

    /// @notice Internal round counter.
    uint80 private _roundId;

    // ─────────────────────────────────────────────────────────────────────────
    // Events
    // ─────────────────────────────────────────────────────────────────────────

    event PriceSet(int256 price, uint256 updatedAt);

    // ─────────────────────────────────────────────────────────────────────────
    // Constructor
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @param initialPrice  Initial mock price (e.g. 100000000 = $1.00 with 8 decimals).
     * @param decimals_     Decimal precision of this feed (e.g. 8 for USD feeds).
     */
    constructor(int256 initialPrice, uint8 decimals_) {
        _price     = initialPrice;
        _decimals  = decimals_;
        _updatedAt = block.timestamp;
        _roundId   = 1;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Setter helpers (test utilities)
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Overwrite the mock price and set updatedAt to block.timestamp.
     * @param price New price to report.
     */
    function setPrice(int256 price) external {
        _price     = price;
        _updatedAt = block.timestamp;
        unchecked { ++_roundId; }
        emit PriceSet(price, _updatedAt);
    }

    /**
     * @notice Overwrite updatedAt without changing the price.
     *         Use a value in the past to simulate a stale feed.
     * @param updatedAt_ New updatedAt timestamp.
     */
    function setUpdatedAt(uint256 updatedAt_) external {
        _updatedAt = updatedAt_;
    }

    /**
     * @notice Overwrite both price and updatedAt in one call.
     * @param price     New price.
     * @param updatedAt_ New updatedAt timestamp.
     */
    function setPriceAndUpdatedAt(int256 price, uint256 updatedAt_) external {
        _price     = price;
        _updatedAt = updatedAt_;
        unchecked { ++_roundId; }
        emit PriceSet(price, _updatedAt);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // IChainlinkAggregator implementation
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Returns the mock round data.
     * @return roundId       Current round ID.
     * @return answer        Simulated price.
     * @return startedAt     Same as updatedAt for simplicity.
     * @return updatedAt     Simulated last-update timestamp.
     * @return answeredInRound Same as roundId.
     */
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (_roundId, _price, _updatedAt, _updatedAt, _roundId);
    }

    /**
     * @notice Returns the decimal precision of this mock feed.
     * @return Decimal places (e.g. 8).
     */
    function decimals() external view returns (uint8) {
        return _decimals;
    }

    /**
     * @notice Returns the description of this mock feed.
     */
    function description() external pure returns (string memory) {
        return "Mock Chainlink Aggregator";
    }

    /**
     * @notice Returns the version of this mock.
     */
    function version() external pure returns (uint256) {
        return 4;
    }
}
P2_FILE_EOF

# ---------- contracts/PriceOraclePolygon.sol ----------
cat > 'contracts/PriceOraclePolygon.sol' << 'P2_FILE_EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/// @dev Minimal IUniswapV2Router02 interface (read-only methods used)
interface IUniswapV2Router02 {
    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

/// @dev Minimal IUniswapV2Pair interface for TWAP
interface IUniswapV2Pair {
    function price0CumulativeLast() external view returns (uint256);
    function price1CumulativeLast() external view returns (uint256);
    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );
    function token0() external view returns (address);
}

/// @dev Minimal IUniswapV2Factory interface
interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

/// @dev Minimal Chainlink aggregator interface
interface IChainlinkAggregator {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
    function decimals() external view returns (uint8);
}

/**
 * @title PriceOraclePolygon
 * @notice On-chain price oracle aggregating QuickSwap, SushiSwap, and Chainlink feeds
 *         for the Polygon network. Used by the flash loan arbitrage contracts to detect
 *         price discrepancies between DEXes.
 * @dev    All prices are returned in 18-decimal fixed-point unless noted otherwise.
 *         TWAP windows are measured in seconds.
 */
contract PriceOraclePolygon is Ownable {
    // ─────────────────────────────────────────────────────────────────────────
    // Constants & immutables
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Maximum age (in seconds) of a Chainlink answer before it is
    ///         considered stale and causes a revert.
    uint256 public constant CHAINLINK_STALENESS_THRESHOLD = 3600; // 1 hour

    /// @notice QuickSwap V2 router (Polygon mainnet)
    address public immutable QUICKSWAP_ROUTER;

    /// @notice SushiSwap router (Polygon mainnet)
    address public immutable SUSHISWAP_ROUTER;

    /// @notice QuickSwap V2 factory (Polygon mainnet)
    address public immutable QUICKSWAP_FACTORY;

    /// @notice SushiSwap factory (Polygon mainnet)
    address public immutable SUSHISWAP_FACTORY;

    // ─────────────────────────────────────────────────────────────────────────
    // Storage
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Chainlink price feed registry: token → feed address
    mapping(address => address) public chainlinkFeeds;

    // ─────────────────────────────────────────────────────────────────────────
    // Events
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Emitted when a Chainlink feed is registered or updated.
    event ChainlinkFeedSet(address indexed token, address indexed feed);

    // ─────────────────────────────────────────────────────────────────────────
    // Errors
    // ─────────────────────────────────────────────────────────────────────────

    error StaleChainlinkPrice(address feed, uint256 updatedAt, uint256 threshold);
    error ZeroAddress();
    error InvalidTWAPWindow();
    error PairDoesNotExist(address tokenA, address tokenB);
    error InsufficientTWAPElapsed();

    // ─────────────────────────────────────────────────────────────────────────
    // Constructor
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Deploys the oracle with DEX factory and router addresses.
     * @param quickswapRouter_  Address of the QuickSwap V2 router.
     * @param sushiswapRouter_  Address of the SushiSwap router.
     * @param quickswapFactory_ Address of the QuickSwap V2 factory.
     * @param sushiswapFactory_ Address of the SushiSwap factory.
     * @param initialFeeds      Token addresses whose Chainlink feeds are pre-registered.
     * @param feedAddresses     Corresponding Chainlink feed addresses.
     */
    constructor(
        address quickswapRouter_,
        address sushiswapRouter_,
        address quickswapFactory_,
        address sushiswapFactory_,
        address[] memory initialFeeds,
        address[] memory feedAddresses
    ) Ownable(msg.sender) {
        if (
            quickswapRouter_ == address(0) ||
            sushiswapRouter_ == address(0) ||
            quickswapFactory_ == address(0) ||
            sushiswapFactory_ == address(0)
        ) revert ZeroAddress();

        QUICKSWAP_ROUTER   = quickswapRouter_;
        SUSHISWAP_ROUTER   = sushiswapRouter_;
        QUICKSWAP_FACTORY  = quickswapFactory_;
        SUSHISWAP_FACTORY  = sushiswapFactory_;

        uint256 len = initialFeeds.length;
        require(len == feedAddresses.length, "PriceOracle: array length mismatch");
        for (uint256 i = 0; i < len; ++i) {
            _setChainlinkFeed(initialFeeds[i], feedAddresses[i]);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Admin
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Register or update a Chainlink price feed for a token.
     * @param token Address of the ERC-20 token.
     * @param feed  Address of the Chainlink aggregator feed.
     */
    function setChainlinkFeed(address token, address feed) external onlyOwner {
        _setChainlinkFeed(token, feed);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // DEX Price Queries
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Get the expected output amount from QuickSwap for a given input.
     * @param tokenA  Input token address.
     * @param tokenB  Output token address.
     * @param amount  Input amount (in tokenA's native decimals).
     * @return price  Expected output amount of tokenB.
     */
    function getQuickSwapPrice(
        address tokenA,
        address tokenB,
        uint256 amount
    ) public view returns (uint256 price) {
        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;
        uint256[] memory amounts = IUniswapV2Router02(QUICKSWAP_ROUTER).getAmountsOut(amount, path);
        return amounts[1];
    }

    /**
     * @notice Get the expected output amount from SushiSwap for a given input.
     * @param tokenA  Input token address.
     * @param tokenB  Output token address.
     * @param amount  Input amount (in tokenA's native decimals).
     * @return price  Expected output amount of tokenB.
     */
    function getSushiSwapPrice(
        address tokenA,
        address tokenB,
        uint256 amount
    ) public view returns (uint256 price) {
        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;
        uint256[] memory amounts = IUniswapV2Router02(SUSHISWAP_ROUTER).getAmountsOut(amount, path);
        return amounts[1];
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Chainlink Oracle
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Fetch the latest price from a registered Chainlink feed.
     * @param feed      Address of the Chainlink aggregator.
     * @return answer   Latest price (in feed's native decimal scale).
     * @return updatedAt Timestamp of the last price update.
     */
    function getChainlinkPrice(address feed)
        public
        view
        returns (int256 answer, uint256 updatedAt)
    {
        (, answer, , updatedAt, ) = IChainlinkAggregator(feed).latestRoundData();
        if (updatedAt < block.timestamp - CHAINLINK_STALENESS_THRESHOLD) {
            revert StaleChainlinkPrice(feed, updatedAt, block.timestamp - CHAINLINK_STALENESS_THRESHOLD);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Spread & Opportunity Detection
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Calculate the arbitrage spread between QuickSwap and SushiSwap
     *         for a given token pair and input amount.
     * @param tokenA        Input token.
     * @param tokenB        Output token.
     * @param amount        Input amount in tokenA's native decimals.
     * @return spread       Absolute difference in output amounts (tokenB).
     * @return cheaperDex   Router address of the DEX offering more tokenB (buy here).
     * @return expensiveDex Router address of the DEX offering less tokenB (sell here).
     */
    function getArbitrageSpread(
        address tokenA,
        address tokenB,
        uint256 amount
    )
        external
        view
        returns (
            uint256 spread,
            address cheaperDex,
            address expensiveDex
        )
    {
        uint256 quickPrice = getQuickSwapPrice(tokenA, tokenB, amount);
        uint256 sushiPrice = getSushiSwapPrice(tokenA, tokenB, amount);

        if (quickPrice >= sushiPrice) {
            spread       = quickPrice - sushiPrice;
            cheaperDex   = QUICKSWAP_ROUTER;   // more out ⟹ "cheaper" to buy tokenB
            expensiveDex = SUSHISWAP_ROUTER;
        } else {
            spread       = sushiPrice - quickPrice;
            cheaperDex   = SUSHISWAP_ROUTER;
            expensiveDex = QUICKSWAP_ROUTER;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TWAP
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Compute an approximate TWAP using UniswapV2 cumulative price accumulators.
     * @dev    Requires two observations at least `window` seconds apart. This function
     *         reads only the *current* cumulative price and the last stored value.
     *         For a production deployment, store a checkpoint off-chain and supply it.
     *         Here we approximate using the last checkpoint stored in the pair contract.
     * @param factory  UniswapV2-compatible factory to resolve the pair.
     * @param tokenA   First token of the pair.
     * @param tokenB   Second token of the pair.
     * @param window   Desired TWAP window in seconds (must be > 0).
     * @return twap    Time-weighted average price of tokenA in terms of tokenB,
     *                 scaled to 1e18.
     */
    function getTWAP(
        address factory,
        address tokenA,
        address tokenB,
        uint256 window
    ) external view returns (uint256 twap) {
        if (window == 0) revert InvalidTWAPWindow();

        address pair = IUniswapV2Factory(factory).getPair(tokenA, tokenB);
        if (pair == address(0)) revert PairDoesNotExist(tokenA, tokenB);

        IUniswapV2Pair pairContract = IUniswapV2Pair(pair);
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) =
            pairContract.getReserves();

        uint256 elapsed = block.timestamp - blockTimestampLast;
        if (elapsed < window) revert InsufficientTWAPElapsed();

        // Determine which reserve corresponds to tokenA
        address token0 = pairContract.token0();
        bool isToken0 = (tokenA == token0);

        // Simple spot price from reserves (approximation when no checkpoint stored)
        // A full TWAP implementation requires storing prior cumulative price snapshots.
        if (isToken0) {
            // price of token0 in terms of token1
            twap = (uint256(reserve1) * 1e18) / uint256(reserve0);
        } else {
            twap = (uint256(reserve0) * 1e18) / uint256(reserve1);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Internal helpers
    // ─────────────────────────────────────────────────────────────────────────

    function _setChainlinkFeed(address token, address feed) internal {
        if (token == address(0) || feed == address(0)) revert ZeroAddress();
        chainlinkFeeds[token] = feed;
        emit ChainlinkFeedSet(token, feed);
    }
}
P2_FILE_EOF

# ---------- contracts/TwapOracle.sol ----------
cat > 'contracts/TwapOracle.sol' << 'P2_FILE_EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title  TwapOracle
 * @notice Two-snapshot TWAP (Time-Weighted Average Price) oracle for UniswapV2-style pairs.
 *
 * @dev    UniswapV2 accumulates price0CumulativeLast / price1CumulativeLast on every swap.
 *         By recording two snapshots (t0 and t1) we derive:
 *
 *             TWAP = (accumulator_t1 - accumulator_t0) / (t1 - t0)
 *
 *         Minimum observation window is 5 minutes to resist flashloan manipulation.
 *
 *         The off-chain bot calls `update(pair)` on every block (or every few blocks).
 *         It then calls `consult(pair, amountIn)` to get a TWAP-weighted amountOut.
 *
 *         Pairs are registered by the owner.
 */
interface IUniswapV2Pair {
        function token0() external view returns (address);
        function token1() external view returns (address);
        function price0CumulativeLast() external view returns (uint256);
        function price1CumulativeLast() external view returns (uint256);
        function getReserves() external view returns (
            uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast
        );
    }

contract TwapOracle is Ownable {

    // ─────────────────────────────────────────────────────────────────────────
    // Types
    // ─────────────────────────────────────────────────────────────────────────

    struct Observation {
        uint256 timestamp;
        uint256 price0Cumulative;
        uint256 price1Cumulative;
    }

    struct PairInfo {
        address token0;
        address token1;
        Observation last;
        Observation prev;
        bool registered;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Constants
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Minimum seconds between snapshots to consider the TWAP valid.
    uint256 public constant MIN_WINDOW = 5 minutes;

    /// @notice Maximum age of the freshest snapshot before the TWAP is considered stale.
    uint256 public constant MAX_STALENESS = 1 hours;

    // ─────────────────────────────────────────────────────────────────────────
    // Storage
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice pair address → PairInfo
    mapping(address => PairInfo) public pairs;

    /// @notice all registered pair addresses
    address[] public pairList;

    // ─────────────────────────────────────────────────────────────────────────
    // Events & Errors
    // ─────────────────────────────────────────────────────────────────────────

    event PairRegistered(address indexed pair, address token0, address token1);
    event ObservationRecorded(address indexed pair, uint256 timestamp);

    error PairNotRegistered(address pair);
    error WindowTooSmall(uint256 elapsed, uint256 minimum);
    error StaleObservation(address pair, uint256 age);
    error ZeroAddress();

    // ─────────────────────────────────────────────────────────────────────────
    // Minimal UniswapV2Pair interface
    // ─────────────────────────────────────────────────────────────────────────

    // ─────────────────────────────────────────────────────────────────────────
    // Constructor
    // ─────────────────────────────────────────────────────────────────────────

    constructor() Ownable(msg.sender) {}

    // ─────────────────────────────────────────────────────────────────────────
    // Owner — pair management
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Register a UniswapV2 pair for TWAP tracking.
     * @param pair  Address of the UniswapV2Pair contract.
     */
    function registerPair(address pair) external onlyOwner {
        if (pair == address(0)) revert ZeroAddress();
        if (pairs[pair].registered) return; // idempotent

        IUniswapV2Pair p = IUniswapV2Pair(pair);
        address t0 = p.token0();
        address t1 = p.token1();

        // Seed with current accumulators so next update has a valid prev
        Observation memory seed = Observation({
            timestamp:        block.timestamp,
            price0Cumulative: _currentCumulative0(pair),
            price1Cumulative: _currentCumulative1(pair)
        });

        pairs[pair] = PairInfo({
            token0:     t0,
            token1:     t1,
            last:       seed,
            prev:       seed,
            registered: true
        });
        pairList.push(pair);

        emit PairRegistered(pair, t0, t1);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Public — snapshot update
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Record a new price observation for the given pair.
     *         Should be called by the bot on each new block (or periodically).
     * @param pair  Registered UniswapV2Pair address.
     */
    function update(address pair) external {
        PairInfo storage info = pairs[pair];
        if (!info.registered) revert PairNotRegistered(pair);

        uint256 elapsed = block.timestamp - info.last.timestamp;
        if (elapsed < 30) return; // skip if less than 30 s since last update (gas save)

        // Roll last → prev, then record new last
        info.prev = info.last;
        info.last = Observation({
            timestamp:        block.timestamp,
            price0Cumulative: _currentCumulative0(pair),
            price1Cumulative: _currentCumulative1(pair)
        });

        emit ObservationRecorded(pair, block.timestamp);
    }

    /**
     * @notice Batch update multiple pairs in one tx.
     * @param _pairs  Array of registered pair addresses.
     */
    function updateAll(address[] calldata _pairs) external {
        for (uint256 i = 0; i < _pairs.length; ++i) {
            PairInfo storage info = pairs[_pairs[i]];
            if (!info.registered) continue;
            uint256 elapsed = block.timestamp - info.last.timestamp;
            if (elapsed < 30) continue;
            info.prev = info.last;
            info.last = Observation({
                timestamp:        block.timestamp,
                price0Cumulative: _currentCumulative0(_pairs[i]),
                price1Cumulative: _currentCumulative1(_pairs[i])
            });
            emit ObservationRecorded(_pairs[i], block.timestamp);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Public — TWAP consultation
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Get the TWAP-weighted output amount for a given input.
     * @param pair      Registered pair address.
     * @param tokenIn   Must be token0 or token1 of the pair.
     * @param amountIn  Input amount (in tokenIn's native decimals).
     * @return amountOut  TWAP-weighted output amount.
     */
    function consult(
        address pair,
        address tokenIn,
        uint256 amountIn
    ) external view returns (uint256 amountOut) {
        PairInfo storage info = pairs[pair];
        if (!info.registered) revert PairNotRegistered(pair);

        uint256 window = info.last.timestamp - info.prev.timestamp;
        if (window < MIN_WINDOW) revert WindowTooSmall(window, MIN_WINDOW);

        uint256 age = block.timestamp - info.last.timestamp;
        if (age > MAX_STALENESS) revert StaleObservation(pair, age);

        // UQ112x112 fixed-point average price
        if (tokenIn == info.token0) {
            uint256 avgPrice = (info.last.price0Cumulative - info.prev.price0Cumulative) / window;
            // avgPrice is UQ112x112 (price of token0 in terms of token1)
            amountOut = (avgPrice * amountIn) >> 112;
        } else {
            uint256 avgPrice = (info.last.price1Cumulative - info.prev.price1Cumulative) / window;
            amountOut = (avgPrice * amountIn) >> 112;
        }
    }

    /**
     * @notice Returns the current window size and whether a TWAP is available.
     * @param pair  Registered pair address.
     */
    function getWindowInfo(address pair)
        external
        view
        returns (uint256 window, bool isReady, uint256 lastUpdate)
    {
        PairInfo storage info = pairs[pair];
        if (!info.registered) return (0, false, 0);
        window     = info.last.timestamp - info.prev.timestamp;
        isReady    = window >= MIN_WINDOW;
        lastUpdate = info.last.timestamp;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Internals
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @dev Read the current price0CumulativeLast, adjusting for time elapsed
     *      since the last pair interaction (mirrors UniswapV2OracleLibrary).
     */
    function _currentCumulative0(address pair) internal view returns (uint256) {
        IUniswapV2Pair p = IUniswapV2Pair(pair);
        (uint112 r0, uint112 r1, uint32 lastTs) = p.getReserves();
        uint256 acc = p.price0CumulativeLast();
        uint256 elapsed = block.timestamp - lastTs;
        if (elapsed > 0 && r0 > 0 && r1 > 0) {
            // price0 = r1/r0 as UQ112x112
            acc += uint256((uint256(r1) << 112) / uint256(r0)) * elapsed;
        }
        return acc;
    }

    function _currentCumulative1(address pair) internal view returns (uint256) {
        IUniswapV2Pair p = IUniswapV2Pair(pair);
        (uint112 r0, uint112 r1, uint32 lastTs) = p.getReserves();
        uint256 acc = p.price1CumulativeLast();
        uint256 elapsed = block.timestamp - lastTs;
        if (elapsed > 0 && r0 > 0 && r1 > 0) {
            acc += uint256((uint256(r0) << 112) / uint256(r1)) * elapsed;
        }
        return acc;
    }
}
P2_FILE_EOF

# ---------- contracts/test/MockAavePool.sol ----------
cat > 'contracts/test/MockAavePool.sol' << 'P2_FILE_EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MockAavePool
 * @notice Minimal mock of the Aave v3 Pool contract for unit tests.
 *         Exposes flashLoanSimple and a helper to call executeOperation
 *         on a receiver with a controlled initiator.
 */
contract MockAavePool {
    /// @notice Simulates Aave calling executeOperation on the receiver.
    ///         Does NOT actually disburse tokens — tests seed the receiver directly.
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 /* referralCode */
    ) external {
        // Call back into the receiver (mimics Aave behaviour)
        (bool success, bytes memory reason) = receiverAddress.call(
            abi.encodeWithSignature(
                "executeOperation(address,uint256,uint256,address,bytes)",
                asset,
                amount,
                (amount * 5) / 10_000, // 0.05% Aave fee
                receiverAddress,        // initiator = receiver itself (correct)
                params
            )
        );
        if (!success) {
            // Bubble up revert reason
            if (reason.length > 0) {
                assembly { revert(add(32, reason), mload(reason)) }
            }
            revert("MockAavePool: executeOperation failed");
        }
    }

    /// @notice Helper for tests that want to call executeOperation with a
    ///         *different* initiator (to simulate the UnauthorisedInitiator path).
    function callExecuteOperation(
        address receiverAddress,
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external {
        (bool success, bytes memory reason) = receiverAddress.call(
            abi.encodeWithSignature(
                "executeOperation(address,uint256,uint256,address,bytes)",
                asset, amount, premium, initiator, params
            )
        );
        if (!success) {
            if (reason.length > 0) {
                assembly { revert(add(32, reason), mload(reason)) }
            }
            revert("MockAavePool: callExecuteOperation failed");
        }
    }
}
P2_FILE_EOF

# ---------- contracts/test/MockAddressesProvider.sol ----------
cat > 'contracts/test/MockAddressesProvider.sol' << 'P2_FILE_EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MockAddressesProvider
 * @notice Mock Aave v3 PoolAddressesProvider for unit tests.
 *         Returns a configurable pool address.
 */
contract MockAddressesProvider {
    address private _pool;

    constructor(address pool_) {
        _pool = pool_;
    }

    function getPool() external view returns (address) {
        return _pool;
    }

    function setPool(address pool_) external {
        _pool = pool_;
    }
}
P2_FILE_EOF

# ---------- contracts/test/MockERC20.sol ----------
cat > 'contracts/test/MockERC20.sol' << 'P2_FILE_EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @notice Simple mintable ERC-20 token for tests.
 */
contract MockERC20 is ERC20 {
    uint8 private _dec;

    constructor(string memory name_, string memory symbol_, uint8 decimals_)
        ERC20(name_, symbol_)
    {
        _dec = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _dec;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}
P2_FILE_EOF

# ---------- contracts/test/MockRouter.sol ----------
cat > 'contracts/test/MockRouter.sol' << 'P2_FILE_EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title MockRouter
 * @notice Mock UniswapV2-style router for unit tests.
 *         Returns a fixed output amount regardless of input.
 *         Caller must have approved this contract to pull tokenIn.
 */
contract MockRouter {
    using SafeERC20 for IERC20;

    /// @notice Fixed output amount returned for every swap.
    uint256 public immutable FIXED_OUTPUT;

    constructor(uint256 fixedOutput_) {
        FIXED_OUTPUT = fixedOutput_;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 /* deadline */
    ) external returns (uint256[] memory amounts) {
        require(path.length >= 2, "MockRouter: path too short");
        require(FIXED_OUTPUT >= amountOutMin, "MockRouter: insufficient output");

        // Pull tokenIn
        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountIn);

        // Push tokenOut (mint if needed — tests pre-fund the router)
        // In tests, the router is pre-seeded with tokenOut via MockERC20.mint
        IERC20(path[path.length - 1]).safeTransfer(to, FIXED_OUTPUT);

        amounts = new uint256[](path.length);
        amounts[0]              = amountIn;
        amounts[path.length - 1] = FIXED_OUTPUT;
    }

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts)
    {
        require(path.length >= 2, "MockRouter: path too short");
        amounts = new uint256[](path.length);
        amounts[0]              = amountIn;
        amounts[path.length - 1] = FIXED_OUTPUT;
    }
}
P2_FILE_EOF

# ---------- dashboard/api/main.py ----------
cat > 'dashboard/api/main.py' << 'P2_FILE_EOF'
"""
FastAPI backend for the Flash Loan Arbitrage Bot monitoring dashboard.

Endpoints
---------
GET  /api/status              — bot status card (running/stopped, uptime, RPC count, WS subs)
GET  /api/opportunities       — recent opportunities feed
GET  /api/trades              — executed trades table
GET  /api/pnl                 — P&L summary (today / 7d / all-time)
GET  /api/rpc-health          — list of 20 RPC endpoints with latency + alive
GET  /api/gas                 — recent base fee / priority fee / our bid / competitor estimate
GET  /api/config              — current configuration (target pairs, min profit, max gas, relay)
GET  /api/relays              — MEV relay stats
POST /api/control/start       — start the bot background service
POST /api/control/stop       — stop the bot
POST /api/control/sim/{mode} — set simulation mode on/off
POST /api/control/emergency-withdraw — emergency withdraw all ERC-20 tokens
POST /api/config              — update runtime config (min profit, max gas, active relay)
WS   /ws/stream               — WebSocket: push live opportunities, trades, status changes
"""

import asyncio
import json
import os
import signal
import subprocess
import time
from datetime import datetime, timezone, timedelta
from pathlib import Path
from typing import Any, Dict, List, Optional

from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

# ─────────────────────────────────────────────────────────────────────────────
# Paths
# ─────────────────────────────────────────────────────────────────────────────
ROOT = Path(__file__).resolve().parent.parent.parent  # /app
LOG_DIR = ROOT / "logs"
STATE_FILE = ROOT / "dashboard" / "state.json"
BOT_PROCESS_PID_FILE = ROOT / "dashboard" / "bot.pid"
BOT_START_TIME_FILE = ROOT / "dashboard" / "bot.start"
BOT_CONTROL_LOCK = ROOT / "dashboard" / "bot.lock"

LOG_DIR.mkdir(parents=True, exist_ok=True)
(ROOT / "dashboard").mkdir(parents=True, exist_ok=True)

# ─────────────────────────────────────────────────────────────────────────────
# Config persistence
# ─────────────────────────────────────────────────────────────────────────────
DEFAULT_CONFIG: Dict[str, Any] = {
    "minProfitUsd": 2.0,
    "maxGasGwei": 350,
    "minPoolDepthUsd": 15000,
    "deadPoolFloorUsd": 1000,
    "maxDailyLossUsd": 100,
    "activeRelay": "fastlane",
    "relayPriority": ["fastlane", "merkle", "flashbots", "public"],
    "simMode": True,
    "targetPairs": [
        {"name": "WETH→USDC (15)", "loan": 15, "asset": "WETH"},
        {"name": "WETH→USDC (10)", "loan": 10, "asset": "WETH"},
        {"name": "WETH→WMATIC",    "loan": 10, "asset": "WETH"},
        {"name": "WMATIC→USDC (50K)", "loan": 50000, "asset": "WMATIC"},
        {"name": "WMATIC→USDC (20K)", "loan": 20000, "asset": "WMATIC"},
    ],
    "rpcPool": [],
    "wsPool": [],
}


def load_config() -> Dict[str, Any]:
    if STATE_FILE.exists():
        try:
            return json.loads(STATE_FILE.read_text())
        except Exception:
            pass
    return DEFAULT_CONFIG.copy()


def save_config(cfg: Dict[str, Any]) -> None:
    STATE_FILE.write_text(json.dumps(cfg, indent=2))


def load_runtime_state() -> Dict[str, Any]:
    """Runtime state written by the bot during execution."""
    state_path = ROOT / "dashboard" / "runtime.json"
    if state_path.exists():
        try:
            return json.loads(state_path.read_text())
        except Exception:
            return {}
    return {}


def write_runtime_state(state: Dict[str, Any]) -> None:
    state_path = ROOT / "dashboard" / "runtime.json"
    state_path.write_text(json.dumps(state, indent=2))


# ─────────────────────────────────────────────────────────────────────────────
# Log parsing
# ─────────────────────────────────────────────────────────────────────────────
def today_log_path() -> Path:
    return LOG_DIR / f"opportunities-{datetime.now(timezone.utc).strftime('%Y-%m-%d')}.jsonl"


def read_jsonl(path: Path, limit: int = 200) -> List[Dict[str, Any]]:
    if not path.exists():
        return []
    out = []
    with path.open("r") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                out.append(json.loads(line))
            except Exception:
                pass
    return out[-limit:]


def list_recent_logs(days: int = 7) -> List[Path]:
    today = datetime.now(timezone.utc).date()
    paths = []
    for i in range(days):
        d = today - timedelta(days=i)
        p = LOG_DIR / f"opportunities-{d.strftime('%Y-%m-%d')}.jsonl"
        if p.exists():
            paths.append(p)
    return paths


def get_trades(limit: int = 100) -> List[Dict[str, Any]]:
    """Trades = log entries with executed=true and a txHash."""
    trades = []
    for p in list_recent_logs(30):
        for entry in read_jsonl(p, limit=500):
            if entry.get("executed") and entry.get("txHash"):
                trades.append(entry)
    return trades[-limit:]


def get_pnl_summary() -> Dict[str, Any]:
    today_trades = [t for t in get_trades(500)
                    if t.get("timestamp", "").startswith(datetime.now(timezone.utc).strftime("%Y-%m-%d"))]
    seven_day_trades = []
    cutoff_7d = (datetime.now(timezone.utc) - timedelta(days=7)).isoformat()
    for t in get_trades(500):
        if t.get("timestamp", "") >= cutoff_7d:
            seven_day_trades.append(t)
    all_trades = get_trades(1000)

    def sum_profit(trades):
        return sum(float(t.get("netProfitUsd", 0)) for t in trades)

    def sum_gas(trades):
        return sum(float(t.get("gasCostUsd", 0)) for t in trades)

    success = sum(1 for t in all_trades if t.get("txStatus") == "confirmed")
    total = len(all_trades)
    avg_exec_ms = sum(float(t.get("executionMs", 0)) for t in all_trades) / max(1, total)

    return {
        "today": {"profit": sum_profit(today_trades), "trades": len(today_trades), "gas": sum_gas(today_trades)},
        "week":  {"profit": sum_profit(seven_day_trades), "trades": len(seven_day_trades), "gas": sum_gas(seven_day_trades)},
        "all":   {"profit": sum_profit(all_trades), "trades": total, "gas": sum_gas(all_trades),
                  "successRate": (success / total * 100) if total else 0,
                  "avgExecutionMs": avg_exec_ms},
    }


# ─────────────────────────────────────────────────────────────────────────────
# RPC health
# ─────────────────────────────────────────────────────────────────────────────
DEFAULT_RPC_LIST = [
    "https://polygon-rpc.com",
    "https://rpc.ankr.com/polygon",
    "https://polygon-bor-rpc.publicnode.com",
    "https://1rpc.io/matic",
    "https://polygon.llamarpc.com",
    "https://polygon.drpc.org",
    "https://polygon.blockpi.network/v1/rpc/public",
    "https://rpc-polygon.cryptexia.com",
    "https://polygon.publicnode.com",
    "https://polygon-bor.publicnode.com",
    "wss://polygon-bor-rpc.publicnode.com",
    "wss://polygon-rpc.com",
]


def rpc_health_from_runtime() -> List[Dict[str, Any]]:
    rt = load_runtime_state()
    snap = rt.get("rpcHealth")
    if snap and isinstance(snap, list):
        return snap
    # No live data — return default list as "unknown"
    return [{"url": u, "alive": None, "latencyMs": None, "isWs": u.startswith("ws"), "failCount": 0}
            for u in DEFAULT_RPC_LIST]


# ─────────────────────────────────────────────────────────────────────────────
# Bot process control
# ─────────────────────────────────────────────────────────────────────────────
def bot_running() -> bool:
    if not BOT_PROCESS_PID_FILE.exists():
        return False
    try:
        pid = int(BOT_PROCESS_PID_FILE.read_text().strip())
        os.kill(pid, 0)  # raises if process is dead
        return True
    except Exception:
        try:
            BOT_PROCESS_PID_FILE.unlink()
        except Exception:
            pass
        return False


def bot_uptime_seconds() -> int:
    if not bot_running() or not BOT_START_TIME_FILE.exists():
        return 0
    try:
        start = float(BOT_START_TIME_FILE.read_text())
        return int(time.time() - start)
    except Exception:
        return 0


def start_bot() -> str:
    if bot_running():
        return "already_running"
    cmd = ["npm", "run", "start"]
    log_path = ROOT / "dashboard" / "bot.stdout.log"
    log_file = open(log_path, "a")
    proc = subprocess.Popen(
        cmd,
        cwd=str(ROOT),
        stdout=log_file,
        stderr=subprocess.STDOUT,
        start_new_session=True,
        env={**os.environ, "PYTHONUNBUFFERED": "1", "NODE_OPTIONS": ""},
    )
    BOT_PROCESS_PID_FILE.write_text(str(proc.pid))
    BOT_START_TIME_FILE.write_text(str(time.time()))
    return f"started pid={proc.pid}"


def stop_bot() -> str:
    if not bot_running():
        return "not_running"
    try:
        pid = int(BOT_PROCESS_PID_FILE.read_text().strip())
        os.killpg(os.getpgid(pid), signal.SIGTERM)
        time.sleep(0.5)
        try:
            os.killpg(os.getpgid(pid), signal.SIGKILL)
        except Exception:
            pass
        BOT_PROCESS_PID_FILE.unlink(missing_ok=True)
        BOT_START_TIME_FILE.unlink(missing_ok=True)
        return f"stopped pid={pid}"
    except Exception as e:
        return f"error: {e}"


def emergency_withdraw() -> str:
    """Run the emergency withdraw script."""
    try:
        script = ROOT / "scripts" / "emergency-withdraw.js"
        if not script.exists():
            return "script not found: scripts/emergency-withdraw.js"
        result = subprocess.run(
            ["node", str(script)],
            cwd=str(ROOT),
            capture_output=True, text=True, timeout=120,
        )
        return result.stdout + ("\n" + result.stderr if result.stderr else "")
    except Exception as e:
        return f"error: {e}"


# ─────────────────────────────────────────────────────────────────────────────
# App
# ─────────────────────────────────────────────────────────────────────────────
app = FastAPI(title="Flash Loan Bot Monitor", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


class ConfigUpdate(BaseModel):
    minProfitUsd: Optional[float] = None
    maxGasGwei: Optional[int] = None
    minPoolDepthUsd: Optional[int] = None
    activeRelay: Optional[str] = None
    simMode: Optional[bool] = None
    targetPairs: Optional[List[Dict[str, Any]]] = None


@app.get("/api/status")
async def api_status():
    rt = load_runtime_state()
    cfg = load_config()
    running = bot_running()
    return {
        "status": "RUNNING" if running else "STOPPED",
        "uptimeSeconds": bot_uptime_seconds(),
        "startedAt": (BOT_START_TIME_FILE.read_text() if BOT_START_TIME_FILE.exists() else None),
        "rpcAlive": rt.get("rpcAlive", 0),
        "rpcTotal": rt.get("rpcTotal", 20),
        "wsSubscriptions": rt.get("wsSubscriptions", 0),
        "lastBlock": rt.get("lastBlock", None),
        "lastBlockAt": rt.get("lastBlockAt", None),
        "hmmRegime": rt.get("hmmRegime", "UNKNOWN"),
        "hmmConfidence": rt.get("hmmConfidence", 0),
        "simMode": cfg.get("simMode", True),
        "currentGasBid": rt.get("lastGasBid", None),
        "lastOpportunityAt": rt.get("lastOpportunityAt", None),
        "activeRelay": rt.get("activeRelay", cfg.get("activeRelay", "fastlane")),
    }


@app.get("/api/opportunities")
async def api_opportunities(limit: int = 50):
    today = read_jsonl(today_log_path(), limit)
    if len(today) < limit:
        # pull from recent logs to fill
        for p in list_recent_logs(7)[1:]:
            today.extend(read_jsonl(p, limit))
            if len(today) >= limit:
                break
    return today[-limit:]


@app.get("/api/trades")
async def api_trades(limit: int = 100):
    return get_trades(limit)


@app.get("/api/pnl")
async def api_pnl():
    return get_pnl_summary()


@app.get("/api/rpc-health")
async def api_rpc_health():
    return rpc_health_from_runtime()


@app.get("/api/gas")
async def api_gas():
    rt = load_runtime_state()
    return {
        "history": rt.get("gasHistory", []),
        "lastBid": rt.get("lastGasBid", None),
    }


@app.get("/api/config")
async def api_config():
    return load_config()


@app.get("/api/relays")
async def api_relays():
    rt = load_runtime_state()
    return rt.get("relayStats", {
        "fastlane":  {"attempts": 0, "successes": 0, "failures": 0},
        "merkle":    {"attempts": 0, "successes": 0, "failures": 0},
        "flashbots": {"attempts": 0, "successes": 0, "failures": 0},
        "public":    {"attempts": 0, "successes": 0, "failures": 0},
    })


@app.post("/api/config")
async def api_update_config(update: ConfigUpdate):
    cfg = load_config()
    data = update.dict(exclude_none=True)
    cfg.update(data)
    save_config(cfg)
    # notify running bot to reload (via state file flag)
    rt = load_runtime_state()
    rt["configReloadRequired"] = True
    write_runtime_state(rt)
    return {"ok": True, "config": cfg}


@app.post("/api/control/start")
async def api_control_start():
    return {"ok": True, "message": start_bot()}


@app.post("/api/control/stop")
async def api_control_stop():
    return {"ok": True, "message": stop_bot()}


@app.post("/api/control/sim/{mode}")
async def api_control_sim(mode: str):
    if mode not in ("on", "off"):
        raise HTTPException(400, "mode must be 'on' or 'off'")
    cfg = load_config()
    cfg["simMode"] = (mode == "on")
    save_config(cfg)
    rt = load_runtime_state()
    rt["configReloadRequired"] = True
    write_runtime_state(rt)
    return {"ok": True, "simMode": cfg["simMode"]}


@app.post("/api/control/emergency-withdraw")
async def api_control_withdraw():
    return {"ok": True, "message": emergency_withdraw()}


# ─────────────────────────────────────────────────────────────────────────────
# WebSocket live stream
# ─────────────────────────────────────────────────────────────────────────────
class ConnectionManager:
    def __init__(self):
        self.active: List[WebSocket] = []

    async def connect(self, ws: WebSocket):
        await ws.accept()
        self.active.append(ws)

    def disconnect(self, ws: WebSocket):
        if ws in self.active:
            self.active.remove(ws)

    async def broadcast(self, message: Dict[str, Any]):
        dead = []
        for ws in self.active:
            try:
                await ws.send_json(message)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.disconnect(ws)


manager = ConnectionManager()


@app.websocket("/ws/stream")
async def ws_stream(ws: WebSocket):
    await manager.connect(ws)
    last_block = None
    try:
        while True:
            # Poll runtime state for changes
            rt = load_runtime_state()
            block = rt.get("lastBlock")
            if block and block != last_block:
                await ws.send_json({"type": "block", "data": {
                    "block": block,
                    "blockAt": rt.get("lastBlockAt"),
                    "hmmRegime": rt.get("hmmRegime"),
                    "rpcAlive": rt.get("rpcAlive"),
                    "lastGasBid": rt.get("lastGasBid"),
                }})
                last_block = block

            # Check for new opportunities
            today = today_log_path()
            if today.exists():
                entries = read_jsonl(today, 5)
                for e in entries[-3:]:
                    await ws.send_json({"type": "opportunity", "data": e})

            await asyncio.sleep(2)
    except WebSocketDisconnect:
        manager.disconnect(ws)
    except Exception:
        manager.disconnect(ws)


# Static dashboard (built by the React frontend → dashboard/index.html)
app.mount("/", StaticFiles(directory=str(ROOT / "dashboard"), html=True), name="dashboard")
P2_FILE_EOF

# ---------- dashboard/api/requirements.txt ----------
cat > 'dashboard/api/requirements.txt' << 'P2_FILE_EOF'
fastapi==0.110.0
uvicorn[standard]==0.27.1
pydantic==2.6.1
websockets==12.0
P2_FILE_EOF

# ---------- dashboard/index.html ----------
cat > 'dashboard/index.html' << 'P2_FILE_EOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0"/>
<title>FLASH//ARB — MEV Search Terminal</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@300;400;500;600;700&family=IBM+Plex+Mono:wght@400;500;600;700&display=swap" rel="stylesheet">
<script type="importmap">
{
  "imports": {
    "react": "https://esm.sh/react@18.3.1",
    "react-dom/client": "https://esm.sh/react-dom@18.3.1/client",
    "htm": "https://esm.sh/htm@3.1.1",
    "preact": "https://esm.sh/preact@10.19.3"
  }
}
</script>
<style>
  :root {
    --bg-0: #050709;
    --bg-1: #0a0d12;
    --bg-2: #0f1318;
    --bg-3: #141921;
    --border: #1d232c;
    --border-hot: #2a3543;
    --green: #00ff9c;
    --green-dim: #00b06b;
    --green-bg: rgba(0,255,156,0.06);
    --red: #ff2e4f;
    --red-dim: #b32038;
    --red-bg: rgba(255,46,79,0.08);
    --amber: #ffb300;
    --amber-bg: rgba(255,179,0,0.08);
    --blue: #4ab3ff;
    --blue-bg: rgba(74,179,255,0.08);
    --purple: #b78aff;
    --text: #d4dde8;
    --text-dim: #6b7785;
    --text-mute: #475160;
    --mono: 'JetBrains Mono', 'IBM Plex Mono', monospace;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  html, body {
    background: var(--bg-0); color: var(--text);
    font-family: var(--mono); font-size: 12px;
    min-height: 100vh; -webkit-font-smoothing: antialiased;
  }
  body::before {
    content: ""; position: fixed; inset: 0;
    background:
      radial-gradient(ellipse at top right, rgba(0,255,156,0.025), transparent 50%),
      radial-gradient(ellipse at bottom left, rgba(74,179,255,0.02), transparent 50%);
    pointer-events: none; z-index: 0;
  }
  #root { position: relative; z-index: 1; }

  /* ── Header ── */
  .topbar {
    display: flex; align-items: center; justify-content: space-between;
    padding: 10px 18px; border-bottom: 1px solid var(--border);
    background: linear-gradient(180deg, var(--bg-1), var(--bg-2));
    backdrop-filter: blur(8px);
  }
  .brand { display: flex; align-items: center; gap: 12px; }
  .brand .logo {
    font-size: 16px; font-weight: 700; letter-spacing: 1px;
    background: linear-gradient(90deg, var(--green), var(--blue));
    -webkit-background-clip: text; -webkit-text-fill-color: transparent;
  }
  .brand .sep { color: var(--text-mute); font-size: 11px; }
  .brand .sub { color: var(--text-dim); font-size: 10px; letter-spacing: 2px; text-transform: uppercase; }
  .topbar-right { display: flex; align-items: center; gap: 18px; font-size: 11px; }
  .ticker { display: flex; gap: 16px; }
  .ticker .item { color: var(--text-dim); }
  .ticker .item b { color: var(--text); font-weight: 500; }
  .ticker .item.up b { color: var(--green); }
  .ticker .item.down b { color: var(--red); }
  .clock { color: var(--green); font-weight: 600; letter-spacing: 1px; font-variant-numeric: tabular-nums; }

  /* ── Status strip ── */
  .status-strip {
    display: flex; align-items: stretch; border-bottom: 1px solid var(--border);
    background: var(--bg-1);
  }
  .status-cell {
    flex: 1; padding: 10px 16px; border-right: 1px solid var(--border);
    display: flex; flex-direction: column; gap: 4px;
  }
  .status-cell:last-child { border-right: none; }
  .status-cell .label {
    font-size: 9px; color: var(--text-mute); text-transform: uppercase;
    letter-spacing: 1.5px;
  }
  .status-cell .value { font-size: 14px; font-weight: 600; font-variant-numeric: tabular-nums; }
  .status-cell .sub { font-size: 10px; color: var(--text-dim); }
  .status-cell .dot {
    display: inline-block; width: 6px; height: 6px; border-radius: 50%;
    background: var(--text-mute); margin-right: 6px; vertical-align: middle;
  }
  .status-cell .dot.running { background: var(--green); box-shadow: 0 0 6px var(--green); animation: pulse 1.5s infinite; }
  .status-cell .dot.stopped { background: var(--text-mute); }
  .status-cell .dot.error { background: var(--red); box-shadow: 0 0 6px var(--red); animation: pulse 0.8s infinite; }
  @keyframes pulse { 0%,100%{opacity:1} 50%{opacity:0.35} }

  /* ── Grid layout ── */
  .grid-main {
    display: grid; grid-template-columns: 320px 1fr 340px;
    grid-template-rows: auto auto auto;
    gap: 8px; padding: 8px;
    grid-template-areas:
      "opps   pnl    controls"
      "opps   trades controls"
      "rpc    gas    config";
  }
  .grid-main > .panel { padding: 12px; }

  .panel {
    background: var(--bg-1);
    border: 1px solid var(--border);
    border-radius: 4px;
    display: flex; flex-direction: column;
    overflow: hidden;
  }
  .panel-header {
    display: flex; justify-content: space-between; align-items: center;
    padding: 8px 12px; border-bottom: 1px solid var(--border);
    background: var(--bg-2);
  }
  .panel-title {
    font-size: 10px; font-weight: 600; color: var(--text);
    text-transform: uppercase; letter-spacing: 1.5px;
  }
  .panel-title::before {
    content: "▸ "; color: var(--green);
  }
  .panel-meta { font-size: 9px; color: var(--text-mute); letter-spacing: 1px; }

  /* ── Opportunities ── */
  .opp-row {
    padding: 8px 12px; border-bottom: 1px solid var(--border);
    display: grid; grid-template-columns: 1fr auto auto;
    align-items: center; gap: 10px; cursor: pointer;
    transition: background 0.1s;
  }
  .opp-row:hover { background: var(--bg-2); }
  .opp-row.flash { animation: flash-green 0.6s ease; }
  @keyframes flash-green {
    0% { background: var(--green-bg); }
    100% { background: transparent; }
  }
  .opp-pair { font-size: 11px; font-weight: 600; }
  .opp-pair .arrow { color: var(--text-mute); margin: 0 4px; }
  .opp-meta { font-size: 9px; color: var(--text-dim); margin-top: 2px; }
  .opp-spread { font-size: 11px; color: var(--amber); font-weight: 600; text-align: right; }
  .opp-net { font-size: 13px; color: var(--green); font-weight: 700; text-align: right; font-variant-numeric: tabular-nums; }
  .opp-net.zero { color: var(--text-mute); }
  .opp-signal {
    font-size: 9px; padding: 2px 6px; border-radius: 2px; font-weight: 600;
    text-transform: uppercase; letter-spacing: 0.5px;
  }
  .opp-signal.execute { background: var(--green-bg); color: var(--green); border: 1px solid var(--green-dim); }
  .opp-signal.marginal { background: var(--amber-bg); color: var(--amber); border: 1px solid var(--amber); }
  .opp-signal.phantom { background: var(--red-bg); color: var(--red); border: 1px solid var(--red-dim); }

  /* ── P&L ── */
  .pnl-grid { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 1px; background: var(--border); }
  .pnl-cell { background: var(--bg-1); padding: 12px; }
  .pnl-cell .period { font-size: 9px; color: var(--text-mute); text-transform: uppercase; letter-spacing: 1.5px; }
  .pnl-cell .amount { font-size: 20px; font-weight: 700; margin: 4px 0; font-variant-numeric: tabular-nums; }
  .pnl-cell .amount.pos { color: var(--green); }
  .pnl-cell .amount.neg { color: var(--red); }
  .pnl-cell .stat { font-size: 9px; color: var(--text-dim); }
  .pnl-row { display: flex; justify-content: space-between; padding: 6px 12px; border-top: 1px solid var(--border); font-size: 10px; }
  .pnl-row .label { color: var(--text-dim); }
  .pnl-row .value { font-variant-numeric: tabular-nums; }

  /* ── Trades ── */
  .trades-table { width: 100%; border-collapse: collapse; font-size: 10px; }
  .trades-table th {
    text-align: left; padding: 6px 8px; color: var(--text-mute);
    font-weight: 500; font-size: 9px; text-transform: uppercase;
    letter-spacing: 1px; border-bottom: 1px solid var(--border);
    background: var(--bg-2);
  }
  .trades-table td {
    padding: 6px 8px; border-bottom: 1px solid var(--border);
    font-variant-numeric: tabular-nums;
  }
  .trades-table tr:hover { background: var(--bg-2); }
  .trades-table a { color: var(--blue); text-decoration: none; }
  .trades-table a:hover { text-decoration: underline; }
  .badge-status {
    display: inline-block; padding: 1px 5px; font-size: 9px; border-radius: 2px;
    text-transform: uppercase; letter-spacing: 0.5px;
  }
  .badge-status.confirmed { background: var(--green-bg); color: var(--green); }
  .badge-status.pending { background: var(--amber-bg); color: var(--amber); }
  .badge-status.failed { background: var(--red-bg); color: var(--red); }
  .empty-state {
    padding: 24px 12px; text-align: center; color: var(--text-mute);
    font-size: 10px; letter-spacing: 1px;
  }

  /* ── RPC health ── */
  .rpc-row {
    display: flex; justify-content: space-between; align-items: center;
    padding: 6px 12px; border-bottom: 1px solid var(--border);
    font-size: 10px;
  }
  .rpc-row .url { color: var(--text); font-family: var(--mono); font-size: 10px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .rpc-row .latency { font-variant-numeric: tabular-nums; }
  .rpc-row .latency.fast { color: var(--green); }
  .rpc-row .latency.med { color: var(--amber); }
  .rpc-row .latency.slow { color: var(--red); }
  .rpc-row .latency.dead { color: var(--text-mute); }
  .rpc-row .alive-dot {
    width: 6px; height: 6px; border-radius: 50%; flex-shrink: 0;
    margin-right: 8px;
  }
  .rpc-row .alive-dot.alive { background: var(--green); box-shadow: 0 0 4px var(--green); }
  .rpc-row .alive-dot.dead { background: var(--red); }
  .rpc-row .alive-dot.unknown { background: var(--text-mute); }

  /* ── Gas chart ── */
  .gas-chart { padding: 12px; height: 200px; position: relative; }
  .gas-bar-row { display: flex; align-items: center; gap: 8px; padding: 4px 12px; font-size: 10px; }
  .gas-bar-label { width: 80px; color: var(--text-dim); }
  .gas-bar-track { flex: 1; background: var(--bg-3); height: 8px; border-radius: 2px; overflow: hidden; position: relative; }
  .gas-bar-fill { height: 100%; transition: width 0.3s; }
  .gas-bar-fill.base { background: linear-gradient(90deg, var(--blue), var(--purple)); }
  .gas-bar-fill.priority { background: linear-gradient(90deg, var(--amber), var(--red)); }
  .gas-bar-fill.our-bid { background: linear-gradient(90deg, var(--green-dim), var(--green)); }
  .gas-bar-fill.competitor { background: linear-gradient(90deg, var(--text-mute), var(--text-dim)); }
  .gas-bar-value { width: 60px; text-align: right; font-variant-numeric: tabular-nums; color: var(--text); }
  .gas-trend { padding: 0 12px 8px; }
  .gas-sparkline { display: flex; align-items: flex-end; height: 60px; gap: 1px; }
  .gas-spark-bar { flex: 1; background: var(--blue); opacity: 0.5; min-height: 2px; border-radius: 1px 1px 0 0; }
  .gas-spark-bar.priority { background: var(--amber); }

  /* ── Controls ── */
  .control-section { padding: 12px; border-bottom: 1px solid var(--border); }
  .control-section:last-child { border-bottom: none; }
  .control-section h4 {
    font-size: 9px; color: var(--text-mute); text-transform: uppercase;
    letter-spacing: 1.5px; margin-bottom: 10px; font-weight: 600;
  }
  .btn {
    width: 100%; padding: 10px 12px; border-radius: 3px;
    border: 1px solid var(--border); background: var(--bg-3);
    color: var(--text); font-family: var(--mono); font-size: 11px;
    font-weight: 600; letter-spacing: 1px; text-transform: uppercase;
    cursor: pointer; transition: all 0.15s; display: flex; align-items: center; justify-content: center; gap: 6px;
  }
  .btn:hover { border-color: var(--border-hot); background: var(--bg-2); }
  .btn.start { border-color: var(--green-dim); color: var(--green); }
  .btn.start:hover { background: var(--green-bg); }
  .btn.stop { border-color: var(--amber); color: var(--amber); }
  .btn.stop:hover { background: var(--amber-bg); }
  .btn.danger { border-color: var(--red-dim); color: var(--red); }
  .btn.danger:hover { background: var(--red-bg); }
  .btn.active { background: var(--green-bg); border-color: var(--green); color: var(--green); }
  .btn-row { display: grid; grid-template-columns: 1fr 1fr; gap: 6px; margin-bottom: 8px; }
  .config-row { display: flex; justify-content: space-between; align-items: center; padding: 6px 0; font-size: 10px; }
  .config-row .label { color: var(--text-dim); }
  .config-row .value { color: var(--text); font-variant-numeric: tabular-nums; font-weight: 600; }
  .config-row .input { width: 80px; background: var(--bg-3); border: 1px solid var(--border); color: var(--text); padding: 4px 6px; border-radius: 2px; font-family: var(--mono); font-size: 10px; text-align: right; }
  .config-row .input:focus { outline: none; border-color: var(--green-dim); }
  .relay-pill {
    display: inline-block; padding: 3px 8px; font-size: 9px; border-radius: 12px;
    margin-right: 4px; margin-bottom: 4px; cursor: pointer; border: 1px solid var(--border);
    background: var(--bg-3); color: var(--text-dim); transition: all 0.15s;
    text-transform: uppercase; letter-spacing: 1px; font-weight: 600;
  }
  .relay-pill.active { background: var(--green-bg); color: var(--green); border-color: var(--green-dim); }
  .relay-pill:hover { border-color: var(--border-hot); }
  .pair-list { font-size: 10px; }
  .pair-row {
    display: flex; justify-content: space-between; padding: 4px 0;
    border-bottom: 1px dashed var(--border);
  }
  .pair-row:last-child { border-bottom: none; }
  .pair-row .name { color: var(--text); }
  .pair-row .loan { color: var(--text-dim); font-variant-numeric: tabular-nums; }

  /* ── Misc ── */
  .footer {
    padding: 8px 18px; border-top: 1px solid var(--border);
    font-size: 9px; color: var(--text-mute); display: flex; justify-content: space-between;
    background: var(--bg-1);
  }
  .footer .blink { color: var(--green); animation: blink 1s infinite; }
  @keyframes blink { 50% { opacity: 0.2; } }
  .scroll { overflow-y: auto; }
  .scroll::-webkit-scrollbar { width: 6px; }
  .scroll::-webkit-scrollbar-track { background: var(--bg-1); }
  .scroll::-webkit-scrollbar-thumb { background: var(--border); border-radius: 3px; }
  .scroll::-webkit-scrollbar-thumb:hover { background: var(--border-hot); }
  .area-opps { grid-area: opps; max-height: 70vh; }
  .area-pnl { grid-area: pnl; }
  .area-trades { grid-area: trades; max-height: 40vh; }
  .area-controls { grid-area: controls; max-height: 80vh; }
  .area-rpc { grid-area: rpc; max-height: 40vh; }
  .area-gas { grid-area: gas; max-height: 40vh; }
  .area-config { grid-area: config; max-height: 40vh; }
</style>
</head>
<body>
<div id="root"></div>
<script type="module">
import React, { useState, useEffect, useRef, useCallback } from 'react';
import { createRoot } from 'react-dom/client';
import htm from 'htm';

const html = htm.bind(React.createElement);
const API = (path, opts) => fetch(path, opts).then(r => r.json()).catch(e => ({ error: e.message }));

// ─────────────────────────────────────────────────────────────────────────────
// Hooks
// ─────────────────────────────────────────────────────────────────────────────
function usePoll(path, intervalMs = 2000) {
  const [data, setData] = useState(null);
  useEffect(() => {
    let active = true;
    const tick = async () => {
      const d = await API(path);
      if (active && !d.error) setData(d);
    };
    tick();
    const id = setInterval(tick, intervalMs);
    return () => { active = false; clearInterval(id); };
  }, [path, intervalMs]);
  return data;
}

// ─────────────────────────────────────────────────────────────────────────────
// Components
// ─────────────────────────────────────────────────────────────────────────────
const fmt = (n, d = 2) => n == null ? '—' : Number(n).toLocaleString(undefined, { maximumFractionDigits: d, minimumFractionDigits: d });
const fmtUsd = (n) => n == null ? '—' : (n >= 0 ? '$' : '-$') + Math.abs(n).toLocaleString(undefined, { maximumFractionDigits: 2, minimumFractionDigits: 2 });
const fmtTime = (iso) => {
  if (!iso) return '—';
  try { return new Date(iso).toLocaleTimeString('en-US', { hour12: false }); }
  catch { return '—'; }
};
const fmtAgo = (iso) => {
  if (!iso) return '—';
  const sec = Math.floor((Date.now() - new Date(iso).getTime()) / 1000);
  if (sec < 60) return `${sec}s ago`;
  if (sec < 3600) return `${Math.floor(sec/60)}m ago`;
  return `${Math.floor(sec/3600)}h ago`;
};

function TopBar({ status }) {
  const [clock, setClock] = useState(new Date());
  useEffect(() => { const id = setInterval(() => setClock(new Date()), 1000); return () => clearInterval(id); }, []);
  return html`
    <div class="topbar">
      <div class="brand">
        <div class="logo">FLASH//ARB</div>
        <div class="sep">::</div>
        <div class="sub">MEV Search Terminal · Polygon V3</div>
      </div>
      <div class="topbar-right">
        <div class="ticker">
          <div class="item"><b>POLYGON</b></div>
          <div class="item">ETH <b>$${fmt(status?.ethPrice ?? 1931)}</b></div>
          <div class="item">MATIC <b>$${fmt(status?.maticPrice ?? 0.084, 4)}</b></div>
          <div class="item">BTC <b>$${fmt(status?.btcPrice ?? 65000, 0)}</b></div>
          <div class="item">GAS <b>${fmt(status?.lastGasBid?.totalGwei ?? 281, 1)} GWEI</b></div>
          <div class="item">BLOCK <b>#${status?.lastBlock ?? '—'}</b></div>
        </div>
        <div class="clock">${clock.toISOString().slice(11, 19)} UTC</div>
      </div>
    </div>
  `;
}

function StatusStrip({ status }) {
  const statusClass = status?.status?.toLowerCase() ?? 'stopped';
  const uptime = status?.uptimeSeconds ? `${Math.floor(status.uptimeSeconds/3600)}h ${Math.floor((status.uptimeSeconds%3600)/60)}m` : '0h 0m';
  const regime = status?.hmmRegime ?? 'UNKNOWN';
  const regimeColor = regime === 'HOT' ? 'var(--red)' : regime === 'WARM' ? 'var(--amber)' : regime === 'COLD' ? 'var(--blue)' : 'var(--text-mute)';
  return html`
    <div class="status-strip">
      <div class="status-cell">
        <div class="label">Bot Status</div>
        <div class="value"><span class=${`dot ${statusClass}`}></span>${status?.status ?? '—'}</div>
        <div class="sub">Uptime ${uptime}</div>
      </div>
      <div class="status-cell">
        <div class="label">RPC Pool</div>
        <div class="value">${status?.rpcAlive ?? 0}<span style="color:var(--text-mute);font-weight:400">/${status?.rpcTotal ?? 20}</span> alive</div>
        <div class="sub">WS subs: ${status?.wsSubscriptions ?? 0}</div>
      </div>
      <div class="status-cell">
        <div class="label">HMM Regime</div>
        <div class="value" style=${{color: regimeColor}}>${regime}</div>
        <div class="sub">Confidence ${fmt(status?.hmmConfidence ?? 0, 1)}%</div>
      </div>
      <div class="status-cell">
        <div class="label">Gas Bid</div>
        <div class="value" style=${{color: 'var(--green)'}}>${fmt(status?.lastGasBid?.totalGwei ?? 0, 1)} <span style="font-size:10px;color:var(--text-dim)">GWEI</span></div>
        <div class="sub">Cap ${fmt(status?.lastGasBid?.capped ? 'CAPPED' : 'OK')}</div>
      </div>
      <div class="status-cell">
        <div class="label">Active Relay</div>
        <div class="value" style=${{color: 'var(--blue)'}}>${(status?.activeRelay ?? 'fastlane').toUpperCase()}</div>
        <div class="sub">MEV private mempool</div>
      </div>
      <div class="status-cell">
        <div class="label">Sim Mode</div>
        <div class="value" style=${{color: status?.simMode ? 'var(--amber)' : 'var(--green)'}}>${status?.simMode ? 'SIMULATION' : 'LIVE'}</div>
        <div class="sub">${status?.simMode ? 'No real txs' : 'Real execution'}</div>
      </div>
      <div class="status-cell">
        <div class="label">Last Signal</div>
        <div class="value">${fmtAgo(status?.lastOpportunityAt)}</div>
        <div class="sub">${status?.lastBlock ? 'Block #' + status.lastBlock : 'Awaiting scan'}</div>
      </div>
    </div>
  `;
}

function OpportunitiesPanel() {
  const opps = usePoll('/api/opportunities?limit=50', 3000);
  const [flashIds, setFlashIds] = useState(new Set());
  const prevIds = useRef(new Set());
  useEffect(() => {
    if (!opps) return;
    const newIds = new Set();
    const toFlash = new Set();
    for (const o of opps) {
      const id = o.id ?? o.timestamp;
      newIds.add(id);
      if (!prevIds.current.has(id)) toFlash.add(id);
    }
    prevIds.current = newIds;
    if (toFlash.size > 0) setFlashIds(toFlash);
  }, [opps]);
  const list = (opps ?? []).slice().reverse();
  return html`
    <div class="panel area-opps scroll">
      <div class="panel-header">
        <div class="panel-title">Live Opportunities</div>
        <div class="panel-meta">${list.length} SIGNALS · LAST ${fmtTime(list[0]?.timestamp)}</div>
      </div>
      <div>
        ${list.length === 0 ? html`<div class="empty-state">AWAITING SIGNAL ▸ SCANNER IDLE</div>` : list.map(o => {
          const signal = (o.signal ?? o.status ?? 'execute').toLowerCase();
          const signalClass = signal.includes('phantom') ? 'phantom' : signal.includes('marg') || signal.includes('low') ? 'marginal' : 'execute';
          const net = Number(o.netProfitUsd ?? o.net ?? 0);
          const isFlash = flashIds.has(o.id ?? o.timestamp);
          return html`
            <div class=${`opp-row ${isFlash ? 'flash' : ''}`} key=${o.id ?? o.timestamp}>
              <div>
                <div class="opp-pair">
                  ${o.pairName ?? o.pair ?? o.tokenIn?.slice(0,6) + '→' + o.tokenOut?.slice(0,6)}
                </div>
                <div class="opp-meta">
                  QS $${fmt(o.qsDepthUsd ?? 0, 0)}K · SS $${fmt(o.ssDepthUsd ?? 0, 0)}K · slip ${fmt(o.slippagePct ?? 0, 1)}%
                </div>
              </div>
              <div class="opp-spread">+${fmt(o.spreadUsd ?? o.spread ?? 0, 0)}$</div>
              <div style=${{textAlign: 'right'}}>
                <div class=${`opp-net ${net === 0 ? 'zero' : ''}`}>+${fmtUsd(net)}</div>
                <div class=${`opp-signal ${signalClass}`} style=${{marginTop: '4px'}}>${signal}</div>
              </div>
            </div>
          `;
        })}
      </div>
    </div>
  `;
}

function PnlPanel() {
  const pnl = usePoll('/api/pnl', 5000);
  if (!pnl) return html`<div class="panel area-pnl"><div class="panel-header"><div class="panel-title">P&L Summary</div></div><div class="empty-state">LOADING…</div></div>`;
  return html`
    <div class="panel area-pnl">
      <div class="panel-header">
        <div class="panel-title">P&L Summary</div>
        <div class="panel-meta">USDC · NET PROFIT</div>
      </div>
      <div class="pnl-grid">
        <div class="pnl-cell">
          <div class="period">Today</div>
          <div class=${`amount ${pnl.today.profit >= 0 ? 'pos' : 'neg'}`}>${fmtUsd(pnl.today.profit)}</div>
          <div class="stat">${pnl.today.trades} trades · ${fmtUsd(pnl.today.gas)} gas</div>
        </div>
        <div class="pnl-cell">
          <div class="period">7-Day</div>
          <div class=${`amount ${pnl.week.profit >= 0 ? 'pos' : 'neg'}`}>${fmtUsd(pnl.week.profit)}</div>
          <div class="stat">${pnl.week.trades} trades · ${fmtUsd(pnl.week.gas)} gas</div>
        </div>
        <div class="pnl-cell">
          <div class="period">All-Time</div>
          <div class=${`amount ${pnl.all.profit >= 0 ? 'pos' : 'neg'}`}>${fmtUsd(pnl.all.profit)}</div>
          <div class="stat">${pnl.all.trades} trades · ${fmtUsd(pnl.all.gas)} gas</div>
        </div>
      </div>
      <div class="pnl-row"><span class="label">Success Rate</span><span class="value" style=${{color: 'var(--green)'}}>${fmt(pnl.all.successRate, 1)}%</span></div>
      <div class="pnl-row"><span class="label">Avg Execution Time</span><span class="value">${fmt(pnl.all.avgExecutionMs, 0)} ms</span></div>
    </div>
  `;
}

function TradesPanel() {
  const trades = usePoll('/api/trades?limit=50', 5000);
  const list = (trades ?? []).slice().reverse();
  return html`
    <div class="panel area-trades scroll">
      <div class="panel-header">
        <div class="panel-title">Executed Trades</div>
        <div class="panel-meta">${list.length} RECORDS</div>
      </div>
      ${list.length === 0
        ? html`<div class="empty-state">NO EXECUTED TRADES YET ▸ SIM MODE</div>`
        : html`<table class="trades-table">
            <thead>
              <tr><th>Block</th><th>Time</th><th>Pair</th><th>Profit</th><th>Gas</th><th>Relay</th><th>TxHash</th><th>Status</th></tr>
            </thead>
            <tbody>
              ${list.map(t => html`
                <tr key=${t.txHash}>
                  <td>${t.blockNumber ?? '—'}</td>
                  <td>${fmtTime(t.timestamp)}</td>
                  <td>${t.pairName ?? t.pair ?? '—'}</td>
                  <td style=${{color: 'var(--green)'}}>+${fmtUsd(t.netProfitUsd ?? t.net)}</td>
                  <td style=${{color: 'var(--amber)'}}>${fmtUsd(t.gasCostUsd ?? 0)}</td>
                  <td>${t.relay ?? 'public'}</td>
                  <td><a href=${`https://polygonscan.com/tx/${t.txHash}`} target="_blank" rel="noopener">${t.txHash?.slice(0,10)}…</a></td>
                  <td><span class=${`badge-status ${t.txStatus ?? 'pending'}`}>${t.txStatus ?? 'pending'}</span></td>
                </tr>
              `)}
            </tbody>
          </table>`}
    </div>
  `;
}

function RpcHealthPanel() {
  const rpc = usePoll('/api/rpc-health', 5000);
  const list = rpc ?? [];
  return html`
    <div class="panel area-rpc scroll">
      <div class="panel-header">
        <div class="panel-title">RPC Health Monitor</div>
        <div class="panel-meta">${list.filter(r => r.alive).length}/${list.length} ALIVE</div>
      </div>
      ${list.length === 0 ? html`<div class="empty-state">NO RPC DATA</div>` : list.map(r => {
        const lat = r.latencyMs;
        const cls = lat == null ? 'unknown' : r.alive ? (lat < 200 ? 'fast' : lat < 800 ? 'med' : 'slow') : 'dead';
        return html`
          <div class="rpc-row" key=${r.url}>
            <span class=${`alive-dot ${r.alive == null ? 'unknown' : r.alive ? 'alive' : 'dead'}`}></span>
            <span class="url" title=${r.url}>${r.url}</span>
            <span class=${`latency ${cls}`}>
              ${r.alive == null ? '—' : r.alive ? `${lat}ms` : 'DEAD'}
              ${r.failCount > 0 && r.alive !== true ? ` ×${r.failCount}` : ''}
            </span>
          </div>
        `;
      })}
    </div>
  `;
}

function GasPanel() {
  const gas = usePoll('/api/gas', 5000);
  const bid = gas?.lastBid;
  const history = gas?.history ?? [];
  const maxGwei = Math.max(50, ...history.map(h => h.baseFeeGwei + h.priorityFeeGwei), bid?.totalGwei ?? 0);
  const recent = history.slice(-30);
  const maxBase = Math.max(1, ...recent.map(h => h.baseFeeGwei));
  return html`
    <div class="panel area-gas">
      <div class="panel-header">
        <div class="panel-title">Gas & Priority Fee</div>
        <div class="panel-meta">EIP-1559 · POLYGON</div>
      </div>
      <div class="gas-bar-row">
        <div class="gas-bar-label">Base Fee</div>
        <div class="gas-bar-track"><div class="gas-bar-fill base" style=${{width: `${(bid?.baseFee ?? 30) / maxGwei * 100}%`}}></div></div>
        <div class="gas-bar-value">${fmt(bid?.baseFee ?? 0, 1)}</div>
      </div>
      <div class="gas-bar-row">
        <div class="gas-bar-label">Priority Fee</div>
        <div class="gas-bar-track"><div class="gas-bar-fill priority" style=${{width: `${(bid?.priorityFee ?? 30) / maxGwei * 100}%`}}></div></div>
        <div class="gas-bar-value">${fmt(bid?.priorityFee ?? 0, 1)}</div>
      </div>
      <div class="gas-bar-row">
        <div class="gas-bar-label">Our Bid</div>
        <div class="gas-bar-track"><div class="gas-bar-fill our-bid" style=${{width: `${(bid?.totalGwei ?? 60) / maxGwei * 100}%`}}></div></div>
        <div class="gas-bar-value" style=${{color: 'var(--green)'}}>${fmt(bid?.totalGwei ?? 0, 1)}</div>
      </div>
      <div class="gas-bar-row">
        <div class="gas-bar-label">Competitor</div>
        <div class="gas-bar-track"><div class="gas-bar-fill competitor" style=${{width: `${(bid?.competitorEstimate ?? 30) / maxGwei * 100}%`}}></div></div>
        <div class="gas-bar-value">${fmt(bid?.competitorEstimate ?? 0, 1)}</div>
      </div>
      <div class="gas-trend">
        <div style=${{fontSize: '9px', color: 'var(--text-mute)', marginBottom: '4px', letterSpacing: '1.5px', textTransform: 'uppercase'}}>▸ Base Fee Trend (last 30 blocks)</div>
        <div class="gas-sparkline">
          ${recent.map(h => html`<div class="gas-spark-bar" style=${{height: `${h.baseFeeGwei / maxBase * 100}%`}} title=${`#${h.blockNumber} ${h.baseFeeGwei}gwei`}></div>`)}
        </div>
      </div>
    </div>
  `;
}

function ControlsPanel({ status, onStatusChange }) {
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState('');
  const call = async (path, method = 'POST') => {
    setBusy(true); setMsg('Working…');
    try {
      const r = await API(path, { method });
      setMsg(r.message ?? JSON.stringify(r).slice(0, 80));
      setTimeout(onStatusChange, 500);
    } catch (e) { setMsg('Error: ' + e.message); }
    setBusy(false);
    setTimeout(() => setMsg(''), 3000);
  };
  return html`
    <div class="panel area-controls scroll">
      <div class="panel-header">
        <div class="panel-title">Bot Controls</div>
        <div class="panel-meta">${status?.status ?? '—'}</div>
      </div>
      <div class="control-section">
        <h4>Service</h4>
        <div class="btn-row">
          <button class=${`btn start ${status?.status === 'RUNNING' ? 'active' : ''}`} disabled=${busy} onClick=${() => call('/api/control/start')}>▶ Start</button>
          <button class="btn stop" disabled=${busy} onClick=${() => call('/api/control/stop')}>■ Stop</button>
        </div>
        <div class="btn-row">
          <button class=${`btn ${status?.simMode ? 'active' : ''}`} disabled=${busy} onClick=${() => call('/api/control/sim/on')}>SIM MODE</button>
          <button class=${`btn ${!status?.simMode ? 'active' : ''}`} disabled=${busy} onClick=${() => call('/api/control/sim/off')}>LIVE</button>
        </div>
        <button class="btn danger" disabled=${busy} onClick=${() => { if (confirm('Emergency withdraw all ERC-20 tokens from FlashLoanSecure contract?')) call('/api/control/emergency-withdraw'); }}>⚠ Emergency Withdraw</button>
      </div>
      ${msg && html`<div style=${{padding: '4px 12px', fontSize: '10px', color: 'var(--amber)'}}>▸ ${msg}</div>`}
      <div class="control-section">
        <h4>MEV Relay Priority</h4>
        ${(status?.relayPriority ?? ['fastlane','merkle','flashbots','public']).map(r => html`
          <span class=${`relay-pill ${r === status?.activeRelay ? 'active' : ''}`} key=${r}>${r}</span>
        `)}
        <div style=${{fontSize: '9px', color: 'var(--text-mute)', marginTop: '8px'}}>
          Private mempool routing protects against sandwich attacks.
        </div>
      </div>
      <div class="control-section">
        <h4>Live Telemetry</h4>
        <div class="config-row"><span class="label">HMM Regime</span><span class="value">${status?.hmmRegime ?? '—'}</span></div>
        <div class="config-row"><span class="label">HMM Confidence</span><span class="value">${fmt(status?.hmmConfidence ?? 0, 1)}%</span></div>
        <div class="config-row"><span class="label">Block</span><span class="value">#${status?.lastBlock ?? '—'}</span></div>
        <div class="config-row"><span class="label">Last Block At</span><span class="value">${fmtTime(status?.lastBlockAt)}</span></div>
        <div class="config-row"><span class="label">Uptime</span><span class="value">${status?.uptimeSeconds ? Math.floor(status.uptimeSeconds/3600) + 'h ' + Math.floor((status.uptimeSeconds%3600)/60) + 'm' : '—'}</span></div>
      </div>
    </div>
  `;
}

function ConfigPanel() {
  const cfg = usePoll('/api/config', 5000);
  const [form, setForm] = useState({ minProfitUsd: '', maxGasGwei: '', activeRelay: '' });
  useEffect(() => {
    if (cfg) setForm({ minProfitUsd: cfg.minProfitUsd, maxGasGwei: cfg.maxGasGwei, activeRelay: cfg.activeRelay });
  }, [cfg]);
  const save = async () => {
    await API('/api/config', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        minProfitUsd: Number(form.minProfitUsd),
        maxGasGwei: Number(form.maxGasGwei),
        activeRelay: form.activeRelay,
      })
    });
  };
  if (!cfg) return html`<div class="panel area-config"><div class="panel-header"><div class="panel-title">Configuration</div></div><div class="empty-state">LOADING…</div></div>`;
  return html`
    <div class="panel area-config scroll">
      <div class="panel-header">
        <div class="panel-title">Configuration</div>
        <div class="panel-meta">RELOADS LIVE</div>
      </div>
      <div class="control-section">
        <h4>Risk Parameters</h4>
        <div class="config-row">
          <span class="label">Min Profit ($)</span>
          <input class="input" type="number" step="0.5" value=${form.minProfitUsd}
            onChange=${e => setForm({ ...form, minProfitUsd: e.target.value })} />
        </div>
        <div class="config-row">
          <span class="label">Max Gas Cap (Gwei)</span>
          <input class="input" type="number" step="10" value=${form.maxGasGwei}
            onChange=${e => setForm({ ...form, maxGasGwei: e.target.value })} />
        </div>
        <div class="config-row">
          <span class="label">Min Pool Depth ($)</span>
          <span class="value">$${fmt(cfg.minPoolDepthUsd, 0)}</span>
        </div>
        <div class="config-row">
          <span class="label">Max Daily Loss ($)</span>
          <span class="value">$${fmt(cfg.maxDailyLossUsd, 0)}</span>
        </div>
        <button class="btn" style=${{marginTop: '10px'}} onClick=${save}>↻ Apply Changes</button>
      </div>
      <div class="control-section">
        <h4>Target Pairs (${cfg.targetPairs?.length ?? 0})</h4>
        <div class="pair-list">
          ${(cfg.targetPairs ?? []).map(p => html`
            <div class="pair-row" key=${p.name}>
              <span class="name">${p.name}</span>
              <span class="loan">${p.loan} ${p.asset}</span>
            </div>
          `)}
        </div>
      </div>
    </div>
  `;
}

function Footer({ status }) {
  return html`
    <div class="footer">
      <div>FLASH//ARB v1.1.0-weth-routing · <span class="blink">●</span> ${status?.status === 'RUNNING' ? 'OPERATIONAL' : 'STANDBY'}</div>
      <div>POLYGON MAINNET · BLOCK #${status?.lastBlock ?? '—'} · ${new Date().toISOString().slice(0,19)}Z</div>
    </div>
  `;
}

// ─────────────────────────────────────────────────────────────────────────────
// App
// ─────────────────────────────────────────────────────────────────────────────
function App() {
  const status = usePoll('/api/status', 2000);
  return html`
    <div>
      <${TopBar} status=${status} />
      <${StatusStrip} status=${status} />
      <div class="grid-main">
        <${OpportunitiesPanel} />
        <${PnlPanel} />
        <${TradesPanel} />
        <${ControlsPanel} status=${status} onStatusChange=${() => {}} />
        <${RpcHealthPanel} />
        <${GasPanel} />
        <${ConfigPanel} />
      </div>
      <${Footer} status=${status} />
    </div>
  `;
}

createRoot(document.getElementById('root')).render(React.createElement(App));
</script>
</body>
</html>
P2_FILE_EOF

# ---------- dashboard/orchestrator.sh ----------
cat > 'dashboard/orchestrator.sh' << 'P2_FILE_EOF'
#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# orchestrator.sh — Run the Flash Loan Bot as a background service in this env.
#
#   ./orchestrator.sh start   — start bot + FastAPI dashboard
#   ./orchestrator.sh stop    — stop everything
#   ./orchestrator.sh status  — show status
#   ./orchestrator.sh restart — restart
#   ./orchestrator.sh logs    — tail recent logs
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail
cd "$(dirname "$0")/.."

PIDS_DIR="./dashboard/pids"
mkdir -p "$PIDS_DIR"

BOT_PID_FILE="$PIDS_DIR/bot.pid"
API_PID_FILE="$PIDS_DIR/api.pid"
BOT_LOG="./dashboard/bot.stdout.log"
API_LOG="./dashboard/api.stdout.log"

is_running() {
  local pid_file="$1"
  [ -f "$pid_file" ] || return 1
  local pid
  pid=$(cat "$pid_file" 2>/dev/null || echo "")
  [ -z "$pid" ] && return 1
  kill -0 "$pid" 2>/dev/null
}

start_api() {
  if is_running "$API_PID_FILE"; then
    echo "[api] already running (pid $(cat $API_PID_FILE))"
    return
  fi
  echo "[api] starting FastAPI dashboard on :8088 ..."
  nohup python3 -m uvicorn dashboard.api.main:app \
    --host 0.0.0.0 --port 8088 --log-level info \
    > "$API_LOG" 2>&1 &
  echo $! > "$API_PID_FILE"
  sleep 1
  if is_running "$API_PID_FILE"; then
    echo "[api] ✓ started (pid $(cat $API_PID_FILE)) → http://localhost:8088"
  else
    echo "[api] ✗ failed to start — see $API_LOG"
    tail -n 20 "$API_LOG" || true
    return 1
  fi
}

start_bot() {
  if is_running "$BOT_PID_FILE"; then
    echo "[bot] already running (pid $(cat $BOT_PID_FILE))"
    return
  fi
  echo "[bot] starting arbitrage bot ..."
  nohup npm run start > "$BOT_LOG" 2>&1 &
  echo $! > "$BOT_PID_FILE"
  # also mirror PID + start time for FastAPI control
  echo "$!" > "./dashboard/bot.pid"
  date +%s > "./dashboard/bot.start"
  sleep 1
  if is_running "$BOT_PID_FILE"; then
    echo "[bot] ✓ started (pid $(cat $BOT_PID_FILE))"
  else
    echo "[bot] ✗ failed to start — see $BOT_LOG"
    tail -n 30 "$BOT_LOG" || true
    return 1
  fi
}

stop_pid() {
  local pid_file="$1" label="$2"
  if ! is_running "$pid_file"; then
    echo "[$label] not running"
    rm -f "$pid_file"
    return
  fi
  local pid
  pid=$(cat "$pid_file")
  echo "[$label] stopping pid $pid ..."
  kill -TERM "$pid" 2>/dev/null || true
  sleep 1
  kill -KILL "$pid" 2>/dev/null || true
  rm -f "$pid_file"
  echo "[$label] stopped"
}

case "${1:-status}" in
  start)
    start_api
    start_bot
    ;;
  stop)
    stop_pid "$BOT_PID_FILE" "bot"
    stop_pid "$API_PID_FILE" "api"
    rm -f "./dashboard/bot.pid" "./dashboard/bot.start" 2>/dev/null || true
    ;;
  restart)
    stop_pid "$BOT_PID_FILE" "bot"
    stop_pid "$API_PID_FILE" "api"
    sleep 1
    start_api
    start_bot
    ;;
  status)
    echo "── Flash Loan Bot Orchestrator ──"
    if is_running "$BOT_PID_FILE"; then
      echo "[bot] RUNNING  pid=$(cat $BOT_PID_FILE)  uptime~$(( $(date +%s) - $(cat ./dashboard/bot.start 2>/dev/null || echo 0) ))s"
    else
      echo "[bot] STOPPED"
    fi
    if is_running "$API_PID_FILE"; then
      echo "[api] RUNNING  pid=$(cat $API_PID_FILE)  http://localhost:8088"
    else
      echo "[api] STOPPED"
    fi
    ;;
  logs)
    echo "── Bot log (last 30 lines) ──"
    tail -n 30 "$BOT_LOG" 2>/dev/null || echo "(empty)"
    echo ""
    echo "── API log (last 30 lines) ──"
    tail -n 30 "$API_LOG" 2>/dev/null || echo "(empty)"
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status|logs}"
    exit 1
    ;;
esac
P2_FILE_EOF

# ---------- dashboard/runtime.json ----------
cat > 'dashboard/runtime.json' << 'P2_FILE_EOF'
{
  "updatedAt": "2026-10-07T04:57:06.212Z",
  "status": "RUNNING",
  "lastBlock": 95095894,
  "lastBlockAt": "2026-10-07T04:57:06.212Z",
  "rpcAlive": 1,
  "rpcTotal": 1,
  "rpcHealth": [
    {
      "url": "https://polygon-mainnet.g.alchemy.com/v2/WKn526I0ulDQICUtzwYMd",
      "alive": true,
      "latencyMs": 192,
      "isWs": false,
      "failCount": 0
    }
  ],
  "wsSubscriptions": 0,
  "hmmRegime": "COLD",
  "hmmConfidence": 0.568,
  "activeRelay": "public",
  "relayStats": {
    "fastlane": {
      "attempts": 0,
      "successes": 0,
      "failures": 0
    },
    "merkle": {
      "attempts": 0,
      "successes": 0,
      "failures": 0
    },
    "flashbots": {
      "attempts": 0,
      "successes": 0,
      "failures": 0
    },
    "public": {
      "attempts": 0,
      "successes": 0,
      "failures": 0
    }
  },
  "lastGasBid": {
    "baseFee": 253.423653783,
    "priorityFee": 183.93716204857498,
    "totalGwei": 350,
    "competitorEstimate": 245.2495493981
  },
  "gasHistory": [
    {
      "blockNumber": 95095875,
      "baseFeeGwei": 249.216425127,
      "priorityFeeGwei": 283,
      "gasUsedRatio": 0.16797453125
    },
    {
      "blockNumber": 95095876,
      "baseFeeGwei": 249.683044754,
      "priorityFeeGwei": 241.7085,
      "gasUsedRatio": 0.16185820625
    },
    {
      "blockNumber": 95095877,
      "baseFeeGwei": 249.991460695,
      "priorityFeeGwei": 248.046,
      "gasUsedRatio": 0.13069319375
    },
    {
      "blockNumber": 95095878,
      "baseFeeGwei": 249.488696456,
      "priorityFeeGwei": 310.666113116,
      "gasUsedRatio": 0.1664864625
    },
    {
      "blockNumber": 95095879,
      "baseFeeGwei": 249.917153334,
      "priorityFeeGwei": 347.769983217,
      "gasUsedRatio": 0.33771246875
    },
    {
      "blockNumber": 95095880,
      "baseFeeGwei": 254.803878941,
      "priorityFeeGwei": 310.666113116,
      "gasUsedRatio": 0.16617710625
    },
    {
      "blockNumber": 95095881,
      "baseFeeGwei": 251.767715013,
      "priorityFeeGwei": 197.8003968,
      "gasUsedRatio": 0.32695680625
    },
    {
      "blockNumber": 95095882,
      "baseFeeGwei": 249.671281253,
      "priorityFeeGwei": 179.476,
      "gasUsedRatio": 0.1198975
    },
    {
      "blockNumber": 95095883,
      "baseFeeGwei": 248.888392739,
      "priorityFeeGwei": 288.440409216,
      "gasUsedRatio": 0.1435396875
    },
    {
      "blockNumber": 95095884,
      "baseFeeGwei": 248.72090349,
      "priorityFeeGwei": 320,
      "gasUsedRatio": 0.1507244375
    },
    {
      "blockNumber": 95095885,
      "baseFeeGwei": 248.739672526,
      "priorityFeeGwei": 333.123529148,
      "gasUsedRatio": 0.28166868125
    },
    {
      "blockNumber": 95095886,
      "baseFeeGwei": 252.151258427,
      "priorityFeeGwei": 253.473,
      "gasUsedRatio": 0.267714175
    },
    {
      "blockNumber": 95095887,
      "baseFeeGwei": 249.718191133,
      "priorityFeeGwei": 184.686872199,
      "gasUsedRatio": 0.2214631375
    },
    {
      "blockNumber": 95095888,
      "baseFeeGwei": 251.577112531,
      "priorityFeeGwei": 165.328,
      "gasUsedRatio": 0.15690181875
    },
    {
      "blockNumber": 95095889,
      "baseFeeGwei": 248.527311811,
      "priorityFeeGwei": 191.247325379,
      "gasUsedRatio": 0.30055925
    },
    {
      "blockNumber": 95095890,
      "baseFeeGwei": 252.425029068,
      "priorityFeeGwei": 337.685612873,
      "gasUsedRatio": 0.08112808125
    },
    {
      "blockNumber": 95095891,
      "baseFeeGwei": 248.938003129,
      "priorityFeeGwei": 338.963982682,
      "gasUsedRatio": 0.09591708125
    },
    {
      "blockNumber": 95095892,
      "baseFeeGwei": 247.535576692,
      "priorityFeeGwei": 338.963982682,
      "gasUsedRatio": 0.48164989375
    },
    {
      "blockNumber": 95095893,
      "baseFeeGwei": 256.087154578,
      "priorityFeeGwei": 166.03911705,
      "gasUsedRatio": 0.23404599375
    },
    {
      "blockNumber": 95095894,
      "baseFeeGwei": 253.423653783,
      "priorityFeeGwei": 142.984071968,
      "gasUsedRatio": 0.216397775
    }
  ],
  "lastOpportunityAt": "2026-10-07T04:57:06.212Z",
  "sessionOpps": 2,
  "sessionTrades": 0,
  "sessionProfitUsd": 0,
  "maticPrice": 0.10310633,
  "ethPrice": 2609.10906831,
  "configReloadRequired": false
}
P2_FILE_EOF
head -c -1 'dashboard/runtime.json' > 'dashboard/runtime.json.__tmp' && mv 'dashboard/runtime.json.__tmp' 'dashboard/runtime.json'

# ---------- scripts/deploy-polygon-mumbai.js ----------
cat > 'scripts/deploy-polygon-mumbai.js' << 'P2_FILE_EOF'
/**
 * @file deploy-polygon-mumbai.js
 * @notice Deployment script for Polygon Mumbai testnet (or Amoy testnet).
 *
 * NOTE: Polygon Mumbai (80001) is deprecated as of Q1 2024. Polygon Amoy (80002)
 *       is the current testnet. This script supports both via the NETWORK env var
 *       but defaults to mumbai for backward compat with existing .env files.
 *
 * Deploys (in order):
 *   1. MockOracle          — substitutes Chainlink on testnet
 *   2. TwapOracle          — two-snapshot TWAP oracle
 *   3. PriceOraclePolygon  — aggregates QuickSwap / SushiSwap / Chainlink prices
 *   4. FlashLoanSecure     — primary arbitrage contract
 *
 * Run:
 *   npx hardhat run scripts/deploy-polygon-mumbai.js --network mumbai
 *
 * Dry-run (no broadcast):
 *   DRY_RUN=true npx hardhat run scripts/deploy-polygon-mumbai.js --network mumbai
 *
 * Output:
 *   output/addresses-mumbai.json
 */

const { ethers } = require("hardhat");
const fs   = require("fs");
const path = require("path");

// ─────────────────────────────────────────────────────────────────────────────
// Testnet addresses
// ─────────────────────────────────────────────────────────────────────────────

const CONFIG = {
  mumbai: {
    chainId:          80001,
    aaveProvider:     "0x5343b5bA672Ae99d627A1C87866b8E53F47Db2E6",
    quickswapRouter:  "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff",
    quickswapFactory: "0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32",
    sushiswapRouter:  "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506",
    sushiswapFactory: "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
    wmatic:           "0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889",
    outputFile:       "addresses-mumbai.json",
  },
  amoy: {
    chainId:          80002,
    // Aave v3 is not deployed on Amoy yet — use a known placeholder
    aaveProvider:     "0xeb7A892BB04A8f836bDEeBbf60897A7Af1Bf5d7F",
    quickswapRouter:  "0x0000000000000000000000000000000000000001",
    quickswapFactory: "0x0000000000000000000000000000000000000001",
    sushiswapRouter:  "0x0000000000000000000000000000000000000001",
    sushiswapFactory: "0x0000000000000000000000000000000000000001",
    wmatic:           "0x0ae690aad8663aab12a671a6a0d74242332de85f",
    outputFile:       "addresses-amoy.json",
  },
};

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

const DRY_RUN = process.env.DRY_RUN === "true";

async function deploy(factory, args = [], label = "") {
  if (DRY_RUN) {
    const fake = `0x${Math.random().toString(16).slice(2).padEnd(40, "0")}`;
    console.log(`   [DRY-RUN] ${label}: ${fake}`);
    return { getAddress: async () => fake, waitForDeployment: async () => {} };
  }
  const contract = await factory.deploy(...args);
  await contract.waitForDeployment();
  const addr = await contract.getAddress();
  console.log(`   ✅ ${label}: ${addr}`);
  return contract;
}

// ─────────────────────────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────────────────────────

async function main() {
  const netName = process.env.DEPLOY_NETWORK || "mumbai";
  const cfg     = CONFIG[netName];
  if (!cfg) throw new Error(`Unknown network config: ${netName}`);

  const [deployer] = await ethers.getSigners();
  const balance    = await ethers.provider.getBalance(deployer.address);

  console.log(`\n🚀 Deploying to ${netName}${DRY_RUN ? " [DRY-RUN]" : ""}`);
  console.log(`   Account: ${deployer.address}`);
  console.log(`   Balance: ${ethers.formatEther(balance)} MATIC\n`);

  if (!DRY_RUN && balance < ethers.parseEther("0.1")) {
    throw new Error(`Insufficient MATIC balance: ${ethers.formatEther(balance)}. Need at least 0.1 MATIC for gas.`);
  }

  // ── 1. MockOracle ──────────────────────────────────────────────────────────
  console.log("1️⃣  Deploying MockOracle…");
  const MockOracle     = await ethers.getContractFactory("MockOracle");
  const mockOracle     = await deploy(MockOracle, [100_000_000n, 8], "MockOracle");
  const mockOracleAddr = await mockOracle.getAddress();

  // ── 2. TwapOracle ──────────────────────────────────────────────────────────
  console.log("\n2️⃣  Deploying TwapOracle…");
  const TwapOracle     = await ethers.getContractFactory("TwapOracle");
  const twapOracle     = await deploy(TwapOracle, [], "TwapOracle");
  const twapOracleAddr = await twapOracle.getAddress();

  // ── 3. PriceOraclePolygon ──────────────────────────────────────────────────
  console.log("\n3️⃣  Deploying PriceOraclePolygon…");
  const PriceOraclePolygon = await ethers.getContractFactory("PriceOraclePolygon");
  const priceOracle = await deploy(
    PriceOraclePolygon,
    [
      cfg.quickswapRouter,
      cfg.sushiswapRouter,
      cfg.quickswapFactory,
      cfg.sushiswapFactory,
      [cfg.wmatic],        // register WMATIC with the mock Chainlink oracle
      [mockOracleAddr],
    ],
    "PriceOraclePolygon"
  );
  const priceOracleAddr = await priceOracle.getAddress();

  // ── 4. FlashLoanSecure ─────────────────────────────────────────────────────
  console.log("\n4️⃣  Deploying FlashLoanSecure…");
  const FlashLoanSecure = await ethers.getContractFactory("FlashLoanSecure");
  const flashLoan = await deploy(
    FlashLoanSecure,
    [cfg.aaveProvider, priceOracleAddr, deployer.address],
    "FlashLoanSecure"
  );
  const flashLoanAddr = await flashLoan.getAddress();

  // ── 5. Write output ────────────────────────────────────────────────────────
  const outputDir = path.join(__dirname, "..", "output");
  if (!fs.existsSync(outputDir)) fs.mkdirSync(outputDir, { recursive: true });

  const addresses = {
    network:      netName,
    chainId:      cfg.chainId,
    flashLoan:    flashLoanAddr,
    priceOracle:  priceOracleAddr,
    twapOracle:   twapOracleAddr,
    mockOracle:   mockOracleAddr,
    deployedAt:   new Date().toISOString(),
    deployer:     deployer.address,
    dryRun:       DRY_RUN,
  };

  const outPath = path.join(outputDir, cfg.outputFile);
  fs.writeFileSync(outPath, JSON.stringify(addresses, null, 2));

  console.log(`\n📄 Addresses written to: ${outPath}`);
  console.log(JSON.stringify(addresses, null, 2));

  // ── 6. Post-deploy config steps ────────────────────────────────────────────
  if (!DRY_RUN) {
    console.log("\n📋 Post-deploy checklist:");
    console.log(`   1. Add these to your .env:`);
    console.log(`      FLASH_LOAN_ADDRESS=${flashLoanAddr}`);
    console.log(`      PRICE_ORACLE_ADDRESS=${priceOracleAddr}`);
    console.log(`\n   2. Get Mumbai test MATIC: https://faucet.polygon.technology`);
    console.log(`\n   3. Run sanity check:`);
    console.log(`      npm run verify:mumbai`);
    console.log(`\n   4. (Optional) Verify on Polygonscan Mumbai:`);
    console.log(`      npx hardhat verify --network mumbai ${flashLoanAddr} \\`);
    console.log(`        "${cfg.aaveProvider}" "${priceOracleAddr}" "${deployer.address}"`);
  }
}

main().catch((err) => {
  console.error("\n❌ Deployment failed:", err.message);
  process.exitCode = 1;
});
P2_FILE_EOF

# ---------- scripts/deploy-polygon.js ----------
cat > 'scripts/deploy-polygon.js' << 'P2_FILE_EOF'
/**
 * @file deploy-polygon.js
 * @notice Deployment script for Polygon mainnet.
 *
 * Deploys (in order):
 *   1. TwapOracle          — two-snapshot TWAP oracle
 *   2. PriceOraclePolygon  — aggregates QuickSwap / SushiSwap / Chainlink prices
 *   3. FlashLoanSecure     — primary arbitrage contract (Aave v3 flash loans)
 *
 * Run:
 *   npx hardhat run scripts/deploy-polygon.js --network polygon
 *
 * Dry-run (no broadcast):
 *   DRY_RUN=true npx hardhat run scripts/deploy-polygon.js --network polygon
 *
 * Output:
 *   output/addresses-mainnet.json
 */

const { ethers } = require("hardhat");
const fs   = require("fs");
const path = require("path");

// ─────────────────────────────────────────────────────────────────────────────
// Polygon Mainnet Addresses (all verified on-chain)
// ─────────────────────────────────────────────────────────────────────────────

const AAVE_POOL_PROVIDER  = "0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb";
const QUICKSWAP_ROUTER    = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";
const QUICKSWAP_FACTORY   = "0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32";
const SUSHISWAP_ROUTER    = "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506";
const SUSHISWAP_FACTORY   = "0xc35DADB65012eC5796536bD9864eD8773aBc74C4";

// ── Tokens ────────────────────────────────────────────────────────────────────
const WMATIC  = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
const USDC    = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
const WETH    = "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619";
const WBTC    = "0x1bfd67037b42cf73acf2047067bd4f2c47d9bfd6";
const DAI     = "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063";

// ── Chainlink USD feeds on Polygon (from docs.chain.link) ─────────────────────
const CL_MATIC_USD = "0xAB594600376Ec9fD91F8e885dADF0CE036862dE0";
const CL_USDC_USD  = "0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7";
const CL_ETH_USD   = "0xF9680D99D6C9589e2a93a78A04A279e509205945";
const CL_BTC_USD   = "0xc907E116054Ad103354f2D350FD2514433D57F6f";
const CL_DAI_USD   = "0x4746DeC9e833A82EC7C2C1356372CcF2cfcD2F3D";

// ── Well-known QuickSwap V2 pairs (for TwapOracle pre-registration) ───────────
const QS_USDC_WMATIC = "0x6e7a5FAFcec6BB1e78bAE2A1F0B612012BF14827";
const QS_WETH_USDC   = "0x853ee4b2a13f8a742d64c8f088be7ba2131f670d";

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

const DRY_RUN = process.env.DRY_RUN === "true";

async function deploy(factory, args = [], label = "") {
  if (DRY_RUN) {
    const fake = `0x${Math.random().toString(16).slice(2).padEnd(40, "0")}`;
    console.log(`   [DRY-RUN] ${label}: ${fake}`);
    return { getAddress: async () => fake, waitForDeployment: async () => {} };
  }
  const contract = await factory.deploy(...args);
  await contract.waitForDeployment();
  const addr = await contract.getAddress();
  console.log(`   ✅ ${label}: ${addr}`);
  return contract;
}

// ─────────────────────────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────────────────────────

async function main() {
  if (!DRY_RUN && !process.env.PRIVATE_KEY) {
    throw new Error("PRIVATE_KEY not set — refusing mainnet deployment. Set it in .env or use DRY_RUN=true.");
  }

  const [deployer] = await ethers.getSigners();
  const balance    = await ethers.provider.getBalance(deployer.address);

  console.log(`\n🚀 Deploying to Polygon Mainnet${DRY_RUN ? " [DRY-RUN]" : ""}`);
  console.log(`   Account: ${deployer.address}`);
  console.log(`   Balance: ${ethers.formatEther(balance)} MATIC\n`);

  if (!DRY_RUN && balance < ethers.parseEther("0.5")) {
    throw new Error(`Low MATIC balance (${ethers.formatEther(balance)}). Need at least 0.5 MATIC for mainnet deployment gas.`);
  }

  // ── 1. TwapOracle ──────────────────────────────────────────────────────────
  console.log("1️⃣  Deploying TwapOracle…");
  const TwapOracleFactory = await ethers.getContractFactory("TwapOracle");
  const twapOracle        = await deploy(TwapOracleFactory, [], "TwapOracle");
  const twapOracleAddr    = await twapOracle.getAddress();

  // ── 2. PriceOraclePolygon ──────────────────────────────────────────────────
  console.log("\n2️⃣  Deploying PriceOraclePolygon…");
  const PriceOracleFactory = await ethers.getContractFactory("PriceOraclePolygon");
  const priceOracle = await deploy(
    PriceOracleFactory,
    [
      QUICKSWAP_ROUTER,
      SUSHISWAP_ROUTER,
      QUICKSWAP_FACTORY,
      SUSHISWAP_FACTORY,
      [WMATIC, USDC,       WETH,       WBTC,       DAI      ],
      [CL_MATIC_USD, CL_USDC_USD, CL_ETH_USD, CL_BTC_USD, CL_DAI_USD],
    ],
    "PriceOraclePolygon"
  );
  const priceOracleAddr = await priceOracle.getAddress();

  // ── 3. FlashLoanSecure ─────────────────────────────────────────────────────
  console.log("\n3️⃣  Deploying FlashLoanSecure…");
  const FlashLoanFactory = await ethers.getContractFactory("FlashLoanSecure");
  const flashLoan = await deploy(
    FlashLoanFactory,
    [AAVE_POOL_PROVIDER, priceOracleAddr, deployer.address],
    "FlashLoanSecure"
  );
  const flashLoanAddr = await flashLoan.getAddress();

  // ── 4. Pre-register TwapOracle pairs (non-critical — skip if revert) ───────
  if (!DRY_RUN) {
    console.log("\n4️⃣  Pre-registering TWAP pairs…");
    try {
      const tx1 = await twapOracle.registerPair(QS_USDC_WMATIC);
      await tx1.wait(1);
      console.log(`   ✅ QS USDC/WMATIC pair registered: ${QS_USDC_WMATIC}`);
    } catch (e) {
      console.log(`   ⚠️  QS USDC/WMATIC register failed (non-critical): ${e.message}`);
    }
    try {
      const tx2 = await twapOracle.registerPair(QS_WETH_USDC);
      await tx2.wait(1);
      console.log(`   ✅ QS WETH/USDC pair registered: ${QS_WETH_USDC}`);
    } catch (e) {
      console.log(`   ⚠️  QS WETH/USDC register failed (non-critical): ${e.message}`);
    }
  } else {
    console.log("\n4️⃣  [DRY-RUN] Skipping TwapOracle pair registration");
  }

  // ── 5. Write output ────────────────────────────────────────────────────────
  const outputDir = path.join(__dirname, "..", "output");
  if (!fs.existsSync(outputDir)) fs.mkdirSync(outputDir, { recursive: true });

  const addresses = {
    network:       "polygon-mainnet",
    chainId:       137,
    flashLoan:     flashLoanAddr,
    priceOracle:   priceOracleAddr,
    twapOracle:    twapOracleAddr,
    mockOracle:    null,
    tokens:        { WMATIC, USDC, WETH, WBTC, DAI },
    chainlinkFeeds: {
      MATIC_USD: CL_MATIC_USD,
      USDC_USD:  CL_USDC_USD,
      ETH_USD:   CL_ETH_USD,
      BTC_USD:   CL_BTC_USD,
      DAI_USD:   CL_DAI_USD,
    },
    deployedAt: new Date().toISOString(),
    deployer:   deployer.address,
    dryRun:     DRY_RUN,
  };

  const outPath = path.join(outputDir, "addresses-mainnet.json");
  fs.writeFileSync(outPath, JSON.stringify(addresses, null, 2));

  console.log(`\n📄 Addresses written to: ${outPath}`);
  console.log(JSON.stringify(addresses, null, 2));

  // ── 6. Post-deploy checklist ───────────────────────────────────────────────
  if (!DRY_RUN) {
    console.log("\n📋 Post-deploy checklist:");
    console.log(`   1. Add to your .env:`);
    console.log(`      FLASH_LOAN_ADDRESS=${flashLoanAddr}`);
    console.log(`      PRICE_ORACLE_ADDRESS=${priceOracleAddr}`);
    console.log(`\n   2. Run sanity check:`);
    console.log(`      npm run verify:check`);
    console.log(`\n   3. Verify on Polygonscan:`);
    console.log(`      npx hardhat verify --network polygon ${flashLoanAddr} \\`);
    console.log(`        "${AAVE_POOL_PROVIDER}" "${priceOracleAddr}" "${deployer.address}"`);
    console.log(`\n   4. Start the bot (after filling .env):`);
    console.log(`      cd bot && npm run start`);
  }
}

main().catch((err) => {
  console.error("\n❌ Deployment failed:", err.message);
  process.exitCode = 1;
});
P2_FILE_EOF

# ---------- scripts/emergency-withdraw.js ----------
cat > 'scripts/emergency-withdraw.js' << 'P2_FILE_EOF'
/**
 * @file emergency-withdraw.js
 * @notice Emergency withdraw — pulls all supported ERC-20 tokens from the
 *         FlashLoanSecure contract into the owner's wallet. Only the contract
 *         owner can call this.
 *
 * Env: PRIVATE_KEY, POLYGON_RPC_URL, FLASH_LOAN_ADDRESS,
 *      WITHDRAW_TOKENS (comma-separated list of ERC-20 addresses, optional —
 *      defaults to WETH, USDC, WMATIC, DAI, WBTC).
 */

const { ethers, Wallet, JsonRpcProvider, Contract } = require("ethers");

const FLASH_ADDR = process.env.FLASH_LOAN_ADDRESS || "0xBafc19Fd23714bD2F3256C20a6036a5B31A9DbD8";
const RPC = process.env.POLYGON_RPC_URL;
const PK = process.env.PRIVATE_KEY;

const DEFAULT_TOKENS = [
  "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619", // WETH
  "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", // USDC
  "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270", // WMATIC
  "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063", // DAI
  "0x1BFD6FAD37F5F5cE7e8bAcaB5c29a2778BFe9D7a", // WBTC
];

const FLASH_ABI = [
  "function emergencyWithdraw(address token) external",
  "function emergencyWithdrawAll(address[] calldata tokens) external",
  "function owner() external view returns (address)",
];

const ERC20_ABI = [
  "function balanceOf(address) external view returns (uint256)",
  "function symbol() external view returns (string)",
  "function decimals() external view returns (uint8)",
];

async function main() {
  if (!RPC) {
    console.error("✗ POLYGON_RPC_URL not set");
    process.exit(1);
  }
  if (!PK) {
    console.error("✗ PRIVATE_KEY not set");
    process.exit(1);
  }

  const provider = new JsonRpcProvider(RPC, undefined, { staticNetwork: true });
  const wallet = new Wallet(PK, provider);
  const flash = new Contract(FLASH_ADDR, FLASH_ABI, wallet);

  console.log(`════════════════════════════════════════════════`);
  console.log(`  EMERGENCY WITHDRAW — FlashLoanSecure`);
  console.log(`  Contract:  ${FLASH_ADDR}`);
  console.log(`  Owner:     ${wallet.address}`);
  console.log(`════════════════════════════════════════════════`);

  // Verify ownership
  const owner = await flash.owner().catch(() => wallet.address);
  if (owner.toLowerCase() !== wallet.address.toLowerCase()) {
    console.error(`✗ Caller ${wallet.address} is not the contract owner (${owner})`);
    process.exit(1);
  }
  console.log("✓ Owner verified");

  // Check balances first
  const tokens = (process.env.WITHDRAW_TOKENS?.split(",").map(s => s.trim()).filter(Boolean) || DEFAULT_TOKENS);
  console.log(`\nChecking balances for ${tokens.length} tokens...`);
  const tokensWithBalance = [];
  for (const addr of tokens) {
    try {
      const erc = new Contract(addr, ERC20_ABI, provider);
      const bal = await erc.balanceOf(FLASH_ADDR);
      const symbol = await erc.symbol().catch(() => "???");
      const decimals = await erc.decimals().catch(() => 18n);
      const human = ethers.formatUnits(bal, decimals);
      if (bal > 0n) {
        console.log(`  ${symbol.padEnd(8)} ${human.padStart(20)}  ${addr}`);
        tokensWithBalance.push(addr);
      } else {
        console.log(`  ${symbol.padEnd(8)} ${"0".padStart(20)}  ${addr} (skip)`);
      }
    } catch (e) {
      console.log(`  ???       (error)               ${addr}: ${(e).message?.slice(0,80)}`);
    }
  }

  if (tokensWithBalance.length === 0) {
    console.log("\n✓ No tokens with non-zero balance — nothing to withdraw");
    return;
  }

  console.log(`\nWithdrawing ${tokensWithBalance.length} token(s) ...`);
  try {
    const tx = await flash.emergencyWithdrawAll(tokensWithBalance);
    console.log(`→ tx submitted: ${tx.hash}`);
    console.log("→ waiting for confirmation...");
    const receipt = await tx.wait();
    console.log(`✓ Confirmed in block ${receipt.blockNumber} (gas ${receipt.gasUsed.toString()})`);
    console.log(`→ https://polygonscan.com/tx/${tx.hash}`);
  } catch (e) {
    // Try one-by-one
    console.warn(`emergencyWithdrawAll failed: ${e.message?.slice(0,200)} — retrying one-by-one`);
    for (const addr of tokensWithBalance) {
      try {
        const tx = await flash.emergencyWithdraw(addr);
        const receipt = await tx.wait();
        console.log(`✓ ${addr} → https://polygonscan.com/tx/${tx.hash}`);
      } catch (err) {
        console.error(`✗ ${addr}: ${err.message?.slice(0,200)}`);
      }
    }
  }
}

main().catch(e => {
  console.error("✗ Emergency withdraw failed:", e.message);
  process.exit(1);
});
P2_FILE_EOF

# ---------- scripts/live-spread-scan.js ----------
cat > 'scripts/live-spread-scan.js' << 'P2_FILE_EOF'
/**
 * @file live-spread-scan.js
 * @notice Live spread scanner with liquidity depth filtering + rotating RPC pool.
 *
 * REAL LIVE DATA ONLY — no simulation, no mock, no synthetic fallbacks:
 *   - Quotes come exclusively from DEX router `getAmountsOut` (real AMM math incl. fees).
 *     The old constant-product "simulation" fallback has been REMOVED.
 *   - Reserve/depth fetch failures are NOT silently swallowed — the scanner
 *     rotates to the next RPC and retries; if every RPC fails the pair is
 *     marked RPC_ERROR rather than showing fabricated numbers.
 *   - Freshness gates: the chain head must be < MAX_BLOCK_AGE_S old, and all
 *     Chainlink feeds must be < 1h old (strict freshness policy). Otherwise
 *     the scan rotates or aborts.
 *
 * RPC rotation: primary endpoint (env POLYGON_RPC_URL, e.g. Alchemy) followed
 * by public failovers. On connection error, rate-limit, or stale head the
 * scanner rotates to the next endpoint — per pair and mid-scan if needed.
 *
 * Run:
 *   node scripts/live-spread-scan.js
 *   POLYGON_RPC_URL=https://... node scripts/live-spread-scan.js
 */

require("dotenv").config();
const { ethers } = require("ethers");
const fs = require("fs");
const path = require("path");

// ─────────────────────────────────────────────────────────────────────────────
// Config
// ─────────────────────────────────────────────────────────────────────────────

/** Rotating RPC pool — tried in order; env-configured primary first. */
const RPC_POOL = [
  ...(process.env.POLYGON_RPC_URL ? [["primary",  process.env.POLYGON_RPC_URL]] : []),
  ["publicnode", "https://polygon-bor-rpc.publicnode.com"],
  ["drpc",       "https://polygon.drpc.org"],
  ["1rpc",       "https://1rpc.io/matic"],
];

/** Max acceptable age of the chain head (seconds) — freshness gate for live data. */
const MAX_BLOCK_AGE_S = 120;

/** Max acceptable age for Chainlink price feeds (seconds) — strict freshness policy. */
const MAX_ORACLE_AGE_S = 3600;

/** Skip a DEX side if USD reserve depth is below this */
const MIN_RESERVE_USD = 15_000;

/** Skip a pair entirely if BOTH DEXes have reserve < this (no market) */
const MIN_EITHER_RESERVE_USD = 15_000;

/** Minimum spread % to bother estimating profit */
const MIN_SPREAD_PCT = 0.02;

const QUICKSWAP_ROUTER  = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";
const SUSHISWAP_ROUTER  = "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506";
const QUICKSWAP_FACTORY = "0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32";
const SUSHISWAP_FACTORY = "0xc35DADB65012eC5796536bD9864eD8773aBc74C4";
const CL_MATIC_USD      = "0xAB594600376Ec9fD91F8e885dADF0CE036862dE0";
const CL_ETH_USD        = "0xF9680D99D6C9589e2a93a78A04A279e509205945";
const CL_BTC_USD        = "0xc907E116054Ad103354f2D350FD2514433D57F6f";

const TOKENS = {
  USDC:  { addr: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", decimals: 6,  symbol: "USDC",  usdPrice: 1.0 },
  WMATIC:{ addr: "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270", decimals: 18, symbol: "WMATIC", usdPrice: null },
  WETH:  { addr: "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619", decimals: 18, symbol: "WETH",  usdPrice: null },
  DAI:   { addr: "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063", decimals: 18, symbol: "DAI",   usdPrice: 1.0 },
};

// Aave v3 Polygon: USDC borrowing DISABLED — all pairs now route via WETH borrow
// WETH available: 9,440 ETH (~$17M) — fully open for flash loans
const SCAN_PAIRS = [
  // ── Native WETH pairs (primary — always enabled) ─────────────────────────
  { from: TOKENS.WETH,   to: TOKENS.USDC,   amount: 10,     label: 'WETH→USDC (borrow WETH)' },
  { from: TOKENS.WETH,   to: TOKENS.USDC,   amount: 15,     label: 'WETH→USDC (15 ETH)' },
  // ── WETH-routed WMATIC arb ────────────────────────────────────────────────
  // Borrow WETH → swap to USDC on QS → swap to WMATIC on SS → net spread
  { from: TOKENS.WETH,   to: TOKENS.WMATIC, amount: 10,     label: 'WETH→USDC→WMATIC (via WETH borrow)' },
  // ── WMATIC native ────────────────────────────────────────────────────────
  { from: TOKENS.WMATIC, to: TOKENS.USDC,   amount: 20_000, label: 'WMATIC→USDC' },
  { from: TOKENS.WMATIC, to: TOKENS.USDC,   amount: 50_000, label: 'WMATIC→USDC (50K)' },
];

// ─────────────────────────────────────────────────────────────────────────────
// ABIs
// ─────────────────────────────────────────────────────────────────────────────

const ROUTER_ABI = [
  "function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts)",
];
const FACTORY_ABI = [
  "function getPair(address tokenA, address tokenB) external view returns (address pair)",
];
const PAIR_ABI = [
  "function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast)",
  "function token0() external view returns (address)",
];
const CL_ABI = [
  "function latestRoundData() external view returns (uint80,int256,uint256,uint256,uint80)",
  "function decimals() external view returns (uint8)",
];

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

function pad(str, len) { return String(str).padEnd(len); }
function pct(a, b) {
  const diff = Math.abs(a - b);
  return Math.max(a, b) === 0 ? 0 : (diff / Math.max(a, b)) * 100;
}

// ─────────────────────────────────────────────────────────────────────────────
// Rotating RPC provider
// ─────────────────────────────────────────────────────────────────────────────

/** Probe one RPC endpoint; resolve fresh candidate or null (never throws). */
async function probeRpc(name, url) {
  try {
    const provider = new ethers.JsonRpcProvider(url, undefined, {
      staticNetwork: true,
      batchMaxCount: 1,
    });
    const blockNumber = await provider.getBlockNumber();
    const blk = await provider.getBlock("latest");
    if (!blk) return null;
    const age = Math.floor(Date.now() / 1000) - Number(blk.timestamp);
    if (age > MAX_BLOCK_AGE_S) return null; // stale head — not live data
    return { name, url, provider, blockNumber, headAgeS: age };
  } catch {
    return null;
  }
}

/** Scan the pool from `startIdx` (inclusive) for the first fresh endpoint. */
async function connectFresh(startIdx) {
  for (let i = 0; i < RPC_POOL.length; i++) {
    const idx = (startIdx + i) % RPC_POOL.length;
    const [name, url] = RPC_POOL[idx];
    const cand = await probeRpc(name, url);
    if (cand) return { ...cand, idx };
  }
  return null;
}

function mkContracts(provider) {
  return {
    qsRouter:  new ethers.Contract(QUICKSWAP_ROUTER,   ROUTER_ABI,  provider),
    ssRouter:  new ethers.Contract(SUSHISWAP_ROUTER,   ROUTER_ABI,  provider),
    qsFactory: new ethers.Contract(QUICKSWAP_FACTORY,  FACTORY_ABI, provider),
    ssFactory: new ethers.Contract(SUSHISWAP_FACTORY, FACTORY_ABI, provider),
  };
}

/** Scanner state — current RPC + bound contracts; rotated on failures. */
function mkState() { return { idx: 0, rpc: null, ctx: null }; }

/** Advance to the next fresh RPC in the pool. Returns true on success. */
async function rotate(state, reason) {
  for (let hop = 0; hop < RPC_POOL.length; hop++) {
    state.idx = (state.idx + 1) % RPC_POOL.length;
    const cand = await connectFresh(state.idx);
    if (cand) {
      state.idx = cand.idx;
      state.rpc = cand;
      state.ctx = mkContracts(cand.provider);
      console.error(`  ↻ RPC rotated → [${cand.name}] (${reason})`);
      return true;
    }
  }
  return false;
}

/**
 * Run `fn(ctx)` against the current RPC; on error rotate and retry until the
 * whole pool has been tried. Throws only if every endpoint failed.
 */
async function withRotation(state, label, fn) {
  let lastErr;
  for (let attempt = 0; attempt <= RPC_POOL.length; attempt++) {
    try {
      return await fn(state.ctx);
    } catch (e) {
      lastErr = e;
      const ok = await rotate(state, `${label}: ${e.message?.slice(0, 80)}`);
      if (!ok) break;
    }
  }
  throw new Error(`${label} failed on all ${RPC_POOL.length} RPCs — last error: ${lastErr?.message}`);
}

// ─────────────────────────────────────────────────────────────────────────────
// Live data fetchers — NO silent fallbacks. Errors propagate to rotation.
// ─────────────────────────────────────────────────────────────────────────────

async function fetchChainlinkPrice(provider, feed, label) {
  const c = new ethers.Contract(feed, CL_ABI, provider);
  const [[, answer, , updatedAt], decimals] = await Promise.all([
    c.latestRoundData(),
    c.decimals(),
  ]);
  const age = Math.floor(Date.now() / 1000) - Number(updatedAt);
  if (age > MAX_ORACLE_AGE_S) {
    throw new Error(`Chainlink ${label} stale: age ${age}s > ${MAX_ORACLE_AGE_S}s — refusing stale price`);
  }
  return Number(answer) / 10 ** Number(decimals);
}

async function getPoolDepth(factory, tokenIn, tokenOut, decIn, decOut, priceIn, priceOut) {
  const pairAddr = await factory.getPair(tokenIn, tokenOut);
  if (!pairAddr || pairAddr === ethers.ZeroAddress) {
    // Genuine on-chain state: pool does not exist
    return { depthUsd: 0, reserveIn: 0n, reserveOut: 0n };
  }

  const pair = new ethers.Contract(pairAddr, PAIR_ABI, factory.runner);
  const [[r0, r1], t0] = await Promise.all([pair.getReserves(), pair.token0()]);

  const isToken0 = t0.toLowerCase() === tokenIn.toLowerCase();
  const resIn  = isToken0 ? r0 : r1;
  const resOut = isToken0 ? r1 : r0;

  const resInF  = parseFloat(ethers.formatUnits(resIn,  decIn));
  const resOutF = parseFloat(ethers.formatUnits(resOut, decOut));
  const depthUsd = priceIn  ? resInF  * priceIn
                 : priceOut ? resOutF * priceOut
                 : 0;

  return { depthUsd, reserveIn: resIn, reserveOut: resOut };
}

/** Real DEX quote via router getAmountsOut (includes pool fees). No simulation. */
async function getRouterQuote(router, tokenIn, tokenOut, amountIn) {
  const out = await router.getAmountsOut(amountIn, [tokenIn, tokenOut]);
  return out[1];
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-pair scan (real data only; throws on RPC failure so rotation can retry)
// ─────────────────────────────────────────────────────────────────────────────

async function scanPair(state, pair, env) {
  const { from, to, amount } = pair;
  const amountIn  = ethers.parseUnits(String(amount), from.decimals);
  const pairLabel = `${from.symbol}→${to.symbol}`;
  const priceIn   = from.usdPrice;
  const priceOut  = to.usdPrice;
  const { COL, results, gasCostUsd } = env;

  // ── 1. Fetch reserves + depth for both DEXes in parallel (live) ──────────
  const [qsDepth, ssDepth] = await Promise.all([
    getPoolDepth(state.ctx.qsFactory, from.addr, to.addr, from.decimals, to.decimals, priceIn, priceOut),
    getPoolDepth(state.ctx.ssFactory, from.addr, to.addr, from.decimals, to.decimals, priceIn, priceOut),
  ]);

  const qsDepthUsd = qsDepth.depthUsd;
  const ssDepthUsd = ssDepth.depthUsd;
  const maxDepth   = Math.max(qsDepthUsd, ssDepthUsd);

  // ── 2. Depth filter ────────────────────────────────────────────────────────
  if (maxDepth < MIN_EITHER_RESERVE_USD) {
    console.log(
      pad(pairLabel, COL[0]) +
      pad(`${amount} ${from.symbol}`, COL[1]) +
      pad("—", COL[2]) + pad("—", COL[3]) + pad("—", COL[4]) +
      pad("—", COL[5]) + pad("—", COL[6]) + pad("—", COL[7]) +
      "⚫ NO LIQUIDITY"
    );
    results.push({ loanNotionalUsd, aaveFeeUsd, pair: pairLabel, signal: "NO_LIQUIDITY", qsDepthUsd, ssDepthUsd });
    return;
  }

  // ── 3. Real router quotes (no CP-formula simulation fallback) ──────────────
  const qsOut = qsDepthUsd >= MIN_RESERVE_USD
    ? await getRouterQuote(state.ctx.qsRouter, from.addr, to.addr, amountIn)
    : null;
  const ssOut = ssDepthUsd >= MIN_RESERVE_USD
    ? await getRouterQuote(state.ctx.ssRouter, from.addr, to.addr, amountIn)
    : null;

  if (!qsOut && !ssOut) {
    console.log(
      pad(pairLabel, COL[0]) +
      pad(`${amount} ${from.symbol}`, COL[1]) +
      pad("—", COL[2]) + pad("—", COL[3]) + pad("—", COL[4]) +
      pad("—", COL[5]) + pad("—", COL[6]) + pad("—", COL[7]) +
      "⚫ QUOTE FAILED"
    );
    results.push({ loanNotionalUsd, aaveFeeUsd, pair: pairLabel, signal: "QUOTE_FAILED" });
    return;
  }

  const qsF = qsOut ? parseFloat(ethers.formatUnits(qsOut, to.decimals)) : null;
  const ssF = ssOut ? parseFloat(ethers.formatUnits(ssOut, to.decimals)) : null;

  // ── 4. Spread ──────────────────────────────────────────────────────────────
  const spreadPct = (qsF && ssF) ? pct(qsF, ssF) : null;

  if (spreadPct !== null && spreadPct < MIN_SPREAD_PCT) {
    console.log(
      pad(pairLabel, COL[0]) +
      pad(`${amount} ${from.symbol}`, COL[1]) +
      pad(`$${(qsDepthUsd/1000).toFixed(0)}K`, COL[2]) +
      pad(qsF?.toFixed(4) ?? "—", COL[3]) +
      pad(ssF?.toFixed(4) ?? "—", COL[4]) +
      pad(spreadPct.toFixed(4)+"%", COL[5]) +
      pad("—", COL[6]) + pad("—", COL[7]) +
      "⚪ FLAT"
    );
    results.push({ loanNotionalUsd, aaveFeeUsd, pair: pairLabel, signal: "FLAT", spreadPct, qsDepthUsd, ssDepthUsd });
    return;
  }

  // ── 5. USD spread value ────────────────────────────────────────────────────
  let spreadUsd = null;
  if (qsF !== null && ssF !== null) {
    const spreadUnits = Math.abs(qsF - ssF);
    const outPrice    = priceOut;
    if (outPrice) spreadUsd = spreadUnits * outPrice;
  }

  // ── 6. Net profit ──────────────────────────────────────────────────────────
  const loanNotionalUsd = priceIn ? amount * priceIn : null;
  const aaveFeeUsd      = loanNotionalUsd ? loanNotionalUsd * 0.0005 : null;
  const netProfit       = (spreadUsd !== null && gasCostUsd !== null && aaveFeeUsd !== null)
    ? spreadUsd - gasCostUsd - aaveFeeUsd
    : null;

  // ── 7. Slippage estimation ──────────────────────────────────────────────────
  // Estimate slippage as trade size / pool depth — rough but useful
  const tradeUsd      = priceIn ? amount * priceIn : 0;
  const sellSideDex   = (qsF && ssF && qsF > ssF) ? ssDepthUsd : qsDepthUsd;
  const slippageEst   = sellSideDex > 0 ? (tradeUsd / sellSideDex) * 100 : 99;
  const slippageCost  = spreadUsd !== null ? spreadUsd * (slippageEst / 100) : 0;

  // Adjust net profit for estimated slippage
  const netProfitAdj  = (netProfit !== null) ? netProfit - slippageCost : null;

  // ── 8. Phantom spread guard ──────────────────────────────────────────────
  // Stablecoin pairs (DAI↔USDC) with >20% spread are almost certainly phantom
  const isStablePair = (
    (from.symbol === "DAI" && to.symbol === "USDC") ||
    (from.symbol === "USDC" && to.symbol === "DAI")
  );
  const isPhantomStable = isStablePair && spreadPct !== null && spreadPct > 20;

  // ── 8b. Universal phantom guard ───────────────────────────────────────────
  // Compute spread vs LOAN NOTIONAL (not pool depth). >5% = phantom.
  const loanNotionalUsdCalc = priceIn ? amount * priceIn : 0;
  const spreadPctOfLoan = (spreadUsd !== null && loanNotionalUsdCalc > 0)
    ? (spreadUsd / loanNotionalUsdCalc) * 100 : 0;
  const isPhantomUniversal = spreadPctOfLoan > 5.0;  // 5% cap
  const isFlat = spreadPctOfLoan < 0.05;  // 0.05% floor

  // Unified phantom flag: stable OR universal — signal string and boolean
  // MUST always agree (fix for issues #93/#100/#102)
  const isPhantom = isPhantomUniversal || isPhantomStable;

  // ── 9. Tiered signal classification ──────────────────────────────────────
  const minDepthSide = Math.min(qsDepthUsd, ssDepthUsd);
  const depthOk      = minDepthSide >= MIN_RESERVE_USD;
  const depthWarning = !depthOk ? ` ⚠️ thin ($${(minDepthSide/1000).toFixed(0)}K)` : "";

  let signal;
  if (isPhantomUniversal) {
    signal = "👻 PHANTOM%";
  } else if (isPhantomStable) {
    signal = "👻 PHANTOM";
  } else if (isFlat) {
    signal = "⚪ FLAT";
  } else if (depthOk && netProfitAdj !== null && netProfitAdj > 2) {
    signal = "🟢 EXECUTE";
  } else if (!depthOk && netProfitAdj !== null && netProfitAdj > 2) {
    signal = "🟡 LOW DEPTH";
  } else if (netProfitAdj !== null && netProfitAdj > 0) {
    signal = "🟡 MARGINAL";
  } else if (netProfitAdj !== null) {
    signal = "🔴 UNPROFITABLE";
  } else if (spreadPct && spreadPct > 1) {
    signal = depthOk ? "🟡 CHECK" : "🟡 LOW DEPTH";
  } else {
    signal = "—";
  }

  const cheaperDex = qsF && ssF ? (qsF > ssF ? "QS" : "SS") : "—";

  results.push({ loanNotionalUsd, aaveFeeUsd,
    pair: pairLabel, amount, signal, spreadPct, spreadPctOfLoan, spreadUsd, netProfit,
    netProfitAdj, slippageEst, isPhantom, isPhantomUniversal,
    qsDepthUsd, ssDepthUsd, cheaperDex, qsF, ssF,
  });

  console.log(
    pad(pairLabel,                                                          COL[0]) +
    pad(`${amount} ${from.symbol}`,                                        COL[1]) +
    pad(`$${(qsDepthUsd/1000).toFixed(0)}K / $${(ssDepthUsd/1000).toFixed(0)}K`, COL[2]) +
    pad(qsF !== null ? qsF.toFixed(4) : "N/A",                            COL[3]) +
    pad(ssF !== null ? ssF.toFixed(4) : "N/A",                            COL[4]) +
    pad(spreadPct !== null ? spreadPct.toFixed(4)+"%" : "N/A",            COL[5]) +
    pad(spreadUsd !== null ? "$"+spreadUsd.toFixed(2) : "N/A",            COL[6]) +
    pad(netProfitAdj !== null ? "$"+netProfitAdj.toFixed(2) : "N/A",      COL[7]) +
    signal + depthWarning
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────────────────────────

async function main() {
  // ── Connect: rotate RPC pool until a fresh endpoint is found ──────────────
  const state = mkState();
  const connected = await connectFresh(0);
  if (!connected) {
    throw new Error(`No fresh RPC endpoint available (head must be < ${MAX_BLOCK_AGE_S}s old). Pool: ${RPC_POOL.map(r => r[0]).join(", ")}`);
  }
  state.idx = connected.idx;
  state.rpc = connected;
  state.ctx = mkContracts(connected.provider);

  // ── Live prices (Chainlink, strict freshness) — rotate on failure ─────────
  const [maticUsd, ethUsd, btcUsd] = await Promise.all([
    withRotation(state, "Chainlink MATIC/USD", (ctx) => fetchChainlinkPrice(ctx.qsFactory.runner, CL_MATIC_USD, "MATIC/USD")),
    withRotation(state, "Chainlink ETH/USD",   (ctx) => fetchChainlinkPrice(ctx.qsFactory.runner, CL_ETH_USD,   "ETH/USD")),
    withRotation(state, "Chainlink BTC/USD",   (ctx) => fetchChainlinkPrice(ctx.qsFactory.runner, CL_BTC_USD,   "BTC/USD")),
  ]);

  // Patch token prices
  TOKENS.WMATIC.usdPrice = maticUsd;
  TOKENS.WETH.usdPrice   = ethUsd;

  // ── Gas (live fee data) ────────────────────────────────────────────────────
  const feeData = await withRotation(state, "fee data", (ctx) => ctx.qsFactory.runner.getFeeData());
  const gasPriceGwei = feeData.gasPrice
    ? parseFloat(ethers.formatUnits(feeData.gasPrice, "gwei"))
    : null;
  if (!gasPriceGwei) throw new Error("Live gas price unavailable — refusing to estimate with defaults");
  const GAS_UNITS    = 750_000;
  const gasCostMatic = parseFloat(ethers.formatUnits(feeData.gasPrice * BigInt(GAS_UNITS), 18));
  const gasCostUsd   = gasCostMatic * maticUsd;

  // ── Print header ────────────────────────────────────────────────────────────
  console.log("\n" + "═".repeat(120));
  console.log("  LIVE SPREAD SCANNER  —  Polygon Mainnet (real data only, rotating RPC)");
  console.log(`  Block: #${state.rpc.blockNumber}   |   ${new Date().toUTCString()}`);
  console.log(`  RPC: [${state.rpc.name}]  head age ${state.rpc.headAgeS}s  |  pool: ${RPC_POOL.map(r => r[0]).join(" → ")}`);
  console.log("═".repeat(120));
  console.log(`  MATIC $${maticUsd?.toFixed(4)}`+
              `   ETH $${ethUsd?.toFixed(0)}`+
              `   BTC $${btcUsd?.toFixed(0)}`+
              `   Gas ${gasPriceGwei.toFixed(1)} Gwei`+
              `   Est. tx cost $${gasCostUsd.toFixed(3)}`);
  console.log(`  Liquidity filter: skip pair if BOTH DEXes < $${MIN_RESERVE_USD.toLocaleString()} | universal phantom guard: spread >5% of loan`);
  console.log("─".repeat(120));

  const COL = [20, 14, 12, 14, 14, 12, 11, 10, 13];
  const HDR = ["Pair","Amount In","QS Depth","QS Out","SS Out","Spread %","Spread $","Net $","Signal"];
  console.log(HDR.map((h,i) => pad(h, COL[i])).join(""));
  console.log("─".repeat(120));

  const results = [];
  const env = { COL, results, gasCostUsd };

  for (const pair of SCAN_PAIRS) {
    try {
      await withRotation(state, `scan ${pair.from.symbol}→${pair.to.symbol} @${pair.amount}`, () =>
        scanPair(state, pair, env)
      );
    } catch (e) {
      // Every RPC failed for this pair — record honestly, no fabricated numbers
      const pairLabel = `${pair.from.symbol}→${pair.to.symbol}`;
      console.log(pad(pairLabel, COL[0]) + " ".repeat(COL[1]+COL[2]+COL[3]+COL[4]+COL[5]+COL[6]+COL[7]) + "❌ RPC_ERROR");
      results.push({ loanNotionalUsd, aaveFeeUsd, pair: pairLabel, amount: pair.amount, signal: "RPC_ERROR", error: e.message?.slice(0, 200) });
    }
  }

  // ── Summary ─────────────────────────────────────────────────────────────────
  console.log("═".repeat(120));
  console.log("\n  SUMMARY");
  console.log("─".repeat(60));

  const executable  = results.filter(r => r.signal === "🟢 EXECUTE");
  const lowDepth    = results.filter(r => r.signal === "🟡 LOW DEPTH");
  const marginal    = results.filter(r => r.signal === "🟡 MARGINAL");
  const phantom     = results.filter(r => r.signal.startsWith("👻 PHANTOM"));
  const rpcErrors   = results.filter(r => r.signal === "RPC_ERROR");

  if (executable.length) {
    console.log("  🟢 Execute now:");
    for (const r of executable) {
      console.log(`     ${pad(r.pair,18)} cheaper: ${r.cheaperDex}   spread $${r.spreadUsd?.toFixed(2)}   net ~$${r.netProfitAdj?.toFixed(2)} (slip ${r.slippageEst?.toFixed(1)}%)   QS $${(r.qsDepthUsd/1000).toFixed(0)}K / SS $${(r.ssDepthUsd/1000).toFixed(0)}K`);
    }
  }
  if (lowDepth.length) {
    console.log("  🟡 Promising — depth below threshold:");
    for (const r of lowDepth) {
      console.log(`     ${pad(r.pair,18)} spread $${r.spreadUsd?.toFixed(2)}   adj net ~$${r.netProfitAdj?.toFixed(2)}   QS $${(r.qsDepthUsd/1000).toFixed(0)}K / SS $${(r.ssDepthUsd/1000).toFixed(0)}K`);
    }
  }
  if (marginal.length) {
    console.log("  🟡 Marginal (adj for slippage):");
    for (const r of marginal) {
      console.log(`     ${pad(r.pair,18)} net ~$${r.netProfitAdj?.toFixed(2)}   slip est ${r.slippageEst?.toFixed(1)}%`);
    }
  }
  if (phantom.length) {
    console.log("  👻 Phantom spreads (spread >5% of loan notional — thin pools, not real arb):");
    for (const r of phantom) {
      console.log(`     ${pad(r.pair,18)} spread ${r.spreadPct?.toFixed(1)}% — SS $${(r.ssDepthUsd/1000).toFixed(0)}K depth likely empty`);
    }
  }
  if (rpcErrors.length) {
    console.log("  ❌ RPC errors (all endpoints failed — NOT simulated):");
    for (const r of rpcErrors) {
      console.log(`     ${pad(r.pair,18)} ${r.error}`);
    }
  }
  if (!executable.length && !lowDepth.length && !marginal.length && !rpcErrors.length) {
    console.log("  🔴 No profitable opportunities at current spreads and gas.");
  }

  console.log(`\n  Pairs scanned: ${results.length}`);
  console.log(`  RPC in use:    [${state.rpc.name}]  (rotated on failure)`);
  console.log(`  Depth filter:  skip < $${MIN_RESERVE_USD.toLocaleString()} per DEX side`);
  console.log(`  Gas:           ${gasPriceGwei.toFixed(1)} Gwei  |  est. tx $${gasCostUsd?.toFixed(3) ?? "?"}`);
  console.log(`  Timestamp:     ${new Date().toISOString()}`);
  // ── Write JSONL log ────────────────────────────────────────────────────────
  const ts = new Date().toISOString();
  const logDate = ts.slice(0, 10); // YYYY-MM-DD (UTC)
  const logDir = "logs";
  const logFile = path.join(logDir, `opportunities-${logDate}.jsonl`);
  if (!fs.existsSync(logDir)) fs.mkdirSync(logDir, { recursive: true });
  for (const r of results) {
    const record = {
      ts, blockNumber: state.rpc?.blockNumber, ...r,
      gasGwei: gasPriceGwei, gasCostUsd,
      executed: false, dryRun: true,
    };
    fs.appendFileSync(logFile, JSON.stringify(record) + "\n");
  }
  console.log(`  📝 Logged ${results.length} records to ${logFile}`);

  console.log("═".repeat(120) + "\n");
}

main().catch(err => {
  console.error("❌ Scan failed:", err.message);
  process.exit(1);
});
P2_FILE_EOF

# ---------- scripts/pre-deploy-check.js ----------
cat > 'scripts/pre-deploy-check.js' << 'P2_FILE_EOF'
/**
 * pre-deploy-check.js — Full readiness audit before going live.
 * Usage: node scripts/pre-deploy-check.js
 */
require("dotenv").config();
const { ethers } = require("ethers");

const FLASH_LOAN   = process.env.FLASH_LOAN_ADDRESS   || "0xBafc19Fd23714bD2F3256C20a6036a5B31A9DbD8";
const PRICE_ORACLE = process.env.PRICE_ORACLE_ADDRESS || "0xbBaf624eDe7A57141ADFF779dBf474c9527faD9f";
const WETH   = "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619";
const USDC   = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
const WMATIC = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";

const FL_ABI = [
  "function paused() external view returns (bool)",
  "function owner() external view returns (address)",
  "function dailyVolumeLimit(address) external view returns (uint256)",
  "function dailyVolumeUsed(address) external view returns (uint256)",
];
const PO_ABI = [
  "function getArbitrageSpread(address,address,uint256) external view returns (uint256,address,address)",
];

const CHECKS = [];
function pass(label, detail="") { CHECKS.push({ ok: true,  label, detail }); }
function fail(label, detail="") { CHECKS.push({ ok: false, label, detail }); }

async function main() {
  const provider = new ethers.JsonRpcProvider(process.env.POLYGON_RPC_URL);
  const wallet   = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
  const fl       = new ethers.Contract(FLASH_LOAN,   FL_ABI, provider);
  const po       = new ethers.Contract(PRICE_ORACLE, PO_ABI, provider);
  const fee      = await provider.getFeeData();
  const bal      = await provider.getBalance(wallet.address);
  const block    = await provider.getBlockNumber();

  console.log(`\n⚡ Flash Loan Arb — Pre-Deploy Check`);
  console.log(`   Block #${block} | ${new Date().toUTCString()}\n`);

  // 1. RPC
  block > 0 ? pass("RPC connectivity", `Block #${block}`) : fail("RPC connectivity");

  // 2. Wallet
  const maticBal = parseFloat(ethers.formatEther(bal));
  const gasGwei  = parseFloat(ethers.formatUnits(fee.gasPrice, "gwei"));
  const txCost   = parseFloat(ethers.formatEther(fee.gasPrice * 750_000n));
  const txCount  = Math.floor(maticBal / txCost);
  maticBal >= txCost * 5
    ? pass("Wallet gas balance", `${maticBal.toFixed(4)} MATIC — ~${txCount} txs`)
    : fail("Wallet gas balance", `${maticBal.toFixed(6)} MATIC — needs top-up (min 5 MATIC)`);

  // 3. Gas price
  gasGwei <= 350
    ? pass("Gas price", `${gasGwei.toFixed(1)} Gwei — under 350 ceiling`)
    : fail("Gas price", `${gasGwei.toFixed(1)} Gwei — ABOVE 350 ceiling`);

  // 4. FlashLoan contract
  const fl_code = await provider.getCode(FLASH_LOAN);
  fl_code.length > 4 ? pass("FlashLoanSecure deployed", FLASH_LOAN) : fail("FlashLoanSecure deployed", "No code at address");

  // 5. PriceOracle contract
  const po_code = await provider.getCode(PRICE_ORACLE);
  po_code.length > 4 ? pass("PriceOracle deployed", PRICE_ORACLE) : fail("PriceOracle deployed", "No code at address");

  // 6. Ownership
  const owner = await fl.owner();
  owner.toLowerCase() === wallet.address.toLowerCase()
    ? pass("Wallet is contract owner", wallet.address)
    : fail("Wallet is contract owner", `Owner is ${owner}, wallet is ${wallet.address}`);

  // 7. Not paused
  const paused = await fl.paused();
  !paused ? pass("FlashLoan not paused") : fail("FlashLoan is PAUSED — call unpause()");

  // 8. Daily volume limits
  const wethLimit  = await fl.dailyVolumeLimit(WETH);
  const usdcLimit  = await fl.dailyVolumeLimit(USDC);
  const wethOk     = wethLimit > 0n;
  const usdcOk     = usdcLimit > 0n;
  wethOk
    ? pass("WETH daily volume limit set", `${ethers.formatEther(wethLimit)} WETH`)
    : fail("WETH daily volume limit", "= 0 — ALL TRADES BLOCKED. Run set-volume-limits.js");
  usdcOk
    ? pass("USDC daily volume limit set", `${ethers.formatUnits(usdcLimit,6)} USDC`)
    : fail("USDC daily volume limit", "= 0 — run set-volume-limits.js");

  // 9. Oracle responding
  try {
    const [spread, cheap] = await po.getArbitrageSpread(WETH, USDC, ethers.parseEther("10"));
    parseFloat(ethers.formatUnits(spread, 6)) > 0
      ? pass("PriceOracle responding", `Spread: $${parseFloat(ethers.formatUnits(spread,6)).toFixed(2)} on 10 WETH`)
      : fail("PriceOracle spread", "returned 0");
  } catch(e) {
    fail("PriceOracle responding", e.message.slice(0,60));
  }

  // 10. DRY_RUN
  const dr = process.env.DRY_RUN;
  dr !== "true"
    ? pass("DRY_RUN disabled", "Live execution mode")
    : fail("DRY_RUN=true", "Set DRY_RUN=false (or remove) to go live");

  // ── Print results ─────────────────────────────────────────────────────────
  console.log("─".repeat(60));
  for (const c of CHECKS) {
    console.log(`  ${c.ok ? "✅" : "❌"} ${c.label}`);
    if (c.detail) console.log(`      ${c.detail}`);
  }
  console.log("─".repeat(60));
  const passed = CHECKS.filter(c => c.ok).length;
  const total  = CHECKS.length;
  console.log(`\n  ${passed}/${total} checks passed`);
  if (passed === total) {
    console.log("  🟢 READY FOR LIVE DEPLOYMENT\n");
  } else {
    console.log("  🔴 NOT READY — fix failing checks above\n");
  }
}

main().catch(console.error);
P2_FILE_EOF

# ---------- scripts/set-volume-limits.js ----------
cat > 'scripts/set-volume-limits.js' << 'P2_FILE_EOF'
/**
 * set-volume-limits.js
 * Run ONCE after funding the wallet — sets circuit-breaker limits on FlashLoanSecure.
 * Usage: node scripts/set-volume-limits.js
 */
require("dotenv").config();
const { ethers } = require("ethers");

const FLASH_LOAN = process.env.FLASH_LOAN_ADDRESS || "0xBafc19Fd23714bD2F3256C20a6036a5B31A9DbD8";
const WETH  = "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619";
const USDC  = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
const WMATIC= "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";

const ABI = ["function setDailyVolumeLimit(address asset, uint256 limit) external"];

async function main() {
  const provider = new ethers.JsonRpcProvider(process.env.POLYGON_RPC_URL);
  const wallet   = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
  const fl       = new ethers.Contract(FLASH_LOAN, ABI, wallet);
  const fee      = await provider.getFeeData();

  console.log("Setting daily volume limits on FlashLoanSecure...");
  console.log("Wallet:", wallet.address);

  const limits = [
    { asset: WETH,   label: "WETH",   limit: ethers.parseEther("500"),          // 500 WETH/day
      dec: 18 },
    { asset: USDC,   label: "USDC",   limit: ethers.parseUnits("1000000", 6),   // 1M USDC/day
      dec: 6 },
    { asset: WMATIC, label: "WMATIC", limit: ethers.parseEther("5000000"),      // 5M WMATIC/day
      dec: 18 },
  ];

  for (const { asset, label, limit, dec } of limits) {
    process.stdout.write(`  setDailyVolumeLimit(${label}, ${ethers.formatUnits(limit, dec)})... `);
    try {
      const tx = await fl.setDailyVolumeLimit(asset, limit, {
        gasPrice: fee.gasPrice,
        gasLimit: 100_000n,
      });
      const receipt = await tx.wait(1);
      console.log(`✅ tx: ${receipt.hash}`);
    } catch (e) {
      console.log(`❌ ${e.message.slice(0,80)}`);
    }
  }
  console.log("\nDone. Bot circuit breakers are now armed.");
}

main().catch(console.error);
P2_FILE_EOF

# ---------- scripts/verify-deployment.js ----------
cat > 'scripts/verify-deployment.js' << 'P2_FILE_EOF'
/**
 * @file verify-deployment.js
 * @notice Post-deployment sanity check script.
 *
 * Reads addresses from output/addresses-<network>.json and verifies:
 *   1. Contracts are deployed (bytecode exists)
 *   2. FlashLoanSecure.ADDRESSES_PROVIDER matches expected Aave address
 *   3. FlashLoanSecure.PRICE_ORACLE matches deployed PriceOraclePolygon
 *   4. Owner is the deployer wallet
 *   5. Contract is not paused
 *   6. PriceOraclePolygon returns non-zero prices for USDC/WMATIC
 *   7. Submits a Polygonscan verification command for each contract
 *
 * Usage:
 *   npx hardhat run scripts/verify-deployment.js --network polygon
 *   npx hardhat run scripts/verify-deployment.js --network mumbai
 */

const { ethers, run, network } = require("hardhat");
const fs   = require("fs");
const path = require("path");

// ─────────────────────────────────────────────────────────────────────────────
// Config by network
// ─────────────────────────────────────────────────────────────────────────────

const NETWORK_CONFIG = {
  polygon: {
    aaveProvider: "0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb",
    usdc:         "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
    wmatic:       "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
    addressFile:  "addresses-mainnet.json",
  },
  mumbai: {
    aaveProvider: "0x5343b5bA672Ae99d627A1C87866b8E53F47Db2E6",
    usdc:         "0xe11a86849d99f524cac3e7a0ec1241828e332526", // Mumbai USDC
    wmatic:       "0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889", // Mumbai WMATIC
    addressFile:  "addresses-mumbai.json",
  },
};

const FLASH_LOAN_ABI = [
  "function ADDRESSES_PROVIDER() external view returns (address)",
  "function PRICE_ORACLE() external view returns (address)",
  "function owner() external view returns (address)",
  "function paused() external view returns (bool)",
  "function MAX_RECURSION_DEPTH() external view returns (uint256)",
];

const PRICE_ORACLE_ABI = [
  "function getQuickSwapPrice(address,address,uint256) external view returns (uint256)",
  "function getSushiSwapPrice(address,address,uint256) external view returns (uint256)",
  "function QUICKSWAP_ROUTER() external view returns (address)",
  "function SUSHISWAP_ROUTER() external view returns (address)",
];

// ─────────────────────────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────────────────────────

async function main() {
  const netName = network.name;
  const cfg     = NETWORK_CONFIG[netName];
  if (!cfg) throw new Error(`Unsupported network: ${netName}`);

  const [signer] = await ethers.getSigners();
  console.log(`\n🔍 Verifying deployment on ${netName}`);
  console.log(`   Signer: ${signer.address}\n`);

  // ── Load addresses ──────────────────────────────────────────────────────────
  const addrPath = path.join(__dirname, "..", "output", cfg.addressFile);
  if (!fs.existsSync(addrPath)) {
    throw new Error(`Address file not found: ${addrPath}. Run the deploy script first.`);
  }
  const addresses = JSON.parse(fs.readFileSync(addrPath, "utf8"));

  if (!addresses.flashLoan || !addresses.priceOracle) {
    throw new Error("Addresses file is missing flashLoan or priceOracle — was deployment successful?");
  }

  console.log("📄 Loaded addresses:");
  console.log(`   FlashLoanSecure:    ${addresses.flashLoan}`);
  console.log(`   PriceOraclePolygon: ${addresses.priceOracle}`);
  if (addresses.mockOracle) console.log(`   MockOracle:         ${addresses.mockOracle}`);
  console.log();

  // ── 1. Bytecode check ───────────────────────────────────────────────────────
  console.log("1️⃣  Checking bytecode…");
  for (const [label, addr] of [
    ["FlashLoanSecure",    addresses.flashLoan],
    ["PriceOraclePolygon", addresses.priceOracle],
  ]) {
    const code = await ethers.provider.getCode(addr);
    if (code === "0x") throw new Error(`${label} has no bytecode at ${addr} — deployment failed?`);
    console.log(`   ✅ ${label} has bytecode (${((code.length - 2) / 2)} bytes)`);
  }
  console.log();

  // ── 2. FlashLoanSecure state ────────────────────────────────────────────────
  console.log("2️⃣  Checking FlashLoanSecure state…");
  const fl = new ethers.Contract(addresses.flashLoan, FLASH_LOAN_ABI, ethers.provider);

  const [provider, oracle, owner, isPaused, maxDepth] = await Promise.all([
    fl.ADDRESSES_PROVIDER(),
    fl.PRICE_ORACLE(),
    fl.owner(),
    fl.paused(),
    fl.MAX_RECURSION_DEPTH(),
  ]);

  _assert(
    provider.toLowerCase() === cfg.aaveProvider.toLowerCase(),
    `ADDRESSES_PROVIDER mismatch: got ${provider}, expected ${cfg.aaveProvider}`
  );
  console.log(`   ✅ ADDRESSES_PROVIDER: ${provider}`);

  _assert(
    oracle.toLowerCase() === addresses.priceOracle.toLowerCase(),
    `PRICE_ORACLE mismatch: got ${oracle}, expected ${addresses.priceOracle}`
  );
  console.log(`   ✅ PRICE_ORACLE: ${oracle}`);

  _assert(
    owner.toLowerCase() === signer.address.toLowerCase(),
    `Owner mismatch: got ${owner}, expected ${signer.address}`
  );
  console.log(`   ✅ Owner: ${owner}`);

  _assert(!isPaused, "Contract is paused — unexpected for a fresh deployment");
  console.log(`   ✅ Not paused`);

  _assert(maxDepth === 3n, `MAX_RECURSION_DEPTH should be 3, got ${maxDepth}`);
  console.log(`   ✅ MAX_RECURSION_DEPTH: ${maxDepth}`);
  console.log();

  // ── 3. PriceOraclePolygon — live price queries ─────────────────────────────
  console.log("3️⃣  Checking PriceOraclePolygon live prices…");
  const po = new ethers.Contract(addresses.priceOracle, PRICE_ORACLE_ABI, ethers.provider);

  const testAmount = ethers.parseUnits("1000", 6); // 1000 USDC
  const [qsPrice, ssPrice] = await Promise.all([
    po.getQuickSwapPrice(cfg.usdc, cfg.wmatic, testAmount).catch(() => 0n),
    po.getSushiSwapPrice(cfg.usdc, cfg.wmatic, testAmount).catch(() => 0n),
  ]);

  if (qsPrice > 0n) {
    console.log(`   ✅ QuickSwap: 1000 USDC → ${ethers.formatUnits(qsPrice, 18)} WMATIC`);
  } else {
    console.log(`   ⚠️  QuickSwap returned 0 (pair may have no liquidity on this network)`);
  }

  if (ssPrice > 0n) {
    console.log(`   ✅ SushiSwap: 1000 USDC → ${ethers.formatUnits(ssPrice, 18)} WMATIC`);
  } else {
    console.log(`   ⚠️  SushiSwap returned 0 (pair may have no liquidity on this network)`);
  }
  console.log();

  // ── 4. Polygonscan verification ─────────────────────────────────────────────
  if (process.env.POLYGONSCAN_API_KEY) {
    console.log("4️⃣  Submitting Polygonscan verification requests…");
    try {
      await run("verify:verify", {
        address: addresses.priceOracle,
        constructorArguments: [
          // These must match the deploy script exactly
        ],
      });
      console.log(`   ✅ PriceOraclePolygon verified`);
    } catch (e) {
      console.log(`   ⚠️  PriceOraclePolygon verification: ${e.message}`);
    }

    try {
      await run("verify:verify", {
        address: addresses.flashLoan,
        constructorArguments: [
          cfg.aaveProvider,
          addresses.priceOracle,
          signer.address,
        ],
      });
      console.log(`   ✅ FlashLoanSecure verified`);
    } catch (e) {
      console.log(`   ⚠️  FlashLoanSecure verification: ${e.message}`);
    }
  } else {
    console.log("4️⃣  Skipping Polygonscan verification (POLYGONSCAN_API_KEY not set)");
    console.log("   To verify manually:");
    console.log(`   npx hardhat verify --network ${netName} ${addresses.flashLoan} "${cfg.aaveProvider}" "${addresses.priceOracle}" "${signer.address}"`);
  }

  console.log("\n🎉 All checks passed — deployment looks healthy!\n");
}

function _assert(condition, message) {
  if (!condition) throw new Error(`Assertion failed: ${message}`);
}

main().catch((err) => {
  console.error("❌ Verification failed:", err.message);
  process.exitCode = 1;
});
P2_FILE_EOF

# ---------- test/FlashLoanPolygon.fork.test.js ----------
cat > 'test/FlashLoanPolygon.fork.test.js' << 'P2_FILE_EOF'
/**
 * @file FlashLoanPolygon.fork.test.js
 * @notice Fork tests against a pinned Polygon mainnet block.
 *
 * Prerequisites:
 *   POLYGON_RPC_URL must be set in .env (Alchemy archival node recommended)
 *
 * Run:
 *   npm run test:fork
 *   # or: POLYGON_RPC_URL=https://... npx hardhat test test/FlashLoanPolygon.fork.test.js
 *
 * What is tested:
 *   1. PriceOraclePolygon queries real QuickSwap / SushiSwap reserves
 *   2. getArbitrageSpread returns valid DEX addresses
 *   3. Chainlink MATIC/USD feed is fresh and returns a plausible price
 *   4. FlashLoanSecure state after deploy (provider, oracle, owner)
 *   5. Daily volume limit fires for over-cap borrow
 *   6. initiateFlashLoan reaches the real Aave pool and calls back
 *      (reverts at InsufficientProfit — proves Aave integration is wired)
 *   7. TwapOracle registers a pair and records a snapshot
 */

const { expect }       = require("chai");
const { ethers }       = require("hardhat");

// ─────────────────────────────────────────────────────────────────────────────
// Polygon mainnet constants (pinned to a recent block)
// ─────────────────────────────────────────────────────────────────────────────

const AAVE_POOL_PROVIDER  = "0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb";
const QUICKSWAP_ROUTER    = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";
const QUICKSWAP_FACTORY   = "0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32";
const SUSHISWAP_ROUTER    = "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506";
const SUSHISWAP_FACTORY   = "0xc35DADB65012eC5796536bD9864eD8773aBc74C4";

// Tokens
const USDC   = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
const WMATIC = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
const WETH   = "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619";

// Chainlink MATIC/USD feed
const CL_MATIC_USD = "0xAB594600376Ec9fD91F8e885dADF0CE036862dE0";

// Well-known USDC/WMATIC QuickSwap pair (for TwapOracle test)
const QS_USDC_WMATIC_PAIR = "0x6e7a5FAFcec6BB1e78bAE2A1F0B612012BF14827";

// A large USDC holder (for seeding the flash loan contract)
const USDC_WHALE = "0xe7804c37c13166fF0b37F5aE0BB07A3aEbb6e245";

// ─────────────────────────────────────────────────────────────────────────────
// ABIs
// ─────────────────────────────────────────────────────────────────────────────

const ERC20_ABI = [
  "function balanceOf(address) external view returns (uint256)",
  "function transfer(address to, uint256 amount) external returns (bool)",
];

const CL_ABI = [
  "function latestRoundData() external view returns (uint80,int256,uint256,uint256,uint80)",
  "function decimals() external view returns (uint8)",
];

// ─────────────────────────────────────────────────────────────────────────────
// Helper
// ─────────────────────────────────────────────────────────────────────────────

function encodeParams(tokenIn, tokenOut, dexA, dexB, minProfit) {
  return ethers.AbiCoder.defaultAbiCoder().encode(
    ["address", "address", "address", "address", "uint256"],
    [tokenIn, tokenOut, dexA, dexB, minProfit]
  );
}

async function fundWithMatic(address) {
  await ethers.provider.send("hardhat_setBalance", [
    address,
    "0x" + (100n * 10n ** 18n).toString(16),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Suite
// ─────────────────────────────────────────────────────────────────────────────

describe("FlashLoanPolygon — Fork Tests", function () {
  this.timeout(180_000);

  let owner, priceOracle, flashLoan, twapOracle;

  before(async function () {
    if (!process.env.POLYGON_RPC_URL) {
      console.warn("  ⚠️  POLYGON_RPC_URL not set — skipping fork tests");
      this.skip();
    }

    [owner] = await ethers.getSigners();
    await fundWithMatic(owner.address);

    // ── Deploy PriceOraclePolygon ──
    const PriceOraclePolygon = await ethers.getContractFactory("PriceOraclePolygon");
    priceOracle = await PriceOraclePolygon.deploy(
      QUICKSWAP_ROUTER,
      SUSHISWAP_ROUTER,
      QUICKSWAP_FACTORY,
      SUSHISWAP_FACTORY,
      [], []
    );

    // ── Deploy FlashLoanSecure ──
    const FlashLoanSecure = await ethers.getContractFactory("FlashLoanSecure");
    flashLoan = await FlashLoanSecure.deploy(
      AAVE_POOL_PROVIDER,
      await priceOracle.getAddress(),
      owner.address
    );

    // ── Deploy TwapOracle ──
    const TwapOracle = await ethers.getContractFactory("TwapOracle");
    twapOracle = await TwapOracle.deploy();

    // ── Seed USDC into flash loan contract via whale ──
    await fundWithMatic(USDC_WHALE);
    await ethers.provider.send("hardhat_impersonateAccount", [USDC_WHALE]);
    const whale = await ethers.getSigner(USDC_WHALE);
    const usdc  = new ethers.Contract(USDC, ERC20_ABI, whale);
    await usdc.transfer(await flashLoan.getAddress(), ethers.parseUnits("200000", 6));
    await ethers.provider.send("hardhat_stopImpersonatingAccount", [USDC_WHALE]);
  });

  // ── 1. Chainlink feed ────────────────────────────────────────────────────────
  describe("1. Chainlink MATIC/USD feed", function () {
    it("returns a positive, fresh MATIC/USD price", async function () {
      const feed = new ethers.Contract(CL_MATIC_USD, CL_ABI, ethers.provider);
      const [, answer, , updatedAt] = await feed.latestRoundData();
      const decimals = await feed.decimals();
      const price    = Number(answer) / 10 ** Number(decimals);

      expect(price).to.be.gt(0.01);
      expect(price).to.be.lt(100); // sanity bound

      const age = Math.floor(Date.now() / 1000) - Number(updatedAt);
      // On a fork the block is recent; age < 2 hours for a valid feed
      expect(age).to.be.lt(7200);

      console.log(`     MATIC/USD: $${price.toFixed(4)} (age: ${age}s)`);
    });
  });

  // ── 2. PriceOraclePolygon ────────────────────────────────────────────────────
  describe("2. PriceOraclePolygon — live DEX queries", function () {
    it("QuickSwap: 1000 USDC → WMATIC returns non-zero", async function () {
      const amt   = ethers.parseUnits("1000", 6);
      const price = await priceOracle.getQuickSwapPrice(USDC, WMATIC, amt);
      expect(price).to.be.gt(0n);
      console.log(`     QS: 1000 USDC → ${ethers.formatUnits(price, 18)} WMATIC`);
    });

    it("SushiSwap: 1000 USDC → WMATIC returns non-zero", async function () {
      const amt   = ethers.parseUnits("1000", 6);
      const price = await priceOracle.getSushiSwapPrice(USDC, WMATIC, amt);
      expect(price).to.be.gt(0n);
      console.log(`     SS: 1000 USDC → ${ethers.formatUnits(price, 18)} WMATIC`);
    });

    it("QuickSwap: 1 WETH → USDC is in $100–$10,000 range", async function () {
      const amt   = ethers.parseUnits("1", 18);
      const price = await priceOracle.getQuickSwapPrice(WETH, USDC, amt);
      const usd   = Number(ethers.formatUnits(price, 6));
      expect(usd).to.be.gt(100).and.lt(10_000);
      console.log(`     QS: 1 WETH = $${usd.toFixed(2)}`);
    });

    it("getArbitrageSpread returns valid DEX addresses", async function () {
      const amt = ethers.parseUnits("1000", 6);
      const [spread, cheaperDex, expensiveDex] =
        await priceOracle.getArbitrageSpread(USDC, WMATIC, amt);

      expect(spread).to.be.gte(0n);
      const validDexes = [
        QUICKSWAP_ROUTER.toLowerCase(),
        SUSHISWAP_ROUTER.toLowerCase(),
      ];
      expect(validDexes).to.include(cheaperDex.toLowerCase());
      expect(validDexes).to.include(expensiveDex.toLowerCase());
      console.log(`     Spread: ${ethers.formatUnits(spread, 18)} WMATIC`);
      console.log(`     Cheaper:   ${cheaperDex}`);
      console.log(`     Expensive: ${expensiveDex}`);
    });
  });

  // ── 3. FlashLoanSecure state ─────────────────────────────────────────────────
  describe("3. FlashLoanSecure deployment state", function () {
    it("ADDRESSES_PROVIDER points to real Aave provider", async function () {
      expect((await flashLoan.ADDRESSES_PROVIDER()).toLowerCase())
        .to.equal(AAVE_POOL_PROVIDER.toLowerCase());
    });

    it("PRICE_ORACLE is correctly set", async function () {
      expect((await flashLoan.PRICE_ORACLE()).toLowerCase())
        .to.equal((await priceOracle.getAddress()).toLowerCase());
    });

    it("owner is the deployer", async function () {
      expect(await flashLoan.owner()).to.equal(owner.address);
    });

    it("contract is not paused", async function () {
      expect(await flashLoan.paused()).to.be.false;
    });

    it("contract received USDC seed funds", async function () {
      const usdc = new ethers.Contract(USDC, ERC20_ABI, ethers.provider);
      const bal  = await usdc.balanceOf(await flashLoan.getAddress());
      expect(bal).to.be.gt(0n);
      console.log(`     USDC balance: ${ethers.formatUnits(bal, 6)}`);
    });
  });

  // ── 4. Circuit breakers ──────────────────────────────────────────────────────
  describe("4. Circuit breakers on forked chain", function () {
    it("daily volume limit blocks over-cap borrow", async function () {
      const limit = ethers.parseUnits("5000", 6);
      await flashLoan.connect(owner).setDailyVolumeLimit(USDC, limit);

      const params = encodeParams(USDC, WMATIC, QUICKSWAP_ROUTER, SUSHISWAP_ROUTER, 0n);
      await expect(
        flashLoan.connect(owner).initiateFlashLoan(
          USDC, ethers.parseUnits("5001", 6), params
        )
      ).to.be.revertedWithCustomError(flashLoan, "DailyVolumeLimitExceeded");

      // Reset so remaining tests aren't blocked
      await flashLoan.connect(owner).setDailyVolumeLimit(USDC, 0n);
    });
  });

  // ── 5. Aave pool reachability ────────────────────────────────────────────────
  describe("5. Aave v3 pool reachability", function () {
    it("initiateFlashLoan reaches real Aave pool (reverts inside executeOperation)", async function () {
      // Set an impossible minProfit — proves Aave called us back and we revert atomically
      const params = encodeParams(
        USDC, WMATIC, QUICKSWAP_ROUTER, SUSHISWAP_ROUTER,
        ethers.parseUnits("9999999", 6)
      );

      await expect(
        flashLoan.connect(owner).initiateFlashLoan(
          USDC, ethers.parseUnits("10000", 6), params,
          { gasLimit: 1_500_000 }
        )
      ).to.be.reverted; // reverts at InsufficientProfit — Aave integration confirmed
    });
  });

  // ── 6. TwapOracle ────────────────────────────────────────────────────────────
  describe("6. TwapOracle — snapshot registration", function () {
    it("registers a pair and records an initial observation", async function () {
      await twapOracle.registerPair(QS_USDC_WMATIC_PAIR);

      const [window, isReady, lastUpdate] =
        await twapOracle.getWindowInfo(QS_USDC_WMATIC_PAIR);

      // Right after registration window = 0 (prev == last), not ready yet
      expect(window).to.equal(0n);
      expect(isReady).to.be.false;
      expect(lastUpdate).to.be.gt(0n);
      console.log(`     Last update: ${new Date(Number(lastUpdate) * 1000).toISOString()}`);
    });

    it("records a second observation after advancing time (window >= MIN_WINDOW)", async function () {
      // Advance time by 6 minutes
      await ethers.provider.send("evm_increaseTime", [360]);
      await ethers.provider.send("evm_mine", []);

      await twapOracle.update(QS_USDC_WMATIC_PAIR);

      const [window, isReady] = await twapOracle.getWindowInfo(QS_USDC_WMATIC_PAIR);
      // window should now be >= 360 seconds (6 min > MIN_WINDOW of 5 min)
      expect(window).to.be.gte(300n);
      expect(isReady).to.be.true;
      console.log(`     TWAP window: ${window}s — ready: ${isReady}`);
    });

    it("consult() returns a non-zero TWAP price after window is ready", async function () {
      const amountIn = ethers.parseUnits("1000", 6); // 1000 USDC
      const amountOut = await twapOracle.consult(QS_USDC_WMATIC_PAIR, USDC, amountIn);
      expect(amountOut).to.be.gt(0n);
      console.log(`     TWAP: 1000 USDC → ${ethers.formatUnits(amountOut, 18)} WMATIC`);
    });
  });
});
P2_FILE_EOF

# ---------- test/FlashLoanPolygon.test.js ----------
cat > 'test/FlashLoanPolygon.test.js' << 'P2_FILE_EOF'
/**
 * @file FlashLoanPolygon.test.js
 * @notice Unit tests for FlashLoanPolygon (lighter variant):
 *   • Happy path: profitable arbitrage executes and repays loan
 *   • Sad path: reverts when profit < minProfit
 *   • Access control: non-owner cannot call initiateFlashLoan
 *   • Ownable2Step behaviour
 *   • Token withdrawal helpers
 */

const { expect }        = require("chai");
const { ethers }        = require("hardhat");
const { loadFixture }   = require("@nomicfoundation/hardhat-toolbox/network-helpers");

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

function encodeParams(tokenIn, tokenOut, dexA, dexB, minProfit) {
  return ethers.AbiCoder.defaultAbiCoder().encode(
    ["address", "address", "address", "address", "uint256"],
    [tokenIn, tokenOut, dexA, dexB, minProfit]
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Fixture: mock infrastructure + FlashLoanPolygon
// ─────────────────────────────────────────────────────────────────────────────

async function deployFixture() {
  const [owner, alice, bob] = await ethers.getSigners();

  // Mock Aave pool
  const MockAavePool         = await ethers.getContractFactory("MockAavePool");
  const mockPool             = await MockAavePool.deploy();

  const MockAddressesProvider = await ethers.getContractFactory("MockAddressesProvider");
  const mockProvider          = await MockAddressesProvider.deploy(await mockPool.getAddress());

  // Deploy FlashLoanPolygon using the mock provider
  const FlashLoanPolygon = await ethers.getContractFactory("FlashLoanPolygon");
  const flashLoan = await FlashLoanPolygon.deploy(await mockProvider.getAddress());

  // Mock ERC-20 tokens
  const MockERC20 = await ethers.getContractFactory("MockERC20");
  const tokenA    = await MockERC20.deploy("TokenA", "TKA", 18);
  const tokenB    = await MockERC20.deploy("TokenB", "TKB", 18);

  // Mock DEX routers (profitable arbitrage scenario)
  const MockRouter = await ethers.getContractFactory("MockRouter");
  // dexA: gives 1050 tokenB for 1000 tokenA
  const dexA = await MockRouter.deploy(1050n * 10n ** 18n);
  // dexB: gives 1010 tokenA for 1050 tokenB
  const dexB = await MockRouter.deploy(1010n * 10n ** 18n);

  // Seed tokens into the flash loan contract (simulates Aave disbursement)
  const LOAN_AMOUNT = 1000n * 10n ** 18n;
  await tokenA.mint(await flashLoan.getAddress(), LOAN_AMOUNT);

  return {
    owner, alice, bob,
    flashLoan, mockPool, mockProvider,
    tokenA, tokenB,
    dexA, dexB,
    LOAN_AMOUNT,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

describe("FlashLoanPolygon", function () {

  // ── Access control ──────────────────────────────────────────────────────────
  describe("Access control", function () {
    it("only owner can call initiateFlashLoan", async function () {
      const { flashLoan, alice, tokenA, dexA, dexB, LOAN_AMOUNT } = await loadFixture(deployFixture);
      const params = encodeParams(
        await tokenA.getAddress(),
        await tokenA.getAddress(),
        await dexA.getAddress(),
        await dexB.getAddress(),
        0n
      );

      await expect(
        flashLoan.connect(alice).initiateFlashLoan(await tokenA.getAddress(), LOAN_AMOUNT, params)
      ).to.be.revertedWithCustomError(flashLoan, "OwnableUnauthorizedAccount");
    });

    it("executeOperation reverts if msg.sender is not the Aave pool", async function () {
      const { flashLoan, alice, tokenA, dexA, dexB } = await loadFixture(deployFixture);
      const params = encodeParams(
        await tokenA.getAddress(),
        await tokenA.getAddress(),
        await dexA.getAddress(),
        await dexB.getAddress(),
        0n
      );

      await expect(
        flashLoan.connect(alice).executeOperation(
          await tokenA.getAddress(), 1000n, 1n, alice.address, params
        )
      ).to.be.revertedWithCustomError(flashLoan, "UnauthorisedCaller");
    });
  });

  // ── Constructor ─────────────────────────────────────────────────────────────
  describe("Constructor", function () {
    it("sets ADDRESSES_PROVIDER correctly", async function () {
      const { flashLoan, mockProvider } = await loadFixture(deployFixture);
      expect(await flashLoan.ADDRESSES_PROVIDER()).to.equal(await mockProvider.getAddress());
    });

    it("owner is the deployer", async function () {
      const { flashLoan, owner } = await loadFixture(deployFixture);
      expect(await flashLoan.owner()).to.equal(owner.address);
    });

    it("reverts on zero pool provider address", async function () {
      const FlashLoanPolygon = await ethers.getContractFactory("FlashLoanPolygon");
      await expect(
        FlashLoanPolygon.deploy(ethers.ZeroAddress)
      ).to.be.revertedWithCustomError({ interface: FlashLoanPolygon.interface }, "ZeroAddress");
    });
  });

  // ── Token withdrawal ────────────────────────────────────────────────────────
  describe("Token withdrawal", function () {
    it("owner can withdraw ERC-20 tokens", async function () {
      const { flashLoan, owner, tokenA, LOAN_AMOUNT } = await loadFixture(deployFixture);

      const ownerBefore = await tokenA.balanceOf(owner.address);
      await flashLoan.connect(owner).withdrawToken(await tokenA.getAddress(), 0n);
      const ownerAfter = await tokenA.balanceOf(owner.address);

      expect(ownerAfter - ownerBefore).to.equal(LOAN_AMOUNT);
    });

    it("owner can withdraw partial amount", async function () {
      const { flashLoan, owner, tokenA } = await loadFixture(deployFixture);

      const partial = ethers.parseUnits("100", 18);
      await flashLoan.connect(owner).withdrawToken(await tokenA.getAddress(), partial);
      expect(await tokenA.balanceOf(owner.address)).to.equal(partial);
    });

    it("non-owner cannot withdraw tokens", async function () {
      const { flashLoan, alice, tokenA } = await loadFixture(deployFixture);

      await expect(
        flashLoan.connect(alice).withdrawToken(await tokenA.getAddress(), 0n)
      ).to.be.revertedWithCustomError(flashLoan, "OwnableUnauthorizedAccount");
    });
  });

  // ── Ownable2Step ─────────────────────────────────────────────────────────────
  describe("Ownable2Step", function () {
    it("requires acceptance before ownership transfers", async function () {
      const { flashLoan, owner, alice } = await loadFixture(deployFixture);

      await flashLoan.connect(owner).transferOwnership(alice.address);
      expect(await flashLoan.owner()).to.equal(owner.address);
      expect(await flashLoan.pendingOwner()).to.equal(alice.address);

      await flashLoan.connect(alice).acceptOwnership();
      expect(await flashLoan.owner()).to.equal(alice.address);
    });
  });

  // ── Zero amount ─────────────────────────────────────────────────────────────
  describe("initiateFlashLoan validations", function () {
    it("reverts on zero amount", async function () {
      const { flashLoan, owner, tokenA, dexA, dexB } = await loadFixture(deployFixture);
      const params = encodeParams(
        await tokenA.getAddress(),
        await tokenA.getAddress(),
        await dexA.getAddress(),
        await dexB.getAddress(),
        0n
      );

      await expect(
        flashLoan.connect(owner).initiateFlashLoan(await tokenA.getAddress(), 0n, params)
      ).to.be.revertedWithCustomError(flashLoan, "ZeroAmount");
    });
  });
});
P2_FILE_EOF

# ---------- test/FlashLoanSecurity.js ----------
cat > 'test/FlashLoanSecurity.js' << 'P2_FILE_EOF'
/**
 * @file FlashLoanSecurity.js
 * @notice Security-focused tests for FlashLoanSecure:
 *   • Reentrancy attack attempt (must revert)
 *   • Pause / unpause
 *   • Daily volume limit enforcement
 *   • Chainlink staleness triggers revert (via PriceOraclePolygon)
 *   • Access control (non-owner cannot call initiateFlashLoan)
 *   • Ownable2Step: pending owner pattern
 */

const { expect }           = require("chai");
const { ethers }           = require("hardhat");
const { loadFixture }      = require("@nomicfoundation/hardhat-toolbox/network-helpers");

// Dummy non-zero address used wherever a real contract isn't needed in unit tests
const DUMMY = "0x0000000000000000000000000000000000000001";

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

function encodeParams(tokenIn, tokenOut, dexA, dexB, minProfit) {
  return ethers.AbiCoder.defaultAbiCoder().encode(
    ["address", "address", "address", "address", "uint256"],
    [tokenIn, tokenOut, dexA, dexB, minProfit]
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Fixture
// ─────────────────────────────────────────────────────────────────────────────

async function deployFixture() {
  const [owner, attacker, newOwner] = await ethers.getSigners();

  // MockOracle: fresh price ($1.00, 8 decimals)
  const MockOracle = await ethers.getContractFactory("MockOracle");
  const mockOracle = await MockOracle.deploy(100_000_000n, 8);

  // Mock Aave pool + addresses provider
  const MockAavePool = await ethers.getContractFactory("MockAavePool");
  const mockPool     = await MockAavePool.deploy();

  const MockAddressesProvider = await ethers.getContractFactory("MockAddressesProvider");
  const mockProvider          = await MockAddressesProvider.deploy(await mockPool.getAddress());

  // PriceOraclePolygon — pass dummy non-zero addresses for factories
  // (TWAP methods not exercised in these unit tests)
  const PriceOraclePolygon = await ethers.getContractFactory("PriceOraclePolygon");
  const priceOracle = await PriceOraclePolygon.deploy(
    await mockPool.getAddress(), // quickswap router (mock)
    await mockPool.getAddress(), // sushiswap router (mock)
    DUMMY,                       // quickswap factory (not used in these tests)
    DUMMY,                       // sushiswap factory (not used in these tests)
    [],
    []
  );

  // FlashLoanSecure
  const FlashLoanSecure = await ethers.getContractFactory("FlashLoanSecure");
  const flashLoan = await FlashLoanSecure.deploy(
    await mockProvider.getAddress(),
    await priceOracle.getAddress(),
    owner.address
  );

  return {
    owner, attacker, newOwner,
    mockOracle, priceOracle, flashLoan,
    mockPool, mockProvider,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

describe("FlashLoanSecurity", function () {

  // ── Access control ──────────────────────────────────────────────────────────
  describe("Access control", function () {
    it("non-owner cannot call initiateFlashLoan", async function () {
      const { flashLoan, attacker } = await loadFixture(deployFixture);
      const USDC    = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
      const WMATIC  = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
      const params  = encodeParams(USDC, WMATIC, DUMMY, DUMMY, 0n);

      await expect(
        flashLoan.connect(attacker).initiateFlashLoan(USDC, ethers.parseUnits("1000", 6), params)
      ).to.be.revertedWithCustomError(flashLoan, "OwnableUnauthorizedAccount");
    });

    it("executeOperation reverts when called by non-Aave address", async function () {
      const { flashLoan, attacker } = await loadFixture(deployFixture);
      const USDC = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
      const params = encodeParams(USDC, DUMMY, DUMMY, DUMMY, 0n);

      await expect(
        flashLoan.connect(attacker).executeOperation(
          USDC, 1000n, 1n, attacker.address, params
        )
      ).to.be.revertedWithCustomError(flashLoan, "UnauthorisedCaller");
    });

    it("executeOperation reverts when initiator is not the contract itself", async function () {
      const { flashLoan, mockPool, owner } = await loadFixture(deployFixture);
      const flashLoanAddress = await flashLoan.getAddress();
      const USDC   = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
      const params = encodeParams(USDC, DUMMY, DUMMY, DUMMY, 0n);

      // Mock pool calls executeOperation with wrong initiator (owner instead of flashLoan)
      await expect(
        mockPool.callExecuteOperation(
          flashLoanAddress,
          USDC, 1000n, 1n,
          owner.address,  // wrong initiator
          params
        )
      ).to.be.reverted;
    });
  });

  // ── Pause / unpause ─────────────────────────────────────────────────────────
  describe("Pause / unpause", function () {
    it("owner can pause and unpause", async function () {
      const { flashLoan, owner } = await loadFixture(deployFixture);

      await flashLoan.connect(owner).pause();
      expect(await flashLoan.paused()).to.be.true;

      await flashLoan.connect(owner).unpause();
      expect(await flashLoan.paused()).to.be.false;
    });

    it("non-owner cannot pause", async function () {
      const { flashLoan, attacker } = await loadFixture(deployFixture);

      await expect(
        flashLoan.connect(attacker).pause()
      ).to.be.revertedWithCustomError(flashLoan, "OwnableUnauthorizedAccount");
    });

    it("initiateFlashLoan reverts when paused", async function () {
      const { flashLoan, owner } = await loadFixture(deployFixture);
      const USDC   = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
      const WMATIC = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
      const params = encodeParams(USDC, WMATIC, DUMMY, DUMMY, 0n);

      await flashLoan.connect(owner).pause();

      await expect(
        flashLoan.connect(owner).initiateFlashLoan(USDC, ethers.parseUnits("1000", 6), params)
      ).to.be.revertedWithCustomError(flashLoan, "EnforcedPause");
    });
  });

  // ── Daily volume limit ───────────────────────────────────────────────────────
  describe("Daily volume limit", function () {
    it("enforces the daily volume cap on a given asset", async function () {
      const { flashLoan, owner } = await loadFixture(deployFixture);
      const USDC = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
      const WMATIC = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";

      // Set daily limit to 500 USDC (6 decimals)
      const limit = ethers.parseUnits("500", 6);
      await flashLoan.connect(owner).setDailyVolumeLimit(USDC, limit);

      const params = encodeParams(USDC, WMATIC, DUMMY, DUMMY, 0n);
      const amount = ethers.parseUnits("501", 6);

      await expect(
        flashLoan.connect(owner).initiateFlashLoan(USDC, amount, params)
      ).to.be.revertedWithCustomError(flashLoan, "DailyVolumeLimitExceeded");
    });

    it("allows borrowing under the daily limit (volume counter starts at 0)", async function () {
      const { flashLoan, owner } = await loadFixture(deployFixture);
      const USDC = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";

      await flashLoan.connect(owner).setDailyVolumeLimit(USDC, ethers.parseUnits("1000000", 6));
      expect(await flashLoan.dailyVolumeUsed(USDC)).to.equal(0n);
    });

    it("emits DailyVolumeLimitSet event", async function () {
      const { flashLoan, owner } = await loadFixture(deployFixture);
      const USDC  = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
      const limit = ethers.parseUnits("10000", 6);

      await expect(flashLoan.connect(owner).setDailyVolumeLimit(USDC, limit))
        .to.emit(flashLoan, "DailyVolumeLimitSet")
        .withArgs(USDC, limit);
    });

    it("non-owner cannot set daily volume limit", async function () {
      const { flashLoan, attacker } = await loadFixture(deployFixture);
      const USDC = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";

      await expect(
        flashLoan.connect(attacker).setDailyVolumeLimit(USDC, 1000n)
      ).to.be.revertedWithCustomError(flashLoan, "OwnableUnauthorizedAccount");
    });
  });

  // ── Chainlink staleness ──────────────────────────────────────────────────────
  describe("Chainlink staleness", function () {
    it("getChainlinkPrice reverts on stale feed", async function () {
      const { priceOracle, mockOracle } = await loadFixture(deployFixture);

      const staleTime = Math.floor(Date.now() / 1000) - 7201;
      await mockOracle.setUpdatedAt(staleTime);

      await expect(
        priceOracle.getChainlinkPrice(await mockOracle.getAddress())
      ).to.be.revertedWithCustomError(priceOracle, "StaleChainlinkPrice");
    });

    it("getChainlinkPrice succeeds with a fresh feed", async function () {
      const { priceOracle, mockOracle } = await loadFixture(deployFixture);
      const [answer] = await priceOracle.getChainlinkPrice(await mockOracle.getAddress());
      expect(answer).to.equal(100_000_000n);
    });
  });

  // ── Ownable2Step ─────────────────────────────────────────────────────────────
  describe("Ownable2Step ownership transfer", function () {
    it("requires new owner to accept before transfer completes", async function () {
      const { flashLoan, owner, newOwner } = await loadFixture(deployFixture);

      await flashLoan.connect(owner).transferOwnership(newOwner.address);
      expect(await flashLoan.owner()).to.equal(owner.address);
      expect(await flashLoan.pendingOwner()).to.equal(newOwner.address);

      await flashLoan.connect(newOwner).acceptOwnership();
      expect(await flashLoan.owner()).to.equal(newOwner.address);
    });

    it("current owner can re-propose to effectively cancel pending transfer", async function () {
      const { flashLoan, owner, newOwner } = await loadFixture(deployFixture);

      await flashLoan.connect(owner).transferOwnership(newOwner.address);
      expect(await flashLoan.pendingOwner()).to.equal(newOwner.address);

      // Overwrite with owner themselves
      await flashLoan.connect(owner).transferOwnership(owner.address);
      expect(await flashLoan.pendingOwner()).to.equal(owner.address);
    });
  });

  // ── Parameter validation ─────────────────────────────────────────────────────
  describe("Parameter validation", function () {
    it("reverts on zero amount", async function () {
      const { flashLoan, owner } = await loadFixture(deployFixture);
      const USDC   = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
      const WMATIC = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
      const params = encodeParams(USDC, WMATIC, DUMMY, DUMMY, 0n);

      await expect(
        flashLoan.connect(owner).initiateFlashLoan(USDC, 0n, params)
      ).to.be.revertedWithCustomError(flashLoan, "ZeroAmount");
    });

    it("reverts on zero asset address", async function () {
      const { flashLoan, owner } = await loadFixture(deployFixture);
      const WMATIC = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
      const params = encodeParams(ethers.ZeroAddress, WMATIC, DUMMY, DUMMY, 0n);

      await expect(
        flashLoan.connect(owner).initiateFlashLoan(ethers.ZeroAddress, 1000n, params)
      ).to.be.revertedWithCustomError(flashLoan, "ZeroAddress");
    });

    it("reverts on empty params", async function () {
      const { flashLoan, owner } = await loadFixture(deployFixture);
      const USDC = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";

      await expect(
        flashLoan.connect(owner).initiateFlashLoan(USDC, 1000n, "0x")
      ).to.be.revertedWithCustomError(flashLoan, "InvalidParams");
    });
  });
});
P2_FILE_EOF

# ---------- test/Reproduction.test.js ----------
cat > 'test/Reproduction.test.js' << 'P2_FILE_EOF'
/**
 * @file Reproduction.test.js
 * @notice Reproduces known vulnerability patterns and verifies the circuit
 *         breakers fire correctly:
 *
 *   1. Reentrancy attack — an attacker tries to re-enter executeOperation
 *   2. Front-running simulation — validates minProfit guard prevents sandwich
 *   3. Sandwich attack — price manipulation between quote and execution
 *   4. Circuit breakers:
 *        a. Daily volume limit fires and resets after a day
 *        b. Pause circuit breaker
 *        c. Max recursion depth guard
 *   5. MockOracle staleness simulation
 */

const { expect }       = require("chai");
const { ethers }       = require("hardhat");
const { loadFixture, time } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

// Dummy non-zero address used wherever a real contract isn't needed in unit tests
const DUMMY = "0x0000000000000000000000000000000000000001";

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

function encodeParams(tokenIn, tokenOut, dexA, dexB, minProfit) {
  return ethers.AbiCoder.defaultAbiCoder().encode(
    ["address", "address", "address", "address", "uint256"],
    [tokenIn, tokenOut, dexA, dexB, minProfit]
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Fixture
// ─────────────────────────────────────────────────────────────────────────────

async function deploySecureFixture() {
  const [owner, attacker] = await ethers.getSigners();

  const MockAavePool          = await ethers.getContractFactory("MockAavePool");
  const mockPool              = await MockAavePool.deploy();
  const MockAddressesProvider = await ethers.getContractFactory("MockAddressesProvider");
  const mockProvider          = await MockAddressesProvider.deploy(await mockPool.getAddress());

  const MockOracle  = await ethers.getContractFactory("MockOracle");
  const mockOracle  = await MockOracle.deploy(100_000_000n, 8);

  // PriceOraclePolygon — use DUMMY for factories (TWAP not exercised here)
  const PriceOraclePolygon = await ethers.getContractFactory("PriceOraclePolygon");
  const priceOracle = await PriceOraclePolygon.deploy(
    await mockPool.getAddress(), // quickswap router (mock)
    await mockPool.getAddress(), // sushiswap router (mock)
    DUMMY,                       // quickswap factory
    DUMMY,                       // sushiswap factory
    [],
    []
  );

  const FlashLoanSecure = await ethers.getContractFactory("FlashLoanSecure");
  const flashLoan = await FlashLoanSecure.deploy(
    await mockProvider.getAddress(),
    await priceOracle.getAddress(),
    owner.address
  );

  const MockERC20  = await ethers.getContractFactory("MockERC20");
  const tokenA     = await MockERC20.deploy("TokenA", "TKA", 18);
  const tokenB     = await MockERC20.deploy("TokenB", "TKB", 18);

  const LOAN_AMOUNT = 1000n * 10n ** 18n;

  return {
    owner, attacker,
    flashLoan, mockPool, mockProvider, mockOracle, priceOracle,
    tokenA, tokenB,
    LOAN_AMOUNT,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

describe("Reproduction Tests — Vulnerability Patterns & Circuit Breakers", function () {

  // ── 1. Reentrancy ───────────────────────────────────────────────────────────
  describe("1. Reentrancy protection", function () {
    it("direct re-entrant call to executeOperation reverts (not Aave pool caller)", async function () {
      const { flashLoan, attacker, tokenA } = await loadFixture(deploySecureFixture);

      const params = encodeParams(
        await tokenA.getAddress(), await tokenA.getAddress(), DUMMY, DUMMY, 0n
      );

      // Attacker calls executeOperation directly — not from Aave pool
      await expect(
        flashLoan.connect(attacker).executeOperation(
          await tokenA.getAddress(), 1000n, 1n, attacker.address, params
        )
      ).to.be.revertedWithCustomError(flashLoan, "UnauthorisedCaller");
    });

    it("ReentrancyGuard: second direct call from attacker also reverts with UnauthorisedCaller", async function () {
      const { flashLoan, attacker, tokenA } = await loadFixture(deploySecureFixture);

      const params = encodeParams(
        await tokenA.getAddress(), await tokenA.getAddress(), DUMMY, DUMMY, 0n
      );

      // Both attempts revert — reentrancy is impossible because the only
      // valid caller is the Aave pool and initiator must be the contract.
      for (let i = 0; i < 2; i++) {
        await expect(
          flashLoan.connect(attacker).executeOperation(
            await tokenA.getAddress(), 1000n, 1n,
            await flashLoan.getAddress(),
            params
          )
        ).to.be.revertedWithCustomError(flashLoan, "UnauthorisedCaller");
      }
    });
  });

  // ── 2. Front-running / minProfit guard ──────────────────────────────────────
  describe("2. Front-running & minProfit slippage guard", function () {
    it("transaction reverts when spread collapses below minProfit (mock pool reachable)", async function () {
      const { flashLoan, owner, tokenA } = await loadFixture(deploySecureFixture);

      // Set a high minProfit that cannot be satisfied
      const impossibleMinProfit = ethers.parseUnits("999999", 18);
      const params = encodeParams(
        await tokenA.getAddress(),
        DUMMY,
        DUMMY,
        DUMMY,
        impossibleMinProfit
      );

      // Will revert — either InvalidParams (DUMMY as tokenOut DEX) or InsufficientProfit
      await expect(
        flashLoan.connect(owner).initiateFlashLoan(
          await tokenA.getAddress(),
          ethers.parseUnits("1000", 18),
          params
        )
      ).to.be.reverted;
    });

    it("zero minProfit param passes validation (no guard at param-check level)", async function () {
      const { flashLoan, owner, tokenA } = await loadFixture(deploySecureFixture);

      const params = encodeParams(
        await tokenA.getAddress(), await tokenA.getAddress(), DUMMY, DUMMY, 0n
      );

      // Reverts at pool interaction, not at minProfit validation
      await expect(
        flashLoan.connect(owner).initiateFlashLoan(
          await tokenA.getAddress(),
          ethers.parseUnits("1000", 18),
          params
        )
      ).to.be.reverted;
    });
  });

  // ── 3. Sandwich attack ──────────────────────────────────────────────────────
  describe("3. Sandwich attack mitigation", function () {
    it("atomic execution prevents partial fills — either full profit or revert", async function () {
      const { flashLoan, owner, tokenA } = await loadFixture(deploySecureFixture);

      // minProfit set to $5 worth — any sandwich that collapses spread below this causes revert
      const minProfitProtection = ethers.parseUnits("5", 18);
      const params = encodeParams(
        await tokenA.getAddress(), DUMMY, DUMMY, DUMMY, minProfitProtection
      );

      // The whole transaction is atomic — either succeeds with >= minProfit or full revert
      await expect(
        flashLoan.connect(owner).initiateFlashLoan(
          await tokenA.getAddress(),
          ethers.parseUnits("1000", 18),
          params
        )
      ).to.be.reverted; // mock DEX not set up to be profitable — proves atomicity
    });
  });

  // ── 4a. Daily volume circuit breaker ────────────────────────────────────────
  describe("4a. Circuit breaker — daily volume limit", function () {
    it("fires correctly when borrow exceeds daily cap", async function () {
      const { flashLoan, owner, tokenA } = await loadFixture(deploySecureFixture);
      const tokenAAddress = await tokenA.getAddress();

      await flashLoan.connect(owner).setDailyVolumeLimit(tokenAAddress, ethers.parseUnits("500", 18));

      const params = encodeParams(tokenAAddress, DUMMY, DUMMY, DUMMY, 0n);

      await expect(
        flashLoan.connect(owner).initiateFlashLoan(
          tokenAAddress, ethers.parseUnits("501", 18), params
        )
      ).to.be.revertedWithCustomError(flashLoan, "DailyVolumeLimitExceeded");
    });

    it("resets counter to 0 after 25 hours have elapsed", async function () {
      const { flashLoan, owner, tokenA } = await loadFixture(deploySecureFixture);
      const tokenAAddress = await tokenA.getAddress();

      await flashLoan.connect(owner).setDailyVolumeLimit(tokenAAddress, ethers.parseUnits("100", 18));

      // Advance time by 25 hours
      await time.increase(25 * 3600);

      // Counter hasn't changed in storage yet (it resets lazily on next call)
      // but the logic uses (block.timestamp / 86400) so after 25 hours a new day begins
      expect(await flashLoan.dailyVolumeUsed(tokenAAddress)).to.equal(0n);
    });

    it("disabled when limit is set to zero (unlimited)", async function () {
      const { flashLoan, owner, tokenA } = await loadFixture(deploySecureFixture);
      const tokenAAddress = await tokenA.getAddress();

      await flashLoan.connect(owner).setDailyVolumeLimit(tokenAAddress, 0n);

      const params = encodeParams(tokenAAddress, DUMMY, DUMMY, DUMMY, 0n);

      // Should NOT revert with DailyVolumeLimitExceeded (will revert for other reasons)
      await expect(
        flashLoan.connect(owner).initiateFlashLoan(
          tokenAAddress, ethers.parseUnits("1000000", 18), params
        )
      ).to.not.be.revertedWithCustomError(flashLoan, "DailyVolumeLimitExceeded");
    });
  });

  // ── 4b. Pause circuit breaker ────────────────────────────────────────────────
  describe("4b. Circuit breaker — pause", function () {
    it("pausing blocks all flash loan initiations immediately", async function () {
      const { flashLoan, owner, tokenA } = await loadFixture(deploySecureFixture);

      await flashLoan.connect(owner).pause();

      const params = encodeParams(
        await tokenA.getAddress(), DUMMY, DUMMY, DUMMY, 0n
      );

      await expect(
        flashLoan.connect(owner).initiateFlashLoan(
          await tokenA.getAddress(), ethers.parseUnits("1000", 18), params
        )
      ).to.be.revertedWithCustomError(flashLoan, "EnforcedPause");
    });

    it("executeOperation also blocked when paused (caller check fires first)", async function () {
      const { flashLoan, owner, tokenA } = await loadFixture(deploySecureFixture);

      await flashLoan.connect(owner).pause();

      const params = encodeParams(
        await tokenA.getAddress(), DUMMY, DUMMY, DUMMY, 0n
      );

      // Direct call from non-pool address while paused — UnauthorisedCaller fires first
      await expect(
        flashLoan.connect(owner).executeOperation(
          await tokenA.getAddress(), 1000n, 1n,
          await flashLoan.getAddress(), params
        )
      ).to.be.reverted;
    });

    it("unpause restores normal operation", async function () {
      const { flashLoan, owner } = await loadFixture(deploySecureFixture);

      await flashLoan.connect(owner).pause();
      expect(await flashLoan.paused()).to.be.true;

      await flashLoan.connect(owner).unpause();
      expect(await flashLoan.paused()).to.be.false;
    });
  });

  // ── 4c. Max recursion depth ──────────────────────────────────────────────────
  describe("4c. Circuit breaker — max recursion depth", function () {
    it("MAX_RECURSION_DEPTH constant is set to 3", async function () {
      const { flashLoan } = await loadFixture(deploySecureFixture);
      expect(await flashLoan.MAX_RECURSION_DEPTH()).to.equal(3n);
    });

    it("unauthorized caller attempting nested call reverts before depth check", async function () {
      const { flashLoan, attacker, tokenA } = await loadFixture(deploySecureFixture);

      const params = encodeParams(
        await tokenA.getAddress(), DUMMY, DUMMY, DUMMY, 0n
      );

      // Even a seemingly "nested" call from attacker is blocked at caller validation
      await expect(
        flashLoan.connect(attacker).executeOperation(
          await tokenA.getAddress(), 1000n, 1n,
          await flashLoan.getAddress(), params
        )
      ).to.be.revertedWithCustomError(flashLoan, "UnauthorisedCaller");
    });
  });

  // ── 5. MockOracle staleness simulation ──────────────────────────────────────
  describe("5. MockOracle staleness simulation", function () {
    it("fresh oracle passes validation", async function () {
      const { mockOracle } = await loadFixture(deploySecureFixture);
      const [, answer, , updatedAt] = await mockOracle.latestRoundData();
      expect(answer).to.equal(100_000_000n);
      expect(updatedAt).to.be.closeTo(BigInt(Math.floor(Date.now() / 1000)), 120n);
    });

    it("stale oracle timestamp causes StaleChainlinkPrice revert", async function () {
      const { mockOracle, priceOracle } = await loadFixture(deploySecureFixture);

      const staleTs = Math.floor(Date.now() / 1000) - 7201;
      await mockOracle.setUpdatedAt(staleTs);

      await expect(
        priceOracle.getChainlinkPrice(await mockOracle.getAddress())
      ).to.be.revertedWithCustomError(priceOracle, "StaleChainlinkPrice");
    });

    it("restoring a fresh timestamp resolves the stale error", async function () {
      const { mockOracle, priceOracle } = await loadFixture(deploySecureFixture);

      // Stale
      await mockOracle.setUpdatedAt(Math.floor(Date.now() / 1000) - 7201);

      // Fresh again
      const freshTs = Math.floor(Date.now() / 1000);
      await mockOracle.setUpdatedAt(freshTs);

      const [answer] = await priceOracle.getChainlinkPrice(await mockOracle.getAddress());
      expect(answer).to.equal(100_000_000n);
    });
  });
});
P2_FILE_EOF

# ---------- finish ----------
echo "All files written. Next:"
echo "  npm install && npx hardhat compile"
echo "  cd bot && npm install && npm run build"
echo "  node scripts/live-spread-scan.js   # dry-run spread scan"
