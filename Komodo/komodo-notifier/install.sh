#!/usr/bin/env bash
set -e

# Usage:
# ./install.sh [path/to/binary]
# Examples:
# ./install.sh                       # Downloads from GitHub based on architecture
# ./install.sh ./build/komodo-notifier-linux-amd64  # Installs the local file

BIN_LOCATION="$1"
ARCH=$(uname -m)

if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root (e.g. sudo ./install.sh)"
    exit 1
fi

if [ -z "$BIN_LOCATION" ]; then
    echo "No local binary provided. Attempting to download..."
    # Update this URL to match your actual GitHub repository releases
    REPO="ravact/komodo-notifier"
    BASE_URL="https://github.com/${REPO}/releases/latest/download/komodo-notifier-linux"
    
    if [ "$ARCH" == "aarch64" ] || [ "$ARCH" == "arm64" ]; then
        DOWNLOAD_URL="${BASE_URL}-arm64"
    else
        DOWNLOAD_URL="${BASE_URL}-amd64"
    fi
    
    echo "Downloading binary from $DOWNLOAD_URL ..."
    BIN_LOCATION="/tmp/komodo-notifier_dl"
    if ! curl -sL -o "$BIN_LOCATION" "$DOWNLOAD_URL"; then
        echo "Failed to download binary from $DOWNLOAD_URL"
        echo "Please provide a local path: ./install.sh /path/to/komodo-notifier"
        exit 1
    fi
    chmod +x "$BIN_LOCATION"
fi

# Ensure it is a valid file
if [ ! -f "$BIN_LOCATION" ]; then
    echo "Error: Binary not found at $BIN_LOCATION"
    exit 1
fi

DEST="/usr/local/bin/komodo-notifier"

if [[ "$BIN_LOCATION" == "$DEST" ]] || [[ "$BIN_LOCATION" == "/usr/local/bin/"* ]]; then
    echo "Binary is already in /usr/local/bin/, skipping move step."
    chmod +x "$BIN_LOCATION"
    # Ensure DEST points to the actual location if it was placed e.g. in /usr/local/bin/something_else
    DEST="$BIN_LOCATION"
else
    echo "Moving binary to $DEST ..."
    cp "$BIN_LOCATION" "$DEST"
    chmod +x "$DEST"
fi

# Initial setup by invoking the binary's setup command
echo ""
echo "Running initial setup phase..."
$DEST setup

# Create Systemd unit file
UNIT_FILE="/etc/systemd/system/komodo-notifier.service"

echo "Creating systemd unit file at $UNIT_FILE ..."

cat <<EOF > "$UNIT_FILE"
[Unit]
Description=Komodo Notifier Service
After=network.target

[Service]
Type=simple
ExecStart=$DEST
Restart=on-failure
User=root
# If you want it to run as a non-root user, specify it above
# Ensure the user has read access to /etc/komodo-notifier/config.json

[Install]
WantedBy=multi-user.target
EOF

echo "Reloading systemd daemon..."
systemctl daemon-reload

echo "Enabling and starting komodo-notifier service..."
systemctl enable komodo-notifier.service
systemctl restart komodo-notifier.service

echo ""
echo "Installation complete!"
echo "You can view logs using: journalctl -u komodo-notifier -f"
echo "You can re-run setup using: sudo komodo-notifier setup"
