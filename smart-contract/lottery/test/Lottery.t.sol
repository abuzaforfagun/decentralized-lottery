// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Lottery} from "../src/Lottery.sol";

contract LotteryTest is Test {
    uint256 private constant ENTRY_FEE = 0.05 ether;
    uint256 private constant NUMBER_OF_PARTICIPANT_REQUIRE_TO_DRAW = 2;
    Lottery public lottery;

    function setUp() public {
        lottery = new Lottery(ENTRY_FEE, NUMBER_OF_PARTICIPANT_REQUIRE_TO_DRAW);
    }

    function test_join_InsufficiantFund() public {
        vm.deal(address(this), 1 ether);
        vm.expectRevert(Lottery.Lottery_InsufficiantFund.selector);

        lottery.join{value: 0.0000001 ether}();
    }

    function test_join_Lottery_StatusIsClosed() public {
        vm.deal(address(this), 1 ether);
        uint256 slot = 4;
        vm.store(address(lottery), bytes32(slot), bytes32(uint256(Lottery.Status.CLOSED)));

        vm.expectRevert(Lottery.Lottery_NotOpened.selector);

        lottery.join{value: ENTRY_FEE}();
    }

    function test_join_Lottery_StatusIsCalculating() public {
        vm.deal(address(this), 1 ether);
        uint256 slot = 4;
        vm.store(address(lottery), bytes32(slot), bytes32(uint256(Lottery.Status.CALCULATING)));

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
        uint256 slot = 4;
        vm.store(address(lottery), bytes32(slot), bytes32(uint256(Lottery.Status.CALCULATING)));

        vm.warp(block.timestamp + 15);

        vm.expectRevert(Lottery.Lottery_InvalidState.selector);
        lottery.declareWinner();
    }

    function test_declareWinner_NoEnoughParticipants() public {
        vm.deal(address(this), 1 ether);

        vm.expectRevert(Lottery.Lottery_NotEnoughParticipants.selector);
        lottery.declareWinner();
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
        uint256 balanceOfParticipant2 = payable(participant2).balance - ENTRY_FEE;
        lottery.join{value: ENTRY_FEE}();

        assert(
            payable(participant1).balance > balanceOfParticipant1
                || payable(participant2).balance > balanceOfParticipant2
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

        assertEq(0, lottery.getTotalParticipants());
        address lastRoundWinner = lottery.getLastRoundWinner();
        assert(lastRoundWinner == participant1 || lastRoundWinner == participant2);
    }
}
