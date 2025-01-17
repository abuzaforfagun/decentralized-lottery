// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Lottery} from "../src/Lottery.sol";

contract DeployLottery is Script {
    uint256 private constant ENTRY_FEE = 0.001 ether;
    uint256 private constant NUMBER_OF_PARTICIPANTS_REQUIRE_TO_DRAW = 10;

    Lottery public lottery;

    function run() public {
        vm.startBroadcast();

        lottery = new Lottery(ENTRY_FEE, NUMBER_OF_PARTICIPANTS_REQUIRE_TO_DRAW);

        vm.stopBroadcast();
    }
}
