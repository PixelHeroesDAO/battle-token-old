const { expect, assert } = require("chai");
const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");
const { string } = require("hardhat/internal/core/params/argumentTypes");
const artifacts = require("../artifacts/contracts/GameVault.sol/GameVault.json");
const artifactsPH = require("../artifacts/contracts/NFT/PixelHeroes.sol/PixelHeroes.json");

const {deployContract} = require("../test/helpers");


const nfts = [
  '0xE72323d7900f26d13093CaFE76b689964Cc99ffc',
  '0xba6E421833F6C190a830Ce6E142685B3916c9BD0'
];

const chainid = [137, 137];
const _name = "GameVault";

describe(`${_name} TEST`, function () {

  let admin, signer, user1, user2, user3;
  let addr; //コントラクトアドレス
  let thisChainId;
  let idPHS, idPHX;
  let ContAdmin, Cont1, Cont2, Cont3;

  it(`${_name} Contract Deploy`, async function () { 
    [admin, signer, user1, user2, user3] = await ethers.getSigners();
    ContAdmin = await deployContract("GameVault", ["V1"]);
    let tx = await ContAdmin.deployTransaction;
    thisChainId = tx.chainId;
    console.log("        Chain ID : ", thisChainId);
    addr = ContAdmin.address;
    console.log(`        ${_name} Deplyed by :`, tx.from);
    console.log(`        ${_name} Deplyed to :`, ContAdmin.address);
  });

  it("Set User Wallet", async function () { 
    Cont1 = await new ethers.Contract(addr, artifacts.abi, user1);
    Cont2 = await new ethers.Contract(addr, artifacts.abi, user2);
    Cont3 = await new ethers.Contract(addr, artifacts.abi, user3);

  });

  it("Get totalCollection", async function () { 
    const ret = await Cont1.totalCollection();
    console.log(`        totalCollection : ${ret}`);

  });

  it("Add Collections", async function () { 
    let tx = await ContAdmin["addCollection(uint256,address)"](chainid[0],nfts[0]);
    await tx.wait();
    tx = await ContAdmin["addCollection(uint256,address)"](chainid[1],nfts[1]);
    await tx.wait();
    const ret = await Cont1.totalCollection();
    console.log(`        totalCollection : ${ret}`);
  });

  it("Get information of the collections", async function () { 
    let cid, addr, serial, startId, maxSupply;
    let ret;
    for (let colid = 1; colid <= 2 ; colid++){
        ret = await ContAdmin.collection(colid);
        [cid, addr, serial, startId, maxSupply] = ret;
        expect(cid).to.be.equal(chainid[colid-1]);
        expect(addr).to.be.equal(nfts[colid-1]);
        console.log(`       CollectionID=${colid}:`, cid.toNumber(), addr, serial, startId.toNumber(), maxSupply.toNumber());
    
    }
  });

  it("Testing set ststus of collection 1 Token 1", async function () {
    let colid = 1;
    let tid = 1;
    let exp = 123242;
    let lv = 2;
    let status = [10,23,45,35,23,66];

    let ret = await ContAdmin._setStatusTEST(colid,tid,exp,lv,status);

  });

});

