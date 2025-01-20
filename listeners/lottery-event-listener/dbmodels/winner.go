package dbmodels

import "time"

type Winner struct {
	Address    string
	RoundNo    int
	DeclaredAt time.Time
}
