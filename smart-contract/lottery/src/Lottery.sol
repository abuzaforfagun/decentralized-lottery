// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract Lottery is VRFConsumerBaseV2Plus {
    error Lottery_InsufficiantFund();
    error Lottery_NotOpened();
    error Lottery_InvalidState();
    error Lottery_PaymentFailed();
    error Lottery_NotEnoughParticipants();

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
    uint256 private s_requestID;

    uint256 private immutable i_entryFee;
    uint256 private immutable i_numberOfParticipantsRequiredToDraw;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subId;

    uint256 private constant PLATFORM_COMMISION_IN_PERCENTAGE = 10;
    uint32 private constant NUM_OF_WORDS = 1;
    uint16 private constant NUM_OF_REQUEST_CONFIRMATION = 3;
    uint32 private constant CALLBACK_GAS_LIMIT = 2500000;

    constructor(
        uint256 entryFee,
        uint256 numberOfParticipantsRequiredToDraw,
        address vrfCoordinator,
        bytes32 keyHash,
        uint256 subId
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entryFee = entryFee;
        s_lastRoundStartedAt = block.timestamp;
        s_owner = msg.sender;
        s_lotteryStatus = Status.ONGOING;
        i_numberOfParticipantsRequiredToDraw = numberOfParticipantsRequiredToDraw;
        i_keyHash = keyHash;
        i_subId = subId;
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

    function getVrfRequestId() external view returns (uint256) {
        return s_requestID;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        uint256 totalParticipants = s_participantes.length;

        uint256 winnerIndex = randomWords[0] % totalParticipants;

        s_lastRoundWinner = s_participantes[winnerIndex];

        uint256 platformComision = (address(this).balance * PLATFORM_COMMISION_IN_PERCENTAGE) / 100;
        uint256 winningPrize = address(this).balance - platformComision;

        (bool success,) = s_lastRoundWinner.call{value: winningPrize}("");

        if (!success) {
            revert Lottery_PaymentFailed();
        }
        s_participantes = new address[](0);
        s_lotteryStatus = Status.ONGOING;

        s_owner.call{value: address(this).balance}("");
        s_requestID = 0;
    }

    function join() external payable returns (uint256) {
        if (msg.value < i_entryFee) {
            revert Lottery_InsufficiantFund();
        }

        if (s_lotteryStatus != Status.ONGOING) {
            revert Lottery_NotOpened();
        }

        s_participantes.push(msg.sender);

        if (s_participantes.length == i_numberOfParticipantsRequiredToDraw) {
            return declareWinner();
        }
        return 0;
    }

    function declareWinner() public returns (uint256) {
        if (s_lotteryStatus != Status.ONGOING) {
            revert Lottery_InvalidState();
        }

        if (s_participantes.length < i_numberOfParticipantsRequiredToDraw) {
            revert Lottery_NotEnoughParticipants();
        }

        s_lotteryStatus = Status.CALCULATING;

        s_requestID = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subId,
                requestConfirmations: NUM_OF_REQUEST_CONFIRMATION,
                callbackGasLimit: CALLBACK_GAS_LIMIT,
                numWords: NUM_OF_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );
        return s_requestID;
    }
}
