// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev String operation for address.
 */
library AddressUint {
    function toUint(address x) internal pure returns (uint256) {
    return uint256(uint160(x));
    }

}
library UintAddress {
    function toAddress(uint256 x) internal pure returns (address) {
    return address(uint160(x));
    }

}