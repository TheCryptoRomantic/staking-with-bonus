const Staking = artifacts.require("Staking");
const Token = artifacts.require("TestToken");

let tokenAddress;
module.exports = async (deployer) => {
  await deployer.deploy(Token);
  const tokenInstance = await Token.deployed();
  tokenAddress = await tokenInstance.address;
  await deployer.deploy(Staking, tokenAddress);
  
};