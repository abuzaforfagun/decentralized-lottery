// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Lottery} from "../src/Lottery.sol";

contract DeployLottery is Script {
    uint256 private constant ENTRY_FEE = 0.001 ether;
    uint256 private constant INTERVAL_IN_SECONDS = 10;

    Lottery public lottery;

    function run() public {
        vm.startBroadcast();

        lottery = new Lottery(ENTRY_FEE, INTERVAL_IN_SECONDS);

        vm.stopBroadcast();
    }
}
