const { ethers } = require('hardhat');
const { BigNumber } = require('ethers');

const deployContract = async function (contractName, constructorArgs) {
  let factory;
  factory = await ethers.getContractFactory(contractName);
  let contract = await factory.deploy(...(constructorArgs || []));
  await contract.deployed();
  return contract;
};

const makeMessage = function(addr, nonce, cid, tid, exp, lv, status){
  let msg = String(addr).toLowerCase() + "|" +
  String(nonce) + "|" +
  String(cid) + "|" +
  String(tid) + "|" +
  String(exp) + "|" +
  String(lv);
  for (let i = 0 ; i < 11 ; i++){
    if (i < status.length) {
      msg = msg + "|" + String(status[i]); 
    }else{
      msg = msg + "|0"; 
    }
  }
  return msg;
}

const makeMessageBytes = function(addr, nonce, cid, tid, exp, lv, status) {
  return ethers.utils.arrayify(ethers.utils.id(makeMessage(addr, nonce, cid, tid, exp, lv, status)));
}

module.exports = { deployContract, makeMessage, makeMessageBytes};