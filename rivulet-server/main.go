package main

import (
	"rivulet_server/cmd/api"
	"rivulet_server/internal/db"
)

// @title           Rivulet API
// @version         0.1
// @description     API for Rivulet
// @termsOfService  http://swagger.io/terms/
//
// @contact.name    API Support
// @contact.email   support@swagger.io
//
// @license.name    MIT
// @license.url     https://opensource.org/license/mit
//
// @host            localhost:8080
// @BasePath        /api/v1
//
// @securityDefinitions.apikey BearerAuth
// @in header
// @name Authorization
func main() {
	db.Connect()
	api.Start()
}
