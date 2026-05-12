// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title  TwapOracle
 * @notice Two-snapshot TWAP (Time-Weighted Average Price) oracle for UniswapV2-style pairs.
 *
 * @dev    UniswapV2 accumulates price0CumulativeLast / price1CumulativeLast on every swap.
 *         By recording two snapshots (t0 and t1) we derive:
 *
 *             TWAP = (accumulator_t1 - accumulator_t0) / (t1 - t0)
 *
 *         Minimum observation window is 5 minutes to resist flashloan manipulation.
 *
 *         The off-chain bot calls `update(pair)` on every block (or every few blocks).
 *         It then calls `consult(pair, amountIn)` to get a TWAP-weighted amountOut.
 *
 *         Pairs are registered by the owner.
 */
interface IUniswapV2Pair {
        function token0() external view returns (address);
        function token1() external view returns (address);
        function price0CumulativeLast() external view returns (uint256);
        function price1CumulativeLast() external view returns (uint256);
        function getReserves() external view returns (
            uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast
        );
    }

contract TwapOracle is Ownable {

    // ─────────────────────────────────────────────────────────────────────────
    // Types
    // ─────────────────────────────────────────────────────────────────────────

    struct Observation {
        uint256 timestamp;
        uint256 price0Cumulative;
        uint256 price1Cumulative;
    }

    struct PairInfo {
        address token0;
        address token1;
        Observation last;
        Observation prev;
        bool registered;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Constants
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Minimum seconds between snapshots to consider the TWAP valid.
    uint256 public constant MIN_WINDOW = 5 minutes;

    /// @notice Maximum age of the freshest snapshot before the TWAP is considered stale.
    uint256 public constant MAX_STALENESS = 1 hours;

    // ─────────────────────────────────────────────────────────────────────────
    // Storage
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice pair address → PairInfo
    mapping(address => PairInfo) public pairs;

    /// @notice all registered pair addresses
    address[] public pairList;

    // ─────────────────────────────────────────────────────────────────────────
    // Events & Errors
    // ─────────────────────────────────────────────────────────────────────────

    event PairRegistered(address indexed pair, address token0, address token1);
    event ObservationRecorded(address indexed pair, uint256 timestamp);

    error PairNotRegistered(address pair);
    error WindowTooSmall(uint256 elapsed, uint256 minimum);
    error StaleObservation(address pair, uint256 age);
    error ZeroAddress();

    // ─────────────────────────────────────────────────────────────────────────
    // Minimal UniswapV2Pair interface
    // ─────────────────────────────────────────────────────────────────────────

    // ─────────────────────────────────────────────────────────────────────────
    // Constructor
    // ─────────────────────────────────────────────────────────────────────────

    constructor() Ownable(msg.sender) {}

    // ─────────────────────────────────────────────────────────────────────────
    // Owner — pair management
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Register a UniswapV2 pair for TWAP tracking.
     * @param pair  Address of the UniswapV2Pair contract.
     */
    function registerPair(address pair) external onlyOwner {
        if (pair == address(0)) revert ZeroAddress();
        if (pairs[pair].registered) return; // idempotent

        IUniswapV2Pair p = IUniswapV2Pair(pair);
        address t0 = p.token0();
        address t1 = p.token1();

        // Seed with current accumulators so next update has a valid prev
        Observation memory seed = Observation({
            timestamp:        block.timestamp,
            price0Cumulative: _currentCumulative0(pair),
            price1Cumulative: _currentCumulative1(pair)
        });

        pairs[pair] = PairInfo({
            token0:     t0,
            token1:     t1,
            last:       seed,
            prev:       seed,
            registered: true
        });
        pairList.push(pair);

        emit PairRegistered(pair, t0, t1);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Public — snapshot update
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Record a new price observation for the given pair.
     *         Should be called by the bot on each new block (or periodically).
     * @param pair  Registered UniswapV2Pair address.
     */
    function update(address pair) external {
        PairInfo storage info = pairs[pair];
        if (!info.registered) revert PairNotRegistered(pair);

        uint256 elapsed = block.timestamp - info.last.timestamp;
        if (elapsed < 30) return; // skip if less than 30 s since last update (gas save)

        // Roll last → prev, then record new last
        info.prev = info.last;
        info.last = Observation({
            timestamp:        block.timestamp,
            price0Cumulative: _currentCumulative0(pair),
            price1Cumulative: _currentCumulative1(pair)
        });

        emit ObservationRecorded(pair, block.timestamp);
    }

    /**
     * @notice Batch update multiple pairs in one tx.
     * @param _pairs  Array of registered pair addresses.
     */
    function updateAll(address[] calldata _pairs) external {
        for (uint256 i = 0; i < _pairs.length; ++i) {
            PairInfo storage info = pairs[_pairs[i]];
            if (!info.registered) continue;
            uint256 elapsed = block.timestamp - info.last.timestamp;
            if (elapsed < 30) continue;
            info.prev = info.last;
            info.last = Observation({
                timestamp:        block.timestamp,
                price0Cumulative: _currentCumulative0(_pairs[i]),
                price1Cumulative: _currentCumulative1(_pairs[i])
            });
            emit ObservationRecorded(_pairs[i], block.timestamp);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Public — TWAP consultation
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Get the TWAP-weighted output amount for a given input.
     * @param pair      Registered pair address.
     * @param tokenIn   Must be token0 or token1 of the pair.
     * @param amountIn  Input amount (in tokenIn's native decimals).
     * @return amountOut  TWAP-weighted output amount.
     */
    function consult(
        address pair,
        address tokenIn,
        uint256 amountIn
    ) external view returns (uint256 amountOut) {
        PairInfo storage info = pairs[pair];
        if (!info.registered) revert PairNotRegistered(pair);

        uint256 window = info.last.timestamp - info.prev.timestamp;
        if (window < MIN_WINDOW) revert WindowTooSmall(window, MIN_WINDOW);

        uint256 age = block.timestamp - info.last.timestamp;
        if (age > MAX_STALENESS) revert StaleObservation(pair, age);

        // UQ112x112 fixed-point average price
        if (tokenIn == info.token0) {
            uint256 avgPrice = (info.last.price0Cumulative - info.prev.price0Cumulative) / window;
            // avgPrice is UQ112x112 (price of token0 in terms of token1)
            amountOut = (avgPrice * amountIn) >> 112;
        } else {
            uint256 avgPrice = (info.last.price1Cumulative - info.prev.price1Cumulative) / window;
            amountOut = (avgPrice * amountIn) >> 112;
        }
    }

    /**
     * @notice Returns the current window size and whether a TWAP is available.
     * @param pair  Registered pair address.
     */
    function getWindowInfo(address pair)
        external
        view
        returns (uint256 window, bool isReady, uint256 lastUpdate)
    {
        PairInfo storage info = pairs[pair];
        if (!info.registered) return (0, false, 0);
        window     = info.last.timestamp - info.prev.timestamp;
        isReady    = window >= MIN_WINDOW;
        lastUpdate = info.last.timestamp;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Internals
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @dev Read the current price0CumulativeLast, adjusting for time elapsed
     *      since the last pair interaction (mirrors UniswapV2OracleLibrary).
     */
    function _currentCumulative0(address pair) internal view returns (uint256) {
        IUniswapV2Pair p = IUniswapV2Pair(pair);
        (uint112 r0, uint112 r1, uint32 lastTs) = p.getReserves();
        uint256 acc = p.price0CumulativeLast();
        uint256 elapsed = block.timestamp - lastTs;
        if (elapsed > 0 && r0 > 0 && r1 > 0) {
            // price0 = r1/r0 as UQ112x112
            acc += uint256((uint256(r1) << 112) / uint256(r0)) * elapsed;
        }
        return acc;
    }

    function _currentCumulative1(address pair) internal view returns (uint256) {
        IUniswapV2Pair p = IUniswapV2Pair(pair);
        (uint112 r0, uint112 r1, uint32 lastTs) = p.getReserves();
        uint256 acc = p.price1CumulativeLast();
        uint256 elapsed = block.timestamp - lastTs;
        if (elapsed > 0 && r0 > 0 && r1 > 0) {
            acc += uint256((uint256(r0) << 112) / uint256(r1)) * elapsed;
        }
        return acc;
    }
}
