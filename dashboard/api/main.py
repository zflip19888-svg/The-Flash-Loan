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
