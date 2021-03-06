// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Staking is Ownable, ReentrancyGuard {
  constructor(address _token) {
    token = ERC20(_token);
  }

  ERC20 public token;

  uint public rewardsPool = 0;

  //частное и знаменатель в множителе награды
  uint private rewardsMultiplier = 1;
  uint private rewardsDivisor = 1000;

  //частное и знаменатель в множителе бонуса 
  uint private bonusMultiplier = 1;
  uint private bonusDivisor = 1000;

  bool public isContractLocked = false;

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

  /**
  * @dev deposit tokens for stake them. If the user had rewards, they are transfered on his address.
  * @param _amount amount of tokens
  */
  function deposit(uint _amount) external notZero(_amount) lockable nonReentrant {
    _resetRewardsAndBonus();
    _deposit(_amount);
    balances[msg.sender].time = block.timestamp; 
    balances[msg.sender].amount += _amount;
    
  }

  /**
  * @dev withdraw tokens from stake. If the user had rewards, they are transfered on his address.
  * @param _amount amount of tokens
  */
  function withdraw(uint _amount) external lockable nonReentrant notZero(_amount) {
    _withdrawBalance(_amount);
  }

  /**
  * @dev withdraw all tokens from stake. If the user had rewards, they are transfered on his address.
  */
  function withdrawAll() external lockable nonReentrant{
    _withdrawBalance(balances[msg.sender].amount);
  }

  /**
  * @dev get stake balance of user
  */
  function getBalance(address _user) external view returns(uint) {
    return balances[_user].amount;
  }

  /**
  * @dev get bonus of user
  */
  function getBonus(address _user) public view returns(uint) {
    Balance memory currentBalance = balances[_user];
    uint elapsedTime = block.timestamp - currentBalance.time;
    return currentBalance.amount * elapsedTime * bonusMultiplier / bonusDivisor - currentBalance.writeOffedBonus;
  }

  /**
  * @dev get rewards of user
  */
  function getRewards(address _user) public view returns(uint){
    Balance memory currentBalance = balances[_user];
    uint elapsedTime = block.timestamp - currentBalance.time;
    return currentBalance.amount * elapsedTime * rewardsMultiplier / rewardsDivisor - currentBalance.withdrawnRewards;
  }

  /**
  * @dev write off bonus of msg.sender
  * @param _amount amount of bonuses
  */
  function writeOffBonus(uint _amount) external nonReentrant notZero(_amount){
    _writeOffBonus(_amount);
  }

  /**
  * @dev write off all bonus of msg.sender
  */
  function writeOffBonusFull() external nonReentrant {
    _writeOffBonus(getBonus(msg.sender));
  }


  /**
  * @dev withdraw rewards of msg.sender
  * @param _amount amount of rewards
  */

  function withdrawRewards(uint _amount) external nonReentrant notZero(_amount){
    _withdrawRewards(_amount);
  }

  /**
  * @dev withdraw all rewards of msg.sender
  */
  function withdrawAllRewards() external nonReentrant{
    _withdrawRewards(getRewards(msg.sender));
  }

  function _writeOffBonus(uint _amount) private {
    require(getBonus(msg.sender) >= _amount, "Insufficient bonus");
    balances[msg.sender].writeOffedBonus += _amount;
    emit WriteOffBonus(msg.sender, _amount);
  }
  
  function _withdrawRewards(uint _amount) private {
    require(getRewards(msg.sender) >= _amount, "Insufficient rewards");
    require(rewardsPool >= _amount , "Insufficient rewards pool");
    _withdraw(_amount);
    balances[msg.sender].withdrawnRewards += _amount;
    rewardsPool -= _amount;
    emit WithdrawRewards(msg.sender, _amount);
  }

  function _resetRewardsAndBonus() private {
    uint bonus = getBonus(msg.sender);
    uint rewards = getRewards(msg.sender);
    if (bonus != 0) {
        _writeOffBonus(bonus);
        balances[msg.sender].writeOffedBonus = 0;
    }

    if (rewards != 0) {
        _withdrawRewards(rewards);
        balances[msg.sender].withdrawnRewards = 0;
    }
    
  }
  
  function _withdrawBalance(uint _amount) private {
    require(balances[msg.sender].amount >= _amount, "Insufficient balance");
    _resetRewardsAndBonus();
    _withdraw(_amount);
    balances[msg.sender].time = block.timestamp; 
    balances[msg.sender].amount -= _amount;
  }


  function _withdraw(uint _amount) private {
    require(token.balanceOf(address(this)) >= _amount, "Insufficient tokens on the contract");
    require(token.transfer(msg.sender, _amount), "Failed to withdraw tokens");
    emit Withdraw(msg.sender, _amount);
  }

  function _deposit(uint _amount) private {
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
    require(!isContractLocked, "Contract is locked");
    isContractLocked = true;
  }

  /**
  * @dev unlock contract for deposit and withdraw
  */
  function unlockContract() external onlyOwner{
    require(isContractLocked, "Contract is unlocked");
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
