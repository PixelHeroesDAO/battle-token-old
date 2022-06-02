pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";

import "hardhat/console.sol";

contract GameVault {

    // Mask of collection data slot (24bits)
    uint256 private constant BITMASK_COLLECTION_SLOT = (1 << 24) - 1;
    // Mask of address
    uint256 private constant BITMASK_ADDRESS = (! << 160) - 1;
    // Mask of 'isSerial' of collection data (8bits)
    uint256 private constant BITMASK_IS_SERIAL = (1 << 8) - 1;
    // The bit position of `addr` in packed collection data.
    uint256 private constant BITPOS_ADDRESS = 24;
    // The bit position of `isSerial` in packed collection data.
    uint256 private constant BITPOS_IS_SERIAL = 144;
    // The bit position of `startId` in packed collection data.
    uint256 private constant BITPOS_START_ID = 152;
    // The bit position of `maxSupply` in packed collection data.
    uint256 private constant BITPOS_MAX_SUPPLY = 176;

    // Mask of key value of packed key (128bits)
    uint256 private constant BITMASK_KEY_VALUE = (1 << 128) - 1;
    // The bit position of `tokenId` in packed key
    uint256 private constant BITPOS_TOKEN_ID = 128;

    // Mask of level vault data slot (16bits)
    uint256 private constant BITMASK_LEVEL = (1 << 16) - 1;
    // Mask of status vault data slot (16bits)
    uint256 private constant BITMASK_STATUS_SLOT = (1 << 16) - 1;
    // The bit position of `level` in packed status vault.
    uint256 private constant BITPOS_LEVEL = 64;

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

    // mapping from packed collectionID(cID) and tokenID(tID) to status vault
    //
    // Input bits layout
    // - [0..127]   `collectionId`
    // - [128..256] `tokenId`
    // Output bits layout
    // - [0..63]    `Experience`
    // - [64..79]   `Level`
    // - [80..95]   `Value[0]`
    // - [16bits]   Value[]
    mapping(uint256 => uint256) private _packedStatusVault;


    constructor (string memory ver_) {
        version = ver_
    }


}

