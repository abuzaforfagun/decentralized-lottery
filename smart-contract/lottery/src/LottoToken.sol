// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LottoToken is ERC20 {
    constructor(address owner, uint256 initialSupply) ERC20("Lotto", "LOT") {
        _mint(owner, initialSupply);
    }
}
