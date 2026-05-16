// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract SimpleStorage {
    uint256 private storedData;

    // Store a value
    function set(uint256 _value) public {
        storedData = _value;
    }

    // Retrieve the stored value
    function get() public view returns (uint256) {
        return storedData;
    }
}
