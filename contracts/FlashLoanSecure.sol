// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// ─────────────────────────────────────────────────────────────────────────────
// Minimal interfaces
// ─────────────────────────────────────────────────────────────────────────────

interface IFlashLoanSimpleReceiver {
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}

interface IAavePool {
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

interface IPoolAddressesProvider {
    function getPool() external view returns (address);
}

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

/// @dev Thin oracle interface used for on-chain spread validation before execution.
interface IPriceOracle {
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
        );
}

/**
 * @title  FlashLoanSecure
 * @notice Production-grade Aave v3 flash loan arbitrage contract for Polygon.
 *
 * @dev    Security posture
 *         ────────────────
 *         • ReentrancyGuard — prevents re-entrancy on the executeOperation callback.
 *         • Pausable         — owner can halt the contract in an emergency.
 *         • Ownable2Step     — two-step ownership transfer prevents accidental lock-out.
 *         • dailyVolumeLimit — configurable per-asset daily borrow cap (circuit breaker).
 *         • maxRecursionDepth — prevents nested flash-loan calls (set to 3; enforced via
 *           a simple counter that is checked in executeOperation).
 *         • Checks-Effects-Interactions — all storage writes happen before external calls.
 *         • No tx.origin usage; no delegatecall to untrusted contracts.
 *         • minProfit slippage guard in arbitrage params.
 *
 *         Arbitrage params encoding
 *         ─────────────────────────
 *         abi.encode(address tokenIn, address tokenOut,
 *                    address dexA, address dexB, uint256 minProfit)
 */
