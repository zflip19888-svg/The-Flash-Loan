#!/usr/bin/env bash
# Generates rebuild-from-scratch.sh from tracked source files.
set -euo pipefail
cd /app
OUT="scripts/rebuild-from-scratch.sh"
DELIM="P2_FILE_EOF"

FILES=(
  .env.example
  .env.scan
  .eslintrc.js
  .gitattributes
  .gitignore
  .prettierrc.js
  .railwayignore
  DEPLOY.md
  Dockerfile
  RAILWAY.md
  hardhat.config.js
  package.json
  railway.toml
  size-sweep.js
  "base44/connectors/github.jsonc"
  "base44/connectors/notion.jsonc"
  "base44/workflows/Bot Anomaly GitHub Issue Reporter.jsonc"
  "base44/workflows/Daily Scan + Commit Opportunity Log.jsonc"
  "bot/.env.example"
  "bot/package.json"
  "bot/src/config.ts"
  "bot/src/gas-bidder.ts"
  "bot/src/hmm.ts"
  "bot/src/index.ts"
  "bot/src/logger.ts"
  "bot/src/loop.ts"
  "bot/src/mev-relay.ts"
  "bot/src/nonce-manager.ts"
  "bot/src/opportunity-log.ts"
  "bot/src/price-feed.ts"
  "bot/src/rpc-pool.ts"
  "bot/src/scanner.ts"
  "bot/tsconfig.json"
  "contracts/FlashLoanPolygon.sol"
  "contracts/FlashLoanSecure.sol"
  "contracts/MockOracle.sol"
  "contracts/PriceOraclePolygon.sol"
  "contracts/TwapOracle.sol"
  "contracts/test/MockAavePool.sol"
  "contracts/test/MockAddressesProvider.sol"
  "contracts/test/MockERC20.sol"
  "contracts/test/MockRouter.sol"
  "dashboard/api/main.py"
  "dashboard/api/requirements.txt"
  "dashboard/index.html"
  "dashboard/orchestrator.sh"
  "dashboard/runtime.json"
  "scripts/deploy-polygon-mumbai.js"
  "scripts/deploy-polygon.js"
  "scripts/emergency-withdraw.js"
  "scripts/live-spread-scan.js"
  "scripts/pre-deploy-check.js"
  "scripts/set-volume-limits.js"
  "scripts/verify-deployment.js"
  "test/FlashLoanPolygon.fork.test.js"
  "test/FlashLoanPolygon.test.js"
  "test/FlashLoanSecurity.js"
  "test/Reproduction.test.js"
)

{
  echo '#!/usr/bin/env bash'
  echo '# ====================================================================='
  echo '# The-Flash-Loan - full rebuild from scratch (generated)'
  echo '# Recreates every source file via cat << heredocs. Generated on:'
  echo "#   $(date -u '+%Y-%m-%d %H:%M UTC') from repo $(git rev-parse --short HEAD 2>/dev/null || echo 'main')"
  echo '# Usage:  mkdir The-Flash-Loan && cd The-Flash-Loan && bash rebuild-from-scratch.sh'
  echo '# Then:   npm install && npx hardhat compile && (cd bot && npm install && npm run build)'
  echo '# Secrets (RPC URL, PRIVATE_KEY, GITHUB_TOKEN_2, contract addresses) must'
  echo '# be re-supplied via env/.env - they are NOT included here.'
  echo '# ====================================================================='
  echo 'set -euo pipefail'
  echo ''
  echo 'mkdir -p \'
  for d in $(printf '%s\n' "${FILES[@]}" | xargs -n1 dirname | sort -u); do
    echo "  $d \\"
  done
  echo '  logs output'
  echo ''
  for f in "${FILES[@]}"; do
    if grep -qx "${DELIM}" "$f" 2>/dev/null; then
      echo "ERROR: $f contains the delimiter '$DELIM'" >&2
      exit 1
    fi
    echo "# ---------- $f ----------"
    echo "cat > '$f' << '${DELIM}'"
    cat "$f"
    if [ -z "$(tail -c 1 "$f")" ]; then
      # file already ends with newline: delimiter lands on its own line
      echo "${DELIM}"
    else
      # no trailing newline: emit a newline so the delimiter is on its own
      # line, then strip that added byte to restore exact original bytes
      echo ""
      echo "${DELIM}"
      echo "head -c -1 '$f' > '$f.__tmp' && mv '$f.__tmp' '$f'"
    fi
    echo ''
  done
  echo '# ---------- finish ----------'
  echo 'echo "All files written. Next:"'
  echo 'echo "  npm install && npx hardhat compile"'
  echo 'echo "  cd bot && npm install && npm run build"'
  echo 'echo "  node scripts/live-spread-scan.js   # dry-run spread scan"'
} > "$OUT"

echo "Wrote $OUT ($(wc -c < "$OUT") bytes, ${#FILES[@]} files)"
