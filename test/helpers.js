const { ethers } = require('hardhat');
const { BigNumber } = require('ethers');

const deployContract = async function (contractName, constructorArgs) {
  let factory;
  factory = await ethers.getContractFactory(contractName);
  let contract = await factory.deploy(...(constructorArgs || []));
  await contract.deployed();
  return contract;
};

module.exports = { deployContract};