// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @dev Minimal Aave v3 IFlashLoanSimpleReceiver
interface IFlashLoanSimpleReceiver {
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}

/// @dev Minimal Aave v3 IPool interface (flash loan entry-point)
interface IAavePool {
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

/// @dev Minimal Aave v3 IPoolAddressesProvider
interface IPoolAddressesProvider {
    function getPool() external view returns (address);
}

/// @dev Minimal UniswapV2Router interface
interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

/**
 * @title FlashLoanPolygon
 * @notice Polygon-optimised (lighter) flash loan arbitrage contract.
 *         Uses Aave v3 flash loans to atomically arbitrage price differences
 *         between QuickSwap and SushiSwap.  Fewer guard layers than
 *         FlashLoanSecure — intended for gas benchmarking and performance
 *         comparison.
 *
 * @dev    Inherits Ownable2Step for two-step ownership transfer.
 *         Uses unchecked arithmetic where overflow is provably impossible
 *         to reduce gas consumption on Polygon.
 */
contract FlashLoanPolygon is IFlashLoanSimpleReceiver, Ownable2Step {
    using SafeERC20 for IERC20;

    // ─────────────────────────────────────────────────────────────────────────
    // Immutables
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Aave v3 PoolAddressesProvider (Polygon mainnet).
    IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;

    // ─────────────────────────────────────────────────────────────────────────
    // Well-known Polygon addresses
    // ─────────────────────────────────────────────────────────────────────────

    address public constant QUICKSWAP_ROUTER  = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;
    address public constant SUSHISWAP_ROUTER  = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;
    address public constant USDC              = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address public constant WMATIC            = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address public constant WETH              = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;

    // ─────────────────────────────────────────────────────────────────────────
    // Events
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Emitted after each successful arbitrage cycle.
    event ArbitrageExecuted(
        address indexed asset,
        uint256 profit,
        address dexA,
        address dexB,
        uint256 timestamp
    );

    // ─────────────────────────────────────────────────────────────────────────
    // Errors
    // ─────────────────────────────────────────────────────────────────────────

    error UnauthorisedCaller(address caller, address expectedPool);
    error UnauthorisedInitiator(address initiator);
    error InsufficientProfit(uint256 actual, uint256 minimum);
    error ZeroAmount();
    error ZeroAddress();

    // ─────────────────────────────────────────────────────────────────────────
    // Constructor
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @param aavePoolProvider Address of the Aave v3 PoolAddressesProvider on Polygon.
     */
    constructor(address aavePoolProvider) Ownable(msg.sender) {
        if (aavePoolProvider == address(0)) revert ZeroAddress();
        ADDRESSES_PROVIDER = IPoolAddressesProvider(aavePoolProvider);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Flash Loan Entry-Point
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Initiate a flash loan arbitrage.
     * @param asset  Token to borrow (e.g. USDC).
     * @param amount Amount to borrow (in asset's native decimals).
     * @param params ABI-encoded arbitrage parameters — see _executeArbitrage.
     */
    function initiateFlashLoan(
        address asset,
        uint256 amount,
        bytes calldata params
    ) external onlyOwner {
        if (amount == 0) revert ZeroAmount();
        address pool = ADDRESSES_PROVIDER.getPool();
        IAavePool(pool).flashLoanSimple(address(this), asset, amount, params, 0);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Aave Callback
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Called by the Aave pool after disbursing the flash loan.
     * @param asset     Borrowed asset address.
     * @param amount    Borrowed amount.
     * @param premium   Aave flash loan fee (amount * 0.05%).
     * @param initiator Address that called flashLoanSimple.
     * @param params    Forwarded arbitrage parameters.
     * @return          Always true (reverts on failure).
     */
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        address pool = ADDRESSES_PROVIDER.getPool();
        if (msg.sender != pool) revert UnauthorisedCaller(msg.sender, pool);
        if (initiator != address(this)) revert UnauthorisedInitiator(initiator);

        _executeArbitrage(asset, amount, premium, params);

        // Approve repayment
        uint256 totalOwed;
        unchecked { totalOwed = amount + premium; }
        IERC20(asset).safeIncreaseAllowance(pool, totalOwed);

        return true;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Core Arbitrage Logic
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Execute the two-leg arbitrage swap atomically.
     * @dev    Params encoding: abi.encode(tokenIn, tokenOut, dexA, dexB, minProfit)
     * @param asset     Borrowed (and repaid) asset.
     * @param amount    Borrowed amount.
     * @param premium   Aave fee due.
     * @param params    Encoded (tokenIn, tokenOut, dexA, dexB, minProfit).
     */
    function _executeArbitrage(
        address asset,
        uint256 amount,
        uint256 premium,
        bytes calldata params
    ) internal {
        (
            address tokenIn,
            address tokenOut,
            address dexA,
            address dexB,
            uint256 minProfit
        ) = abi.decode(params, (address, address, address, address, uint256));

        // Leg 1: buy tokenOut on dexA using tokenIn (the borrowed asset)
        IERC20(tokenIn).safeIncreaseAllowance(dexA, amount);
        address[] memory pathAB = new address[](2);
        pathAB[0] = tokenIn;
        pathAB[1] = tokenOut;
        uint256[] memory outAmountsA = IUniswapV2Router(dexA).swapExactTokensForTokens(
            amount,
            1, // min out — slippage enforced by minProfit below
            pathAB,
            address(this),
            block.timestamp + 300
        );
        uint256 receivedOut = outAmountsA[1];

        // Leg 2: sell tokenOut on dexB back to tokenIn
        IERC20(tokenOut).safeIncreaseAllowance(dexB, receivedOut);
        address[] memory pathBA = new address[](2);
        pathBA[0] = tokenOut;
        pathBA[1] = tokenIn;
        uint256[] memory outAmountsB = IUniswapV2Router(dexB).swapExactTokensForTokens(
            receivedOut,
            1,
            pathBA,
            address(this),
            block.timestamp + 300
        );
        uint256 returnedIn = outAmountsB[1];

        // Profit check (unchecked: totalOwed ≤ amount + premium ≤ returnedIn)
        uint256 totalOwed;
        unchecked { totalOwed = amount + premium; }
        if (returnedIn < totalOwed) {
            revert InsufficientProfit(0, minProfit);
        }
        uint256 profit;
        unchecked { profit = returnedIn - totalOwed; }
        if (profit < minProfit) revert InsufficientProfit(profit, minProfit);

        emit ArbitrageExecuted(asset, profit, dexA, dexB, block.timestamp);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Owner Utilities
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Withdraw any ERC-20 token profit accumulated in this contract.
     * @param token  Token to withdraw.
     * @param amount Amount to withdraw (0 = full balance).
     */
    function withdrawToken(address token, uint256 amount) external onlyOwner {
        uint256 bal = IERC20(token).balanceOf(address(this));
        uint256 withdrawAmt = amount == 0 ? bal : amount;
        IERC20(token).safeTransfer(owner(), withdrawAmt);
    }

    /**
     * @notice Withdraw native MATIC accumulated in this contract.
     */
    function withdrawMATIC() external onlyOwner {
        (bool ok,) = payable(owner()).call{value: address(this).balance}("");
        require(ok, "MATIC transfer failed");
    }

    receive() external payable {}
}
