// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MockAavePool
 * @notice Minimal mock of the Aave v3 Pool contract for unit tests.
 *         Exposes flashLoanSimple and a helper to call executeOperation
 *         on a receiver with a controlled initiator.
 */
contract MockAavePool {
    /// @notice Simulates Aave calling executeOperation on the receiver.
    ///         Does NOT actually disburse tokens — tests seed the receiver directly.
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 /* referralCode */
    ) external {
        // Call back into the receiver (mimics Aave behaviour)
        (bool success, bytes memory reason) = receiverAddress.call(
            abi.encodeWithSignature(
                "executeOperation(address,uint256,uint256,address,bytes)",
                asset,
                amount,
                (amount * 5) / 10_000, // 0.05% Aave fee
                receiverAddress,        // initiator = receiver itself (correct)
                params
            )
        );
        if (!success) {
            // Bubble up revert reason
            if (reason.length > 0) {
                assembly { revert(add(32, reason), mload(reason)) }
            }
            revert("MockAavePool: executeOperation failed");
        }
    }

    /// @notice Helper for tests that want to call executeOperation with a
    ///         *different* initiator (to simulate the UnauthorisedInitiator path).
    function callExecuteOperation(
        address receiverAddress,
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external {
        (bool success, bytes memory reason) = receiverAddress.call(
            abi.encodeWithSignature(
                "executeOperation(address,uint256,uint256,address,bytes)",
                asset, amount, premium, initiator, params
            )
        );
        if (!success) {
            if (reason.length > 0) {
                assembly { revert(add(32, reason), mload(reason)) }
            }
            revert("MockAavePool: callExecuteOperation failed");
        }
    }
}
