pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./PHBattleVault.sol";
import "./PHGameToken.sol";

contract PHGameExchange is Ownable{
    address public vaultAddress;
    address public tokenAddress;

    error ZeroAddress();

    constructor(){
        
    }

    function setVault(address addr) public onlyOwner {
        if (addr == address(0)) revert ZeroAddress();
        vaultAddress = addr;
    }

    function setToken(address addr) public onlyOwner {
        if (addr == address(0)) revert ZeroAddress();
        tokenAddress = addr;
    }

}
