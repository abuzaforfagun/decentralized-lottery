package main

import (
	"abuzaforfagun/decentralized-lottery/listeners/lottery-event-listener/dbmodels"
	"log"
	"os"

	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/joho/godotenv"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

var client *ethclient.Client
var CONTRACT_ADDRESS string
var PRIVATE_KEY string

func main() {
	err := godotenv.Load(".env")
	if err != nil {
		log.Fatalf("Error loading .env file: %s", err)
	}

	connectionString := os.Getenv("MYSQL_CONNECTION_STRING")
	CONTRACT_ADDRESS = os.Getenv("CONTRACT_ADDRESS")
	PRIVATE_KEY = os.Getenv("PRIVATE_KEY")

	db, err := gorm.Open(mysql.Open(connectionString), &gorm.Config{})

	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	db.AutoMigrate(&dbmodels.Round{})
	db.AutoMigrate(&dbmodels.Participant{})
	db.AutoMigrate(&dbmodels.Winner{})

	nodeUrl := os.Getenv("NODE_WS")
	client, err = ethclient.Dial(nodeUrl)
	if err != nil {
		log.Fatalf("Failed to connect to Anvil: %v", err)
	}

	listener, err := NewLotteryListener(db, client, CONTRACT_ADDRESS, PRIVATE_KEY)
	if err != nil {
		log.Fatalf("failed to create lottery listener: %v", err)
	}
	listener.StartListening()
}
