// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MockOracle
 * @notice Mock implementation of a Chainlink AggregatorV3Interface for Hardhat tests.
 *         Allows manual control of the reported price and updatedAt timestamp so tests
 *         can simulate both fresh and stale oracle data.
 */
contract MockOracle {
    // ─────────────────────────────────────────────────────────────────────────
    // Storage
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Simulated price returned by latestRoundData.
    int256 private _price;

    /// @notice Simulated updatedAt timestamp returned by latestRoundData.
    uint256 private _updatedAt;

    /// @notice Decimal precision of the mock feed (default: 8, same as Chainlink USD feeds).
    uint8 private _decimals;

    /// @notice Internal round counter.
    uint80 private _roundId;

    // ─────────────────────────────────────────────────────────────────────────
    // Events
    // ─────────────────────────────────────────────────────────────────────────

    event PriceSet(int256 price, uint256 updatedAt);

    // ─────────────────────────────────────────────────────────────────────────
    // Constructor
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @param initialPrice  Initial mock price (e.g. 100000000 = $1.00 with 8 decimals).
     * @param decimals_     Decimal precision of this feed (e.g. 8 for USD feeds).
     */
    constructor(int256 initialPrice, uint8 decimals_) {
        _price     = initialPrice;
        _decimals  = decimals_;
        _updatedAt = block.timestamp;
        _roundId   = 1;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Setter helpers (test utilities)
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Overwrite the mock price and set updatedAt to block.timestamp.
     * @param price New price to report.
     */
    function setPrice(int256 price) external {
        _price     = price;
        _updatedAt = block.timestamp;
        unchecked { ++_roundId; }
        emit PriceSet(price, _updatedAt);
    }

    /**
     * @notice Overwrite updatedAt without changing the price.
     *         Use a value in the past to simulate a stale feed.
     * @param updatedAt_ New updatedAt timestamp.
     */
    function setUpdatedAt(uint256 updatedAt_) external {
        _updatedAt = updatedAt_;
    }

    /**
     * @notice Overwrite both price and updatedAt in one call.
     * @param price     New price.
     * @param updatedAt_ New updatedAt timestamp.
     */
    function setPriceAndUpdatedAt(int256 price, uint256 updatedAt_) external {
        _price     = price;
        _updatedAt = updatedAt_;
        unchecked { ++_roundId; }
        emit PriceSet(price, _updatedAt);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // IChainlinkAggregator implementation
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Returns the mock round data.
     * @return roundId       Current round ID.
     * @return answer        Simulated price.
     * @return startedAt     Same as updatedAt for simplicity.
     * @return updatedAt     Simulated last-update timestamp.
     * @return answeredInRound Same as roundId.
     */
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (_roundId, _price, _updatedAt, _updatedAt, _roundId);
    }

    /**
     * @notice Returns the decimal precision of this mock feed.
     * @return Decimal places (e.g. 8).
     */
    function decimals() external view returns (uint8) {
        return _decimals;
    }

    /**
     * @notice Returns the description of this mock feed.
     */
    function description() external pure returns (string memory) {
        return "Mock Chainlink Aggregator";
    }

    /**
     * @notice Returns the version of this mock.
     */
    function version() external pure returns (uint256) {
        return 4;
    }
}
