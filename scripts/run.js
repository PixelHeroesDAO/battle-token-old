//ローカルチェーンへのデプロイと初期設定用スクリプト
//terminal 1:
//npx hardhat node
//terminal 2:
//npx hardhat run scripts/run.js
//

const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");
const { string } = require("hardhat/internal/core/params/argumentTypes");
//const artifacts = require("../artifacts/contracts/GameVault.sol/GameVault.json");
const artifacts = require("../artifacts/contracts/PHBattleVault.sol/PHBattleVault.json");
const artifactsPH = require("../artifacts/contracts/NFT/PixelHeroes.sol/PixelHeroes.json");
const artifactsToken = require("../artifacts/contracts/PHGameToken.sol/PHGameToken.json");
const artifactsEx = require("../artifacts/contracts/PHGameExchange.sol/PHGameExchange.json");

const {helpers} = require("../test/helpers");


const nfts = [
  '0xE72323d7900f26d13093CaFE76b689964Cc99ffc',
  '0xba6E421833F6C190a830Ce6E142685B3916c9BD0',
  '0xba6E421833F6C190a830Ce6E142685B3916c9BD0'
];

const chainid = [137, 137, 1];
const _name = "PHBattleVault";

let vaultAdmin, tokenAdmin, exAdmin;
let addrVault, addrToken, addrEx;
let tx;
let admin, signer;

const main = async () => {
    [admin, signer] = await ethers.getSigners();
    vaultAdmin = await helpers.deployContract(_name, ["alpha1"]);
    tx = await vaultAdmin.deployTransaction;
    addrVault = vaultAdmin.address;
    console.log(`        Deplyed by :`, tx.from);
    console.log(`        ${_name} Deplyed to :`, vaultAdmin.address);
    tokenAdmin = await helpers.deployContract("PHGameToken");
    tx = await tokenAdmin.deployTransaction;
    console.log(`        PHGameToken Deplyed to :`, tokenAdmin.address);
    addrToken = tokenAdmin.address;
    exAdmin = await helpers.deployContract("PHGameExchange");
    tx = await exAdmin.deployTransaction;
    console.log(`        PHGameExchange Deplyed to :`, exAdmin.address);
    addrEx = exAdmin.address;
    exAdmin.setVault(addrVault);
    exAdmin.setToken(addrToken);

    //signer / minterの設定
    tx = await vaultAdmin.grantRole(await vaultAdmin.SIGNER_ROLE(), signer.address);
    console.log("        signer address of vault : ", signer.address);
    tx = await tokenAdmin.grantRole(await tokenAdmin.MINTER_ROLE(), addrEx);
    console.log("        minter address of token: ", addrEx);

    //Vaultへのコレクション追加
    for (let i = 0; i < chainid.length; i ++){
      tx = await vaultAdmin["addCollection(uint24,address)"](chainid[i],nfts[i]);
      await tx.wait();
    } 
    tx = await vaultAdmin.totalCollection();
    console.log(`        totalCollection : ${tx}`);

}

const runMain = async () => {
    try {
      await main();
      process.exit(0);
    } catch (error) {
      console.error(error);
      process.exit(1);
    }
};

  
runMain();