package dbmodels

import "time"

type Participant struct {
	Address  string
	JoinedAt time.Time
	RoundNo  int
}
