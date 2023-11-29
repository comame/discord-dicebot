SHELL=/bin/bash

include .env
export

.PHONY: build dev

build:
	exit 0

dev:
	cd diceserver && bundle exec ruby main.rb &
	cd bot && go run .
