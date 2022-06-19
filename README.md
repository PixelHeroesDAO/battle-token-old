# Pixel Heroes Battle Token

## 概要
- NFTトークンごとに経験値を含むゲームデータを保存する、貯蔵(Vault)用コントラクトと、ERC20に準拠したウォレットに紐付くゲームトークン用コントラクトに分離する。
- NFTトークンの経験値は、ゲームトークンに不可逆に移転することができる。詳細は検討中だが、移転権限を持つ移転用コントラクトを別途準備し、経験値の消費とゲームトークンのmintを行う実装を想定。

## 実行方法
### Node.js バージョン

hardhatドキュメントではv16となっている(22年5月現在)

### インストール
```
npm install hardhat --save-dev
```

テスト性改善やガス代計算のため、3種類のパッケージを追加 (5/29)

### テスト実行
```bash
## Normal test
npx hardhat test
## Test with gas estimation
npm run testgas
```

## 使用方法

### 準備

1. ウォレットの準備とコントラクトへの接続、サイナーの設定
   
   操作を行うウォレットを準備する。hardhatテスト環境の場合、例えば以下のようにして取得することができる。

   ```javascript
   let admin, signer, user1, user2, user3;
   [admin, signer, user1, user2, user3] = await ethers.getSigners(); 
   ```

   ABIの準備をする。デプロイする際には不要だが、デプロイ済みのコントラクトを別ウォレット等で操作する際に必要。以下のコードを実行しておくと、`artifacts.abi`でABIを渡すことができる。

   ```javascript
   const artifacts = require("../artifacts/contracts/PHBattleVault.sol/PHBattleVault.json");
   ```

   コントラクトに接続する。

   ```javascript
   const addr = コントラクトアドレス;
   Cont1 = await new ethers.Contract(addr, artifacts.abi, user1);
   ```

   必要に応じてサイナーアドレスを変更する。通常はバックエンドで管理し署名するウォレットの秘密鍵と、コントラクト自体を管理するウォレットは異なる。設定する場合は下記の通りにする。`ContAdmin`は管理者ウォレットが接続したコントラクトオブジェクトである。

   ```javascript
   let tx = await ContAdmin.grantRole(await ContAdmin.SIGNER_ROLE(), signer.address);
   ```

2. Vaultへのコレクションの追加
   
   NFTに経験値やステータスを紐付けるため、NFTをコントラクトに登録し、コレクションを呼ぶ。コレクションはチェーンID`chainId_`、コントラクトアドレス`addr_`、IDが連続しているか否か`isSerial_`、トークンの開始ID`startId_`、最大供給量`maxSupply_`で構成される。`isSerial_`が真の場合、残り2つの情報を登録できる（現状は登録してもコントラクト内では利用していない）。なお、異なるチェーンIDのNFTを登録できる代わりに、NFTの所有者情報等のチェックはコントラクト側では行えない点に注意。

   コレクションの追加には`addCollection()`を用いる。この関数は勝手に追加されないようにDEFAULT_ADMIN_ROLEを持つアドレス(初期値はデプロイしたアドレス)のみが実行できる。`isSerial`を偽、`startId_`と`maxSupply_`を初期値(0)に自動設定するタイプと、5つの引数すべてを指定する2種類の関数が存在する。そのため、hardhatから呼び出す場合にはABI形式で呼び出す必要がある（関数が自動では識別できない）。

   次の例ではADMINアドレスで接続したコントラクトオブジェクト`ContAdmin`を用いてチェーンIDとコントラクトアドレスのみ指定して登録する。

   ```javascript
   let tx = await ContAdmin['addCollection(uint24,address)'](137,'0xE72323d7900f26d13093CaFE76b689964Cc99ffc');
   ```

   この関数を実行すると、1から始まるコレクションに割り当てられるコレクションIDが設定される。コレクションIDが関数の戻り値なのだが、EVMでは戻り値を外部から取り出すことができない。イベントからの取り出しが必要になる。`AddCollection(uint128 indexed collectionId, uint24 chainId, address addr)`イベントが定義されているので、確実に取り出したい場合このイベントを処理する。通常は'totalCollection()`関数で得られる値+1が与えられる。

   以上でNFTにステータスを設定する準備が整った。

