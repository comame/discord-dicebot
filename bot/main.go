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

var gameMap = map[string]string{
	"emo": "Emoklore",
	"coc": "Cthulhu",
}

func main() {
	var publicKey = os.Getenv("DISCORD_PUBLICKEY")
	var applicationID = os.Getenv("DISCORD_APPLICATION_ID")
	var botToken = os.Getenv("DISCORD_BOT_TOKEN")

	if err := registerApplicationCommand(applicationCommand{
		Name:        "dice",
		Type:        applicationCommandTypeChatInput,
		Description: "Dicebot powered by BCDice",
		Options: []applicationCommandOption{{
			Type:        applicationCommandTypeString,
			Name:        "dice",
			Description: "1D100, 2DM<=6",
			Required:    true,
		}, {
			Type:        applicationCommandTypeString,
			Name:        "game",
			Description: "emo=>Emoklore, coc=>Cthulhu (See bcdice.org/systems)",
			Required:    false,
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

			// デフォルトではエモクロアを指定
			game := "Emoklore"
			if len(req.Data.Options) == 2 {
				reqGame := req.Data.Options[1].Value.(string)
				alias, ok := gameMap[reqGame]
				if ok {
					game = alias
				} else {
					game = reqGame
				}
			}

			result, err := doRoll(dice, game)

			if err != nil {
				log.Println(err)
				res = interactionResponse{
					Type: interactionCallbackTypeChannelMessageWithSource,
					Data: &interactionCallbackDataMessages{
						Content: err.Error(),
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

func doRoll(dice, game string) (string, error) {
	type resp struct {
		Body  string `json:"body"`
		Error string `json:"error"`
	}

	u, _ := url.Parse("http://localhost:8081/")

	q := make(url.Values)
	q.Add("dice", dice)
	q.Add("game", game)
	u.RawQuery = q.Encode()

	res, err := http.Get(u.String())
	if err != nil {
		return "", errors.Join(errors.New("failed to get"), err)
	}

	b, err := io.ReadAll(res.Body)
	if err != nil {
		return "", err
	}

	var r resp
	if err := json.Unmarshal(b, &r); err != nil {
		log.Println("")
		return "", errors.Join(errors.New("failed to unmarshal json"), err)
	}

	if r.Error != "" {
		log.Println("")
		return "", errors.New(r.Error)
	}

	return r.Body, nil
}
