const Staking = artifacts.require("Staking");
const Token = artifacts.require("TestToken");

module.exports = async (deployer) => {
  await deployer.deploy(Token);
  const tokenInstance = await Token.deployed();
  const tokenAddress = await tokenInstance.address;

  deployer.deploy(Staking, tokenAddress);
};
