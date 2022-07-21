pragma solidity ^0.8.0;

interface IGameVault{ 

    // イベント
    event AddCollection(uint128 indexed collectionId, uint24 chainId, address addr);
    event SetStatus(uint128 indexed collectionId, uint128 indexed tokenId, uint64 exp, uint16 lv, uint16[] slot);

    function addCollection(
        uint24 chainId_, 
        address addr_, 
        bool isSerial_,
        uint24 startId_,
        uint24 maxSupply_
    ) external returns(uint256);

    function addCollection(uint24 chainId_, address addr_) external returns(uint256);

    function totalCollection() external view returns (uint256);

    function collection(uint128 cID) external view returns (
        uint256 chainId_, 
        address addr_, 
        bool isSerial_, 
        uint24 startId_, 
        uint24 maxSupply_
    );
    function changeCollectionSupply(
        uint128 cID, 
        bool isSerial_, 
        uint256 startId_, 
        uint256 maxSupply_)
    external returns(bool);

    function setCollectionDisable(uint128 cID) external ;

    function setCollectionEnable(uint128 cID) external ;

    function collectionDisable(uint128 cID) external view returns(bool);

    function status(uint128 cID, uint128 tID) external view returns(
        uint64 exp,
        uint16 lv,
        uint16[] memory slot
    );

    function setStatus(
        uint256 uts,
        uint128 cID, 
        uint128 tID, 
        uint64 exp, 
        uint16 lv, 
        uint16[] memory slot,
        bytes memory signature
        ) external;

    function expireDuration() external view returns(uint256);

    function setExpireDuration(uint256 newDuration) external;


}