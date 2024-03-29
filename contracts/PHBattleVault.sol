pragma solidity ^0.8.4;

import "./GameVault.sol";
import "./interfaces/IPHBattleVault.sol";

//import "@openzeppelin/contracts/access/AccessControl.sol";
//import "@openzeppelin/contracts/utils/Strings.sol";

//import "./lib/RecoverSigner.sol";
//import "./lib/AddressStrings.sol";
//import "./lib/AddressUint.sol";


import "hardhat/console.sol";


contract PHBattleVault is GameVault, IPHBattleVault{

    using Strings for uint256;
    using Strings for uint128;
    using AddressStrings for address;
    using AddressUint for address;
    using UintAddress for uint256;

    error ExperienceOverFlow();
    error ExperienceUnderFlow();

    constructor (string memory ver_) GameVault(ver_){

    }

    // Expのミントを実行。主にオフチェーンからのトークン移行時に使用し、専用のイベントを発行する。
    function mintExp (uint256 blockNumber, uint128 cID, uint128 tID, uint64 dExp, bytes memory signature) external override {
        _changeExp(blockNumber, cID, tID, dExp, true, signature, false);
        emit MintExp(cID, tID, dExp);
    }

    // Expを増加させる。主に内部での処理を想定し、SetStatusイベントが発行される。
    function increaseExp (uint256 blockNumber, uint128 cID, uint128 tID, uint64 dExp, bytes memory signature) external override{
        _changeExp(blockNumber, cID, tID, dExp, true, signature, true);
    }

    // Expを減少させる。主に内部での処理を想定し、SetStatusイベントが発行される。
    function decreaseExp (uint256 blockNumber, uint128 cID, uint128 tID, uint64 dExp, bytes memory signature) external override{
        _changeExp(blockNumber, cID, tID, dExp, false, signature, true);
    }

    function _changeExp (
        uint256 blockNumber, 
        uint128 cID, 
        uint128 tID, 
        uint64 dExp, 
        bool inc, 
        bytes memory signature,
        bool emitSetStatusEvent
    ) private {
        _checkCollectionId(cID);
        Status memory data = _status(cID, tID);
        if (inc) {
            if (data.exp + dExp > type(uint64).max) revert ExperienceOverFlow();   
            data.exp = data.exp + dExp;
        } else {
            if (data.exp < dExp) revert ExperienceUnderFlow();
            data.exp = data.exp - dExp;
        }
        _checkStatus(data);
        _checkDisable(cID);
        _verifySigner(_makeMsgExp(msg.sender, blockNumber, cID, tID, dExp, inc), signature);
        _verifyBlockNumber(blockNumber);
        _increaseNonce(msg.sender);
        _setStatus(cID, tID, data, emitSetStatusEvent);

    }

        /**
     * @dev make message for sign to update status by user
     *   The message contains address of user, nonce of address, cID and tID
     *   with "|" separator. All parts are string.
     * @param addr      EOA of user
     * @param cID       Unix Timestamp
     * @param cID       Collection ID
     * @param tID       Token ID of collection
     * @param dExp       Experience
     * @param inc       true: increase experience, false: decrease experience
     */
    function _makeMsgExp(
        address addr,
        uint256 blockNumber,
        uint128 cID,
        uint128 tID,
        uint64 dExp, 
        bool inc
    )internal view virtual returns (string memory){
        string memory sgn;
        if (inc) {
            sgn = "+";
        }else{
            sgn = "-";
        }
        string memory ret = string(abi.encodePacked(
            "0x",
            addr.toAsciiString(), "|", 
            nonce[addr].toString(),  "|",
            blockNumber.toString(), "|",
            cID.toString(), "|",
            tID.toString(), "|",
            sgn, uint256(dExp).toString()
        ));
        return ret;
    }

}