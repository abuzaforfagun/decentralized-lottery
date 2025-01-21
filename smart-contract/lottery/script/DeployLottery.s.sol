// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Lottery} from "../src/Lottery.sol";
import {VRFCoordinatorV2_5Mock} from "../mock/chainlink/VRFCoordinatorV2_5Mock.sol";

contract DeployLottery is Script {
    uint256 private constant ENTRY_FEE = 0.001 ether;
    uint256 private constant NUMBER_OF_PARTICIPANTS_REQUIRE_TO_DRAW = 3;

    Lottery public lottery;

    function run() public returns (Lottery) {
        uint96 baseFee = 1000000000000000;
        uint96 gasPriceLink = 50000000000;
        int256 weiPerunitLink = 10000000000000000;

        address vrfCoordinatorAddress = vm.envAddress("VRF_COORDINATOR");
        bytes32 keyHash = vm.envBytes32("KEY_HASH");
        uint256 subId = vm.envUint("SUB_ID");

        vm.startBroadcast();

        if (block.chainid == 31337) {
            VRFCoordinatorV2_5Mock vrfCoordinatorV2_5Mock = new VRFCoordinatorV2_5Mock(
                    baseFee,
                    gasPriceLink,
                    weiPerunitLink
                );
            uint256 subscriptionId = vrfCoordinatorV2_5Mock
                .createSubscription();
            vrfCoordinatorV2_5Mock.fundSubscription(subscriptionId, 10 ether);

            lottery = new Lottery(
                ENTRY_FEE,
                NUMBER_OF_PARTICIPANTS_REQUIRE_TO_DRAW,
                address(vrfCoordinatorV2_5Mock),
                keyHash,
                subscriptionId
            );

            vrfCoordinatorV2_5Mock.addConsumer(
                subscriptionId,
                address(lottery)
            );
        } else {
            lottery = new Lottery(
                ENTRY_FEE,
                NUMBER_OF_PARTICIPANTS_REQUIRE_TO_DRAW,
                vrfCoordinatorAddress,
                keyHash,
                subId
            );
        }

        vm.stopBroadcast();

        return lottery;
    }
}
