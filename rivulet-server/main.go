package main

import (
	"rivulet_server/cmd/api"
	"rivulet_server/internal/db"
)

func main() {
	db.Connect()

	api.InitProviders()
	api.Start()
}