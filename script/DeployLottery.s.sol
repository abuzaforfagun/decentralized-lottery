// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {Lottery} from "../src/Lottery.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployLottery is Script {
    function run() public returns (Lottery) {
        HelperConfig helperConfig = new HelperConfig();
        (
            HelperConfig.NetworkConfig memory config,
            Lottery lottery
        ) = helperConfig.getNetworkConfig(31337);

        console.log("VRF Coordinator from deploy: %s", config.vrfCoordinator);

        // vm.startBroadcast();
        // Lottery lottery = new Lottery(
        //     config.entryFee,
        //     config.intervalInSeconds,
        //     config.vrfCoordinator,
        //     config.keyHash,
        //     config.subscriptionId
        // );
        // vm.stopBroadcast();

        return lottery;
    }
}
