package main

import (
	"log"
	"net/http"

	"github.com/comame/router-go"
)

func main() {
	router.Get("/", nil)

	log.Println("Start bot http://127.0.0.1:8080")
	http.ListenAndServe(":8080", router.Handler())
}
