// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Lottery} from "../src/Lottery.sol";
import {VRFCoordinatorV2_5Mock} from "../mock/chainlink/VRFCoordinatorV2_5Mock.sol";

contract DeployLottery is Script {
    uint256 private constant ENTRY_FEE = 0.001 ether;
    uint256 private constant NUMBER_OF_PARTICIPANTS_REQUIRE_TO_DRAW = 3;
    address private constant VRF_COORDINATOR =
        0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    bytes32 private constant KEY_HASH =
        0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint256 private constant SUB_ID =
        6504699982786204825045679599031601495393816841262864436601874575408228222640;

    Lottery public lottery;

    function run() public returns (Lottery) {
        uint96 baseFee = 1000000000000000;
        uint96 gasPriceLink = 50000000000;
        int256 weiPerunitLink = 10000000000000000;

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
                KEY_HASH,
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
                VRF_COORDINATOR,
                KEY_HASH,
                SUB_ID
            );
        }

        vm.stopBroadcast();

        return lottery;
    }
}
