#!/bin/bash
# ==============================================================================
# Update Infisical SMTP Credentials
# This script securely updates the SMTP configuration in the Infisical .env file,
# tests the connection, and gracefully restarts the backend.
# ==============================================================================

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_DIR="/opt/infisical"
ENV_FILE="${INSTALL_DIR}/.env"

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Root Check ────────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root (sudo bash update-smtp.sh)"
fi

if [ ! -f "$ENV_FILE" ]; then
    error "Could not find .env file at $ENV_FILE. Is Infisical installed?"
fi

clear
echo -e "${BOLD}${CYAN}──────────────────────────────────────────────────────────────────${NC}"
echo -e "${BOLD}  Update Infisical SMTP Credentials${NC}"
echo -e "${BOLD}${CYAN}──────────────────────────────────────────────────────────────────${NC}\n"

# ── Prompt for Credentials ────────────────────────────────────────────────────
read -rp "  SMTP Host (e.g., mail.example.com): " SMTP_HOST
read -rp "  SMTP Port (e.g., 587): " SMTP_PORT
read -rp "  SMTP From Address (e.g., noreply@infisical.io): " SMTP_FROM_ADDRESS
read -rp "  SMTP From Name (e.g., Infisical): " SMTP_FROM_NAME
read -rp "  SMTP Username: " SMTP_USERNAME
read -rs -p "  SMTP Password: " SMTP_PASSWORD; echo
echo ""

# ── Test SMTP Connection ──────────────────────────────────────────────────────
info "Testing SMTP connection and authentication..."

cat << 'EOF' > /tmp/test_smtp.py
import smtplib, sys

host = sys.argv[1]
port = int(sys.argv[2])
user = sys.argv[3]
password = sys.argv[4]

try:
    if port == 465:
        # Implicit TLS
        server = smtplib.SMTP_SSL(host, port, timeout=10)
    else:
        # Plaintext / STARTTLS
        server = smtplib.SMTP(host, port, timeout=10)
        
        # Determine if we should attempt STARTTLS (skip for local port 25 without auth usually, but safe to try if server supports it)
        # We will attempt STARTTLS if the server supports it and we are not on port 25
        if port != 25:
            server.starttls()
    
    if user and password:
        server.login(user, password)
        
    server.quit()
    sys.exit(0)
except Exception as e:
    print(str(e))
    sys.exit(1)
EOF

if ! python3 /tmp/test_smtp.py "$SMTP_HOST" "$SMTP_PORT" "$SMTP_USERNAME" "$SMTP_PASSWORD" > /tmp/smtp_error.log 2>&1; then
    echo -e "${RED}❌ SMTP Test Failed!${NC}"
    echo -e "  Error details: $(cat /tmp/smtp_error.log)"
    echo -e "  ${YELLOW}No changes were made to your configuration.${NC}\n"
    rm -f /tmp/test_smtp.py /tmp/smtp_error.log
    exit 1
fi

success "SMTP Connection and Authentication Successful!"
rm -f /tmp/test_smtp.py /tmp/smtp_error.log

# ── Update .env ───────────────────────────────────────────────────────────────
info "Updating $ENV_FILE..."

update_env() {
    local key="$1"
    local value="$2"
    # Escape ampersands and slashes for sed
    local safe_value=$(echo "$value" | sed -e 's/[\/&]/\\&/g')
    
    if grep -q "^${key}=" "$ENV_FILE"; then
        sed -i "s|^${key}=.*|${key}=${safe_value}|" "$ENV_FILE"
    else
        echo "${key}=${value}" >> "$ENV_FILE"
    fi
}

update_env "SMTP_HOST" "$SMTP_HOST"
update_env "SMTP_PORT" "$SMTP_PORT"
update_env "SMTP_FROM_ADDRESS" "$SMTP_FROM_ADDRESS"
update_env "SMTP_FROM_NAME" "$SMTP_FROM_NAME"
update_env "SMTP_USERNAME" "$SMTP_USERNAME"
update_env "SMTP_PASSWORD" "$SMTP_PASSWORD"

success "Configuration updated."

# ── Restart Backend ───────────────────────────────────────────────────────────
info "Restarting Infisical backend..."
cd "$INSTALL_DIR"
docker compose restart backend

echo -e "\n${BOLD}${GREEN}══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  ✅  SMTP Credentials updated and backend restarted successfully!${NC}"
echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════════════════════${NC}\n"
