// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20("Good Game Token", "GGT") {
    constructor() {
        _mint(msg.sender, 1e23);
    }
    
    function mintFor(address user, uint256 amount) public {
        _mint(user, amount);
    }

    function mint(uint256 amount) public {
        _mint(msg.sender, amount);
    }
}
