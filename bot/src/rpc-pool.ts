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
