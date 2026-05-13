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
