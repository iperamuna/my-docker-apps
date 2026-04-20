# Komodo Notifier

A minimal, self-contained service that acts as a webhook receiver for Komodo alerts and forwards them to Telegram or Microsoft Teams.

## Features

- **No external dependencies**: Pure Go standard library.
- **Single Binary**: Compiles to a small, single executable file.
- **Interactive Setup**: Built-in `setup` command to easily configure your notification settings.
- **Cross-Platform**: Compile for Linux/Mac/Windows in `amd64` and `arm64` via the Makefile.

## Build

You can build the binaries using the provided `Makefile`:

```bash
make all
```

This will output:
- `build/komodo-notifier-linux-amd64`
- `build/komodo-notifier-linux-arm64`
- `build/komodo-notifier-darwin-arm64`

## Installation

You can use the provided bash script to quickly deploy it as a systemd service on Linux.

### Install from a local build

```bash
sudo ./install.sh ./build/komodo-notifier-linux-amd64
```

### Install from internet (download latest release)

*(Note: Assumes binary releases are published to GitHub)*
```bash
sudo ./install.sh
```

## Setup & Configuration

During installation, the `install.sh` script will automatically invoke the interactive setup.
If you need to change settings later, just run:

```bash
sudo komodo-notifier setup
```

Follow the prompts to enter:
1. The port to listen on.
2. The notification type (`telegram` or `teams`).
3. For Telegram: `Bot Token` and `Chat ID`.
4. For Teams: `Webhook URL`.

The configuration is securely saved to `/etc/komodo-notifier/config.json`.

---

## 💡 Configuration Tips

### 1. How to get Telegram Chat ID
If the built-in auto-detection fails (usually due to Privacy Mode), you can get it manually:

#### For Groups/Channels:
1.  Add the **`@userinfobot`** to your group.
2.  It will immediately post the **Id** (e.g., `-1003964490311`).
3.  Copy that number (including the minus sign) and paste it into the setup.
4.  Remove the bot from the group once done.

#### For Private Messages:
1.  Search for **`@userinfobot`** and send it any message.
2.  It will reply with your personal **Id**.

### 2. How to get Microsoft Teams Webhook URL
Teams now uses **Workflows** for webhooks:
1.  Open **Microsoft Teams** and go to the target Channel.
2.  Click the **three dots (...)** next to the channel name and select **Workflows**.
3.  Search for **"Post to a channel when a Webhook request is received"**.
4.  Give it a name (e.g., "Komodo Alerts").
5.  Confirm the Channel and click **Next**.
6.  Copy the **URL** provided. This is your Webhook URL.

---

## 🏗️ Docker & Firewall Configuration

If your **Komodo Core/Agent** is running in a **Docker container** and this notifier is running on the **Host**, you must ensure they can talk to each other.

### 1. The Webhook URL
Use your server's **Bridge IP** (usually `172.17.0.1`) or your **Private LAN IP** in the Komodo dashboard:
`http://172.17.0.1:8080/webhook`

### 2. Firewall Rules (UFW)
By default, firewalls like `ufw` often block traffic from the Docker bridge. You must allow your configured port:

```bash
# Replace 8080 with your actual port
sudo ufw allow 8080/tcp
```

For better security, you can limit access to only the Docker bridge:
```bash
sudo ufw allow from 172.17.0.0/16 to any port 8080 proto tcp
```

---

## Run manually (Non-Service)

```bash
sudo komodo-notifier
```
*(sudo needed if reading config from `/etc`)*

## Restarting Service

Whenever you change the configuration via `setup`, restart the systemd service to apply the new settings:

```bash
sudo systemctl restart komodo-notifier
```
