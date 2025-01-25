// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Lottery} from "../src/Lottery.sol";
import {DeployLottery} from "../script/DeployLottery.s.sol";
import {VRFCoordinatorV2_5Mock} from "../mock/chainlink/VRFCoordinatorV2_5Mock.sol";

contract LotteryTest is Test {
    uint256 private constant ENTRY_FEE = 0.05 ether;
    uint256 private constant NUMBER_OF_PARTICIPANT_REQUIRE_TO_DRAW = 2;
    bytes32 private constant KEY_HASH =
        0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint256 private constant SUB_ID =
        6504699982786204825045679599031601495393816841262864436601874575408228222640;
    VRFCoordinatorV2_5Mock vrfCoordinatorV2_5Mock;

    Lottery public lottery;

    function setUp() public {
        uint96 baseFee = 1000000000000000;
        uint96 gasPriceLink = 50000000000;
        int256 weiPerunitLink = 10000000000000000;

        vrfCoordinatorV2_5Mock = new VRFCoordinatorV2_5Mock(
            baseFee,
            gasPriceLink,
            weiPerunitLink
        );
        uint256 subscriptionId = vrfCoordinatorV2_5Mock.createSubscription();
        vrfCoordinatorV2_5Mock.fundSubscription(subscriptionId, 10 ether);

        lottery = new Lottery(
            ENTRY_FEE,
            NUMBER_OF_PARTICIPANT_REQUIRE_TO_DRAW,
            address(vrfCoordinatorV2_5Mock),
            KEY_HASH,
            subscriptionId
        );

        vrfCoordinatorV2_5Mock.addConsumer(subscriptionId, address(lottery));
    }

    function test_join_InsufficiantFund() public {
        vm.deal(address(this), 1 ether);
        vm.expectRevert(Lottery.Lottery_InsufficiantFund.selector);

        lottery.join{value: 0.0000001 ether}();
    }

    function test_join_Lottery_StatusIsClosed() public {
        vm.deal(address(this), 1 ether);
        uint256 slot = 7;
        vm.store(
            address(lottery),
            bytes32(slot),
            bytes32(uint256(Lottery.Status.CLOSED))
        );

        vm.expectRevert(Lottery.Lottery_NotOpened.selector);

        lottery.join{value: ENTRY_FEE}();
    }

    function test_join_Lottery_StatusIsCalculating() public {
        vm.deal(address(this), 1 ether);
        uint256 slot = 7;
        vm.store(
            address(lottery),
            bytes32(slot),
            bytes32(uint256(Lottery.Status.CALCULATING))
        );

        vm.expectRevert(Lottery.Lottery_NotOpened.selector);

        lottery.join{value: ENTRY_FEE}();
    }

    function test_join_should_work() public {
        vm.deal(address(this), 1 ether);

        lottery.join{value: ENTRY_FEE}();

        assertEq(lottery.getTotalParticipants(), 1);
    }

    function test_declareWinner_StatusIsNotOnGoing() public {
        vm.deal(address(this), 1 ether);
        uint256 slot = 7;
        vm.store(
            address(lottery),
            bytes32(slot),
            bytes32(uint256(Lottery.Status.CALCULATING))
        );

        vm.warp(block.timestamp + 15);

        vm.expectRevert(Lottery.Lottery_InvalidState.selector);
        lottery.declareWinner();
    }

    function test_declareWinner_NoEnoughParticipants() public {
        vm.deal(address(this), 1 ether);

        vm.expectRevert(Lottery.Lottery_NotEnoughParticipants.selector);
        lottery.declareWinner();
    }

    function test_performUpkeep_shouldreturn_false_when_hasNoEnoughParticipants()
        public
    {
        address participant1 = address(0x123);
        vm.deal(participant1, 1 ether);
        vm.prank(participant1);

        lottery.join{value: ENTRY_FEE}();

        (bool upkeepNeeded, ) = lottery.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function test_performUpkeep_shouldreturn_true_when_hasEnoughParticipants()
        public
    {
        address participant1 = address(0x123);
        vm.deal(participant1, 1 ether);
        vm.prank(participant1);
        lottery.join{value: ENTRY_FEE}();

        address participant2 = address(0x124);
        vm.deal(participant2, 1 ether);
        vm.prank(participant2);
        lottery.join{value: ENTRY_FEE}();

        (bool upkeepNeeded, ) = lottery.checkUpkeep("");
        assert(upkeepNeeded);
    }

    function test_declareWinner_ShouldResetParticipants() public {
        address participant1 = address(0x123);
        vm.deal(participant1, 1 ether);
        vm.prank(participant1);
        lottery.join{value: ENTRY_FEE}();

        address participant2 = address(0x131);
        vm.deal(participant2, 1 ether);
        vm.prank(participant2);
        lottery.join{value: ENTRY_FEE}();
        uint256 requestId = lottery.declareWinner();
        vrfCoordinatorV2_5Mock.fulfillRandomWords(requestId, address(lottery));

        assertEq(0, lottery.getTotalParticipants());
    }

    function test_declareWinner_ShouldSendPrizeToWinner() public {
        address participant1 = address(0x123);
        vm.deal(participant1, 1 ether);
        vm.prank(participant1);
        lottery.join{value: ENTRY_FEE}();
        uint256 balanceOfParticipant1 = payable(participant1).balance;

        address participant2 = address(0x131);
        vm.deal(participant2, 1 ether);
        vm.prank(participant2);
        uint256 balanceOfParticipant2 = payable(participant2).balance -
            ENTRY_FEE;

        lottery.join{value: ENTRY_FEE}();
        uint256 requestId = lottery.declareWinner();
        vrfCoordinatorV2_5Mock.fulfillRandomWords(requestId, address(lottery));

        assert(
            payable(participant1).balance > balanceOfParticipant1 ||
                payable(participant2).balance > balanceOfParticipant2
        );
    }

    function test_declareWinner_ShouldStoreLastRoundWinner() public {
        address participant1 = address(0x123);
        vm.deal(participant1, 1 ether);
        vm.prank(participant1);
        lottery.join{value: ENTRY_FEE}();

        address participant2 = address(0x131);
        vm.deal(participant2, 1 ether);
        vm.prank(participant2);
        lottery.join{value: ENTRY_FEE}();
        uint256 requestId = lottery.declareWinner();
        vrfCoordinatorV2_5Mock.fulfillRandomWords(requestId, address(lottery));

        assertEq(0, lottery.getTotalParticipants());
        address lastRoundWinner = lottery.getLastRoundWinner();
        assert(
            lastRoundWinner == participant1 || lastRoundWinner == participant2
        );
    }

    function test_performUpkeep_should_not_call_declareWinner_when_hasNoEnoughParticipants()
        public
    {
        address participant1 = address(0x123);
        vm.deal(participant1, 1 ether);
        vm.prank(participant1);
        lottery.join{value: ENTRY_FEE}();

        lottery.performUpkeep("");

        assertEq(0, lottery.getVrfRequestId());
    }

    function test_performUpkeep_should_call_declareWinner_when_hasEnoughParticipants()
        public
    {
        address participant1 = address(0x123);
        vm.deal(participant1, 1 ether);
        vm.prank(participant1);
        lottery.join{value: ENTRY_FEE}();

        address participant2 = address(0x122);
        vm.deal(participant2, 1 ether);
        vm.prank(participant2);
        lottery.join{value: ENTRY_FEE}();

        lottery.performUpkeep("");

        assert(lottery.getVrfRequestId() > 0);
    }
}