3. ステータスの更新
   
   すでに述べたとおり、チェーンをまたいでステータスを付与するため、コントラクトではステータスの更新のTxが起こされてもそれが妥当な内容なのか（NFTの所有者なのか、など）を検証するすべがない。ステータス更新関数はどんなウォレットでも自由に実行することができてしまう。そこでフロント側で検証を行い妥当性が確認されたTxのみを実行する仕組みが必要となる。実行するTxの内容を記したメッセージにsignerが秘密鍵を用いて署名を行い、これをコントラクト側で復号してsignerのアドレスと一致するか否かで検証結果を確認する。署名はsignerの秘密鍵でしか行えないため、フロント側で検証し署名を付けた場合のみ、Txが実行されることになる。

   署名を行う場合、メッセージを作成しハッシュを取り、`arrayify`を行う必要がある。分かりづらいため、`helpers.js`に`helpers`オブジェクトとしてまとめた。`～Bytes()`関数で作成したメッセージハッシュを`ウォレット.signMessage()`に渡すと、署名を取得できる。これをコントラクトに渡す。

   具体的には次のようにステータスを更新する。ここでは上記`user1`(接続したコントラクトオブジェクトは`Cont1`)が、コレクションID=1、トークンID=1、経験値=123242、レベル=2、ステータス=[10,23,45,35,23,66]を設定する。フロント側では、この内容に対して妥当と判断し、上記のように処理して署名する。ウォレットアドレスのnonceはコントラクトの関数`nonce()`で取得する。

   ```javascript
    let colid = 1;
    let tid = 1;
    let exp = 123242;
    let lv = 2;
    let status = [10,23,45,35,23,66];

    let hashbytes = helpers.MessageBytes
    (
      user1.address,
      await Cont1.nonce(user1.address),
      colid,
      tid,
      exp,
      lv,
      status
    );
    let signature = await signer.signMessage(hashbytes);

    let tx = await Cont1.setStatus(colid, tid, exp, lv, status, signature);
   ```

   ステータスは11スロット用意されており、特に用途は決まっていない。データサイズは以下の通り。

   exp : 64bit 0～約18Z(10^18)

   lv : 16bit 0～65536

   status : 16bit 0～65536



## 実装する機能

この内容は概要だけに修正し、個別の機能説明はコントラクトごとのドキュメントに移管予定。

### トークン保管

- コントラクトアドレスWhiteList
  - トークンを保管できるアドレス一覧。boolへのマッピングを想定
  - 追加、無効化のwrite関数を用意
  - コントラクトID0のtoken IDをウォレットアドレスに使用することで、変数を増やさずにウォレットにトークンを保有させられる
- コントラクトアドレスxTokenID _iBalances
  - クレーム　サーバーの署名付きでクレーム量を担保する
- transfer
  - 実装はするが、無効にしておく
- 送金許可
  - _Allowances コントラクトに対して許可できるようにする

### 戦歴保管

- 単純な勝敗記録？
  - Tokenは消費できるが戦歴は消費不能なので別のストレージになる。
  - コントラクトアドレスxTokenID

### ERC20機能

- balanceOf
  - tokenOfOwnerByIndexメソッドで所有TokenIDを取得する。取得できないコントラクトは無視する。
- 無効化(今のところ)
  - transfer
  - allowance
  - approve
  - transferFrom

### 署名内容案
ウォレットアドレス(文字列)|ウォレットNonce|コントラクトID|トークンID|関数ID|トークン量

"|"を入れるのは、連続して数字を文字列化すると、ハッシュ衝突が起こるため。例えばNonce=1, ContractID=11, tokenID=222は、111222となる。一方でNonce=11, ContractID=12, tokenID=22も111222となる。間に数字以外のセパレータを入れることで、1|11|222と11|12|22として異なる文字列になり、ハッシュ衝突を回避できる。

ハッシュ衝突が起こる弊害は、例えばすでに前者のTxが完了している場合、後者のNonce=10の状態をまち、そのタイミングで同じ署名を使い回してTxを起こすことで、ウォレット所有者がシステムの意図しないトークン獲得等が可能になりうる。





