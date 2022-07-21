pragma solidity ^0.8.4;

import "./IGameVault.sol";

interface IPHBattleVault is IGameVault{
    event MintExp(uint128 indexed collectionId, uint128 indexed tokenId, uint64 dExp);

    // Expのミントを実行。主にオフチェーンからのトークン移行時に使用し、専用のイベントを発行する。
    function mintExp (uint256 uts, uint128 cID, uint128 tID, uint64 dExp, bytes memory signature) external;

    // Expを増加させる。主に内部での処理を想定し、SetStatusイベントが発行される。
    function increaseExp (uint256 uts, uint128 cID, uint128 tID, uint64 dExp, bytes memory signature) external;

    // Expを減少させる。主に内部での処理を想定し、SetStatusイベントが発行される。
    function decreaseExp (uint256 uts, uint128 cID, uint128 tID, uint64 dExp, bytes memory signature) external;

}