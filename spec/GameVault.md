# GameVault

[`BattleToken/contracts/GameVault.sol`](https://github.com/PixelHeroesDAO/battle-token/tree/master/contracts/GameVault.sol)

ゲーム関連情報保存用コントラクト

## Overview

5/31のゲーム内でのboo changとの会話で、以下の実装ですすめることに決定。
- コレクションIDを登録する（チェーンID×コントラクトアドレス） (0は欠番、1スタートのインクリメンタルID)
- コレクションID×トークンIDでステータス読み書きをする

### コレクションID

collectionId(cID) => `Chain ID(24bits)` + `Contract Address(160bits)` + `IsSerial(8bit)`
                     + `startId(24bits)` + `maxSupply(24bits)` + `Aux(16bits)` = 256bits

チェーン、コントラクト、NFTのID情報を登録
- Chain ID : チェーンID
- Contract Address : NFTコントラクトのアドレス
- IsSerial : TokenIDが連続して発行されるか否か 0(false) or 1(true)
- startId : (IsSerial:true) 開始ID, (false) 0
- maxSupply : (IsSerial:true) 最大供給量 (false) 0 

### ステータス情報

key : `Collection ID(128bits)` + `Token ID(128bits)` = 256bits

key => Stored parameter(uint256) :

- Experience(64bits/max:18Zeta(10^21))
- Level(16bits/max:65K)
- Status (HP, Attack, Defense, Speed, luck, etc...) (16bits/max:65K x 11slots)

keyを元にステータス情報の保存

### Message for signature to update status vault

[wallet address(lower case)]|[wallet nonce]|[Exp]|[Lv]|[Status1]|[Status2]|...|[Status11]

- Statusは11個に満たない場合、0で埋めて11個にする(コントラクト側には常に11個分のスロットが用意され初期値は0)。
- それぞれの値は文字列とし、"|"をセパレータとする。
- メッセージに全データを使う理由：例えばメッセージをnonceだけとした場合、意図的に低いガス代を設定してTxをpendingにすることで、未使用nonceの署名を入手することができる。この署名を使えばステータスを都合よく変更した新たなTxをコントラクトに対して直接実行できてしまう。コントラクトに書き込むデータすべてに対しての署名を用いることで、このような問題を防ぐことができる。


## Functions
### constructor
```solidity
constructor(string memory ver_)
```
バージョン情報を設定してコントラクトを初期化する。

### addCollection
```solidity
function addCollection(uint24 chainId_, address contract_, bool isSerial_, uint256 startId_, uint256 maxSupply_) public virtual returns(uint256)
```
コレクションを追加。
isSerial_が真の場合、startId_とmaxSupply_を保持する。
isSerial_が偽の場合は0で埋める。
- isSerial_ (uint8)
- startId_ (uint24)
- maxSupply_ (uint24)
戻り値はコレクションID。

### 


