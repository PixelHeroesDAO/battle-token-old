// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
//import "./ERC20Immobile.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./lib/AddressStrings.sol";
import "./lib/AddressUint.sol";

import "hardhat/console.sol";

contract BattleToken is ERC20, Pausable, AccessControl {

    struct NFTContract{
        address addr;
        uint256 chainId;
    }

    using Address for address;
    using Strings for uint256;
    using AddressStrings for address;
    using AddressUint for address;
    using UintAddress for uint256;

    // NFTコントラクトアドレスIDリスト 0は登録なし、1以上で識別No.([addr][ChainId] => contractId)
    mapping(address => mapping(uint256 => uint256)) private _contractId;
    // 逆引きリスト-アドレス/ChainID情報([ContractId])
    mapping(uint256 => NFTContract) private _contractInfo;
    // 同一チェーンのContractIdリスト
    uint256[] _inChainsId;
    // 登録済みコントラクト数
    uint256 private _totalContracts;  //=0
    // トークン操作用のnonce(ウォレットごとに持たせる)
    mapping(address => uint256) private _nonce;
    // コントラクトのトークン更新有効性([ContractId])
    mapping(uint256 => bool) private _availablity;
    // トークン残高([ContractId][TokenId]) => [balance][nonce]
    mapping(uint256 => mapping(uint256 => uint256)) private _balances;
    // トークン移動許可([ContractId][TokenId][spender] => [allowance])
    // TokenIDから実行者への移転許可。
    mapping(uint256 => mapping(uint256 => mapping(address => uint256))) private _allowance;

    // このコントラクトのチェーンID
    uint256 public immutable chainid = block.chainid;
    // ERC20向け
    uint256 private _totalSupply;
    // 送金機能の有効性
    bool private _transferable;
    
    // AccessControl関係
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // 要署名関数用識別子
    string public constant SIG_MINT = "SIG_MINT";
    string public constant SIG_BURN = "SIG_BURN";
    string public constant SIG_TRANSFER = "SIG_TRANSFER";
    string public constant SIG_APPROVE = "SIG_APPROVE";

    event TransferById(
        uint256 indexed from, 
        uint256 indexed tokenFrom, 
        uint256 indexed to, 
        uint256 tokenTo,
        uint256 amount
    );

    event AddContract(uint256 indexed id, NFTContract nft);

    event ApproveById(uint256 indexed cid, uint256 indexed tid, address spender, uint256 amount);

    modifier whenTransferable() {
        require(_transferable, "token transfering is restricted");
        _;
    }
    constructor() ERC20("PixelHeroesBattleToken", "PHBT") public {
        // AccessControlのロール付与。Deployerに各権限を付与する。
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        // 送金可否の初期値設定
        _transferable = false;
    }

    function totalSupply() public view virtual override returns(uint256){
        return _totalSupply;
        console.log('totalSupply : ',_totalSupply);
    }

    //同一チェーンかつtokenOfOwnerByIndexのあるコントラクトについて、トークン数を収集する
    // ※現状supportsinterfaceでうまくtrueがとれていない→これではtrueが得られない？
    function balanceOf(address account) public view  virtual override returns (uint256) {
        address addr;
        uint256 amount = _balances[0][msg.sender.toUint()];
        uint256 tokenCount;
        require(account != address(0), "address zero is not a valid owner");
        for (uint i = 0; i < _inChainsId.length; i++){
            addr = _contractInfo[_inChainsId[i]].addr;
            tokenCount = IERC721(addr).balanceOf(account);
            for (uint j = 0; j < tokenCount ; j++){
                //tokenOfOwnerByIndexがある場合はトークン数を収集する
                try IERC721Enumerable(addr).tokenOfOwnerByIndex(account, j) 
                    returns (uint256 retToken)
                {
                    amount += _balances[ _inChainsId[i] ][retToken];

                }catch Error (string memory reason) {
                    console.log('error(ContractID, TokenID, msg):', _inChainsId[i], j, reason);
                }catch (bytes memory reason) {
                    console.log('error w/o reason(ContractID, TokenID, msg):', _inChainsId[i], j);
                }
            }   
        }
        return amount;
    }
    
    // コントラクトID登録
    function addContract(address addr_, uint256 chainId_) 
        public virtual onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused
        returns(uint256)
    {
        NFTContract memory newContract = NFTContract({
            addr: addr_,
            chainId : chainId_
        });
        // 同一チェーンの場合、コントラクトアドレスかチェックする
        if (chainId_ == chainid) {
            require(addr_.isContract(), 'cannot add contract : address is not contract.');
        }
        // コントラクトが未登録であることを確認する
        require(contractId(addr_, chainId_) == 0, 'cannot add contract : contract already exists');
        // 内部登録処理を起動
        uint256 ret = _addContract(newContract);
        return ret;
    }

    // コントラクトID登録(内部関数)
    function _addContract(NFTContract memory contract_) internal virtual returns(uint256) {
        uint256 newId = _totalContracts + 1;
        // コントラクトIDを登録する
        _contractId[contract_.addr][contract_.chainId]= newId;
        // コントラクトIDを有効にする
        _availablity[newId] = true;
        // 逆引きを登録する
        _contractInfo[newId] = contract_;
        // 同一チェーンの場合、同一チェーンIDリストにコントラクトIDを追加する
        if (contract_.chainId == chainid) {
            _inChainsId.push(newId);
        }
        //カウントアップ
        _totalContracts += 1;
        //イベント送信
        emit AddContract(newId, contract_);
        //戻り値を返す
        return newId;
    }

    function recoverSigner(bytes32 hash, bytes memory signature) public pure returns (address) {
        bytes32 messageDigest = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32", 
                hash
            )
        );
        return ECDSA.recover(messageDigest, signature);
    }

    /* 署名用メッセージ生成 ***デバッグ中はpublicだが、リリース時はinternalに変更する
　      * stringで構成する
        * 要素間は|で区切る
        * msg.sender|nonce|contractId|tokendId|sigFunc|amount
    */
    function _makeMessage(
        address account_,
        uint256 contractId_,
        uint256 tokenId_,
        string memory sigFunc_,
        uint256 amount_
    )public view virtual returns (string memory){
        return string(abi.encodePacked(
            "0x",
            account_.toAsciiString(), "|", 
            _nonce[account_].toString(),  "|",
            contractId_.toString(),  "|",
            tokenId_.toString(),  "|",
            sigFunc_, "|",
            amount_.toString()
        ));
    }

    function mint(
        uint256 contractId_, 
        uint256 tokenId_, 
        uint256 amount_, 
        bytes memory signature
    ) public virtual whenNotPaused {
        _mint(contractId_, tokenId_, amount_, signature);
    }

    function burn(
        uint256 contractId_, 
        uint256 tokenId_, 
        uint256 amount_, 
        bytes memory signature
    ) public virtual whenNotPaused {
        _burn(contractId_, tokenId_, amount_, signature);
    }

    /* ミント関数
        * チェーンまたぎを想定しているため、フロント側でTx発行の妥当性が検証されている前提。
        * 検証の証拠としてMINTER_ROLEアドレスの署名を確認する。
        * TransferByIdイベントは無効なContractID:0=>TokenID:0を0x0相当として扱う
    */
    function _mint(
        uint256 contractId_, 
        uint256 tokenId_, 
        uint256 amount_, 
        bytes memory signature
    ) internal virtual {
        // contractId検証
        _verifyContractId(contractId_);

        _beforeTokenTransfer(0,0, contractId_, tokenId_, amount_);

        //署名検証
        string memory message =_makeMessage(
            msg.sender,
            contractId_,
            tokenId_,
            SIG_MINT,
            amount_
        );
        _verifyMinter(message, signature);

        _increaseNonce();

        _totalSupply += amount_;
        _balances[contractId_][tokenId_] += amount_;

        emit TransferById(0,0, contractId_, tokenId_, amount_);

        _afterTokenTransfer(0,0, contractId_, tokenId_, amount_);

    }

    /* バーン関数
        * チェーンまたぎを想定しているため、フロント側でTx発行の妥当性が検証されている前提。
        * 検証の証拠としてMINTER_ROLEアドレスの署名を確認する。
        * TransferByIdイベントは無効なContractID:0=>TokenID:0を0x0相当として扱う
    */
    function _burn(
        uint256 contractId_, 
        uint256 tokenId_, 
        uint256 amount_, 
        bytes memory signature
    ) internal virtual {
        // contractId検証
        _verifyContractId(contractId_);

        _beforeTokenTransfer(contractId_, tokenId_, 0, 0, amount_);

        // 残高検証
        uint256 bal = balanceById(contractId_, tokenId_);
        require(amount_ <= bal, "cannot burn : amount is greater than balance");
        //署名検証
        string memory message =_makeMessage(
            msg.sender,
            contractId_,
            tokenId_,
            SIG_BURN,
            amount_
        );
        _verifyMinter(message, signature);

        _increaseNonce();

        _totalSupply -= amount_;
        _balances[contractId_][tokenId_] -= amount_;

        emit TransferById(contractId_, tokenId_, 0, 0, amount_);

        _afterTokenTransfer(contractId_, tokenId_, 0, 0, amount_);

    }

    function approveById(uint256 contractId_, uint256 tokenId_, address spender_, uint256 amount_, bytes memory signature)
        public virtual whenNotPaused
    {
        // contractId検証
        _verifyContractId(contractId_);
        //署名検証
        string memory message =_makeMessage(
            msg.sender,
            contractId_,
            tokenId_,
            SIG_APPROVE,
            amount_
        );
        _verifyMinter(message, signature);

        _increaseNonce();

        _approveById(contractId_, tokenId_, spender_, amount_);
    }

    function _approveById(uint256 contractId_, uint256 tokenId_, address spender_, uint256 amount_)
        internal virtual
    {

        _allowance[contractId_][tokenId_][spender_] = amount_;

        emit ApproveById(contractId_, tokenId_, spender_, amount_);

    }

    function _verifyContractId(uint256 contractId_) internal view virtual returns(bool){
        // contractId検証
        require(contractId_ > 0, "burn from the zero contractId");
        require(contractId_ < _totalContracts + 1, "bunr from the non-registered contractId");
        // contractId有効性検証
        require(_availablity[contractId_], "burn from the non available contract");
        return true;
    }
    function _verifyMinter(string memory message, bytes memory signature )
        internal view returns(bool)
    {
        //署名検証
        bytes32 hash = keccak256(abi.encodePacked(message));
        require(hasRole(MINTER_ROLE, recoverSigner(hash, signature)), "invalid signature to operate token");
        return true;
    }

    function _increaseNonce() internal returns(uint256){
        uint256 nonce = _nonce[msg.sender] + 1;
        _nonce[msg.sender] = nonce;
        return nonce;
    }
    function _beforeTokenTransfer(
        uint256 from, 
        uint256 tokenFrom,
        uint256 to, 
        uint256 tokenTo,
        uint256 amount
    ) internal virtual{}

    function _afterTokenTransfer(
        uint256 from, 
        uint256 tokenFrom,
        uint256 to, 
        uint256 tokenTo,
        uint256 amount
    ) internal virtual{}


    // 登録コントラクトの有効/無効設定
    function setAvailablity(uint256 contractId_, bool val_) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _availablity[contractId_] = val_;
    }

    // 送金可否設定
    function setTransferable(bool state) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _transferable = state;
    }
    // ゲッター関数
    function contractId(address contract_, uint256 chainId_) public view virtual returns(uint256){
        return _contractId[contract_][chainId_];
    }
    function contractId(NFTContract memory contract_) public view virtual returns(uint256){
        return contractId(contract_.addr, contract_.chainId);
    }
    function contractInfo(uint256 contractId_) public view virtual returns(NFTContract memory){
        return _contractInfo[contractId_];
    }
    function totalContracts() public view virtual returns(uint256){
        return _totalContracts;
    }
    function balanceById(uint256 contractId_, uint256 tokenId_) public view virtual returns(uint256){
        return _balances[contractId_][tokenId_];
    }
    function totalInChains() public view virtual returns(uint256){
        return _inChainsId.length;
    }
    function nonce(address addr) public view virtual returns(uint256){
        return _nonce[addr];
    }
    function availablity(uint256 contractId_) public view virtual returns(bool){
        return _availablity[contractId_];
    }
    function allowance(uint256 ownerCont, uint256 ownerTokenId, address spender) public view virtual returns(uint256){
        return _allowance[ownerCont][ownerTokenId][spender];
    }
    // Pause関連
    function pause() public virtual whenNotPaused onlyRole(PAUSER_ROLE){
        _pause();
    }
    function unpause() public virtual whenPaused onlyRole(PAUSER_ROLE){
        _unpause();
    }

    function transferById(
        uint256 fromCont, 
        uint256 fromTokenId, 
        uint256 toCont, 
        uint256 toTokenId, 
        uint256 amount, 
        bytes memory signature
    ) public virtual whenNotPaused whenTransferable returns(bool){
        address spender = msg.sender;
        _spendAllowance(fromCont, fromTokenId, spender, amount);
        _transfer(fromCont, fromTokenId, toCont, toTokenId, amount, signature);
        return true;
    }

    /* Transfer関数
        * チェーンまたぎを想定しているため、フロント側でTx発行の妥当性が検証されている前提。
        * 検証の証拠としてMINTER_ROLEアドレスの署名を確認する。
        * TransferByIdイベントは無効なContractID:0=>TokenID:0を0x0相当として扱う
    */
    function _transfer(
        uint256 fromCont, 
        uint256 fromTokenId, 
        uint256 toCont, 
        uint256 toTokenId, 
        uint256 amount, 
        bytes memory signature
    ) internal virtual {
        // contractId検証
        _verifyContractId(fromCont);
        _verifyContractId(toCont);

        // 送金許可量検証
        require(amount <= _allowance[fromCont][fromTokenId][msg.sender] , "allowance is not enough");

        _beforeTokenTransfer(fromCont, fromTokenId, toCont, toTokenId, amount);

        // 残高検証
        uint256 fromBal = balanceById(fromCont, fromTokenId);
        require(amount <= fromBal, "cannot transfer : transfer amount exceeds balance");

        //署名検証
        string memory message =_makeMessage(
            msg.sender,
            fromCont,
            fromTokenId,
            SIG_TRANSFER,
            amount
        );
        _verifyMinter(message, signature);

        _increaseNonce();
        unchecked{
            _balances[fromCont][fromTokenId] = fromBal - amount;
        }
        _balances[toCont][toTokenId] += amount;

        emit TransferById(fromCont, fromTokenId, toCont, toTokenId, amount);

        _afterTokenTransfer(fromCont, fromTokenId, toCont, toTokenId, amount);

    }

    function _spendAllowance(
        uint256 ownerCont,
        uint256 ownerTokenId,
        address spender,
        uint256 amount
    ) internal virtual{
        uint256 currentAllowance = allowance(ownerCont,ownerTokenId, spender);
        if (currentAllowance != type(uint256).max){
            require(currentAllowance >= amount, "insufficient allowance");
            unchecked{
                _approve(ownerCont, ownerTokenId, spender, currentAllowance - amount);
            }
        }
    }

    // ERC20のうち、使用不可の関数をrevertする
    function transfer(address to, uint256 amount) public override returns (bool){
        revert('This token cannot be tranfered between addresses.');
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        revert('This token cannot be used for approval from an address.');
    }
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        revert('This token cannot be tranfered between addresses.');
    }
    function increaseAllowance(address spender, uint256 addedValue) public override returns (bool) {
        revert('This token cannot be used for approval from an address.');
    }
    function decreaseAllowance(address spender, uint256 subtractedValue) public override returns (bool) {
        revert('This token cannot be used for approval from an address.');
    }

}
