pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";

import "hardhat/console.sol";

contract GameVault {

    //

    // バージョン情報
    string public version;
    // コレクション情報

    // mapping from collectionID(cID) to collection data
    //
    // Bits layout
    // - [0..23]    `chainId`
    // - [24..143]  `addr` of contract
    // - [144..151]      `isSerial
    // - [152..175] `startId'
    // - [176..199] `maxSupply'
    mapping(uint256 => uint256) private _packedCollection;


    constructor (string memory ver_) {
        version = ver_
    }


}

