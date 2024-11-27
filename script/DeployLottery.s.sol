// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {Lottery} from "../src/Lottery.sol";

contract DeployLottery is Script {
    uint256 private constant ENTRY_FEE = 0.001 ether;
    uint256 private constant INTERVAL_IN_SECONDS = 120;

    function run() public returns (Lottery) {
        vm.startBroadcast();
        Lottery lottery = new Lottery(ENTRY_FEE, INTERVAL_IN_SECONDS);
        vm.stopBroadcast();

        return lottery;
    }
}
