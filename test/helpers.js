const { ethers } = require('hardhat');
const { BigNumber } = require('ethers');

const deployContract = async function (contractName, constructorArgs) {
  let factory;
  factory = await ethers.getContractFactory(contractName);
  let contract = await factory.deploy(...(constructorArgs || []));
  await contract.deployed();
  return contract;
};

const makeMessage = function(addr, nonce, timestamp, cid, tid, exp, lv, status){
  let msg = String(addr).toLowerCase() + "|" +
  String(nonce) + "|" +
  String(timestamp) + "|" +
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

const makeMessageBytes = function(addr, nonce, timestamp, cid, tid, exp, lv, status) {
  return ethers.utils.arrayify(ethers.utils.id(makeMessage(addr, nonce, timestamp, cid, tid, exp, lv, status)));
}
const makeMsgExp = function(addr, nonce, timestamp, cid, tid, dExp, inc){
  let sgn = "+";
  if (!inc) sgn = "-";
  let msg = String(addr).toLowerCase() + "|" +
  String(nonce) + "|" +
  String(timestamp) + "|" +
  String(cid) + "|" +
  String(tid) + "|" +
  sgn + String(dExp)
  return msg;
}

const makeMsgExpBytes = function(addr, nonce, timestamp, cid, tid, dExp, inc) {
  return ethers.utils.arrayify(ethers.utils.id(makeMsgExp(addr, nonce, timestamp, cid, tid, dExp, inc)));
}



//DateオブジェクトからUNIX epoch(秒単位)に変換する
function Date2UnixTimestamp(date){
  let uts = date.getTime(date);
  return Math.floor(uts / 1000);
}

//UNIX epoch(秒単位)をdateオブジェクトに変換する
function UnixTimestamp2Date(uts){
  return new Date(uts*1000);
}

const helpers={
  deployContract : deployContract,
  Message : makeMessage,
  MessageBytes : makeMessageBytes,
  MsgExp : makeMsgExp,
  MsgExpBytes : makeMsgExpBytes,
  Date2UnixTimestamp : Date2UnixTimestamp,
  UnixTimestamp2Date : UnixTimestamp2Date
}

//module.exports = { deployContract, makeMessage, makeMessageBytes};
module.exports = { helpers };
