const { expect, assert } = require("chai");
const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");
const { string } = require("hardhat/internal/core/params/argumentTypes");
const artifacts = require("../artifacts/contracts/BattleToken.sol/BattleToken.json");
const artifactsPH = require("../artifacts/contracts/NFT/PixelHeroes.sol/PixelHeroes.json");


const nfts = [
  '0xE72323d7900f26d13093CaFE76b689964Cc99ffc',
  '0xba6E421833F6C190a830Ce6E142685B3916c9BD0'
];

const chainid = [137, 137];

describe("Battle Token Test", function () {

  let admin, minter, user, user2, user3;
  let addr; //コントラクトアドレス
  let thisChainId;
  let idPHS, idPHX;

  it("Deploy contract", async function () { 
    [admin, minter, user, user2, user3] = await ethers.getSigners();
    const PHBTDepFactory = await ethers.getContractFactory('BattleToken');
    const PHBTDep = await PHBTDepFactory.deploy();
    let tx = await PHBTDep.deployTransaction;
    thisChainId = tx.chainId;
    console.log("        Chain ID : ", thisChainId);
    addr = PHBTDep.address;
    console.log("        PHBT Deplyed by :", tx.from);
    console.log("        PHBT Deplyed to :", PHBTDep.address);
  });

  it("Set minter role", async function () { 
    const PHBT = await new ethers.Contract(addr, artifacts.abi, admin);
    await PHBT.grantRole(await PHBT.MINTER_ROLE() ,minter.address);
  });

  it("Add 2 contracts by admin", async function () { 
    const PHBT = await new ethers.Contract(addr, artifacts.abi, admin);
    // tx => rc -> event
    let tx = await PHBT.addContract(nfts[0], chainid[0]);
    let reciept = await tx.wait();
    let event = reciept.events.find(event => event.event === 'AddContract');
    let [newId, contractInfo] = event.args;
    //console.log(newId, contractInfo.addr, contractInfo.chainId);
    expect(newId).to.equal(1);
    expect(await PHBT.totalInChains()).to.equal(0);
    tx = await PHBT.addContract(nfts[1], chainid[1]);
    reciept = await tx.wait();
    event = reciept.events.find(event => event.event === 'AddContract');
    [newId, contractInfo] = event.args;
    expect(newId).to.equal(2);
    expect(await PHBT.totalInChains()).to.equal(0);
  });

  it("Add a contract by user", async function () { 
    const PHBT = await new ethers.Contract(addr, artifacts.abi, user);
    try {
      await PHBT.addContract(nfts[0], chainid[0]);
    } catch(e) {
      expect(e).to.equal("AccessControl");
    }
  });


  it("Add the same contract by admin again", async function () { 
    const PHBT = await new ethers.Contract(addr, artifacts.abi, admin);
    try{
      await PHBT.addContract(nfts[0], chainid[0]);
    } catch(e) {
      expect(e).to.equal("cannot add contract");
    }
  });

  const amountMint = 0.1 * 10 ** 18;
  const CIDmint = 1;
  const TIDmint = 0;
  let nonce;

  it(`Mint token on ContractID: ${CIDmint}, TokenID: ${TIDmint}, Amount: ${amountMint/10**18}PHBT`, async function () { 
    const PHBT = await new ethers.Contract(addr, artifacts.abi, user);
    nonce = await PHBT.nonce(user.address);
    let sigfunc = await PHBT.SIG_MINT();

    let msg = 
      user.address.toLowerCase() + "|" +
      nonce.toString() + "|" + 
      CIDmint.toString() + "|" +
      TIDmint.toString() + "|" + 
      sigfunc + "|"
      + amountMint.toString()
    ;

    let msgContr = await PHBT._makeMessage(user.address,1,0,await PHBT.SIG_MINT(), amountMint.toString());
    //コントラクトから得られる署名と比較する。この関数はデバッグ中はpublicになっている
    expect(msg).to.equal(msgContr);

    console.log("        message for sign:", msg);
    let msgHash = ethers.utils.id(msg);
    let msgBytes = ethers.utils.arrayify(msgHash);
    signature = await minter.signMessage(msgBytes);

    await PHBT.mint(1, 0, amountMint.toString(), signature);
  });

  it(`Balance check : ${amountMint/10**18}PHBT`, async function () {
    const PHBT = await new ethers.Contract(addr, artifacts.abi, user);
    const retval = await PHBT.balanceById(CIDmint,TIDmint);
    const bnAmount = ethers.BigNumber.from(amountMint.toString());
    expect(await PHBT.balanceById(CIDmint,TIDmint)).to.equal(bnAmount);
  });
  it(`Nonce check of count up`, async function () {
    const PHBT = await new ethers.Contract(addr, artifacts.abi, user);
    expect(await PHBT.nonce(user.address)).to.equal(nonce.toNumber()+1);
  });

  const amountBurn = 0.04 * 10 ** 18;
  it(`Burn token on ContractID: ${CIDmint}, TokenID: ${TIDmint}, Amount: ${amountBurn/10**18}PHBT`, async function () { 
    const PHBT = await new ethers.Contract(addr, artifacts.abi, user);
    nonce = await PHBT.nonce(user.address);
    let sigfunc = await PHBT.SIG_BURN();

    let msg = 
      user.address.toLowerCase() + "|" +
      nonce.toString() + "|" + 
      CIDmint.toString() + "|" +
      TIDmint.toString() + "|" + 
      sigfunc + "|"
      + amountBurn.toString()
    ;

    let msgContr = await PHBT._makeMessage(user.address,1,0,sigfunc, amountBurn.toString());
    //コントラクトから得られる署名と比較する。この関数はデバッグ中はpublicになっている
    expect(msg).to.equal(msgContr);

    console.log("message for sign:", msg);
    let msgHash = ethers.utils.id(msg);
    let msgBytes = ethers.utils.arrayify(msgHash);
    signature = await minter.signMessage(msgBytes);

    await PHBT.burn(1, 0, amountBurn.toString(), signature);
  });

  it(`Balance check : ${(amountMint - amountBurn)/10**18}PHBT`, async function () {
    const PHBT = await new ethers.Contract(addr, artifacts.abi, user);
    const retval = await PHBT.balanceById(CIDmint,TIDmint);
    const bnAmount = ethers.BigNumber.from(amountMint.toString()).sub(ethers.BigNumber.from(amountBurn.toString()));
    expect(await PHBT.balanceById(CIDmint,TIDmint)).to.equal(bnAmount);
  });
  it(`Nonce check of count up`, async function () {
    const PHBT = await new ethers.Contract(addr, artifacts.abi, user);
    expect(await PHBT.nonce(user.address)).to.equal(nonce.toNumber()+1);
  });

//PHS, PHXを用意
  let addrPHS, addrPHX;
  it("Deploy the PH NFT contracts", async function () { 
    const PHFactory = await ethers.getContractFactory('PixelHeroes');
    const PHS = await PHFactory.deploy(
      "PixelHeroes",
      "PHS",
      "ipfs://QmTz7TZCApkDjxB8Wt7zNEVB5YHZCsZHh7mWdgqYiXS38n/",
      1000);
    let tx = await PHS.deployTransaction;
    await tx.wait();
    addrPHS = PHS.address;
    console.log("        PHS Deplyed by :", tx.from);
    console.log("        PHS Deplyed to :", addrPHS);
    console.log("        PHS maxSupply  :", await PHS.maxSupply().toString());
    const PHX = await PHFactory.deploy(
      "Pixel Heroes X",
      "PHX",
      "ipfs://QmTWewjSwE7wNPKpKHK1frmiCXXmkvsFpSx8Wk7ms1UwMC/",
      5555);
    tx = await PHX.deployTransaction;
    await tx.wait();
    addrPHX = PHX.address;
    console.log("        PHX Deplyed to :", addrPHX);
    console.log("        PHX maxSupply  :", await PHX.maxSupply().toString());
  });  

  it(`Mint PHSs`, async function () {
    const cost = 0.00001;
    let amount = 10;
    let fee = amount * cost + 1;
    const PHS1 = await new ethers.Contract(addrPHS, artifactsPH.abi, user);
    let overrides = {
      value: ethers.utils.parseEther(fee.toString())  //,
    };
    let tx = await PHS1.mint(amount, overrides);
    const PHS2 = await new ethers.Contract(addrPHS, artifactsPH.abi, user2);
    tx = await PHS2.mint(amount, overrides);
    const PHS3 = await new ethers.Contract(addrPHS, artifactsPH.abi, user3);
    tx = await PHS3.mint(amount, overrides);
    console.log("        PHS totalSupply:", await PHS3.totalSupply().toString());
  });

  it(`Mint PHXs`, async function () {
    const cost = 0.00001;
    let amount = 10;
    let fee = amount * cost + 1;
    let PHX = await new ethers.Contract(addrPHX, artifactsPH.abi, user);
    let overrides = {
      value: ethers.utils.parseEther(fee.toString())  //,
    };
    let tx = await PHX.mint(amount, overrides);
    await tx.wait()
    PHX = await new ethers.Contract(addrPHX, artifactsPH.abi, user2);
    tx = await PHX.mint(amount, overrides);
    await tx.wait()
    PHX = await new ethers.Contract(addrPHX, artifactsPH.abi, user3);
    tx = await PHX.mint(amount, overrides);
    await tx.wait()
    console.log("        PHX totalSupply:", await PHX.totalSupply().toString());
  });


  it(`Add PHS in PHBT`, async function(){
    const PHBT = await new ethers.Contract(addr, artifacts.abi, admin);
    let tx = await PHBT.addContract(addrPHS.toString(), thisChainId);
    await tx.wait();
    idPHS = await PHBT["contractId(address,uint256)"](addrPHS.toString(), thisChainId);
    console.log("        PHS ContractId:", idPHS.toString());
    tx = await PHBT.addContract(addrPHX.toString(), thisChainId);
    await tx.wait();
    idPHX = await PHBT["contractId(address,uint256)"](addrPHX.toString(), thisChainId);
    console.log("        PHX ContractId:", idPHX.toString());
    
  });

  const TID = [2,5,8,14,17];
  it(`Mint token on PHS , TokenID: ${TID}, Each Amount: ${amountMint/10**18}PHBT`, async function () { 

    const users = [user,user,user,user2, user2];
    let PHBT;
    let sigfunc, mgs, msgHash, msgBytes,signature;
    for (let i = 0 ; i < 5 ; i++ ) {
      PHBT = await new ethers.Contract(addr, artifacts.abi, users[i]);
      sigfunc = await PHBT.SIG_MINT();
        nonce = await PHBT.nonce(users[i].address);
      msg = 
        users[i].address.toLowerCase() + "|" +
        nonce.toString() + "|" + 
        idPHS.toString() + "|" +
        TID[i].toString() + "|" + 
        sigfunc + "|"
        + amountMint.toString()
      ;
      msgHash = ethers.utils.id(msg);
      msgBytes = ethers.utils.arrayify(msgHash);
      signature = await minter.signMessage(msgBytes);
      await PHBT.mint(idPHS, TID[i], amountMint.toString(), signature);
    }
    
    let ret;
    ret = await PHBT.balanceOf(user.address);
    ret = ret.div(BigNumber.from(10).pow(BigNumber.from(12))).toNumber()/(10**6);
    console.log("        PHS user1 balance: ", ret , "PHBT");
    ret = await PHBT.balanceOf(user2.address);
    ret = ret.div(BigNumber.from(10).pow(BigNumber.from(12))).toNumber()/(10**6);
    console.log("        PHS user2 balance: ", ret , "PHBT");

  });

});
