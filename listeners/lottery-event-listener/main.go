package main

import (
	"context"
	"fmt"
	"log"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
	"golang.org/x/crypto/sha3"
)

func main() {
	client, err := ethclient.Dial("ws://127.0.0.1:8545")
	if err != nil {
		log.Fatalf("Failed to connect to Anvil: %v", err)
	}

	userJoinedEventSignatureHash := hashEvent("UserJoined(address)")
	winnerSelectedEventSignaturehash := hashEvent("WinnerDeclared(address)")

	eventsQuery := ethereum.FilterQuery{
		Addresses: []common.Address{
			common.HexToAddress("0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9"),
		},
		Topics: [][]common.Hash{{userJoinedEventSignatureHash, winnerSelectedEventSignaturehash}},
	}

	logs := make(chan types.Log)

	logSubscription, err := client.SubscribeFilterLogs(context.Background(), eventsQuery, logs)
	if err != nil {
		log.Fatalf("Unable to create subscription: %v", err)
	}

	for {
		select {
		case logErr := <-logSubscription.Err():
			log.Fatalf("Subscription error: %v", logErr)
		case eventLog := <-logs:
			switch eventLog.Topics[0] {
			case userJoinedEventSignatureHash:
				fmt.Println("User Joined: ", eventLog.Topics[1])
			case winnerSelectedEventSignaturehash:
				fmt.Println("Winner Declared: ", eventLog.Topics[1])
			}
		}
	}
}

func hashEvent(event string) common.Hash {
	hash := sha3.NewLegacyKeccak256()
	hash.Write([]byte(event))
	return common.BytesToHash(hash.Sum(nil))
}
