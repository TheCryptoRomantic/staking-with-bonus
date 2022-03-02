// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Staking is Ownable {
  constructor(address _token) {
    token = ERC20(_token);
  }

  ERC20 token;

  uint rewardsPool = 0;

  //частное и знаменатель в множителе награды
  uint rewardsMultiplier = 1;
  uint rewardsDivisor = 10;

  //частное и знаменатель в множителе бонуса
  uint bonusMultiplier = 1;
  uint bonusDivisor = 10;

  bool isContractLocked = false;

  struct Balance {
    uint amount;
    uint time;
    uint withdrawnRewards;
    uint writeOffedBonus;
  }

  mapping (address => Balance) private balances;

  modifier notZero(uint _amount) {
    require(_amount != 0, "Can't transfer zero tokens");
    _;
  }

  modifier lockable() {
    require(!isContractLocked, "Contract is locked for transactoins");
    _;
  }

  event Deposit(address user, uint amount);
  event Withdraw(address user, uint amount);
  event WriteOffBonus(address user, uint amount);
  event WithdrawRewards(address user, uint amount);

  function deposit(uint _amount) external notZero(_amount) lockable {
    balances[msg.sender].time = block.timestamp; 
    balances[msg.sender].amount += _amount;
    _deposit(_amount);
    if (getBonus() != 0 && getRewards() != 0) {
        _resetRewardsAndBonus();
    }
  }

  function withdraw(uint _amount) public lockable {
    require(balances[msg.sender].amount >= _amount, "Insufficient balance");
    _withdraw(_amount);
    _resetRewardsAndBonus();
  }

  function withdrawAll() external {
    withdraw(balances[msg.sender].amount);
  }

  function getBalance() public view returns(uint) {
    return balances[msg.sender].amount;
  }

  function getBonus() public view returns(uint) {
    Balance memory currentBalance = balances[msg.sender];
    return currentBalance.amount * (block.timestamp - currentBalance.time) * bonusMultiplier / bonusDivisor - balances[msg.sender].writeOffedBonus;
  }

  function writeOffBonus(uint _amount) public {
    require(getBonus() - _amount >= 0, "Insufficient bonus");
    balances[msg.sender].writeOffedBonus += _amount;
    emit WriteOffBonus(msg.sender, _amount);
  }

  function writeOffBonusFull() public {
    writeOffBonus(getBonus());
  }

  function getRewards() public view returns(uint){
    Balance memory currentBalance = balances[msg.sender];
    return currentBalance.amount * (block.timestamp - currentBalance.time) * rewardsMultiplier / rewardsDivisor - balances[msg.sender].withdrawnRewards;
  }

  function withdrawRewards(uint _amount) public {
    require(getRewards() - _amount >= 0, "Insufficient rewards");
    require(rewardsPool - _amount >= 0, "Insufficient rewards pool");
    _withdraw(_amount);
    balances[msg.sender].withdrawnRewards += _amount;
    rewardsPool -= _amount;
    emit WithdrawRewards(msg.sender, _amount);
  }

  function withdrawAllRewards() public {
    withdrawRewards(getRewards());
  }
  
  function _resetRewardsAndBonus() private {
    writeOffBonusFull();
    balances[msg.sender].writeOffedBonus = 0;

    withdrawAllRewards();
    balances[msg.sender].withdrawnRewards = 0;
  }
  

  function _withdraw(uint _amount) private notZero(_amount) {
    require(token.balanceOf(address(this)) >= _amount, "Insufficient balance");
    require(token.transfer(msg.sender, _amount), "Failed to withdraw tokens");
    emit Withdraw(msg.sender, _amount);
  }

  function _deposit(uint _amount) private notZero(_amount) {
    uint currentAllowance = token.allowance(msg.sender, address(this));
    require(currentAllowance >= _amount, "Insufficient allowance");
    require(token.transferFrom(msg.sender, address(this), _amount), "Failed to deposit tokens");
    emit Deposit(msg.sender, _amount);
  }

  //FOR OWNER--------------------------------------------------

  /**
  * @dev lock contract for deposit and withdraw
  */
  function lockContract() external onlyOwner{
    require(!isContractLocked, "Contract is also locked");
    isContractLocked = true;
  }

  /**
  * @dev unlock contract for deposit and withdraw
  */
  function unlockContract() external onlyOwner{
    require(isContractLocked, "Contract is also unlocked");
    isContractLocked = false;
  }

  /**
  * @dev set address of staked token
  */
  function setToken(address _token) external onlyOwner {
    token = ERC20(_token);
  }

  /**
  * @dev change factor for rewards
  */
  function setRewardsFactor(uint _multiplier, uint _divisor) external onlyOwner {
    rewardsMultiplier = _multiplier;
    rewardsDivisor = _divisor;

  }

  /**
  * @dev change factor for bonus
  */
  function setBonusFactor(uint _multiplier, uint _divisor) external onlyOwner {
    bonusMultiplier = _multiplier;
    bonusDivisor = _divisor;
  }

  /**
  * @dev add rewards to pool
  */
  function addRewardsToPool(uint _amount) external onlyOwner {
    rewardsPool += _amount;
    _deposit(_amount);
  }

  /**
  * @dev withdraw rewards from pool
  */
  function withdrawRewardsFromPool(uint _amount) external onlyOwner {
    require(rewardsPool >= _amount, "Insufficient rewards pool");
    _withdraw(_amount);
  }
}
