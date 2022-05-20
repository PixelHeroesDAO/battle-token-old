const { expect } = require("chai");
const { ethers } = require("hardhat");
const { string } = require("hardhat/internal/core/params/argumentTypes");
const artifacts = require("../artifacts/contracts/BattleToken.sol/BattleToken.json");


const nfts = [
  '0xE72323d7900f26d13093CaFE76b689964Cc99ffc',
  '0xba6E421833F6C190a830Ce6E142685B3916c9BD0'
];

const chainid = [137, 137];

let cont;

describe("Battle Token Test", function () {
  let admin, minter, user ;

  it("Deploy contract", async function () { 
    [admin, minter, user] = await ethers.getSigners();
    const BTFactory = await ethers.getContractFactory('BattleToken');
    const PHBT = await BTFactory.deploy();
    let tx = await PHBT.deployTransaction;
    cont = PHBT.address;
    console.log("Deplyed by :", tx.from);
    console.log("Deplyed to :", PHBT.address);
  });

  it("Set minter role", async function () { 
    const PHBT = await new ethers.Contract(cont, artifacts.abi, admin);
    await PHBT.grantRole(await PHBT.MINTER_ROLE() ,minter.address);
  });

  it("Add 2 contracts", async function () { 
    const PHBT = await new ethers.Contract(cont, artifacts.abi, admin);
    await PHBT.addContract(nfts[0], chainid[0]);
    expect(await PHBT.totalContracts()).to.equal(1);
    expect(await PHBT.totalInChains()).to.equal(0);
    await PHBT.addContract(nfts[1], chainid[1]);
    expect(await PHBT.totalContracts()).to.equal(2);
    expect(await PHBT.totalInChains()).to.equal(0);
  });

  it("Add contract by user : error has to be occured", async function () { 
    const PHBT = await new ethers.Contract(cont, artifacts.abi, user);
    await PHBT.addContract(nfts[0], chainid[0]);
  });


  it("Add contract again : error has to be occured", async function () { 
    const PHBT = await new ethers.Contract(cont, artifacts.abi, admin);
    await PHBT.addContract(nfts[0], chainid[0]);
  });

  it("Mint token", async function () { 
    const PHBT = await new ethers.Contract(cont, artifacts.abi, user);
    const nonce = await PHBT.nonce(user.address);
    const amount = 1000000;
    let sigfunc = await PHBT.SIG_MINT();

    let msg = user.address.toLowerCase()+"|"+nonce.toString()+"|"+"1"+"|"+"0"+"|"+sigfunc+"|"+amount.toString();
    console.log("msg:", msg);
    let msgHash = ethers.utils.id(msg);
    let msgBytes = ethers.utils.arrayify(msgHash);
    signature = await minter.signMessage(msgBytes);

    let msgContr = await PHBT._makeMessage(user.address,1,0,await PHBT.SIG_MINT(), amount.toString());
    await PHBT._mint(1, 0, amount.toString(), signature);
    expect(await PHBT.balanceById(1,0)).to.equal(amount);
  });


});
