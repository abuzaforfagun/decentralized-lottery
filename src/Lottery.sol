// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

event EnterParticipant(address indexed participant);
event DeclaredWinner(address indexed winner, uint256 indexed prizeMoney);

error Lottery__InsufficiantFund();
error Lottery__InvalidState();
error Lottery__PaymentFaild();
error Lottery__InvalidOperation();
error Lottery__NotOpen();
error Lottery__UnAuthorized();

contract Lottery {
    
    address private s_owner;
    struct winner {
        address participant;
        uint time;
        uint256 prize;
        uint256 platformCommission;
    }

    enum Status {
        ONGOING, CALCULATING, CLOSED
    }

    address payable[] private s_participantes;
    winner[] private s_winners;
    uint private s_lastRoundStartedAt;

    uint256 private immutable i_entryFee;
    uint private i_intervalInSeconds;
    uint private constant ESTIMATED_GAS_UNIT = 100000;
    uint256 private constant PLATFORM_COMMISSION_IN_PERCENTAGE = 5;
    uint256 private constant NUMBER_OF_ROUNDS_REQUIRE_TO_WITHDRAW = 10;
    Status private s_lotteryStatus; 

    constructor(uint256 entryFee, uint256 intervalInSeconds) {
        i_entryFee = entryFee;
        i_intervalInSeconds = intervalInSeconds;
        s_lastRoundStartedAt = block.timestamp;
        s_lotteryStatus = Status.ONGOING;
        owner = msg.sender;
    }

    function enter() external payable {
        if (msg.value < i_entryFee) {
            revert Lottery__InsufficiantFund();
        }

        if (s_lotteryStatus != Status.ONGOING) {
            revert Lottery__NotOpen();
        }

        s_participantes.push(payable(msg.sender));
        emit EnterParticipant(msg.sender);
    }

    function declareWinner() external payable {
        if (block.timestamp - s_lastRoundStartedAt < i_intervalInSeconds) {
            revert Lottery__InvalidState();
        }

        if (s_lotteryStatus != Status.ONGOING) {
            revert Lottery__InvalidState();
        }

        s_lotteryStatus = Status.CALCULATING;
        address payable winner = s_participantes[0];

        // get random number
        // find out mod of random number and total participants.
        uint estimatedGasCost = ESTIMATED_GAS_UNIT * tx.gasprice;
        uint256 platformCommission = (address(this).balance *
            PLATFORM_COMMISSION_IN_PERCENTAGE) / 100;
        uint256 winningPrize = address(this).balance -
            estimatedGasCost -
            platformCommission;
        s_winners.push(winner{participant: winner, time: block.timestamp, prize: winningPrize, platformCommission: platformCommission});
        emit DeclaredWinner(s_participantes[0], winningPrize);

        if (s_winners.length % NUMBER_OF_ROUNDS_REQUIRE_TO_WITHDRAW == 0) {
            s_lotteryStatus = Status.CLOSED;
        } else {
            s_lotteryStatus = Status.ONGOING;
        }

        (bool success, ) = s_participantes[0].call{value: winningPrize}("");
        if (!success) {
            revert Lottery__PaymentFaild();
        }
    }


    function withdraw() external payable {
        if(msg.sender != s_owner) {
            revert Lottery__UnAuthorized();
        }

        if(s_lotteryStatus != Status.CLOSED) {
            revert Lottery__InvalidState();
        }

        (bool success, ) = payable(owner).call{value: address(this).balance}("");

        if (!success) {
            revert Lottery__PaymentFaild();
        }
        s_lotteryStatus = Status.ONGOING;
    }
}
