package main

import (
	"bytes"
	"crypto/ed25519"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
)

// https://discord.com/developers/docs/interactions/receiving-and-responding#interaction-object-interaction-structure
type interaction struct {
	ID            string          `json:"id"`
	ApplicationID string          `json:"application_id"`
	Type          interactionType `json:"type"`
	Data          interactionData `json:"data"`
}

// https://discord.com/developers/docs/interactions/receiving-and-responding#interaction-object-interaction-type
type interactionType int

const (
	interactionTypePing interactionType = iota + 1
	interactionTypeApplicationCommand
)

// https://discord.com/developers/docs/interactions/receiving-and-responding#interaction-object-application-command-data-structure
type interactionData struct {
	ID      string                                    `json:"id"`
	Name    string                                    `json:"name"`
	Type    applicationCommandType                    `json:"type"`
	Options []applicationCommandInteractionDataOption `json:"options"`
}

// https://discord.com/developers/docs/interactions/receiving-and-responding#interaction-response-object-interaction-response-structure
type interactionResponse struct {
	Type interactionCallbackType `json:"type"`
	// interactionCallbackDataMessages
	Data interface{} `json:"data,omitempty"`
}

// https://discord.com/developers/docs/interactions/receiving-and-responding#interaction-response-object-interaction-callback-type
type interactionCallbackType int

const (
	interactionCallbackTypePong                     interactionCallbackType = iota + 1
	interactionCallbackTypeChannelMessageWithSource                         = iota + 3
)

// https://discord.com/developers/docs/interactions/receiving-and-responding#interaction-response-object-messages
type interactionCallbackDataMessages struct {
	Content string `json:"content,omitempty"`
}

// https://discord.com/developers/docs/interactions/receiving-and-responding#interaction-object-application-command-interaction-data-option-structure
type applicationCommandInteractionDataOption struct {
	Name string                       `json:"name"`
	Type applicationCommandOptionType `json:"type"`
	// string, integer, double, or boolean
	Value interface{} `json:"value"`
}

// https://discord.com/developers/docs/interactions/application-commands#application-command-object-application-command-types
type applicationCommandType int

const (
	applicationCommandTypeChatInput applicationCommandType = iota + 1
	applicationCommandTypeUser
	applicationCommandTypeMessage
)

// https://discord.com/developers/docs/interactions/application-commands#application-command-object-application-command-structure
type applicationCommand struct {
	Name        string                     `json:"name"`
	Type        applicationCommandType     `json:"type"`
	Description string                     `json:"description"`
	Options     []applicationCommandOption `json:"options,omitempty"`
}

// https://discord.com/developers/docs/interactions/application-commands#application-command-object-application-command-option-structure
type applicationCommandOption struct {
	Type        applicationCommandOptionType `json:"type"`
	Name        string                       `json:"name"`
	Description string                       `json:"description"`
	Required    bool                         `json:"required"`
}

// https://discord.com/developers/docs/interactions/application-commands#application-command-object-application-command-option-type
type applicationCommandOptionType int

const (
	applicationCommandTypeString = iota + 3
)

func registerApplicationCommand(cmd applicationCommand, applicationID, botToken string) error {
	b, err := json.Marshal(cmd)
	if err != nil {
		return err
	}
	br := bytes.NewBuffer(b)

	endpoint := fmt.Sprintf("https://discord.com/api/v10/applications/%s/commands", applicationID)

	req, _ := http.NewRequest(http.MethodPost, endpoint, br)
	req.Header.Set("Authorization", fmt.Sprintf("Bot %s", botToken))
	req.Header.Set("Content-Type", "application/json")

	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}

	rb, _ := io.ReadAll(res.Body)
	log.Println(string(rb))

	return nil
}

func verifySignature(signature, timestamp, body, publicKey string) bool {
	var msg bytes.Buffer

	sig, err := hex.DecodeString(signature)
	if err != nil {
		return false
	}

	pubKey, err := hex.DecodeString(publicKey)
	if err != nil {
		return false
	}

	if len(sig) != ed25519.SignatureSize {
		return false
	}

	msg.WriteString(timestamp)
	msg.WriteString(body)

	return ed25519.Verify(pubKey, msg.Bytes(), sig)
}
