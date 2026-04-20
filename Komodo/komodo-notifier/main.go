package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

func cap(n, length int) int {
	if n > length {
		return length
	}
	return n
}


type Config struct {
	Port             string `json:"port"`
	NotificationType string `json:"notification_type"` // "telegram" or "teams"
	TelegramToken    string `json:"telegram_token,omitempty"`
	TelegramChatID   string `json:"telegram_chat_id,omitempty"`
	TeamsWebhookURL  string `json:"teams_webhook_url,omitempty"`
}

type KomodoAlert struct {
	Level    string `json:"level"` // OK, ERROR, WARNING
	Resolved bool   `json:"resolved"`
	Target   struct {
		ID   string `json:"id"`
		Type string `json:"type"`
	} `json:"target"`
	Data struct {
		Type string `json:"type"`
		Data struct {
			ID   string `json:"id"`
			Name string `json:"name"`
		} `json:"data"`
	} `json:"data"`
	TS int64 `json:"ts"`
}

const defaultConfigPath = "/etc/komodo-notifier/config.json"

func main() {
	if len(os.Args) > 1 && os.Args[1] == "setup" {
		setupCmd := flag.NewFlagSet("setup", flag.ExitOnError)
		port := setupCmd.String("port", "", "Port to run the service on")
		notifType := setupCmd.String("type", "", "Notification type: 'telegram' or 'teams'")
		tgToken := setupCmd.String("telegram-token", "", "Telegram Bot Token")
		tgChatID := setupCmd.String("telegram-chat", "", "Telegram Chat ID")
		teamsWebhook := setupCmd.String("teams-webhook", "", "Teams Webhook URL")
		configPath := setupCmd.String("config", defaultConfigPath, "Path to config file")

		setupCmd.Parse(os.Args[2:])
		runSetup(*configPath, *port, *notifType, *tgToken, *tgChatID, *teamsWebhook)
		return
	}

	configPath := flag.String("config", defaultConfigPath, "Path to config file (run 'komodo-notifier setup' first)")
	flag.Parse()

	if *configPath == "" {
		*configPath = defaultConfigPath
	}

	runServer(*configPath)
}

