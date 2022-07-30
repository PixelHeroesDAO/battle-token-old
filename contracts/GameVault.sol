pragma solidity ^0.8.4;

//import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./interfaces/IGameVault.sol";

import "./lib/RecoverSigner.sol";
import "./lib/AddressStrings.sol";
import "./lib/AddressUint.sol";

import "hardhat/console.sol";


contract GameVault is IGameVault, AccessControl{

    using Strings for uint256;
    using Strings for uint128;
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

    // Mask of experience vault data slot (16bits)
    uint256 private constant BITMASK_EXPERIENCE = (1 << 64) - 1;
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
    // Length of status slot
    uint256 private constant LENGTH_STATUS_SLOT = 11;

    // uint bool
    uint256 private constant UINT_TRUE = 1;
    uint256 private constant UINT_FALSE = 0;

    // uint bool
    uint256 private constant UINT_DISABLE = 1;
    uint256 private constant UINT_ENABLE = 0;

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

    // コレクションの無効性
    // uint256の動的配列として1コレクション1bitを使う。また登録時有効をデフォルト値とするため
    // 0:有効　1:無効　とする(Disableがfalse or true)
    uint256[] private _collectionDisable;
    
    // 登録済みコレクション数
    uint128 private _totalCollection;

    // 署名の有効期限
    uint256 private _expireDuration;

    //エラー関数
    // 存在しないコレクションへの参照
    error ReferNonexistentCollection();
    // ID0コレクションへの参照
    error ReferZeroCollection();
    // statusのスロットサイズエラー
    error SetOutSizedStatus();
    // 不正な署名による操作
    error OperateWithInvalidSignature();
    // コレクション無効性の初期化失敗
    error FailInitializingCollectionDisable();
    // コレクションが無効化されている
    error CollectionIsDisable();
    // 署名が失効した
    error SignatureExpired();


    constructor (string memory ver_) {
        version = ver_;
        _expireDuration = 5 minutes;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(SIGNER_ROLE, msg.sender);
    }

    /**
     * @dev NFT collectionを登録する。
     * The internal collection ID is valid in uint128.
     * @param data      Collection構造体データ
     */
    function addCollection(Collection memory data) public override onlyRole(DEFAULT_ADMIN_ROLE) returns(uint256){
        return _addCollection(data.chainId, data.addr, data.isSerial, data.startId, data.maxSupply);
    }

    /**
     * @dev NFT collectionを登録する。開始・発行数を登録しない場合用。
     * The internal collection ID is valid in uint128.
     * @param chainId_  NFTコントラクトのチェーンID(内部uint24)
     * @param addr_     NFTコントラクトアドレス
     */
    function addCollection(
        uint24 chainId_, 
        address addr_
    ) public override onlyRole(DEFAULT_ADMIN_ROLE) returns(uint256){
        return _addCollection(chainId_, addr_, false, uint24(0), uint24(0));
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
        _initDisable(uint128(newId));
        emit AddCollection(uint128(newId), chainId_, addr_);
        return newId;
    }


    /**
     * @dev Return total number of registered NFT collection.
     * The internal collection ID is valid in uint128.
     */
    function totalCollection() public view override returns (uint256){
        return uint256(_totalCollection);
    }

    /**
     * @dev Return total number of registered NFT collection.
     * The internal collection ID is valid in uint128.
     */
    function collection(uint128 cID) public view override returns (Collection memory ret){
        _checkCollectionId(cID);
        uint256 packedUint = _packedCollection[cID];
        ret.chainId = uint24(packedUint & BITMASK_COLLECTION_SLOT);
        ret.addr = ((packedUint >> BITPOS_ADDRESS) & BITMASK_ADDRESS).toAddress();
        if((packedUint >> BITPOS_IS_SERIAL) & BITMASK_IS_SERIAL == 0){
            ret.isSerial = false;
        } else {
            ret.isSerial = true;
        }
        ret.startId = uint24((packedUint >> BITPOS_START_ID) & BITMASK_COLLECTION_SLOT);
        ret.maxSupply = uint24((packedUint >> BITPOS_MAX_SUPPLY) & BITMASK_COLLECTION_SLOT);
    }

    function changeCollectionSupply(
        uint128 cID, 
        bool isSerial_, 
        uint24 startId_, 
        uint24 maxSupply_)
    public override onlyRole(DEFAULT_ADMIN_ROLE) returns(bool) {
        _checkCollectionId(cID);
        return _changeCollectionSupply(cID, isSerial_, startId_, maxSupply_);
    }

    function _changeCollectionSupply(
        uint128 cID_, 
        bool isSerial_, 
        uint24 startId_, 
        uint24 maxSupply_)
    internal virtual returns(bool) {
        //isSerialの前のパックデータを抽出する
        uint256 packedData = _packedCollection[cID_] & ((1 << BITPOS_IS_SERIAL)-1);
        //iSSerialがtrueの場合、パックデータに追記する
        if (isSerial_){
            packedData = packedData |
                (uint256(maxSupply_) << BITPOS_MAX_SUPPLY) |
                (uint256(startId_) << BITPOS_START_ID) |
                (UINT_TRUE << BITPOS_IS_SERIAL);
        }
        _packedCollection[cID_] = packedData;
        return true;
    }
    /**
     * @dev コレクションの無効性を初期化。
     *      256区切りを超えるIDが指定された場合に配列を拡張する。
     *      0など_totalCollection以下の値を指定すると、_totalCollectionで初期化を試す。
     *      1を超える配列拡張になる場合エラーを返す。
     */
    function _initDisable(uint128 cID) internal virtual {
        uint128 id = _totalCollection;
        uint128 len = uint128(_collectionDisable.length);
        if (cID > id) id = cID;
        if(id > 256 * len){
            if(id <= 256 * (len + 1)) {
                _collectionDisable.push(0);
            } else {
                revert FailInitializingCollectionDisable();
            }
        }
    }

    /**
     * dev 指定のコレクションIDを無効にする
     *
     */
/*    function _setDisable(uint128 cID) internal virtual {
        uint128 id = _totalCollection;
        if (id > cID) id = cID;
        // コレクションIDは1スタートだが配列は0スタートなのでずらす
        id--;
        uint256 index = id / 256;
        uint256 op = ~ (1 << (id % 256));
        uint256 data = _collectionDisable[index];
        _collectionDisable[index] = ~ ((~ data) & op);
    }*/

    /**
     * @dev 指定のコレクションIDを有効または無効にする
     *
     */
    function _setDisable(uint128 cID, bool disable) internal virtual {
        uint128 id = _totalCollection;
        if (id > cID) id = cID;
        // コレクションIDは1スタートだが配列は0スタートなのでずらす
        id--;
        uint256 index = id / 256;
        uint256 op = ~ (1 << (id % 256));
        uint256 data = _collectionDisable[index];
        if (disable){
             _collectionDisable[index] = ~ ((~ data) & op);
       }else{
            _collectionDisable[index] = data & op;
        }
    }

    function setCollectionDisable(uint128 cID) public override onlyRole(DEFAULT_ADMIN_ROLE) {
        _checkCollectionId(cID);
        _setDisable(cID, true);
    }

    function setCollectionEnable(uint128 cID) public override onlyRole(DEFAULT_ADMIN_ROLE) {
        _checkCollectionId(cID);
        _setDisable(cID, false);
    }

    /**
     * @dev 指定のコレクションIDが無効かを取得する
     *
     */
    function collectionDisable(uint128 cID) public override view returns(bool) {
        _checkCollectionId(cID);
        // コレクションIDは1スタートだが配列は0スタートなのでずらす
        uint128 id = cID - 1;
        uint256 index = id / 256;
        uint256 data = _collectionDisable[index];
        if ((data >> (id % 256)) & 1 == UINT_ENABLE){
            return false;
        }else{
            return true;
        }
    }

    /**
     * @dev 指定のコレクションIDの有効無効を確認、無効ならrevertする。
     */
    function _checkDisable(uint128 cID) internal view returns(bool){
        if (collectionDisable(cID)) revert CollectionIsDisable();
        return true;
    }
    function status(uint128 cID, uint128 tID) public override view returns(Status memory){
        _checkCollectionId(cID);
        return _status(cID, tID);
    }

    function _status(uint128 cID, uint128 tID) internal view returns(Status memory ret){
        uint256 packedData = _packedStatusVault[_makePackedId(cID, tID)];
        ret.exp = uint64(packedData & BITMASK_EXPERIENCE);
        ret.lv = uint16((packedData >> BITPOS_LEVEL) & BITMASK_LEVEL);
        ret.slot = new uint16[](11);
        for (uint i = 0 ; i < LENGTH_STATUS_SLOT ; i++){
            ret.slot[i] =uint16( 
                (packedData >> (BITPOS_STATUS_FIRST + i * BITLENGTH_STATUS_SLOT))
                & BITMASK_STATUS_SLOT
            );
        }
    }

    /**
     * @dev Set all status data internally.
     * Public interfce function must be allowed with sign by signer role account
     * if user should pay gas fee.
     * @param cID           collection ID
     * @param tID           token ID of collection
     *   if length is under 11, lack slot(s) is filled with 0.
     */
    function _setStatus(
        uint128 cID,
        uint128 tID,
        Status memory data,
        bool emitEvent
)
        internal returns(bool)
    {
        uint256 packedData = _makePackedStatus(data);
        _packedStatusVault[_makePackedId(cID, tID)] = packedData;
        if (emitEvent) emit SetStatus(cID, tID, data.exp, data.lv, data.slot);
        return true;
    }

    function _makePackedStatus(Status memory data)
        internal pure returns(uint256)
    {
        uint256 len = data.slot.length;
        if (len > LENGTH_STATUS_SLOT) revert SetOutSizedStatus();
        uint256 packedData = 
            data.exp | 
            (uint256(data.lv) << BITPOS_LEVEL);
        for (uint256 i ; i < len ; i++){
            packedData = 
                packedData | 
                (uint256(data.slot[i]) << (BITPOS_STATUS_FIRST + BITLENGTH_STATUS_SLOT * i));
        }
        return packedData;
    }

    function _makePackedId(uint128 cID, uint128 tID) internal pure returns(uint256){
        return cID | (uint256(tID) << BITPOS_TOKEN_ID);
    }

    /**
     * @dev Public setting status function with signature by signer role.
     * @param cID       Collection ID
     * @param tID       Token ID
     * @param data      Struct of status.
     * @param signature Signed message by signer role accouunt.
     */ 
    function setStatus(
        uint256 uts,
        uint128 cID, 
        uint128 tID, 
        Status memory data,
        bytes memory signature
        ) public override
    {
        _checkStatus(data);
        _checkDisable(cID);
        _verifySigner(_makeMessage(msg.sender, uts, cID, tID, data), signature);
        _verifyTimestamp(uts);
        _increaseNonce(msg.sender);
        _setStatus(cID, tID, data, true);
    }

    function expireDuration() public override view returns(uint256){
        return _expireDuration;
    }
    function setExpireDuration(uint256 newDuration) public override onlyRole(DEFAULT_ADMIN_ROLE) {
        _expireDuration = newDuration;
    }
    function _increaseNonce(address addr) internal {
        nonce[addr]++;
    }

    function _checkCollectionId(uint128 cID) internal virtual view returns(bool){
        if (cID > uint256(_totalCollection)) revert ReferNonexistentCollection();
        if (cID == 0) revert ReferZeroCollection();
        return true;
    }

    /**
     * @dev Check status data. This function is called before storing data.
     *      Default implementation is nothing.
     *      Overriding depends on each vault specifiation.
     */
    function _checkStatus(Status memory data)
        internal virtual view returns(bool)
    {
        return true;
    }

    /**
     * @dev make message for sign to update status by user
     *   The message contains address of user, nonce of address, cID and tID
     *   with "|" separator. All parts are string.
     * @param addr      EOA of user
     * @param uts       Unix Timestamp
     * @param cID       Collection ID
     * @param tID       Token ID of collection
     * @param data      Struct of status
     */
    function _makeMessage(
        address addr,
        uint256 uts,
        uint128 cID,
        uint128 tID,
        Status memory data
    )internal view virtual returns (string memory){
        string memory ret = string(abi.encodePacked(
            "0x",
            addr.toAsciiString(), "|", 
            nonce[addr].toString(),  "|",
            uts.toString(), "|",
            cID.toString(), "|",
            tID.toString(), "|",
            uint256(data.exp).toString(), "|",
            uint256(data.lv).toString()
        ));
        uint256 len = data.slot.length;
        for (uint256 i = 0 ; i < LENGTH_STATUS_SLOT ; i++){
            if (i < len) {
                ret = string(abi.encodePacked(ret, "|", uint256(data.slot[i]).toString()));
            } else {
                ret = string(abi.encodePacked(ret, "|", "0"));
            }
        }
        return ret;
    }

    function TEST_makeMessage(
        address addr,
        uint256 uts,
        uint128 cID,
        uint128 tID,
        Status memory data
    )public view returns (string memory){
        return _makeMessage(addr, uts, cID, tID, data);
    }
    /**
     * @dev verify signature function
     */
    function _verifySigner(string memory message, bytes memory signature )
        internal view returns(bool)
    {
        //署名検証
        if(!hasRole(SIGNER_ROLE, RecoverSigner.recoverSignerByMsg(message, signature))) 
            revert OperateWithInvalidSignature();
        return true;
    }

    function _verifyTimestamp(uint256 uts) internal view returns(bool){
        if (uts + _expireDuration < block.timestamp) revert SignatureExpired();
        console.log("chain stamp", block.timestamp, "test stamp", uts );
        return true;
    }

}

