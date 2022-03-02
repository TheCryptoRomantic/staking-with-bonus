const { expect } = require("chai");

const Staking = artifacts.require('Staking');
const Token = artifacts.require('TestToken');

const { web3 } = require('@openzeppelin/test-helpers/src/setup');
const { BN, expectRevert, time } = require('@openzeppelin/test-helpers');


const ZERO = new BN(0);
const ONE = new BN(1);
const TWO = new BN(2);
const THREE = new BN(3);
const FOUR = new BN(4);
const FIVE = new BN(5);
const TEN = new BN(10);
const DECIMALS = new BN(18);

const ETHER = TEN.pow(DECIMALS);

contract('Staking', ([deployer]) => {
    let staking, token;
    let stakingAddress, tokenAddress;
    let deposit;

    beforeEach(async () => {
        token = await Token.new({ from: deployer });
        tokenAddress = await token.address;

        staking = await Staking.new(tokenAddress, { from: deployer });
        stakingAddress = await staking.address;

        deposit = ETHER;
        await token.approve(stakingAddress, deposit, {from: deployer});
    });
    it("deposit test", async () => {
        const balanceBefore = await staking.getBalance({from: deployer});
        await staking.deposit(deposit, {from: deployer});
        const balanceAfter = await staking.getBalance({from: deployer});

        expect(balanceAfter.sub(balanceBefore).eq(deposit));
    });
    it("rewards and bonus calculating test", async () => {
        await time.advanceBlock()
        const testTime = await time.latest();
        await staking.deposit(deposit, {from: deployer});

        const multipier = ONE;
        const divisor = THREE;
        await staking.setRewardsFactor(multipier, divisor, {from: deployer});
        await staking.setBonusFactor(multipier, divisor, {from: deployer});

        await time.increaseTo(testTime.add(TEN));

        const rewards = await staking.getRewards({from: deployer});
        const bonus = await staking.getBonus({from: deployer});

        expect(rewards.eq(deposit.mul(TEN).mul(multipier).div(divisor)));
        expect(bonus.eq(deposit.mul(TEN).mul(multipier).div(divisor)));
    });
    it("withdraw test", async () => {
        const tokensBefore = await token.balanceOf(deployer);
        
        await staking.deposit(deposit, {from: deployer});

        await time.increase(TEN);

        const rewards = await staking.getRewards({from: deployer});

        const withdrawnTokens = deposit.div(TWO);

        await expectRevert (
            staking.withdraw(withdrawnTokens, {from: deployer}), 
            "revert"
        );

        await expectRevert (
            staking.withdrawRewardsFromPool(new BN(100), {from: deployer}), 
            "Insufficient rewards pool"
        );
        
        await token.approve(stakingAddress, rewards.mul(TWO), {from: deployer});
        await staking.addRewardsToPool(rewards.mul(TWO), {from: deployer}); 
        const toknesAfter = await token.balanceOf(deployer);
        
        await staking.withdraw(withdrawnTokens, {from: deployer}), 

        expect(toknesAfter.eq(tokensBefore.add(rewards).add(withdrawnTokens)));
    });
});