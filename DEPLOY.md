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

