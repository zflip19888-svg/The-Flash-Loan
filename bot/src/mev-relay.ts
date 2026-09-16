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
