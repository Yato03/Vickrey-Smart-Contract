// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract HashHelper {
    function getHashedBid(uint value, string memory salt) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(value, "|", salt));
    }
}
