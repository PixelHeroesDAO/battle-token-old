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
    // イベント
    event AddCollection(uint128 indexed collectionId, uint24 chainId, address addr);
    event SetStatus(uint128 indexed collectionId, uint128 indexed tokenId, uint256 packedStatus);

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
        uint24 chainId_, 
        address addr_, 
        bool isSerial_,
        uint24 startId_,
        uint24 maxSupply_
    ) public virtual onlyRole(DEFAULT_ADMIN_ROLE) returns(uint256){
        return _addCollection(
            chainId_, 
            addr_, 
            isSerial_, 
            startId_, 
            maxSupply_
        );
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
    ) public virtual onlyRole(DEFAULT_ADMIN_ROLE) returns(uint256){
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
    function totalCollection() public view returns (uint256){
        return uint256(_totalCollection);
    }

    /**
     * @dev Return total number of registered NFT collection.
     * The internal collection ID is valid in uint128.
     */
    function collection(uint128 cID) public view returns (
        uint256 chainId_, 
        address addr_, 
        bool isSerial_, 
        uint24 startId_, 
        uint24 maxSupply_
    ){
        _checkCollectionId(cID);
        uint256 packedUint = _packedCollection[cID];
        chainId_ = packedUint & BITMASK_COLLECTION_SLOT;
        addr_ = ((packedUint >> BITPOS_ADDRESS) & BITMASK_ADDRESS).toAddress();
        if((packedUint >> BITPOS_IS_SERIAL) & BITMASK_IS_SERIAL == 0){
            isSerial_ = false;
        } else {
            isSerial_ = true;
        }
        startId_ = uint24((packedUint >> BITPOS_START_ID) & BITMASK_COLLECTION_SLOT);
        maxSupply_ = uint24((packedUint >> BITPOS_MAX_SUPPLY) & BITMASK_COLLECTION_SLOT);
    }

    function changeCollectionSupply(
        uint128 cID, 
        bool isSerial_, 
        uint256 startId_, 
        uint256 maxSupply_)
    public virtual onlyRole(DEFAULT_ADMIN_ROLE) returns(bool) {
        _checkCollectionId(cID);
        return _changeCollectionSupply(cID, isSerial_, startId_, maxSupply_);
    }

    function _changeCollectionSupply(
        uint128 cID_, 
        bool isSerial_, 
        uint256 startId_, 
        uint256 maxSupply_)
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
     * @dev 指定のコレクションIDを無効にする
     *
     */
    function _setDisable(uint128 cID) internal virtual {
        uint128 id = _totalCollection;
        if (id > cID) id = cID;
        // コレクションIDは1スタートだが配列は0スタートなのでずらす
        id--;
        uint256 index = id / 256;
        uint256 op = ~ (1 << (id % 256));
        uint256 data = _collectionDisable[index];
        _collectionDisable[index] = ~ ((~ data) & op);
    }

    /**
     * @dev 指定のコレクションIDを有効にする
     *
     */
    function _setEnable(uint128 cID) internal virtual {
        uint128 id = _totalCollection;
        if (id > cID) id = cID;
        // コレクションIDは1スタートだが配列は0スタートなのでずらす
        id--;
        uint256 index = id / 256;
        uint256 op = ~ (1 << (id % 256));
        uint256 data = _collectionDisable[index];
        _collectionDisable[index] = data & op;
    }

    function setDisable(uint128 cID) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setDisable(cID);
    }

    function setEnable(uint128 cID) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setEnable(cID);
    }

    /**
     * @dev 指定のコレクションIDを有効にする
     *
     */
    function collectionDisable(uint128 cID) public view returns(bool) {
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
    }
    function status(uint128 cID, uint128 tID) public virtual view returns(
        uint64 exp,
        uint16 lv,
        uint16[] memory slot
    ){
        _checkCollectionId(cID);
        return _status(cID, tID);
    }

    function _status(uint128 cID, uint128 tID) internal view returns(
        uint64 exp,
        uint16 lv,
        uint16[] memory slot
    ){
        //戻り値に動的配列形式を使うため、配列サイズを予め定義する（memoryは可変できない）
        slot = new uint16[](LENGTH_STATUS_SLOT);
        uint256 packedData = _packedStatusVault[_makePackedId(cID, tID)];
        exp = uint64(packedData & BITMASK_EXPERIENCE);
        lv = uint16((packedData >> BITPOS_LEVEL) & BITMASK_LEVEL);
        for (uint i = 0 ; i < LENGTH_STATUS_SLOT ; i++){
            slot[i] =uint16( 
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
     * @param packedData    Packed status data
     *   if length is under 11, lack slot(s) is filled with 0.
     */
    function _setStatus(uint128 cID, uint128 tID, uint256 packedData)
        internal returns(bool)
    {
        _packedStatusVault[_makePackedId(cID, tID)] = packedData;
        emit SetStatus(cID, tID, packedData);
        return true;
    }

    function _makePackedStatus(uint64 exp, uint16 lv, uint16[] memory slot)
        internal view returns(uint256)
    {
        uint256 len = slot.length;
        if (len > 11) revert SetOutSizedStatus();
        uint256 packedData = 
            exp | 
            (uint256(lv) << BITPOS_LEVEL);
        for (uint256 i ; i < len ; i++){
            packedData = 
                packedData | 
                (uint256(slot[i]) << (BITPOS_STATUS_FIRST + BITLENGTH_STATUS_SLOT * i));
        }
        return packedData;
    }

    function _makePackedId(uint128 cID, uint128 tID) internal view returns(uint256){
        return cID | (uint256(tID) << BITPOS_TOKEN_ID);
    }

    /**
     * @dev Public setting status function with signature by signer role.
     * @param cID       Collection ID
     * @param tID       Token ID
     * @param exp       Experience to be set
     * @param lv        Level to be set
     * @param slot[]    Array of status. Max length is 11.
     * @param signature Signed message by signer role accouunt.
     */
    function setStatus(
        uint128 cID, 
        uint128 tID, 
        uint64 exp, 
        uint16 lv, 
        uint16[] memory slot,
        bytes memory signature
        ) external
    {
        _checkStatus(exp, lv, slot);
        _checkDisable(cID);
        _verifySigner(_makeMessage(msg.sender, cID, tID, exp, lv, slot), signature);
        _increaseNonce(msg.sender);
        _setStatus(cID, tID, _makePackedStatus(exp, lv, slot));
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
    function _checkStatus(uint64 exp, uint16 lv, uint16[] memory slot)
        internal virtual view returns(bool)
    {
        return true;
    }

    /**
     * @dev make message for sign to update status by user
     *   The message contains address of user, nonce of address, cID and tID
     *   with "|" separator. All parts are string.
     * @param addr      EOA of user
     * @param cID       Collection ID
     * @param tID       Token ID of collection
     * @param exp       Experience
     * @param lv        Level
     * @param slot      Array of status
     */
    function _makeMessage(
        address addr,
        uint256 cID,
        uint256 tID,
        uint64 exp, 
        uint16 lv, 
        uint16[] memory slot
    )internal view virtual returns (string memory){
        string memory ret = string(abi.encodePacked(
            "0x",
            addr.toAsciiString(), "|", 
            nonce[addr].toString(),  "|",
            cID.toString(), "|",
            tID.toString(), "|",
            uint256(exp).toString(), "|",
            uint256(lv).toString()
        ));
        uint256 len = slot.length;
        for (uint256 i = 0 ; i < LENGTH_STATUS_SLOT ; i++){
            if (i < len) {
                ret = string(abi.encodePacked(ret, "|", uint256(slot[i]).toString()));
            } else {
                ret = string(abi.encodePacked(ret, "|", "0"));
            }
        }
        return ret;
    }

    function TEST_makeMessage(
        address addr,
        uint256 cID,
        uint256 tID,
        uint64 exp, 
        uint16 lv, 
        uint16[] memory slot
    )public view returns (string memory){
        return _makeMessage(addr, cID, tID, exp, lv, slot);
    }
    /**
     * @dev verify signature function
     */
    function _verifySigner(string memory message, bytes memory signature )
        internal view returns(bool)
    {
        console.log(RecoverSigner.recoverSignerByMsg(message, signature));
        //署名検証
        if(!hasRole(SIGNER_ROLE, RecoverSigner.recoverSignerByMsg(message, signature))) 
            revert OperateWithInvalidSignature();
        return true;
    }

}

