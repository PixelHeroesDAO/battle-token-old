# GameVault

[`BattleToken/contracts/GameVault.sol`](https://github.com/PixelHeroesDAO/battle-token/tree/master/contracts/GameVault.sol)

ゲーム関連情報保存用コントラクト

## Overview

5/31のゲーム内でのboo changとの会話で、以下の実装ですすめることに決定。
- コレクションIDを登録する（チェーンID×コントラクトアドレス） (0は欠番、1スタートのインクリメンタルID)
- コレクションID×トークンIDでステータス読み書きをする

### コレクションID

collectionId(cID) => `Chain ID(24bits)` + `Contract Address(160bits)` + `Aux(72bits)` = 256bits

チェーン、コントラクト、NFTのID情報を登録
後半は現状の案で、無くてもよい（コントラクト側ではチェックしない）

### ステータス情報

key : `Collection ID(128bits)` + `Token ID(128bits)` = 256bits

key => Stored parameter(uint256) :

- Experience(64bits/max:18Zeta(10^21))
- Level(16bits/max:65K)
- Status (HP, Attack, Defense, Speed, luck, etc...) (16bits/max:65K x 11slots)

keyを元にステータス情報の保存

Message for signature : [wallet address]|[wallet nonce]|[Key]|[Function]

## Functions
### constructor
```solidity
constructor(string memory ver_)
```
バージョン情報を設定してコントラクトを初期化する。

### addCollection
```solidity
function addExperience(uint24 chainId_, address contract_, bool isSerial_, uint24 startId_, uint24 maxSupply_) public virtual returns(uint24)
```
コレクションを追加。
isSerial_が真の場合、startId_とmaxSupply_を保持する。
isSerial_が偽の場合は0で埋める。
戻り値はコレクションID。

### 

### コレクション情報取得関数を追加する

### experience
```solidity
function experience(uint24 chainId_, address contract_, uint24 tokenId_) public view virtual returns(uint256)
```
経験値情報の取得。

### addExperience
```solidity
function addExperience(uint24 chainId_, address contract_, uint24 tokenId_, uint256 value, bytes memory signature) public virtual
```
経験値の追加。

### useExperience
```solidity
function useExperience(uint24 chainId_, address contract_, uint24 tokenId_, uint256 value, bytes memory signature) public virtual
```
経験値を消費。

### level
```solidity
function level(uint24 chainId_, address contract_, uint24 tokenId_) public view virtual returns(uint256)
```
レベル情報の取得。

### raiseLevel
```solidity
function raiseLevel(uint24 chainId_, address contract_, uint24 tokenId_, bytes memory signature) public virtual
```
レベルUP。実行すると1上がる。

### status
```solidity
function status(uint24 chainId_, address contract_, uint24 tokenId_, uint8 index_) public view virtual returns(uint256)
```
ステータス情報の取得。

### statusSet
```solidity
function statusSet(uint24 chainId_, address contract_, uint24 tokenId_) public view virtual returns(uint256[])
```
ステータス情報の取得。

### setStatus
```solidity
function setStatus(uint24 chainId_, address contract_, uint24 tokenId_, uint8 index_, uint256 value, bytes memory signature) public virtual
```
パラメータが減る可能性も加味して、セットにする。

### setStatusArray
```solidity
function setStatusArray(uint24 chainId_, address contract_, uint24 tokenId_, uint256[] value, bytes memory signature) public virtual
```
パラメータが減る可能性も加味して、セットにする。


