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
