const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const { string } = require("hardhat/internal/core/params/argumentTypes");
const artifacts = require("../artifacts/contracts/BattleToken.sol/BattleToken.json");


const nfts = [
  '0xE72323d7900f26d13093CaFE76b689964Cc99ffc',
  '0xba6E421833F6C190a830Ce6E142685B3916c9BD0'
];

const chainid = [137, 137];

describe("Battle Token Test", function () {

  let admin, minter, user;
  let addr; //コントラクトアドレス

  it("Deploy contract", async function () { 
    [admin, minter, user] = await ethers.getSigners();
    const PHBTDepFactory = await ethers.getContractFactory('BattleToken');
    const PHBTDep = await PHBTDepFactory.deploy();
    let tx = await PHBTDep.deployTransaction;
    addr = PHBTDep.address;
    console.log("Deplyed by :", tx.from);
    console.log("Deplyed to :", PHBTDep.address);
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

    console.log("message for sign:", msg);
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


});
