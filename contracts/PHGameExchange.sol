pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./PHBattleVault.sol";
import "./PHGameToken.sol";

import "hardhat/console.sol";

contract PHGameExchange is Ownable{
    address public vaultAddress;
    address public tokenAddress;

    // 経験値1あたりのトークン交換レート
    uint256 public exchangeRate;

    error ZeroAddress();

    constructor(){
        exchangeRate = 1 ether / 1000;
    }

    function setVault(address addr) public onlyOwner {
        if (addr == address(0)) revert ZeroAddress();
        vaultAddress = addr;
    }

    function setToken(address addr) public onlyOwner {
        if (addr == address(0)) revert ZeroAddress();
        tokenAddress = addr;
    }

    function setExchangeRate(uint256 rate) public onlyOwner {
        exchangeRate = rate;
    }

    function exchangeToToken(
        uint128 cID, 
        uint128 tID, 
        uint64 expAmount, 
        bytes memory signature
    ) public returns(bool) {
        uint64 exp;
        PHBattleVault vault = PHBattleVault(vaultAddress);
        (exp,,) = vault.status(cID, tID);
        console.log(exp);
    }

}