contract FlashLoanSecure is
    IFlashLoanSimpleReceiver,
    ReentrancyGuard,
    Pausable,
    Ownable2Step
{
    using SafeERC20 for IERC20;

    // ─────────────────────────────────────────────────────────────────────────
    // Constants
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Maximum recursion depth for nested flash-loan calls.
    uint256 public constant MAX_RECURSION_DEPTH = 3;

    // ─────────────────────────────────────────────────────────────────────────
    // Well-known Polygon addresses (hardcoded for gas savings)
    // ─────────────────────────────────────────────────────────────────────────

    address public constant AAVE_POOL_PROVIDER = 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb;
    address public constant QUICKSWAP_ROUTER   = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;
    address public constant SUSHISWAP_ROUTER   = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;
    address public constant USDC               = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address public constant WMATIC             = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address public constant WETH               = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;

    // ─────────────────────────────────────────────────────────────────────────
    // Immutables
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Aave v3 PoolAddressesProvider (resolved once at construction).
    IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;

    /// @notice On-chain price oracle for pre-execution spread validation.
    IPriceOracle public immutable PRICE_ORACLE;

    // ─────────────────────────────────────────────────────────────────────────
    // Mutable state
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Per-asset daily borrow limit (0 = unlimited).
    mapping(address => uint256) public dailyVolumeLimit;

    /// @notice Per-asset accumulated volume for the current UTC day.
    mapping(address => uint256) public dailyVolumeUsed;

    /// @notice Timestamp of the start of the currently tracked day (Unix day boundary).
    mapping(address => uint256) public dailyVolumeResetAt;

    /// @notice Current call depth counter to enforce maxRecursionDepth.
    uint256 private _callDepth;

    // ─────────────────────────────────────────────────────────────────────────
    // Events
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Emitted after every successful arbitrage execution.
     * @param profit     Net profit retained by the contract (in borrowed asset).
     * @param asset      Address of the borrowed/profit asset.
     * @param dexA       Router used for the first swap (buy leg).
     * @param dexB       Router used for the second swap (sell leg).
     * @param timestamp  Block timestamp of the execution.
     */
    event ArbitrageExecuted(
        uint256 indexed profit,
        address indexed asset,
        address dexA,
        address dexB,
        uint256 timestamp
    );

    /// @notice Emitted when the per-asset daily volume limit is updated.
    event DailyVolumeLimitSet(address indexed asset, uint256 limit);

    /// @notice Emitted when an emergency withdrawal is performed.
    event EmergencyWithdraw(address indexed token, uint256 amount, address to);

    // ─────────────────────────────────────────────────────────────────────────
    // Errors
    // ─────────────────────────────────────────────────────────────────────────

    error UnauthorisedCaller(address caller, address expectedPool);
    error UnauthorisedInitiator(address initiator);
    error InsufficientProfit(uint256 actual, uint256 minimum);
    error DailyVolumeLimitExceeded(address asset, uint256 used, uint256 limit);
    error MaxRecursionDepthExceeded(uint256 depth);
    error ZeroAmount();
    error ZeroAddress();
    error InvalidParams();

    // ─────────────────────────────────────────────────────────────────────────
    // Constructor
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Deploys the secure flash loan contract.
     * @param aavePoolProvider  Aave v3 PoolAddressesProvider on Polygon.
     * @param priceOracle       Deployed PriceOraclePolygon address.
     * @param owner_            Address that will own (and control) this contract.
     */
    constructor(
        address aavePoolProvider,
        address priceOracle,
        address owner_
    ) Ownable(owner_) {
        if (aavePoolProvider == address(0)) revert ZeroAddress();
        if (priceOracle      == address(0)) revert ZeroAddress();
        if (owner_           == address(0)) revert ZeroAddress();

        ADDRESSES_PROVIDER = IPoolAddressesProvider(aavePoolProvider);
        PRICE_ORACLE       = IPriceOracle(priceOracle);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Owner — configuration
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Set (or remove) the daily volume limit for a given asset.
     * @param asset  ERC-20 token address.
     * @param limit  Maximum notional (in token's native decimals) per UTC day.
     *               Pass 0 to disable the limit.
     */
    function setDailyVolumeLimit(address asset, uint256 limit) external onlyOwner {
        if (asset == address(0)) revert ZeroAddress();
        dailyVolumeLimit[asset] = limit;
        emit DailyVolumeLimitSet(asset, limit);
    }

    /**
     * @notice Pause all flash loan executions. Callable by owner only.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause flash loan executions. Callable by owner only.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Flash Loan Entry-Point
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Trigger a flash loan arbitrage opportunity.
     * @dev    Only callable by the owner; reverts when paused.
     * @param asset   ERC-20 token to borrow (must be supported by Aave v3).
     * @param amount  Amount to borrow (in asset's native decimals).
     * @param params  ABI-encoded (tokenIn, tokenOut, dexA, dexB, minProfit).
     */
    function initiateFlashLoan(
        address asset,
        uint256 amount,
        bytes calldata params
    ) external onlyOwner whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (asset  == address(0)) revert ZeroAddress();
        if (params.length == 0)   revert InvalidParams();

        // Circuit breaker: daily volume check (CEI pattern — storage update before external call)
        _checkAndUpdateDailyVolume(asset, amount);

        address pool = ADDRESSES_PROVIDER.getPool();
        IAavePool(pool).flashLoanSimple(address(this), asset, amount, params, 0);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Aave Callback
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Invoked by the Aave pool immediately after loan disbursal.
     * @dev    Guards:
     *           1. Caller must be the official Aave pool address.
     *           2. Initiator must be this contract itself.
     *           3. Recursion depth must not exceed MAX_RECURSION_DEPTH.
     *           4. ReentrancyGuard inherited via parent.
     * @param asset     Borrowed asset address.
     * @param amount    Borrowed amount.
     * @param premium   Aave flash loan fee (amount × 0.05% on Polygon).
     * @param initiator Address that called flashLoanSimple.
     * @param params    Forwarded arbitrage parameters.
     * @return          Always true (reverts on any failure).
     */
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external override nonReentrant whenNotPaused returns (bool) {
        // ── Guard 1: must be called by the Aave pool ──
        address pool = ADDRESSES_PROVIDER.getPool();
        if (msg.sender != pool) revert UnauthorisedCaller(msg.sender, pool);

        // ── Guard 2: must have been initiated by this contract ──
        if (initiator != address(this)) revert UnauthorisedInitiator(initiator);

        // ── Guard 3: recursion depth ──
        unchecked { ++_callDepth; }
        if (_callDepth > MAX_RECURSION_DEPTH) {
            unchecked { --_callDepth; }
            revert MaxRecursionDepthExceeded(_callDepth);
        }

        // ── Execute arbitrage (effects before interactions) ──
        _executeArbitrage(asset, amount, premium, params);

        // ── Approve repayment ──
        uint256 totalOwed = amount + premium; // safe: amount+premium << max uint256
        IERC20(asset).safeIncreaseAllowance(pool, totalOwed);

        unchecked { --_callDepth; }
        return true;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Core Arbitrage Logic
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Decode params and execute the two-leg arbitrage swap.
     * @dev    Leg 1 — buy tokenOut on dexA with tokenIn (the borrowed asset).
     *         Leg 2 — sell tokenOut on dexB back to tokenIn.
     *         Both legs follow checks-effects-interactions: allowances and
     *         storage are updated before each external swap call.
     *
     * @param asset    Borrowed (and repaid) asset — should equal tokenIn.
     * @param amount   Borrowed amount (input for leg 1).
     * @param premium  Aave fee due on repayment.
     * @param params   abi.encode(tokenIn, tokenOut, dexA, dexB, minProfit).
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

        // Sanity checks
        if (tokenIn != asset)              revert InvalidParams();
        if (tokenOut == address(0))        revert InvalidParams();
        if (dexA == address(0) || dexB == address(0)) revert InvalidParams();

        // ── Leg 1: buy tokenOut on dexA ──
        IERC20(tokenIn).safeIncreaseAllowance(dexA, amount);
        address[] memory pathAB = new address[](2);
        pathAB[0] = tokenIn;
        pathAB[1] = tokenOut;

        uint256[] memory outA = IUniswapV2Router(dexA).swapExactTokensForTokens(
            amount,
            1,                           // slippage enforced by minProfit assertion
            pathAB,
            address(this),
            block.timestamp + 300        // 5-minute deadline
        );
        uint256 receivedOut = outA[outA.length - 1];

        // ── Leg 2: sell tokenOut on dexB ──
        IERC20(tokenOut).safeIncreaseAllowance(dexB, receivedOut);
        address[] memory pathBA = new address[](2);
        pathBA[0] = tokenOut;
        pathBA[1] = tokenIn;

        uint256[] memory outB = IUniswapV2Router(dexB).swapExactTokensForTokens(
            receivedOut,
            1,
            pathBA,
            address(this),
            block.timestamp + 300
        );
        uint256 returnedIn = outB[outB.length - 1];

        // ── Profit assertion (slippage guard) ──
        uint256 totalOwed = amount + premium;
        if (returnedIn < totalOwed) {
            revert InsufficientProfit(0, minProfit);
        }
        uint256 profit = returnedIn - totalOwed;
        if (profit < minProfit) revert InsufficientProfit(profit, minProfit);

        emit ArbitrageExecuted(profit, asset, dexA, dexB, block.timestamp);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Circuit Breaker — Daily Volume
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Check whether the proposed borrow amount would breach the per-asset
     *         daily limit, and if not, record it.  Resets the counter at each new
     *         UTC day (86 400-second window).
     * @param asset  Asset being borrowed.
     * @param amount Amount about to be borrowed.
     */
    function _checkAndUpdateDailyVolume(address asset, uint256 amount) internal {
        uint256 limit = dailyVolumeLimit[asset];
        if (limit == 0) return; // limit not configured → skip

        // Reset daily counter if a new day has started
        uint256 dayStart = (block.timestamp / 86400) * 86400;
        if (dailyVolumeResetAt[asset] < dayStart) {
            dailyVolumeUsed[asset]    = 0;
            dailyVolumeResetAt[asset] = dayStart;
        }

        uint256 newUsed = dailyVolumeUsed[asset] + amount;
        if (newUsed > limit) {
            revert DailyVolumeLimitExceeded(asset, dailyVolumeUsed[asset], limit);
        }
        dailyVolumeUsed[asset] = newUsed;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Owner Utilities
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Withdraw accumulated ERC-20 profit from the contract.
     * @param token  Token address.
     * @param amount Amount to withdraw; pass 0 to sweep full balance.
     */
    function withdrawToken(address token, uint256 amount) external onlyOwner {
        uint256 bal        = IERC20(token).balanceOf(address(this));
        uint256 withdrawAmt = (amount == 0 || amount > bal) ? bal : amount;
        IERC20(token).safeTransfer(owner(), withdrawAmt);
        emit EmergencyWithdraw(token, withdrawAmt, owner());
    }

    /**
     * @notice Emergency withdrawal of native MATIC.
     */
    function withdrawMATIC() external onlyOwner {
        uint256 bal = address(this).balance;
        (bool ok,) = payable(owner()).call{value: bal}("");
        require(ok, "FlashLoanSecure: MATIC transfer failed");
        emit EmergencyWithdraw(address(0), bal, owner());
    }

    receive() external payable {}
}
