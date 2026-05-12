// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title MockRouter
 * @notice Mock UniswapV2-style router for unit tests.
 *         Returns a fixed output amount regardless of input.
 *         Caller must have approved this contract to pull tokenIn.
 */
contract MockRouter {
    using SafeERC20 for IERC20;

    /// @notice Fixed output amount returned for every swap.
    uint256 public immutable FIXED_OUTPUT;

    constructor(uint256 fixedOutput_) {
        FIXED_OUTPUT = fixedOutput_;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 /* deadline */
    ) external returns (uint256[] memory amounts) {
        require(path.length >= 2, "MockRouter: path too short");
        require(FIXED_OUTPUT >= amountOutMin, "MockRouter: insufficient output");

        // Pull tokenIn
        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountIn);

        // Push tokenOut (mint if needed — tests pre-fund the router)
        // In tests, the router is pre-seeded with tokenOut via MockERC20.mint
        IERC20(path[path.length - 1]).safeTransfer(to, FIXED_OUTPUT);

        amounts = new uint256[](path.length);
        amounts[0]              = amountIn;
        amounts[path.length - 1] = FIXED_OUTPUT;
    }

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts)
    {
        require(path.length >= 2, "MockRouter: path too short");
        amounts = new uint256[](path.length);
        amounts[0]              = amountIn;
        amounts[path.length - 1] = FIXED_OUTPUT;
    }
}
