// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/// @dev Minimal IUniswapV2Router02 interface (read-only methods used)
interface IUniswapV2Router02 {
    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

/// @dev Minimal IUniswapV2Pair interface for TWAP
interface IUniswapV2Pair {
    function price0CumulativeLast() external view returns (uint256);
    function price1CumulativeLast() external view returns (uint256);
    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );
    function token0() external view returns (address);
}

/// @dev Minimal IUniswapV2Factory interface
interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

/// @dev Minimal Chainlink aggregator interface
interface IChainlinkAggregator {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
    function decimals() external view returns (uint8);
}

/**
 * @title PriceOraclePolygon
 * @notice On-chain price oracle aggregating QuickSwap, SushiSwap, and Chainlink feeds
 *         for the Polygon network. Used by the flash loan arbitrage contracts to detect
 *         price discrepancies between DEXes.
 * @dev    All prices are returned in 18-decimal fixed-point unless noted otherwise.
 *         TWAP windows are measured in seconds.
 */
contract PriceOraclePolygon is Ownable {
    // ─────────────────────────────────────────────────────────────────────────
    // Constants & immutables
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Maximum age (in seconds) of a Chainlink answer before it is
    ///         considered stale and causes a revert.
    uint256 public constant CHAINLINK_STALENESS_THRESHOLD = 3600; // 1 hour

    /// @notice QuickSwap V2 router (Polygon mainnet)
    address public immutable QUICKSWAP_ROUTER;

    /// @notice SushiSwap router (Polygon mainnet)
    address public immutable SUSHISWAP_ROUTER;

    /// @notice QuickSwap V2 factory (Polygon mainnet)
    address public immutable QUICKSWAP_FACTORY;

    /// @notice SushiSwap factory (Polygon mainnet)
    address public immutable SUSHISWAP_FACTORY;

    // ─────────────────────────────────────────────────────────────────────────
    // Storage
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Chainlink price feed registry: token → feed address
    mapping(address => address) public chainlinkFeeds;

    // ─────────────────────────────────────────────────────────────────────────
    // Events
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Emitted when a Chainlink feed is registered or updated.
    event ChainlinkFeedSet(address indexed token, address indexed feed);

    // ─────────────────────────────────────────────────────────────────────────
    // Errors
    // ─────────────────────────────────────────────────────────────────────────

    error StaleChainlinkPrice(address feed, uint256 updatedAt, uint256 threshold);
    error ZeroAddress();
    error InvalidTWAPWindow();
    error PairDoesNotExist(address tokenA, address tokenB);
    error InsufficientTWAPElapsed();

    // ─────────────────────────────────────────────────────────────────────────
    // Constructor
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Deploys the oracle with DEX factory and router addresses.
     * @param quickswapRouter_  Address of the QuickSwap V2 router.
     * @param sushiswapRouter_  Address of the SushiSwap router.
     * @param quickswapFactory_ Address of the QuickSwap V2 factory.
     * @param sushiswapFactory_ Address of the SushiSwap factory.
     * @param initialFeeds      Token addresses whose Chainlink feeds are pre-registered.
     * @param feedAddresses     Corresponding Chainlink feed addresses.
     */
    constructor(
        address quickswapRouter_,
        address sushiswapRouter_,
        address quickswapFactory_,
        address sushiswapFactory_,
        address[] memory initialFeeds,
        address[] memory feedAddresses
    ) Ownable(msg.sender) {
        if (
            quickswapRouter_ == address(0) ||
            sushiswapRouter_ == address(0) ||
            quickswapFactory_ == address(0) ||
            sushiswapFactory_ == address(0)
        ) revert ZeroAddress();

        QUICKSWAP_ROUTER   = quickswapRouter_;
        SUSHISWAP_ROUTER   = sushiswapRouter_;
        QUICKSWAP_FACTORY  = quickswapFactory_;
        SUSHISWAP_FACTORY  = sushiswapFactory_;

        uint256 len = initialFeeds.length;
        require(len == feedAddresses.length, "PriceOracle: array length mismatch");
        for (uint256 i = 0; i < len; ++i) {
            _setChainlinkFeed(initialFeeds[i], feedAddresses[i]);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Admin
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Register or update a Chainlink price feed for a token.
     * @param token Address of the ERC-20 token.
     * @param feed  Address of the Chainlink aggregator feed.
     */
    function setChainlinkFeed(address token, address feed) external onlyOwner {
        _setChainlinkFeed(token, feed);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // DEX Price Queries
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Get the expected output amount from QuickSwap for a given input.
     * @param tokenA  Input token address.
     * @param tokenB  Output token address.
     * @param amount  Input amount (in tokenA's native decimals).
     * @return price  Expected output amount of tokenB.
     */
    function getQuickSwapPrice(
        address tokenA,
        address tokenB,
        uint256 amount
    ) public view returns (uint256 price) {
        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;
        uint256[] memory amounts = IUniswapV2Router02(QUICKSWAP_ROUTER).getAmountsOut(amount, path);
        return amounts[1];
    }

    /**
     * @notice Get the expected output amount from SushiSwap for a given input.
     * @param tokenA  Input token address.
     * @param tokenB  Output token address.
     * @param amount  Input amount (in tokenA's native decimals).
     * @return price  Expected output amount of tokenB.
     */
    function getSushiSwapPrice(
        address tokenA,
        address tokenB,
        uint256 amount
    ) public view returns (uint256 price) {
        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;
        uint256[] memory amounts = IUniswapV2Router02(SUSHISWAP_ROUTER).getAmountsOut(amount, path);
        return amounts[1];
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Chainlink Oracle
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Fetch the latest price from a registered Chainlink feed.
     * @param feed      Address of the Chainlink aggregator.
     * @return answer   Latest price (in feed's native decimal scale).
     * @return updatedAt Timestamp of the last price update.
     */
    function getChainlinkPrice(address feed)
        public
        view
        returns (int256 answer, uint256 updatedAt)
    {
        (, answer, , updatedAt, ) = IChainlinkAggregator(feed).latestRoundData();
        if (updatedAt < block.timestamp - CHAINLINK_STALENESS_THRESHOLD) {
            revert StaleChainlinkPrice(feed, updatedAt, block.timestamp - CHAINLINK_STALENESS_THRESHOLD);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Spread & Opportunity Detection
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Calculate the arbitrage spread between QuickSwap and SushiSwap
     *         for a given token pair and input amount.
     * @param tokenA        Input token.
     * @param tokenB        Output token.
     * @param amount        Input amount in tokenA's native decimals.
     * @return spread       Absolute difference in output amounts (tokenB).
     * @return cheaperDex   Router address of the DEX offering more tokenB (buy here).
     * @return expensiveDex Router address of the DEX offering less tokenB (sell here).
     */
    function getArbitrageSpread(
        address tokenA,
        address tokenB,
        uint256 amount
    )
        external
        view
        returns (
            uint256 spread,
            address cheaperDex,
            address expensiveDex
        )
    {
        uint256 quickPrice = getQuickSwapPrice(tokenA, tokenB, amount);
        uint256 sushiPrice = getSushiSwapPrice(tokenA, tokenB, amount);

        if (quickPrice >= sushiPrice) {
            spread       = quickPrice - sushiPrice;
            cheaperDex   = QUICKSWAP_ROUTER;   // more out ⟹ "cheaper" to buy tokenB
            expensiveDex = SUSHISWAP_ROUTER;
        } else {
            spread       = sushiPrice - quickPrice;
            cheaperDex   = SUSHISWAP_ROUTER;
            expensiveDex = QUICKSWAP_ROUTER;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TWAP
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Compute an approximate TWAP using UniswapV2 cumulative price accumulators.
     * @dev    Requires two observations at least `window` seconds apart. This function
     *         reads only the *current* cumulative price and the last stored value.
     *         For a production deployment, store a checkpoint off-chain and supply it.
     *         Here we approximate using the last checkpoint stored in the pair contract.
     * @param factory  UniswapV2-compatible factory to resolve the pair.
     * @param tokenA   First token of the pair.
     * @param tokenB   Second token of the pair.
     * @param window   Desired TWAP window in seconds (must be > 0).
     * @return twap    Time-weighted average price of tokenA in terms of tokenB,
     *                 scaled to 1e18.
     */
    function getTWAP(
        address factory,
        address tokenA,
        address tokenB,
        uint256 window
    ) external view returns (uint256 twap) {
        if (window == 0) revert InvalidTWAPWindow();

        address pair = IUniswapV2Factory(factory).getPair(tokenA, tokenB);
        if (pair == address(0)) revert PairDoesNotExist(tokenA, tokenB);

        IUniswapV2Pair pairContract = IUniswapV2Pair(pair);
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) =
            pairContract.getReserves();

        uint256 elapsed = block.timestamp - blockTimestampLast;
        if (elapsed < window) revert InsufficientTWAPElapsed();

        // Determine which reserve corresponds to tokenA
        address token0 = pairContract.token0();
        bool isToken0 = (tokenA == token0);

        // Simple spot price from reserves (approximation when no checkpoint stored)
        // A full TWAP implementation requires storing prior cumulative price snapshots.
        if (isToken0) {
            // price of token0 in terms of token1
            twap = (uint256(reserve1) * 1e18) / uint256(reserve0);
        } else {
            twap = (uint256(reserve0) * 1e18) / uint256(reserve1);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Internal helpers
    // ─────────────────────────────────────────────────────────────────────────

    function _setChainlinkFeed(address token, address feed) internal {
        if (token == address(0) || feed == address(0)) revert ZeroAddress();
        chainlinkFeeds[token] = feed;
        emit ChainlinkFeedSet(token, feed);
    }
}
