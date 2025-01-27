package main

import (
	"abuzaforfagun/decentralized-lottery/listeners/lottery-event-listener/dbmodels"
	"context"
	"crypto/ecdsa"
	"fmt"
	"log"
	"math/big"
	"strings"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"golang.org/x/crypto/sha3"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

var client *ethclient.Client
var CONTRACT_ADDRESS = common.HexToAddress("0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9")
var PRIVATE_KEY = "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

func main() {

	db, err := gorm.Open(mysql.Open("root:admin@tcp(localhost:3306)/lottery"), &gorm.Config{})

	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	db.AutoMigrate(&dbmodels.Round{})
	db.AutoMigrate(&dbmodels.Participant{})
	db.AutoMigrate(&dbmodels.Winner{})

	client, err = ethclient.Dial("ws://127.0.0.1:8545")
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
			CONTRACT_ADDRESS,
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
			CONTRACT_ADDRESS,
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
				go triggerPerformUpKeep()
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

func doesRequireTriggerUpKeep() bool {
	checkUpKeepAbi := `[{
		"type": "function",
		"name": "checkUpkeep",
		"inputs": [
		  {
			"name": "",
			"type": "bytes",
			"internalType": "bytes"
		  }
		],
		"outputs": [
		  {
			"name": "upkeepNeeded",
			"type": "bool",
			"internalType": "bool"
		  },
		  {
			"name": "",
			"type": "bytes",
			"internalType": "bytes"
		  }
		],
		"stateMutability": "view"
	  }]`

	parsedCheckUpKeepAbi, err := abi.JSON(strings.NewReader(checkUpKeepAbi))
	if err != nil {
		log.Fatalf("Failed to parse ABI: %v", err)
	}
	methodCheckUpkeep := "checkUpkeep"
	data, err := parsedCheckUpKeepAbi.Pack(methodCheckUpkeep, []byte{})
	if err != nil {
		log.Fatalf("Failed to pack data: %v", err)
	}

	callMsg := ethereum.CallMsg{
		To:   &CONTRACT_ADDRESS,
		Data: data,
	}

	result, err := client.CallContract(context.Background(), callMsg, nil)
	if err != nil {
		log.Fatalf("Failed to call contract: %v", err)
	}

	output, err := parsedCheckUpKeepAbi.Unpack(methodCheckUpkeep, result)
	if err != nil {
		log.Fatalf("Failed to unpack data: %v", err)
	}
	upkeepNeeded := output[0].(bool)

	return upkeepNeeded
}

func triggerPerformUpKeep() {

	if !doesRequireTriggerUpKeep() {
		return
	}
	performUpKeepAbi := `[{
          "inputs": [
            {
              "internalType": "bytes",
              "name": "",
              "type": "bytes"
            }
          ],
          "stateMutability": "nonpayable",
          "type": "function",
          "name": "performUpkeep"
        }]`
	parsedPerformUpKeepAbi, err := abi.JSON(strings.NewReader(performUpKeepAbi))
	if err != nil {
		log.Fatalf("Failed to parse ABI: %v", err)
	}
	privatekey, err := crypto.HexToECDSA(PRIVATE_KEY)
	if err != nil {
		log.Fatalf("Failed to get private key: %v", err)
	}

	publicKey := privatekey.Public()
	publicKeyECDSA, ok := publicKey.(*ecdsa.PublicKey)
	if !ok {
		log.Fatalf("Failed to get public key: %v", err)
	}
	fromAddress := crypto.PubkeyToAddress(*publicKeyECDSA)

	nonce, err := client.PendingNonceAt(context.Background(), fromAddress)
	if err != nil {
		log.Fatalf("Failed to get nonce: %v", err)
	}

	gasPrice, err := client.SuggestGasPrice(context.Background())
	if err != nil {
		log.Fatalf("Failed to get gas price: %v", err)
	}

	methodPerformUpKeep := "performUpkeep"
	performData := []byte{}
	dataPerformUpKeep, err := parsedPerformUpKeepAbi.Pack(methodPerformUpKeep, performData)

	if err != nil {
		log.Fatalf("Failed to pack data: %v", err)
	}

	msg := ethereum.CallMsg{
		From: fromAddress,
		To:   &CONTRACT_ADDRESS,
		Data: dataPerformUpKeep,
	}

	gasLimit, err := client.EstimateGas(context.Background(), msg)
	if err != nil {
		log.Fatalf("Failed to estimate gas: %v", err)
	}

	tx := types.NewTransaction(nonce, CONTRACT_ADDRESS, big.NewInt(0), gasLimit, gasPrice, dataPerformUpKeep)
	chainId, err := client.NetworkID(context.Background())
	if err != nil {
		log.Fatalf("Failed to get network id: %v", err)
	}
	signedTx, err := types.SignTx(tx, types.NewEIP155Signer(chainId), privatekey)
	if err != nil {
		log.Fatalf("Failed to sign transaction: %v", err)
	}

	err = client.SendTransaction(context.Background(), signedTx)
	if err != nil {
		log.Fatalf("Failed to send transaction: %v", err)
	}
}
