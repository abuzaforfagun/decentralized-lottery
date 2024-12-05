// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Lottery} from "../src/Lottery.sol";

contract HelperConfig is Script {
    uint96 public MOCK_BASE_FEE = 0.25 ether;
    uint96 public MOCK_GAS_PRICE_LINK = 1e9;
    // LINK / ETH price
    int256 public MOCK_WEI_PER_UINT_LINK = 4e15;

    uint256 private constant ENTRY_FEE = 0.001 ether;
    uint256 private constant INTERVAL_IN_SECONDS = 30;
    address private constant SEPOLIA_VRF_CORDINATOR =
        0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    bytes32 private constant KEY_HASH =
        0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint256 private constant SUBSCRIPTION_ID =
        6504699982786204825045679599031601495393816841262864436601874575408228222640;

    struct NetworkConfig {
        uint256 entryFee;
        uint256 intervalInSeconds;
        address vrfCoordinator;
        bytes32 keyHash;
        uint256 subscriptionId;
    }

    function getNetworkConfig(
        uint256 chainId
    ) public returns (NetworkConfig memory, Lottery) {
        // if (chainId == 11155111) {
        //     return getSepoliaConfig();
        // }

        return getOrCreateAnvilConfig();
    }

    function getSepoliaConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entryFee: ENTRY_FEE,
                intervalInSeconds: INTERVAL_IN_SECONDS,
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                subscriptionId: 6504699982786204825045679599031601495393816841262864436601874575408228222640
            });
    }

    function getOrCreateAnvilConfig()
        public
        returns (NetworkConfig memory, Lottery)
    {
        uint96 baseFee = 100000000000000;
        uint96 gasPriceLink = 10000000;
        int256 weiPerunitLink = 5007500000000000;

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorV2_5Mock = new VRFCoordinatorV2_5Mock(
                baseFee,
                gasPriceLink,
                weiPerunitLink
            );

        uint256 subscriptionId = vrfCoordinatorV2_5Mock.createSubscription();
        vrfCoordinatorV2_5Mock.fundSubscription(subscriptionId, 10 ether);
        // Deploy your Lottery contract
        Lottery lottery = new Lottery(
            ENTRY_FEE,
            INTERVAL_IN_SECONDS,
            address(vrfCoordinatorV2_5Mock),
            0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId
        );

        // Add the Lottery contract as a consumer
        vrfCoordinatorV2_5Mock.addConsumer(subscriptionId, address(lottery));
        vm.stopBroadcast();
        HelperConfig.NetworkConfig memory config = NetworkConfig({
            entryFee: ENTRY_FEE,
            intervalInSeconds: INTERVAL_IN_SECONDS,
            vrfCoordinator: address(vrfCoordinatorV2_5Mock),
            keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: subscriptionId
        });
        return (config, lottery);
    }
}
