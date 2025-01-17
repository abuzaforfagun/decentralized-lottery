// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

contract Lottery {
    error Lottery_InsufficiantFund();
    error Lottery_NotOpened();
    error Lottery_InvalidState();
    error Lottery_PaymentFailed();
    error Lottery_NoParticipants();

    enum Status {
        ONGOING,
        CALCULATING,
        CLOSED
    }

    address[] private s_participantes;
    address private s_lastRoundWinner;
    address private s_owner;
    uint256 private s_lastRoundStartedAt;
    Status private s_lotteryStatus;

    uint256 private immutable i_entryFee;
    uint256 private immutable i_intervalInSeconds;

    uint256 private constant PLATFORM_COMMISION_IN_PERCENTAGE = 5;

    constructor(uint256 entryFee, uint256 intervalInSeconds) {
        i_entryFee = entryFee;
        i_intervalInSeconds = intervalInSeconds;
        s_lastRoundStartedAt = block.timestamp;
        s_owner = msg.sender;
        s_lotteryStatus = Status.ONGOING;
    }

    function status() external view returns (Status) {
        return s_lotteryStatus;
    }

    function getLastRoundStarted() external view returns (uint256) {
        return s_lastRoundStartedAt;
    }

    function getTotalParticipants() external view returns (uint256) {
        return s_participantes.length;
    }

    function getLastRoundWinner() external view returns (address) {
        return s_lastRoundWinner;
    }

    function join() external payable {
        if (msg.value < i_entryFee) {
            revert Lottery_InsufficiantFund();
        }

        if (s_lotteryStatus != Status.ONGOING) {
            revert Lottery_NotOpened();
        }

        s_participantes.push(msg.sender);
    }

    function declareWinner() external payable {
        if (block.timestamp - s_lastRoundStartedAt < i_intervalInSeconds) {
            revert Lottery_InvalidState();
        }

        if (s_lotteryStatus != Status.ONGOING) {
            revert Lottery_InvalidState();
        }

        if (s_participantes.length == 0) {
            revert Lottery_NoParticipants();
        }

        s_lotteryStatus = Status.CALCULATING;

        //TODO: Use VRF of chainlink
        uint256 winnerIndex = s_participantes.length / 2;

        s_lastRoundWinner = s_participantes[winnerIndex];

        uint256 platformComision = (address(this).balance * PLATFORM_COMMISION_IN_PERCENTAGE) / 100;
        uint256 winningPrize = address(this).balance - platformComision;

        (bool success,) = s_lastRoundWinner.call{value: winningPrize}("");

        if (!success) {
            revert Lottery_PaymentFailed();
        }
        s_participantes = new address[](0);
        s_lotteryStatus = Status.ONGOING;
    }
}
