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
