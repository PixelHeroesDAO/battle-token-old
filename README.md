# Pixel Heroes Battle Token

## 概要
- ERC20とことなりNFTコントラクトアドレス×チェーンID×トークンIDにトークンを付与・償還する。
- mint/burn/transferは専用のバックエンドシステムからMinterRoleアドレスの署名付きでのみ可能とする（チェーン外のコントラクトの情報を取得するオラクルを作る必要がありハードルが高い）
- ERC20準拠の残高表示を提供する。ただし
  - 本コントラクトと同一チェーンのNFTコントラクトに限る
  - ERC721Enumerabelに準拠しているNFTコントラクトに限る

## 実行方法
### Node.js バージョン

hardhatドキュメントではv16となっている(22年5月現在)

### インストール
```
npm install hardhat
```
### テスト実行
```
npx hardhat test
```

## 継承
- ERC20Immobile.sol
  - OpenZeppelinのERC20から不要機能を削除したもの
- Pusable.sol
  - OpenZeppelinのWizard準拠
- AccessControl.sol
  - OpenZeppelinのWizard準拠
  - mintをオフチェーンDBから署名付きで行うMinterRoleが必要なため

## 実装する機能
### トークン保管

- コントラクトアドレスWhiteList
  - トークンを保管できるアドレス一覧。boolへのマッピングを想定
  - 追加、無効化のwrite関数を用意
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





