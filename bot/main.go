package main

import (
	"encoding/json"
	"errors"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"

	"github.com/comame/router-go"
)

func main() {
	var publicKey = os.Getenv("DISCORD_PUBLICKEY")
	var applicationID = os.Getenv("DISCORD_APPLICATION_ID")
	var botToken = os.Getenv("DISCORD_BOT_TOKEN")

	if err := registerApplicationCommand(applicationCommand{
		Name:        "dicebot",
		Type:        applicationCommandTypeChatInput,
		Description: "Dicebot based on BCDice.",
		Options: []applicationCommandOption{{
			Type:        applicationCommandTypeString,
			Name:        "dice",
			Description: "Dice string.",
			Required:    true,
		}},
	}, applicationID, botToken); err != nil {
		panic(err)
	}

	router.All("/dicebot/interactions", func(w http.ResponseWriter, r *http.Request) {
		bb, err := io.ReadAll(r.Body)
		if err != nil {
			http.Error(w, "error", http.StatusBadRequest)
			return
		}

		sigEd25519 := r.Header.Get("X-Signature-Ed25519")
		sigTimestamp := r.Header.Get("X-Signature-Timestamp")

		verified := verifySignature(sigEd25519, sigTimestamp, string(bb), publicKey)
		if !verified {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}

		var req interaction
		if err = json.Unmarshal(bb, &req); err != nil {
			http.Error(w, "failed to parse request body", http.StatusBadRequest)
			return
		}

		var res interactionResponse
		switch req.Type {
		case interactionTypePing:
			res = interactionResponse{
				Type: interactionCallbackTypePong,
				Data: nil,
			}
		case interactionTypeApplicationCommand:
			// Command 登録で Options[0] が dice なので
			dice := req.Data.Options[0].Value.(string)
			result, err := doRoll(dice)

			if err != nil {
				log.Println(err)
				res = interactionResponse{
					Type: interactionCallbackTypeChannelMessageWithSource,
					Data: &interactionCallbackDataMessages{
						Content: "ダイスロールに失敗 " + err.Error(),
					},
				}
			} else {
				res = interactionResponse{
					Type: interactionCallbackTypeChannelMessageWithSource,
					Data: &interactionCallbackDataMessages{
						Content: result,
					},
				}
			}
		}

		rb, err := json.Marshal(res)
		if err != nil {
			http.Error(w, "failed to marshal json", http.StatusBadRequest)
			return
		}

		w.Header().Add("Content-Type", "application/json")
		w.Write(rb)
	})

	log.Println("Start bot http://127.0.0.1:8080")
	http.ListenAndServe(":8080", router.Handler())
}

func doRoll(dice string) (string, error) {
	type resp struct {
		Body  string `json:"body"`
		Error string `json:"error"`
	}

	u, _ := url.Parse("http://localhost:8081/")

	q := make(url.Values)
	q.Add("dice", dice)
	u.RawQuery = q.Encode()

	res, err := http.Get(u.String())
	if err != nil {
		return "", err
	}

	b, err := io.ReadAll(res.Body)
	if err != nil {
		return "", err
	}

	var r resp
	if err := json.Unmarshal(b, &r); err != nil {
		return "", err
	}

	if r.Error != "" {
		return "", errors.New(r.Error)
	}

	return r.Body, nil
}
