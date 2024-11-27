// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

event EnterParticipant(address participant);
event DisbursePayment(address winner, address )

error Lottery__InsufficiantFund();
error Lottery__InvalidState();
error Lottery__PaymentFaild();

contract Lottery {
    struct winner {
        address participant;
        uint time;
        uint256 prize;
        uint256 gasCost;
        uint256 platformCommission;
    }

    address payable[] private s_participantes;
    winner[] private s_winners;
    uint private s_lastRoundStartedAt;

    uint256 private immutable i_entryFee;
    uint private i_intervalInSeconds;
    uint private constant ESTIMATED_GAS_UNIT = 100000;
    uint256 private constant PLATFORM_COMMISSION_IN_PERCENTAGE = 5;

    constructor(uint256 entryFee, uint256 intervalInSeconds) {
        i_entryFee = entryFee;
        i_intervalInSeconds = intervalInSeconds;
        s_lastRoundStartedAt = block.timestamp;
    }

    function enter() external payable {
        if (msg.value < i_entryFee) {
            revert Lottery__InsufficiantFund();
        }

        s_participantes.push(payable(msg.sender));
        emit EnterParticipant(msg.sender);
    }

    function declareWinner() external payable {
        if (block.timestamp - s_lastRoundStartedAt < i_intervalInSeconds) {
            revert Lottery__InvalidState();
        }

        // get random number
        // find out mod of random number and total participants.
        uint estimatedGasCost = ESTIMATED_GAS_UNIT * tx.gasprice;
        uint256 platformCommission = (address(this).balance * PLATFORM_COMMISSION_IN_PERCENTAGE)/100;
        uint256 winningPrize = address(this).balance - estimatedGasCost - platformCommission;
        (bool success, ) = s_participantes[0].call{
            value: winningPrize
        }("");
        if (!success) {
            revert Lottery__PaymentFaild();
        }
    }
}
