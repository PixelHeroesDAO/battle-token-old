pragma solidity ^0.8.4;

import "./GameVault.sol";

//import "@openzeppelin/contracts/access/AccessControl.sol";
//import "@openzeppelin/contracts/utils/Strings.sol";

//import "./lib/RecoverSigner.sol";
//import "./lib/AddressStrings.sol";
//import "./lib/AddressUint.sol";


import "hardhat/console.sol";


contract PHBattleVault is GameVault{

    using Strings for uint256;
    using AddressStrings for address;
    using AddressUint for address;
    using UintAddress for uint256;
    error ExperienceOverFlow();
    error ExperienceUnderFlow();

    constructor (string memory ver_) GameVault(ver_){

    }
    function increaseExp (uint128 cID, uint128 tID, uint64 dExp, bytes memory signature) external {
        _changeExp(cID, tID, dExp, true, signature);
    }

    function decreaseExp (uint128 cID, uint128 tID, uint64 dExp, bytes memory signature) external {
        _changeExp(cID, tID, dExp, false, signature);
    }

    function _changeExp (uint128 cID, uint128 tID, uint64 dExp, bool inc, bytes memory signature) private {
        _checkCollectionId(cID);
        uint64 exp; 
        uint16 lv;
        uint16[11] memory slot;
        (exp, lv, slot) = _status(cID, tID);
        //動的配列に静的配列を渡せない。関数内では配列のリサイズはできないので、
        //newを使って予めサイズを設定する。
        uint16[] memory slot_out = new uint16[](11);
        if (inc) {
            if (exp + dExp > type(uint64).max) revert ExperienceOverFlow();   
            exp = exp + dExp;
        } else {
            if (exp < dExp) revert ExperienceUnderFlow();
            exp = exp - dExp;
        }
        for(uint i = 0; i < 11 ; i++){
            slot_out[i]=slot_out[i];
        }
        _checkStatus(exp, lv, slot_out);
        _checkDisable(cID);
        _verifySigner(_makeMsgExp(msg.sender, cID, tID, dExp, inc), signature);
        _increaseNonce(msg.sender);
        _setStatus(cID, tID, _makePackedStatus(exp, lv, slot_out));

    }

        /**
     * @dev make message for sign to update status by user
     *   The message contains address of user, nonce of address, cID and tID
     *   with "|" separator. All parts are string.
     * @param addr      EOA of user
     * @param cID       Collection ID
     * @param tID       Token ID of collection
     * @param dExp       Experience
     * @param inc       true: increase experience, false: decrease experience
     */
    function _makeMsgExp(
        address addr,
        uint256 cID,
        uint256 tID,
        uint64 dExp, 
        bool inc
    )internal view virtual returns (string memory){
        string memory sgn;
        if (!inc) sgn = "-";
        string memory ret = string(abi.encodePacked(
            "0x",
            addr.toAsciiString(), "|", 
            nonce[addr].toString(),  "|",
            cID.toString(), "|",
            tID.toString(), "|",
            sgn, uint256(dExp).toString()
        ));
        return ret;
    }

}