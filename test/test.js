const { expect, assert } = require("chai");
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
//const _name = "GameVault";
const _name = "PHBattleVault";

describe(`${_name} TEST`, function () {

  let admin, signer, user1, user2, user3;
  let addr, addrToken, addrEx; //コントラクトアドレス
  let thisChainId;
  let idPHS, idPHX;
  let ContAdmin, Cont1, Cont2, Cont3;
  let tokenAdmin, token1;
  let exAdmin, ex1;

  it(`${_name} Contract Deploy`, async function () { 
    let tx;
    [admin, signer, user1, user2, user3] = await ethers.getSigners();

    ContAdmin = await helpers.deployContract(_name, ["alpha1"]);
    tx = await ContAdmin.deployTransaction;
    thisChainId = tx.chainId;
    console.log("        Chain ID : ", thisChainId);
    addr = ContAdmin.address;
    console.log(`        Deplyed by :`, tx.from);
    console.log(`        ${_name} Deplyed to :`, ContAdmin.address);
    tokenAdmin = await helpers.deployContract("PHGameToken");
    tx = await tokenAdmin.deployTransaction;
    console.log(`        PHGameToken Deplyed to :`, tokenAdmin.address);
    addrToken = tokenAdmin.address;
    exAdmin = await helpers.deployContract("PHGameExchange");
    tx = await exAdmin.deployTransaction;
    console.log(`        PHGameExchange Deplyed to :`, exAdmin.address);
    addrEx = exAdmin.address;
    exAdmin.setVault(addr);
    exAdmin.setToken(addrToken);
    expect(await exAdmin.vault()).to.be.equal(addr);
  });

  it(`Set signer role`, async function () {
    let tx = await ContAdmin.grantRole(await ContAdmin.SIGNER_ROLE(), signer.address);
    expect(await ContAdmin.hasRole(await ContAdmin.SIGNER_ROLE(), signer.address)).to.be.equal(true);
    console.log("        signer address of vault : ", signer.address);
    tx = await tokenAdmin.grantRole(await tokenAdmin.MINTER_ROLE(), addrEx);
    expect(await tokenAdmin.hasRole(await tokenAdmin.MINTER_ROLE(), addrEx)).to.be.equal(true);
    console.log("        minter address of token: ", addrEx);
  })

  it("Set User Wallet", async function () { 
    Cont1 = await new ethers.Contract(addr, artifacts.abi, user1);
    Cont2 = await new ethers.Contract(addr, artifacts.abi, user2);
    Cont3 = await new ethers.Contract(addr, artifacts.abi, user3);
    ex1 = await new ethers.Contract(addrEx, artifactsEx.abi, user1);
    token1 = await new ethers.Contract(addrToken, artifactsToken.abi, user1);
  });

  it("Get totalCollection", async function () { 
    const ret = await Cont1.totalCollection();
    console.log(`        totalCollection : ${ret}`);

  });

  it("Add Collections", async function () {
    let tx;
    for (let i = 0; i < chainid.length; i ++){
      tx = await ContAdmin["addCollection(uint24,address)"](chainid[i],nfts[i]);
      await tx.wait();
    } 
    for (i = 0; i < 256 ; i++){
      tx = await ContAdmin["addCollection(uint24,address)"](i+2,nfts[2]);
      await tx.wait();
    }
    const ret = await Cont1.totalCollection();
    console.log(`        totalCollection : ${ret}`);
    expect(ret).to.be.equal(256+3);
  });

  it("Get information of the collections", async function () { 
    let ret;
    for (let colid = 1; colid <= 3 ; colid++){
        ret = await ContAdmin.collection(colid);
        expect(ret.chainId).to.be.equal(chainid[colid-1]);
        expect(ret.addr).to.be.equal(nfts[colid-1]);
        console.log(`       CollectionID=${colid}:`, ret.chainId, ret.addr, ret.isSerial, ret.startId, ret.maxSupply);
    
    }
  });

  it("Change the supply of the collection", async function () { 
    let cid, addr, serial, startId, maxSupply;
    const colid = 3;
    const new_serial = true;
    const new_startId = 1;
    const new_supply = 1000;

    let ret = await ContAdmin.changeCollectionSupply(colid,new_serial,new_startId,new_supply);
    ret = await ContAdmin.collection(colid);
    [chainId, addr, isSerial, startId, maxSupply] = ret;
    expect(isSerial).to.be.equal(new_serial);
    expect(startId).to.be.equal(new_startId);
    expect(maxSupply).to.be.equal(new_supply);
    console.log(`       CollectionID=${colid}:`, chainId, addr, isSerial, startId, maxSupply);
  
  });

  it("Testing make message", async function () {
    let colid = 1;
    let tid = 1;
    let exp = 123242;
    let lv = 2;
    let slot = [10,23,45,35,23,66];
    let data = {exp, lv, slot};
    let bn = await user1.provider.getBlockNumber();//helpers.Date2UnixTimestamp(new Date());

    let ret = await Cont1.TEST_makeMessage(user1.address,bn, colid,tid,data);
    let msg = helpers.Message
    (
      user1.address,
      await Cont1.nonce(user1.address),
      bn, 
      colid,
      tid,
      exp,
      lv,
      slot
    );
    console.log(`       Message:${ret}`)
    expect(ret).to.be.equal(msg);
  });

  it("Set status of collection 1 Token 1 and verify with get function", async function () {
    let colid = 1;
    let tid = 1;
    let exp = 123242;
    let lv = 2;
    let slot = [10,23,45,35,23,66];
    let data = {exp:exp, lv:lv, slot:slot};

    let bn = await user1.provider.getBlockNumber();//helpers.Date2UnixTimestamp(new Date());

    let hashbytes = helpers.MessageBytes
    (
      user1.address,
      await Cont1.nonce(user1.address),
      bn, 
      colid,
      tid,
      exp,
      lv,
      slot
    );
    let signature = await signer.signMessage(hashbytes);

    let tx = await Cont1.setStatus(bn, colid, tid, data, signature);
    let ret = await Cont1.status(colid, tid);
    expect(ret.exp.toNumber()).to.be.equal(exp);
    expect(ret.lv).to.be.equal(lv);
    let testSlot = slot;
    for (let i = slot.length ; i < 11 ; i++){
      testSlot.push(0);
    }
    // 配列を比較する場合、eqaulではなくeqlを使うとうまくいくらしい
    expect(data.slot).to.be.eql(testSlot);
     
  });

  it("Get collection status about disable", async function(){
    let ret;
    for (let i = 1 ; i <= 3 ; i++){
      ret = await Cont1.collectionDisable(i);
      console.log(`        Collection Disable of ID=${i}:${ret}`);
      expect(ret).to.be.equal(false);
    }
  });

  it("Set collection status to disable of ID = 3", async function(){
    let ret;
    let colid = 3;
    const resExpect = [false, false, true];
    ret = await ContAdmin.setCollectionDisable(colid);
    for (let i = 1 ; i <= 3 ; i++){
      ret = await Cont1.collectionDisable(i);
      console.log(`        Collection Disable of ID=${i}:${ret}`);
      expect(ret).to.be.equal(resExpect[i-1]);
    }
  });

  it("Set collection status to enable of ID = 3", async function(){
    let ret;
    let colid = 3;
    const resExpect = [false, false, false];
    ret = await ContAdmin.setCollectionEnable(colid);
    for (let i = 1 ; i <= 3 ; i++){
      ret = await Cont1.collectionDisable(i);
      console.log(`        Collection Disable of ID=${i}:${ret}`);
      expect(ret).to.be.equal(resExpect[i-1]);
    }
  });

  it("Set collection status to disable of ID = 254 - 257(beyond boundary of array)", async function(){
    let ret;
    const resExpect = [false, true, true, true, true, false];
    for (let i = 254 ; i <= 257 ; i++){
      ret = await ContAdmin.setCollectionDisable(i);
    }
    for (let i = 253 ; i <= 258 ; i++){
      ret = await Cont1.collectionDisable(i);
      console.log(`        Collection Disable of ID=${i}:${ret}`);
      expect(ret).to.be.equal(resExpect[i-253]);
    }
  });

  it("Revert test : Set status of disable collection ", async function () {
    let colid = 3;
    let tid = 1;
    let exp = 123242;
    let lv = 2;
    let slot = [10,23,45,35,23,66];
    let data = {exp, lv, slot};
    
    let bn = await user1.provider.getBlockNumber();//helpers.Date2UnixTimestamp(new Date());

    let ret = await ContAdmin.setCollectionDisable(colid);

    let hashbytes = helpers.MessageBytes
    (
      user1.address,
      await Cont1.nonce(user1.address),
      bn,
      colid,
      tid,
      exp,
      lv,
      slot
    );
    let signature = await signer.signMessage(hashbytes);

    await expect(ContAdmin.setStatus(bn, colid, tid, data, signature)).to.be.revertedWith('CollectionIsDisable');
     
  });
  

  it("Revert test : Operate collection by non-admin user", async function(){
    await expect(Cont1["addCollection(uint24,address)"](chainid[0], nfts[0]))
      .to.be.revertedWith('missing role');
    await expect(Cont2.changeCollectionSupply(1,true,12,56)).to.be.revertedWith('missing role');
  });

  it("Revert test :Access invalid collection ID", async function(){
    await expect(Cont1.collection(300))
      .to.be.revertedWith('ReferNonexistentCollection');
      await expect(Cont1.collection(0))
      .to.be.revertedWith('ReferZeroCollection');
  });

  it("Increment Exp for collection 1 Token 1", async function () {
    let colid = 1;
    let tid = 1;
    let dExp = 324;
    let inc = true;

    let bn = await user1.provider.getBlockNumber();//helpers.Date2UnixTimestamp(new Date());

    let r_exp_org, r_lv, r_status;
    let ret = await ContAdmin.status(colid, tid);
    [r_exp_org, , ] = ret;


    let hashbytes = helpers.MsgExpBytes
    (
      user1.address,
      await Cont1.nonce(user1.address),
      bn,
      colid,
      tid,
      dExp,
      inc
    );
    let signature = await signer.signMessage(hashbytes);

    await Cont1.increaseExp(bn, colid, tid, dExp, signature);
    ret = await Cont1.status(colid, tid);
    [r_exp, r_lv, r_status] = ret;
    expect(r_exp.toNumber()).to.be.equal(r_exp_org.toNumber() + dExp);
     
  });
  it("Decrement Exp for collection 1 Token 1", async function () {
    let colid = 1;
    let tid = 1;
    let dExp = 4220;
    let inc = false;

    let bn = await user1.provider.getBlockNumber();//helpers.Date2UnixTimestamp(new Date());

    let r_exp_org, r_lv, r_status;
    let ret = await ContAdmin.status(colid, tid);
    [r_exp_org, , ] = ret;


    let hashbytes = helpers.MsgExpBytes
    (
      user1.address,
      await Cont1.nonce(user1.address),
      bn,
      colid,
      tid,
      dExp,
      inc
    );
    let signature = await signer.signMessage(hashbytes);

    await Cont1.decreaseExp(bn,colid, tid, dExp, signature);
    ret = await Cont1.status(colid, tid);
    [r_exp, r_lv, r_status] = ret;
    expect(r_exp.toNumber()).to.be.equal(r_exp_org.toNumber() - dExp);
    console.log(`        Remain EXP : ${r_exp}`);

  });

  it("Exchange Exp to Token", async function () {
    let colid = 1;
    let tid = 1;
    let dExp = 1312;
    
    let bn = await user1.provider.getBlockNumber();//helpers.Date2UnixTimestamp(new Date());

    let hashbytes = helpers.MsgExpBytes
    (
      addrEx,
      await Cont1.nonce(addrEx),
      bn, 
      colid,
      tid,
      dExp,
      false
    );
    let signature = await signer.signMessage(hashbytes);

    await ex1.exchangeToToken(bn, colid, tid, dExp, signature);
    ret = await Cont1.status(colid, tid);
    [r_exp, r_lv, r_status] = ret;
    console.log(`        Remain EXP : ${r_exp}`);
    let r_bal = await token1.totalSupply();
    console.log(`        Token Balance : ${(r_bal.div(BigNumber.from(10).pow(15))).toNumber()/1000} PIKU`);
     
  });
});



