// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MUSDT is ERC20 {
    constructor() ERC20("MUSDT", "MUSDT") {
        _mint(msg.sender, 10000_000_000 * 1e18);
    }
}
