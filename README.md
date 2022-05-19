# Pixel Heroes Battle Token

## 概要
- ERC20とことなりNFTコントラクトアドレス×チェーンID×トークンIDにトークンを付与・償還する。
- mint/burn/transferは専用のバックエンドシステムからMinterRoleアドレスの署名付きでのみ可能とする（チェーン外のコントラクトの情報を取得するオラクルを作る必要がありハードルが高い）
- ERC20準拠の残高表示を提供する。ただし
  - 本コントラクトと同一チェーンのNFTコントラクトに限る
  - ERC721Enumerabelに準拠しているNFTコントラクトに限る

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
  - _iAllowances コントラクトに対して許可できるようにする

### 戦歴保管

- 単純な勝敗記録？
  - Tokenは消費できるが戦歴は消費不能なので別のストレージになる。
  - コントラクトアドレスxTokenID

### ERC20機能

- balanceOf
  - ERC721Enumerableを継承していれば、balanceOfとtokenOfOwnerByIndexで割と軽量に集約できる。supportsinterfaceIdにbytes4(keccak256('tokenOfOwnerByIndex(address,uint256)'))をいれることで確認できる。サポートしていない場合は取得しない。
- 無効化
  - transfer
  - allowance
  - approve
  - transferFrom

### 署名内容案
[ウォレットアドレス][ウォレットNonce][コントラクトID][トークンID][関数ID][トークン量][関数Param1][関数Param2]





