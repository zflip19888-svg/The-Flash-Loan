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
