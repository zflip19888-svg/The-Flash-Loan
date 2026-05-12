// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MockAddressesProvider
 * @notice Mock Aave v3 PoolAddressesProvider for unit tests.
 *         Returns a configurable pool address.
 */
contract MockAddressesProvider {
    address private _pool;

    constructor(address pool_) {
        _pool = pool_;
    }

    function getPool() external view returns (address) {
        return _pool;
    }

    function setPool(address pool_) external {
        _pool = pool_;
    }
}
