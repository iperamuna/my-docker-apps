#!/bin/bash

# ==============================================================================
# Komodo Periphery Agent Automated Installer
# Target: Ubuntu 20.04/22.04/24.04
# ==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==========================================================${NC}"
echo -e "${BLUE}   Komodo Periphery Agent Setup Script   ${NC}"
echo -e "${BLUE}==========================================================${NC}"

# 1. Prerequisites Check
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root.${NC}"
   echo -e "Try: sudo ./setup-periphery-agent.sh"
   exit 1
fi

# 2. Check for required tools
echo -e "${GREEN}Checking prerequisites...${NC}"
for tool in curl python3 openssl; do
    if ! command -v $tool &> /dev/null; then
        echo -e "${YELLOW}Installing $tool...${NC}"
        apt-get update && apt-get install -y $tool
    fi
done

# 3. Install Docker if missing
if ! command -v docker &> /dev/null; then
    echo -e "${GREEN}Installing Docker...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    echo -e "${GREEN}Docker installed successfully.${NC}"
else
    echo -e "${BLUE}Docker is already installed.${NC}"
fi

# 4. Run official Komodo Periphery Setup Script
echo -e "${GREEN}Running official Komodo Periphery setup...${NC}"
curl -sSL https://raw.githubusercontent.com/moghtech/komodo/main/scripts/setup-periphery.py | python3 -

# 5. Configuration (Passkey Setup)
CONFIG_FILE="/etc/komodo/periphery.config.toml"
mkdir -p /etc/komodo

# Generate a passkey if it doesn't exist
if [ ! -f "$CONFIG_FILE" ] || ! grep -q "passkeys =" "$CONFIG_FILE"; then
    echo -e "${GREEN}Configuring secure passkey...${NC}"
    NEW_PASSKEY=$(openssl rand -hex 16)
    
    # If file exists, append or replace. If not, create.
    if [ -f "$CONFIG_FILE" ]; then
        # Remove existing passkeys line if it exists
        sed -i '/passkeys =/d' "$CONFIG_FILE"
        echo "passkeys = [\"$NEW_PASSKEY\"]" >> "$CONFIG_FILE"
    else
        cat > "$CONFIG_FILE" <<EOF
# Komodo Periphery Configuration
passkeys = ["$NEW_PASSKEY"]
EOF
    fi
    echo -e "${GREEN}Passkey configured.${NC}"
    RESTART_NEEDED=true
else
    # Extract existing passkey
    NEW_PASSKEY=$(grep "passkeys =" "$CONFIG_FILE" | sed -E 's/.*"(.*)".*/\1/')
    echo -e "${BLUE}Using existing passkey found in $CONFIG_FILE.${NC}"
fi

# 6. Ensure service is enabled and running
echo -e "${GREEN}Starting Periphery service...${NC}"
systemctl daemon-reload
systemctl enable periphery
if [ "$RESTART_NEEDED" = true ]; then
    systemctl restart periphery
else
    systemctl start periphery
fi

# 7. Firewall Configuration (Optional but recommended)
if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
    echo -e "${GREEN}Opening port 8120 in UFW...${NC}"
    ufw allow 8120/tcp
fi

# 8. Get Public IP
PUBLIC_IP=$(curl -s https://ifconfig.me || curl -s https://api.ipify.org || echo "YOUR_SERVER_IP")

# 9. Output Connection Info
echo -e "\n${BLUE}==========================================================${NC}"
echo -e "${GREEN}   Setup Complete!   ${NC}"
echo -e "${BLUE}==========================================================${NC}"
echo -e "\nUse the following details to add this server to your Komodo Dashboard:"
echo -e "\n${YELLOW}Server Name:${NC}  $(hostname)"
echo -e "${YELLOW}Address:${NC}      https://$PUBLIC_IP:8120"
echo -e "${YELLOW}Passkey:${NC}      $NEW_PASSKEY"
echo -e "\n${BLUE}Steps to connect to komodo.ravact.com:${NC}"
echo -e "1. Login to https://komodo.ravact.com"
echo -e "2. Go to ${BLUE}Servers${NC} > ${BLUE}Add Server${NC}"
echo -e "3. Enter the details above."
echo -e "4. IMPORTANT: Check ${YELLOW}'Skip TLS Verification'${NC} (if using default self-signed cert)."
echo -e "5. Click ${GREEN}'Add'${NC}."
echo -e "\n${BLUE}==========================================================${NC}"
