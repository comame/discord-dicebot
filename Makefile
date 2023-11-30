SHELL=/bin/bash

include .env.prod
export

.PHONY: deploy dev

dev:
	cd diceserver && bundle exec ruby main.rb &
	cd bot && go run .

deploy:
	cd diceserver && \
	docker build -t registry.comame.dev/discord-dicebot-ruby . && \
	docker push registry.comame.dev/discord-dicebot-ruby

	cd bot && \
	go build -o out && \
	docker build -t registry.comame.dev/discord-dicebot-go . && \
	docker push registry.comame.dev/discord-dicebot-go

	kubectl rollout restart -n comame-xyz deployment discord-dicebot
