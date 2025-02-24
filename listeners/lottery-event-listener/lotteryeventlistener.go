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
	"gorm.io/gorm"
)

type LotteryListener struct {
	client          *ethclient.Client
	contractAddress common.Address
	privateKey      string
	db              *gorm.DB
}

func NewLotteryListener(
	db *gorm.DB,
	client *ethclient.Client,
	contractAddress string,
	privateKey string) (*LotteryListener, error) {

	return &LotteryListener{
		client:          client,
		contractAddress: common.HexToAddress(contractAddress),
		privateKey:      privateKey,
		db:              db,
	}, nil
}

func (l *LotteryListener) StartListening() {
	eventHandlers := map[common.Hash]func(types.Log){
		hashEvent("RoundStarted()"):          l.handleRoundStarted,
		hashEvent("UserJoined(address)"):     l.handleUserJoined,
		hashEvent("WinnerDeclared(address)"): l.handleWinnerDeclared,
	}

	logs := make(chan types.Log)
	logSubscription, err := l.client.SubscribeFilterLogs(context.Background(), ethereum.FilterQuery{Addresses: []common.Address{l.contractAddress}}, logs)
	if err != nil {
		log.Fatalf("Unable to create subscription: %v", err)
	}

	for {
		select {
		case err := <-logSubscription.Err():
			log.Fatalf("Subscription error: %v", err)
		case eventLog := <-logs:
			if handler, exists := eventHandlers[eventLog.Topics[0]]; exists {
				handler(eventLog)
			}
		}
	}
}

func (l *LotteryListener) handleRoundStarted(eventLog types.Log) {
	currentTime := time.Now().UTC()
	var lastRound dbmodels.Round
	if err := l.db.Last(&lastRound).Error; err == nil {
		lastRound.EndedAt = &currentTime
		l.db.Save(&lastRound)
	}
	round := &dbmodels.Round{StartedAt: currentTime, No: lastRound.No + 1}
	l.db.Create(round)
}

func (l *LotteryListener) handleUserJoined(eventLog types.Log) {
	participant := &dbmodels.Participant{
		Address:  eventLog.Topics[1].Hex(),
		JoinedAt: time.Now().UTC(),
	}
	l.db.Create(participant)
	fmt.Println("User Joined: ", participant.Address)
	go l.triggerPerformUpKeep()
}

func (l *LotteryListener) handleWinnerDeclared(eventLog types.Log) {
	currentTime := time.Now().UTC()
	var lastRound dbmodels.Round
	if err := l.db.Last(&lastRound).Error; err == nil {
		lastRound.EndedAt = &currentTime
		l.db.Save(&lastRound)
	}
	winner := &dbmodels.Winner{
		Address: eventLog.Topics[1].Hex(), DeclaredAt: currentTime, RoundNo: lastRound.No,
	}
	l.db.Create(winner)
	fmt.Println("Winner Declared: ", winner.Address)
}

func (l *LotteryListener) doesRequireTriggerUpKeep() bool {
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
	parsedABI, _ := abi.JSON(strings.NewReader(checkUpKeepAbi))
	data, _ := parsedABI.Pack("checkUpkeep", []byte{})
	callMsg := ethereum.CallMsg{To: &l.contractAddress, Data: data}
	result, err := l.client.CallContract(context.Background(), callMsg, nil)
	if err != nil {
		log.Fatalf("Failed to call contract: %v", err)
	}
	output, _ := parsedABI.Unpack("checkUpkeep", result)
	return output[0].(bool)
}

func (l *LotteryListener) triggerPerformUpKeep() {
	if !l.doesRequireTriggerUpKeep() {
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
	parsedABI, _ := abi.JSON(strings.NewReader(performUpKeepAbi))
	privateKeyECDSA, _ := crypto.HexToECDSA(l.privateKey)
	publicKey := privateKeyECDSA.Public()
	publicKeyECDSA, ok := publicKey.(*ecdsa.PublicKey)
	if !ok {
		log.Fatalf("Failed to get public key")
	}

	fromAddress := crypto.PubkeyToAddress(*publicKeyECDSA)
	nonce, _ := l.client.PendingNonceAt(context.Background(), fromAddress)
	gasPrice, _ := l.client.SuggestGasPrice(context.Background())
	data, _ := parsedABI.Pack("performUpkeep", []byte{})
	gasLimit, _ := l.client.EstimateGas(context.Background(), ethereum.CallMsg{From: fromAddress, To: &l.contractAddress, Data: data})
	tx := types.NewTransaction(nonce, l.contractAddress, big.NewInt(0), gasLimit, gasPrice, data)
	chainID, _ := l.client.NetworkID(context.Background())
	signedTx, _ := types.SignTx(tx, types.NewEIP155Signer(chainID), privateKeyECDSA)
	l.client.SendTransaction(context.Background(), signedTx)
}

func hashEvent(event string) common.Hash {
	hash := sha3.NewLegacyKeccak256()
	hash.Write([]byte(event))
	return common.BytesToHash(hash.Sum(nil))
}
