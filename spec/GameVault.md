# GameVault

[`BattleToken/contracts/GameVault.sol`](https://github.com/PixelHeroesDAO/battle-token/tree/master/contracts/GameVault.sol)

ゲーム関連情報保存用コントラクト

## Overview

5/31のゲーム内でのboo changとの会話で、以下の実装ですすめることに決定。
- コレクションIDを登録する（チェーンID×コントラクトアドレス） (0は欠番、1スタートのインクリメンタルID)
- コレクションID×トークンIDでステータス読み書きをする

7/30 別途テストしたpackedデータのArrayとuint8のArrayで意外にuint8のArrayガス代がやすかったため、
Structでもそれほどガス代が上がらないかむしろ安くなる可能性にかけてまずはcollectionに対して導入してみた。
mappingをarray変更とセットで実施するとかなり上昇。mappingに戻しても1400程度の差が生じた。
具体的には
- addCollection
  - packed 97692 / 57695
  - struct 99064 / 59067
- changeCollectionSupply
  - packed 33085
  - struct 35510
- setStatus(内部はpacked、structからのオーバーヘッドの差)
  - packed 231226
  - struct input 231799
struct保存は想定以上に高いため、内部構造はpackedに戻し、インターフェースとしてStructを使って見やすくすることにした。