func runSetup(configPath, port, notifType, tgToken, tgChatID, teamsWebhook string) {
	reader := bufio.NewReader(os.Stdin)

	// Load existing config if available to provide defaults
	var existingCfg Config
	if data, err := os.ReadFile(configPath); err == nil {
		json.Unmarshal(data, &existingCfg)
	}

	fmt.Println("--- Komodo Notifier Setup ---")

	if port == "" {
		defaultPort := "8080"
		if existingCfg.Port != "" {
			defaultPort = existingCfg.Port
		}
		fmt.Printf("Enter HTTP port to listen on [%s]: ", defaultPort)
		p, _ := reader.ReadString('\n')
		p = strings.TrimSpace(p)
		if p == "" {
			port = defaultPort
		} else {
			port = p
		}
	}

	if notifType == "" {
		defaultType := "telegram"
		if existingCfg.NotificationType != "" {
			defaultType = existingCfg.NotificationType
		}
		fmt.Printf("Select notification type:\n  1. Telegram\n  2. Microsoft Teams\nChoice [%s]: ", defaultType)
		nt, _ := reader.ReadString('\n')
		nt = strings.TrimSpace(nt)
		
		switch nt {
		case "1":
			notifType = "telegram"
		case "2":
			notifType = "teams"
		case "":
			notifType = defaultType
		default:
			notifType = strings.ToLower(nt)
		}
	}

	notifType = strings.ToLower(notifType)

	if notifType == "telegram" {
		if tgToken == "" {
			prompt := "Enter Telegram Bot Token: "
			if existingCfg.TelegramToken != "" {
				prompt = fmt.Sprintf("Enter Telegram Bot Token [%s...]: ", existingCfg.TelegramToken[:cap(5, len(existingCfg.TelegramToken))])
			}
			fmt.Print(prompt)
			t, _ := reader.ReadString('\n')
			tgToken = strings.TrimSpace(t)
			if tgToken == "" && existingCfg.TelegramToken != "" {
				tgToken = existingCfg.TelegramToken
			}
		}

		if tgChatID == "" {
			if existingCfg.TelegramChatID != "" {
				fmt.Printf("Use existing Telegram Chat ID (%s)? [Y/n]: ", existingCfg.TelegramChatID)
				confirm, _ := reader.ReadString('\n')
				confirm = strings.ToLower(strings.TrimSpace(confirm))
				if confirm == "" || confirm == "y" {
					tgChatID = existingCfg.TelegramChatID
				}
			}

			if tgChatID == "" {
				fmt.Println("\n--- Telegram Chat ID Setup ---")
				fmt.Println("Press [ENTER] to auto-detect by sending a message, OR type your Chat ID if you already know it:")
				t, _ := reader.ReadString('\n')
				tgChatID = strings.TrimSpace(t)

				if tgChatID == "" {
					fmt.Println("\n1. Ensure your bot is added to the target Group or Channel.")
					fmt.Println("2. IMPORTANT: Send a message starting with '/' (e.g., /id) or mention the bot (e.g., @botname hello).")
					fmt.Println("   (Bots in groups often can't see regular text unless 'Privacy Mode' is disabled in @BotFather)")
					fmt.Print("Waiting for message to appear... ")
					tgChatID = fetchTelegramChatID(tgToken)
					fmt.Printf("\nSuccessfully captured Chat ID: %s\n\n", tgChatID)
				}
			}
		}
	} else if notifType == "teams" {
		if teamsWebhook == "" {
			prompt := "Enter Teams Webhook URL: "
			if existingCfg.TeamsWebhookURL != "" {
				prompt = fmt.Sprintf("Enter Teams Webhook URL [%s...]: ", existingCfg.TeamsWebhookURL[:cap(10, len(existingCfg.TeamsWebhookURL))])
			}
			fmt.Print(prompt)
			t, _ := reader.ReadString('\n')
			teamsWebhook = strings.TrimSpace(t)
			if teamsWebhook == "" && existingCfg.TeamsWebhookURL != "" {
				teamsWebhook = existingCfg.TeamsWebhookURL
			}
		}
	} else {
		fmt.Println("Invalid notification type. Must be 'telegram' or 'teams'.")
		os.Exit(1)
	}

	cfg := Config{
		Port:             port,
		NotificationType: notifType,
		TelegramToken:    tgToken,
		TelegramChatID:   tgChatID,
		TeamsWebhookURL:  teamsWebhook,
	}


	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		fmt.Printf("Failed to marshal config: %v\n", err)
		os.Exit(1)
	}

	dir := filepath.Dir(configPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		fmt.Printf("Failed to create config directory %s: %v\n", dir, err)
		fmt.Println("Please run this command with sudo if writing to /etc")
		os.Exit(1)
	}

	if err := os.WriteFile(configPath, data, 0644); err != nil {
		fmt.Printf("Failed to write config file %s: %v\n", configPath, err)
		fmt.Println("Please run this command with sudo if writing to /etc")
		os.Exit(1)
	}

	fmt.Printf("Configuration saved successfully to: %s\n", configPath)
}

