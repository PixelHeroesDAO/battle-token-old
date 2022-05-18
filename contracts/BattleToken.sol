// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./ERC20Immobile.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "hardhat/console.sol";

contract BattelToken is ERC20Immobile, Pausable, AccessControl {

    struct NFTContract{
        address addr;
        uint256 chainId;
    }

    using Address for address;

    // NFTコントラクトアドレスIDリスト 0は登録なし、1以上で識別No.([addr][ChainId] => contractId)
    mapping(address => mapping(uint256 => uint256)) private _contractId;
    // 逆引きリスト-アドレス/ChainID情報([ContractId])
    mapping(uint256 => NFTContract) private _contractInfo;
    // 同一チェーンのContractIdリスト
    uint256[] _inChainsId;
    // 登録済みコントラクト数
    uint256 private _totalContracts;  //=0
    // コントラクトのトークン更新有効性([ContractId])
    mapping(uint256 => bool) private _availablity;
    // トークン残高([ContractId][TokenId])
    mapping(uint256 => mapping(uint256 => uint256)) private _balances;
    // トークン移動許可
    mapping(uint256 => mapping(address => uint256)) private _allowance;

    // このコントラクトのチェーンID
    uint256 public immutable chainid = block.chainid;
    //ERC20向け
    uint256 private _totalSupply;
    
    // AccessControl関係
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    event Transfer(uint256 indexed from, uint256 indexed to, uint256 value);

    event Approval(uint256 indexed owner, address indexed spender, uint256 value);

    event AddContract(uint256 indexed id, NFTContract nft);

    constructor() ERC20Immobile("PixelHeroesBattleToken", "PHBT") public {
        // AccessControlのロール付与。Deployerに各権限を付与する。
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    function totalSupply() public view virtual override returns(uint256){
        return _totalSupply;
        console.log('totalSupply : ',_totalSupply);
    }

    //同一チェーンかつtokenOfOwnerByIndexのあるコントラクトについて、トークン数を収集する
    function balanceOf(address account) public view  virtual override returns (uint256) {
        address addr;
        uint256 amount = 0;
        uint256 tokenCount;
        require(account != address(0), "address zero is not a valid owner");
        for (uint i = 0; i < _inChainsId.length; i++){
            addr = _contractInfo[_inChainsId[i]].addr;
            try IERC721Enumerable(addr).supportsInterface(bytes4(keccak256('tokenOfOwnerByIndex(address,uint256)'))) 
                returns (bool retval)
            {
                //tokenOfOwnerByIndexがある場合はトークン数を収集する
                if (retval){
                    tokenCount = IERC721(addr).balanceOf(account);
                    for (uint j = 0; j < tokenCount; j++){
                        amount += _balances[ _inChainsId[i] ][j];
                    }
                }

            }catch Error (string memory reason) {
                console.log(_inChainsId[i], reason);
            }catch (bytes memory reason) {
                console.log(_inChainsId[i], "low level error was occured.");
            }
        }
        return amount;
    }
    
    // コントラクトID登録
    function addContract(address addr_, uint256 chainId_) public virtual onlyRole(DEFAULT_ADMIN_ROLE) returns(uint256){
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
        return _addContract(newContract);

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

    // 登録コントラクトの有効/無効設定
    function setAvailablity(uint256 contractId_, bool val_) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _availablity[contractId_] = val_;
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
    function totalInChains() public view virtual returns(uint256){
        return _inChainsId.length;
    }
    function availablity(uint256 contractId_) public view virtual returns(bool){
        return _availablity[contractId_];
    }
    // Pause関連
    function pause() public virtual whenNotPaused onlyRole(PAUSER_ROLE){
        _pause();
    }
    function unpause() public virtual whenPaused onlyRole(PAUSER_ROLE){
        _unpause();
    }


    function transfer(uint256 contractId_,  uint256 amount_) public virtual returns (bool) {
        address owner = _msgSender();
        return true;
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
