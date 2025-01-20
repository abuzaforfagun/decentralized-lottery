package dbmodels

import "time"

type Round struct {
	No        int
	StartedAt time.Time
	EndedAt   *time.Time
}
