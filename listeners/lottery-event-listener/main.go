package main

import (
	"abuzaforfagun/decentralized-lottery/listeners/lottery-event-listener/dbmodels"
	"context"
	"fmt"
	"log"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
	"golang.org/x/crypto/sha3"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

func main() {

	db, err := gorm.Open(mysql.Open("root:admin@tcp(localhost:3306)/lottery"), &gorm.Config{})

	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	db.AutoMigrate(&dbmodels.Round{})
	db.AutoMigrate(&dbmodels.Participant{})
	db.AutoMigrate(&dbmodels.Winner{})

	client, err := ethclient.Dial("ws://127.0.0.1:8545")
	if err != nil {
		log.Fatalf("Failed to connect to Anvil: %v", err)
	}

	roundStartedSignatureHash := hashEvent("RoundStarted()")
	userJoinedEventSignatureHash := hashEvent("UserJoined(address)")
	winnerSelectedEventSignaturehash := hashEvent("WinnerDeclared(address)")

	header, err := client.HeaderByNumber(context.Background(), nil)
	if err != nil {
		log.Fatalf("Failed to get latest block header: %v", err)
	}
	latestBlock := header.Number
	currentRoundNo := 0

	roundsQuery := ethereum.FilterQuery{
		Addresses: []common.Address{
			common.HexToAddress("0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9"),
		},
		Topics:    [][]common.Hash{{roundStartedSignatureHash}},
		FromBlock: big.NewInt(0),
		ToBlock:   latestBlock,
	}

	blockLogs, err := client.FilterLogs(context.Background(), roundsQuery)
	if err != nil {
		log.Fatalf("Failed to fetch logs: %v", err)
	}

	var lastRoundStartedAt *time.Time
	for _, vLog := range blockLogs {
		blockNumber := vLog.BlockNumber
		block, err := client.BlockByNumber(context.Background(), big.NewInt(int64(blockNumber)))
		if err != nil {
			log.Fatalf("Failed to get block: %v", err)
		}
		currentRoundNo++
		blockTime := block.Time()
		round := &dbmodels.Round{
			StartedAt: time.Unix(int64(blockTime), 0),
			No:        currentRoundNo,
			EndedAt:   lastRoundStartedAt,
		}

		db.Create(round)
		lastRoundStartedAt = &round.StartedAt
	}

	eventsQuery := ethereum.FilterQuery{
		Addresses: []common.Address{
			common.HexToAddress("0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9"),
		},
		Topics: [][]common.Hash{
			{
				userJoinedEventSignatureHash,
				winnerSelectedEventSignaturehash,
				roundStartedSignatureHash,
			}},
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
			case roundStartedSignatureHash:
				currentTime := time.Now().UTC()

				roundNo := 1
				var lastRound *dbmodels.Round
				_ = db.Last(&lastRound)

				if lastRound != nil {
					roundNo = lastRound.No + 1
				}
				round := &dbmodels.Round{
					StartedAt: currentTime,
					No:        roundNo,
				}

				db.Create(round)
				currentRoundNo = roundNo
			case userJoinedEventSignatureHash:
				participantAddress := eventLog.Topics[1].Hex()
				currentTime := time.Now().UTC()
				participant := &dbmodels.Participant{
					Address:  participantAddress,
					JoinedAt: currentTime,
					RoundNo:  currentRoundNo,
				}

				_ = db.Create(participant)
				fmt.Println("User Joined: ", eventLog.Topics[1])
			case winnerSelectedEventSignaturehash:
				winnerAddress := eventLog.Topics[1].Hex()
				currentTime := time.Now().UTC()

				var lastRound *dbmodels.Round
				_ = db.Last(&lastRound)
				lastRound.EndedAt = &currentTime

				_ = db.Save(&lastRound)

				winner := &dbmodels.Winner{
					Address:    winnerAddress,
					DeclaredAt: currentTime,
					RoundNo:    lastRound.No,
				}

				_ = db.Create(winner)
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
