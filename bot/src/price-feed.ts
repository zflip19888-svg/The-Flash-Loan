/**
 * @file price-feed.ts
 * @notice On-chain Chainlink price feed reader — replaces the CoinGecko HTTP call
 *         in scanner.ts with direct on-chain reads.  No external HTTP dependency.
 *
 * Usage:
 *   const feed = new ChainlinkPriceFeed(provider);
 *   const maticUsd = await feed.getPrice(FEEDS.MATIC_USD);  // returns float
 */

import { Contract, JsonRpcProvider } from "ethers";
import { logWarn, logError } from "./logger";

// ─────────────────────────────────────────────────────────────────────────────
// Chainlink AggregatorV3 ABI (minimal)
// ─────────────────────────────────────────────────────────────────────────────

const AGGREGATOR_ABI = [
  "function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)",
  "function decimals() external view returns (uint8)",
] as const;

// ─────────────────────────────────────────────────────────────────────────────
// Well-known Polygon mainnet Chainlink feeds
// ─────────────────────────────────────────────────────────────────────────────

export const FEEDS = {
  MATIC_USD : "0xAB594600376Ec9fD91F8e885dADF0CE036862dE0",
  USDC_USD  : "0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7",
  ETH_USD   : "0xF9680D99D6C9589e2a93a78A04A279e509205945",
  BTC_USD   : "0xc907E116054Ad103354f2D350FD2514433D57F6f",
  DAI_USD   : "0x4746DeC9e833A82EC7C2C1356372CcF2cfcD2F3D",
} as const;

/** Map from token address → Chainlink feed address */
export const TOKEN_TO_FEED: Record<string, string> = {
  "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270": FEEDS.MATIC_USD, // WMATIC
  "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174": FEEDS.USDC_USD,  // USDC
  "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619": FEEDS.ETH_USD,   // WETH
};

// ─────────────────────────────────────────────────────────────────────────────
// Max staleness for price feed data
// ─────────────────────────────────────────────────────────────────────────────

const MAX_FEED_AGE_S = 3600; // 1 hour

// ─────────────────────────────────────────────────────────────────────────────
// Cache (TTL = 30 seconds to avoid hammering RPC)
// ─────────────────────────────────────────────────────────────────────────────

interface CacheEntry {
  price:     number;
  fetchedAt: number; // unix ms
}

const CACHE_TTL_MS = 30_000;

// ─────────────────────────────────────────────────────────────────────────────
// ChainlinkPriceFeed
// ─────────────────────────────────────────────────────────────────────────────

export class ChainlinkPriceFeed {
  private provider: JsonRpcProvider;
  private cache = new Map<string, CacheEntry>();

  constructor(provider: JsonRpcProvider) {
    this.provider = provider;
  }

  /**
   * @notice Fetch the latest USD price for a Chainlink feed address.
   * @param feedAddress  Chainlink AggregatorV3 contract address.
   * @param fallback     Value to return if the feed is unreachable (default: 0).
   * @returns            Price in USD as a float.
   */
  async getPrice(feedAddress: string, fallback = 0): Promise<number> {
    // Check cache first
    const cached = this.cache.get(feedAddress);
    if (cached && Date.now() - cached.fetchedAt < CACHE_TTL_MS) {
      return cached.price;
    }

    try {
      const agg = new Contract(feedAddress, AGGREGATOR_ABI, this.provider);

      const [decimalsRaw, [, answer, , updatedAt]] = await Promise.all([
        agg.decimals(),
        agg.latestRoundData(),
      ]);

      const decimals  = Number(decimalsRaw);
      const age       = Math.floor(Date.now() / 1000) - Number(updatedAt);

      if (age > MAX_FEED_AGE_S) {
        logWarn("ChainlinkPriceFeed: stale data — using fallback", {
          feedAddress, ageSecs: age, maxAge: MAX_FEED_AGE_S,
        });
        return fallback;
      }

      const price = Number(answer) / 10 ** decimals;

      this.cache.set(feedAddress, { price, fetchedAt: Date.now() });
      return price;

    } catch (err) {
      logError("ChainlinkPriceFeed: failed to fetch price", err, { feedAddress });
      return fallback;
    }
  }

  /**
   * @notice Convenience: get USD price for a token by its ERC-20 address.
   * @param tokenAddress  ERC-20 token address (must be in TOKEN_TO_FEED map).
   * @param fallback      Value returned if no feed is mapped or feed is unreachable.
   */
  async getTokenPriceUsd(tokenAddress: string, fallback = 0): Promise<number> {
    const feed = TOKEN_TO_FEED[tokenAddress.toLowerCase()] ??
                 TOKEN_TO_FEED[tokenAddress];
    if (!feed) {
      logWarn("ChainlinkPriceFeed: no feed mapped for token", { tokenAddress });
      return fallback;
    }
    return this.getPrice(feed, fallback);
  }

  /**
   * @notice Pre-warm the cache for all tokens in TOKEN_TO_FEED.
   */
  async warmCache(): Promise<void> {
    await Promise.allSettled(
      Object.values(FEEDS).map((f) => this.getPrice(f))
    );
  }

  /** Flush the entire cache (e.g. on a new block to force fresh reads). */
  flushCache(): void {
    this.cache.clear();
  }
}
