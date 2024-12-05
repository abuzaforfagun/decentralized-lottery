// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {console} from "forge-std/Script.sol";

contract Lottery is VRFConsumerBaseV2Plus {
    event EnterParticipant(address indexed participant);
    event DeclaredWinner(address indexed winner, uint256 indexed prizeMoney);
    event WithdrawMoney();

    error Lottery__InsufficiantFund();
    error Lottery__InvalidState();
    error Lottery__PaymentFaild();
    error Lottery__InvalidOperation();
    error Lottery__NotOpen();
    error Lottery__UnAuthorized();
    struct Winner {
        address participant;
        uint time;
        uint256 prize;
        uint256 platformCommission;
    }

    enum Status {
        ONGOING,
        CALCULATING,
        CLOSED
    }

    uint32 private constant NUM_OF_WORDS = 1;
    uint16 private constant NUM_OF_REQUEST_CONFIRMATION = 3;
    uint32 private constant CALLBACK_GAS_LIMIT = 2500000;

    address payable[] private s_participantes;
    Winner[] private s_winners;
    address private s_lastRoundWinner;
    uint private s_lastRoundStartedAt;
    uint256 private s_randomWords;
    Status private s_lotteryStatus;
    uint256 private s_requestId;

    uint256 private immutable i_entryFee;
    uint private i_intervalInSeconds;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subId;
    address private immutable i_owner;

    uint private constant ESTIMATED_GAS_UNIT = 100000;
    uint256 private constant PLATFORM_COMMISSION_IN_PERCENTAGE = 5;
    uint256 private constant NUMBER_OF_ROUNDS_REQUIRE_TO_WITHDRAW = 10;

    constructor(
        uint256 entryFee,
        uint256 intervalInSeconds,
        address vrfCoordinator,
        bytes32 keyHash,
        uint256 subId
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        console.log("VRF COORDINATOR: %s", vrfCoordinator);
        i_entryFee = entryFee;
        i_intervalInSeconds = intervalInSeconds;
        s_lastRoundStartedAt = block.timestamp;
        s_lotteryStatus = Status.ONGOING;
        i_owner = msg.sender;
        i_keyHash = keyHash;
        i_subId = subId;
    }

    function lotteryStatus() external view returns (Status) {
        return s_lotteryStatus;
    }

    function getRequestId() external view returns (uint256) {
        return s_requestId;
    }

    function getRandomWords() external view returns (uint256) {
        return s_randomWords;
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

    function getLastRoundStartedAt() public view returns (uint) {
        return s_lastRoundStartedAt;
    }

    function getLastRoundWinner() public view returns (address) {
        return s_lastRoundWinner;
    }

    function declareWinner() external payable {
        if (block.timestamp - s_lastRoundStartedAt < i_intervalInSeconds) {
            revert Lottery__InvalidState();
        }

        if (s_lotteryStatus != Status.ONGOING) {
            revert Lottery__InvalidState();
        }

        s_lotteryStatus = Status.CALCULATING;

        s_requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subId,
                requestConfirmations: NUM_OF_REQUEST_CONFIRMATION,
                callbackGasLimit: CALLBACK_GAS_LIMIT,
                numWords: NUM_OF_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
    }

    function fulfillRandomWords(
        uint256,
        uint256[] calldata randomWords
    ) internal override {
        uint256 totalParticipant = s_participantes.length;
        uint256 winnerIndex = (randomWords[0] % totalParticipant);

        address winnerOfThisRound = s_participantes[winnerIndex];

        uint estimatedGasCost = ESTIMATED_GAS_UNIT * tx.gasprice;
        uint256 platformCommission = (address(this).balance *
            PLATFORM_COMMISSION_IN_PERCENTAGE) / 100;
        uint256 winningPrize = address(this).balance -
            estimatedGasCost -
            platformCommission;

        Winner memory winner = Winner({
            participant: winnerOfThisRound,
            time: block.timestamp,
            prize: winningPrize,
            platformCommission: platformCommission
        });
        s_lastRoundWinner = winnerOfThisRound;
        s_winners.push(winner);
        emit DeclaredWinner(winnerOfThisRound, winningPrize);

        if (s_winners.length % NUMBER_OF_ROUNDS_REQUIRE_TO_WITHDRAW == 0) {
            s_lotteryStatus = Status.CLOSED;
        } else {
            s_lotteryStatus = Status.ONGOING;
        }

        (bool success, ) = winnerOfThisRound.call{value: winningPrize}("");
        if (!success) {
            revert Lottery__PaymentFaild();
        }
    }

    function withdraw() external payable {
        if (msg.sender != i_owner) {
            revert Lottery__UnAuthorized();
        }

        if (s_lotteryStatus != Status.CLOSED) {
            revert Lottery__InvalidState();
        }

        (bool success, ) = payable(i_owner).call{value: address(this).balance}(
            ""
        );

        if (!success) {
            revert Lottery__PaymentFaild();
        }
        s_lotteryStatus = Status.ONGOING;

        emit WithdrawMoney();
    }

    function getRaffleState() public view returns (Status) {
        return s_lotteryStatus;
    }
}
