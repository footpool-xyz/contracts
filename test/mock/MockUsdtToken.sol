// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUsdtToken is ERC20 {
    constructor () ERC20("Tether token", "USDT") {
        _mint(msg.sender, 100000000000000000000);
    }

    function mint(address to) external {
        // 100 Tokens
        _mint(to, 100000000000000000000); 
    }
}
