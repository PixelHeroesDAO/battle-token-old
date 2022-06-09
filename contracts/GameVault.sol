pragma solidity ^0.8.4;

//import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./lib/RecoverSigner.sol";
import "./lib/AddressStrings.sol";
import "./lib/AddressUint.sol";

import "hardhat/console.sol";


contract GameVault is AccessControl{

    using Strings for uint256;
    using AddressStrings for address;
    using AddressUint for address;
    using UintAddress for uint256;

    // Mask of collection data slot (24bits)
    uint256 private constant BITMASK_COLLECTION_SLOT = (1 << 24) - 1;
    // Mask of address
    uint256 private constant BITMASK_ADDRESS = (1 << 160) - 1;
    // Mask of 'isSerial' of collection data (8bits)
    uint256 private constant BITMASK_IS_SERIAL = (1 << 8) - 1;
    // The bit position of `addr` in packed collection data.
    uint256 private constant BITPOS_ADDRESS = 24;
    // The bit position of `isSerial` in packed collection data.
    uint256 private constant BITPOS_IS_SERIAL = 184;
    // The bit position of `startId` in packed collection data.
    uint256 private constant BITPOS_START_ID = 208;
    // The bit position of `maxSupply` in packed collection data.
    uint256 private constant BITPOS_MAX_SUPPLY = 233;

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
    // The bit position of `status[0]` in packed status vault.
    uint256 private constant BITPOS_STATUS_FIRST = 80;
    // The bit length of `status[]` in packed status vault.
    uint256 private constant BITLENGTH_STATUS_SLOT = 16;

    // uint bool
    uint256 private constant UINT_TRUE = 1;
    uint256 private constant UINT_FALSE = 0;

    // AccessControl関係
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    // バージョン情報
    string public version;
    // コレクション情報

    // mapping from collectionID(cID) to collection data
    //
    // Bits layout
    // - [0..23]    `chainId`
    // - [24..183]  `addr` of contract
    // - [184..207] `isSerial
    // - [208..231] `startId'
    // - [232..255] `maxSupply'
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

    // wallet nonce for status updating transaction
    mapping(address => uint256) public nonce;

    // 登録済みコレクション数
    uint128 private _totalCollection;
    // イベント
    event AddCollection(uint256 indexed collectionId, uint24 chainId, address addr);

    //エラー関数
    // 存在しないコレクションへの参照
    error ReferNonexistentCollection();
    // ID0コレクションへの参照
    error ReferZeroCollection();
    // statusのスロットサイズエラー
    error SetOutSizedStatus();
    // 不正な署名による操作
    error OperateWithInvalidSignature();

    constructor (string memory ver_) {
        version = ver_;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(SIGNER_ROLE, msg.sender);
    }

    /**
     * @dev NFT collectionを登録する。
     * The internal collection ID is valid in uint128.
     * @param chainId_  NFTコントラクトのチェーンID(内部uint24)
     * @param addr_     NFTコントラクトアドレス
     * @param isSerial_ needs true if the collection is issued serialy. uint8 internally.
     * @param startId_ is only used when isSerial is true. Otherwise assign 0. uint24 internally.
     * @param maxSupply_ is only used when isSerial is true. Otherwise assign 0. uint24 internally.
     */
    function addCollection(
        uint256 chainId_, 
        address addr_, 
        bool isSerial_,
        uint256 startId_,
        uint256 maxSupply_
    ) public virtual onlyRole(DEFAULT_ADMIN_ROLE) returns(uint256){
        return _addCollection(
            uint24(chainId_), 
            addr_, 
            isSerial_, 
            uint24(startId_), 
            uint24(maxSupply_)
        );
    }

    /**
     * @dev NFT collectionを登録する。開始・発行数を登録しない場合用。
     * The internal collection ID is valid in uint128.
     * @param chainId_  NFTコントラクトのチェーンID(内部uint24)
     * @param addr_     NFTコントラクトアドレス
     */
    function addCollection(
        uint256 chainId_, 
        address addr_
    ) public virtual onlyRole(DEFAULT_ADMIN_ROLE) returns(uint256){
        return _addCollection(uint24(chainId_), addr_, false, uint24(0), uint24(0));
    }

    /**
     * @dev Add NFT collection on vault. Return collection ID. Internal function.
     * The internal collection ID is valid in uint128.
     * @param isSerial_ needs true if the collection is issued serialy.
     * @param startId_ is only used when isSerial is true. Otherwise assign 0. uint48 internally.
     * @param maxSupply_ is only used when isSerial is true. Otherwise assign 0. uint48 internally.
     */
    function _addCollection(
        uint24 chainId_, 
        address addr_, 
        bool isSerial_,
        uint24 startId_,
        uint24 maxSupply_
    ) internal returns(uint256){
        uint256 newId = uint256(_totalCollection + 1);
        uint256 packedData = uint256(chainId_) | (addr_.toUint() << BITPOS_ADDRESS);
        if (isSerial_){
            packedData = packedData |
                (uint256(maxSupply_) << BITPOS_MAX_SUPPLY) |
                (uint256(startId_) << BITPOS_START_ID) |
                (UINT_TRUE << BITPOS_IS_SERIAL);
        }
        _totalCollection += 1;
        _packedCollection[newId] = packedData;
        emit AddCollection(newId, chainId_, addr_);
        return newId;
    }

    /**
     * @dev Return total number of registered NFT collection.
     * The internal collection ID is valid in uint128.
     */
    function totalCollection() public view returns (uint256){
        return uint256(_totalCollection);
    }

    /**
     * @dev Return total number of registered NFT collection.
     * The internal collection ID is valid in uint128.
     */
    function collection(uint256 cID) public view returns (
        uint256 chainId_, 
        address addr_, 
        bool isSerial_, 
        uint256 startId_, 
        uint256 maxSupply_
    ){
        if (cID > uint256(_totalCollection)) revert ReferNonexistentCollection();
        if (cID == 0) revert ReferZeroCollection();
        uint256 packedUint = _packedCollection[cID];
        chainId_ = packedUint & BITMASK_COLLECTION_SLOT;
        addr_ = ((packedUint >> BITPOS_ADDRESS) & BITMASK_ADDRESS).toAddress();
        if((packedUint >> BITPOS_IS_SERIAL) & BITMASK_IS_SERIAL == 0){
            isSerial_ = false;
        } else {
            isSerial_ = true;
        }
        startId_ = (packedUint >> BITPOS_START_ID) & BITMASK_COLLECTION_SLOT;
        maxSupply_ = (packedUint >> BITPOS_MAX_SUPPLY) & BITMASK_COLLECTION_SLOT;
    }

    /**
     * @dev Set all status data internally.
     * Public interfce function must be allowed with sign by signer role account
     * if user should pay gas fee.
     * @param cID       collection ID
     * @param tID       token ID of collection
     * @param exp       experience of token
     * @param lv        level of token
     * @param status    array of status. max length is 11.
     *   if length is under 11, lack slot(s) is filled with 0.
     */
    function _setStatus(uint128 cID, uint128 tID, uint64 exp, uint16 lv, uint16[] memory status)
        internal returns(bool)
    {
        if (cID > uint256(_totalCollection)) revert ReferNonexistentCollection();
        if (cID == 0) revert ReferZeroCollection();
        uint256 len = status.length;
        if (len > 11) revert SetOutSizedStatus();
        uint256 packedData = 
            exp | 
            (uint256(lv) << BITPOS_LEVEL);
        for (uint256 i ; i < len ; i++){
            packedData = 
                packedData | 
                (uint256(status[i]) << (BITPOS_STATUS_FIRST + BITMASK_STATUS_SLOT * i));
        }
        _packedStatusVault[cID | (uint256(tID) << BITPOS_TOKEN_ID)] = packedData;
        return true;
    }

    /**
     * Test function for setStatus
     */
    function _setStatusTEST(uint128 cID, uint128 tID, uint64 exp, uint16 lv, uint16[] memory status)
        public returns(bool)
    {
        return _setStatus(cID, tID, exp, lv, status);
    }


    /**
     * @dev make message for sign to update status by user
     *   The message contains address of user, nonce of address, cID and tID
     *   with "|" separator. All parts are string.
     * @param addr  EOA of user
     * @param cID   Collection ID
     * @param tID   Token ID of collection
     */
    function _makeMessage(
        address addr,
        uint256 cID,
        uint256 tID
    )internal view virtual returns (string memory){
        return string(abi.encodePacked(
            "0x",
            addr.toAsciiString(), "|", 
            nonce[addr].toString(),  "|",
            cID.toString(),  "|",
            tID.toString()
        ));
    }

    /**
     * @dev verify signature function
     */
    function _verifySigner(string memory message, bytes memory signature )
        internal view returns(bool)
    {
        //署名検証
        if(hasRole(SIGNER_ROLE, RecoverSigner.recoverSignerByMsg(message, signature))) 
            revert OperateWithInvalidSignature();
        return true;
    }

}