func runServer(configPath string) {
	data, err := os.ReadFile(configPath)
	if err != nil {
		fmt.Printf("Error reading config file %s: %v\n", configPath, err)
		fmt.Println("Please run 'komodo-notifier setup' first to generate the config.")
		os.Exit(1)
	}

	var cfg Config
	if err := json.Unmarshal(data, &cfg); err != nil {
		fmt.Printf("Error parsing config file: %v\n", err)
		os.Exit(1)
	}

	http.HandleFunc("/webhook", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		bodyBytes, err := io.ReadAll(r.Body)
		if err != nil {
			http.Error(w, "Failed to read body", http.StatusBadRequest)
			return
		}

		var alert KomodoAlert
		var messageTitle, messageBody string
		
		if err := json.Unmarshal(bodyBytes, &alert); err == nil && alert.Level != "" {
			// Rich formatting for recognized Komodo Alerts
			messageTitle, messageBody = formatAlert(alert)
		} else {
			// Fallback for unknown payloads
			messageTitle = "🔔 *Komodo Alert*"
			var payload map[string]interface{}
			if err := json.Unmarshal(bodyBytes, &payload); err == nil {
				pretty, _ := json.MarshalIndent(payload, "", "  ")
				messageBody = fmt.Sprintf("```json\n%s\n```", pretty)
			} else {
				messageBody = string(bodyBytes)
			}
		}

		// Ensure we don't block the HTTP response
		go func(cfg Config, title, body string) {
			if cfg.NotificationType == "telegram" {
				sendTelegram(cfg, title, body)
			} else if cfg.NotificationType == "teams" {
				sendTeams(cfg, title, body)
			}
		}(cfg, messageTitle, messageBody)

		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	fmt.Printf("Starting komodo-notifier on port %s...\n", cfg.Port)
	fmt.Printf("Configured for sending alerts via %s\n", cfg.NotificationType)
	fmt.Printf("Listening for webhooks at http://0.0.0.0:%s/webhook\n", cfg.Port)
	
	if err := http.ListenAndServe(":"+cfg.Port, nil); err != nil {
		fmt.Printf("Server failed: %v\n", err)
	}
}

func formatAlert(alert KomodoAlert) (string, string) {
	statusEmoji := "⚪"
	level := strings.ToUpper(alert.Level)

	switch level {
	case "OK":
		statusEmoji = "🟢"
	case "WARNING":
		statusEmoji = "🟡"
	case "ERROR", "CRITICAL":
		statusEmoji = "🔴"
	}

	title := fmt.Sprintf("%s Komodo Alert - %s", statusEmoji, level)
	
	name := alert.Data.Data.Name
	if name == "" {
		name = alert.Target.ID
	}

	body := fmt.Sprintf("*Target:* %s\n*Type:* %s\n*Status:* %s", 
		name, 
		alert.Data.Type,
		level,
	)

	if alert.Resolved {
		body += "\n✅ *Issue Resolved*"
	}

	return title, body
}

func sendTelegram(cfg Config, title, body string) {
	url := fmt.Sprintf("https://api.telegram.org/bot%s/sendMessage", cfg.TelegramToken)

	message := title + "\n\n" + body
	payload := map[string]interface{}{
		"chat_id":    cfg.TelegramChatID,
		"text":       message,
		"parse_mode": "Markdown",
	}

	data, _ := json.Marshal(payload)
	resp, err := http.Post(url, "application/json", bytes.NewBuffer(data))
	if err != nil {
		fmt.Printf("Error sending to telegram: %v\n", err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		respBody, _ := io.ReadAll(resp.Body)
		fmt.Printf("Telegram API returned error status: %d, %s\n", resp.StatusCode, string(respBody))
	} else {
		fmt.Println("Successfully sent alert to Telegram")
	}
}

func sendTeams(cfg Config, title, body string) {
	// Microsoft Teams MessageCard format
	payload := map[string]interface{}{
		"@type":      "MessageCard",
		"@context":   "http://schema.org/extensions",
		"themeColor": "0076D7",
		"summary":    "Komodo Alert",
		"sections": []map[string]interface{}{
			{
				"activityTitle":    title,
				"activitySubtitle": time.Now().Format("2006-01-02 15:04:05"),
				"text":             strings.ReplaceAll(body, "*", "**"), // Teams uses Double Asterisk for Bold
				"markdown":         true,
			},
		},
	}

	// Change color based on alert level
	if strings.Contains(title, "🔴") {
		payload["themeColor"] = "FF0000"
	} else if strings.Contains(title, "🟢") {
		payload["themeColor"] = "00FF00"
	}

	data, _ := json.Marshal(payload)
	resp, err := http.Post(cfg.TeamsWebhookURL, "application/json", bytes.NewBuffer(data))
	if err != nil {
		fmt.Printf("Error sending to teams: %v\n", err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		respBody, _ := io.ReadAll(resp.Body)
		fmt.Printf("Teams API returned error status: %d, %s\n", resp.StatusCode, string(respBody))
	} else {
		fmt.Println("Successfully sent alert to Teams")
	}
}

func fetchTelegramChatID(token string) string {
	url := fmt.Sprintf("https://api.telegram.org/bot%s/getUpdates", token)
	client := &http.Client{Timeout: 10 * time.Second}
	
	for {
		resp, err := client.Get(url)
		if err == nil {
			var result struct {
				Ok     bool `json:"ok"`
				Result []struct {
					Message struct {
						Chat struct {
							ID float64 `json:"id"`
						} `json:"chat"`
					} `json:"message"`
					ChannelPost struct {
						Chat struct {
							ID float64 `json:"id"`
						} `json:"chat"`
					} `json:"channel_post"`
				} `json:"result"`
			}
			
			if err := json.NewDecoder(resp.Body).Decode(&result); err == nil && result.Ok {
				for i := len(result.Result) - 1; i >= 0; i-- {
					id := result.Result[i].Message.Chat.ID
					if id == 0 {
						id = result.Result[i].ChannelPost.Chat.ID
					}
					if id != 0 {
						resp.Body.Close()
						// Format without scientific notation or decimals
						return fmt.Sprintf("%.0f", id)
					}
				}
			}
			resp.Body.Close()
		}
		time.Sleep(3 * time.Second)
		fmt.Print(".")
	}
}
