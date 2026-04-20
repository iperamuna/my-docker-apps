#!/bin/bash
# ==============================================================================
# enable-mss-sending.sh — Mass/Bulk SMTP Sending Setup for Mailu + Listmonk
# ==============================================================================
# What this script does:
#   1. Reads Mailu's .env to detect domain, API token, Docker network
#   2. Creates a dedicated bulk-sending mailbox in Mailu (via API)
#   3. Adds Listmonk's Docker subnet to Mailu RELAYNETS (trusted internal relay)
#   4. Raises the per-account sending quota for the MSS mailbox
#   5. Reloads affected Mailu containers
#   6. Prints a ready-to-paste SMTP config block for Listmonk's config.toml
# ==============================================================================
# Usage (run on the server as root):
#   sudo bash enable-mss-sending.sh
#   sudo bash enable-mss-sending.sh --no-interaction
# ==============================================================================

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
header()  { echo -e "\n${BOLD}${GREEN}══════════════════════════════════════════${NC}"; echo -e "${BOLD}${GREEN}  $*${NC}"; echo -e "${BOLD}${GREEN}══════════════════════════════════════════${NC}\n"; }

# ── Root check ────────────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && error "Run as root: sudo bash $0"

# ── Parse flags ───────────────────────────────────────────────────────────────
INTERACTIVE=true
for arg in "$@"; do
  case "$arg" in
    --no-interaction|-y) INTERACTIVE=false ;;
  esac
done

# ── Banner ────────────────────────────────────────────────────────────────────
clear
echo -e "${BOLD}${CYAN}"
echo "  ███╗   ███╗███████╗███████╗    ███████╗███╗   ██╗ █████╗ ██████╗ ██╗     ███████╗██████╗ "
echo "  ████╗ ████║██╔════╝██╔════╝    ██╔════╝████╗  ██║██╔══██╗██╔══██╗██║     ██╔════╝██╔══██╗"
echo "  ██╔████╔██║███████╗███████╗    █████╗  ██╔██╗ ██║███████║██████╔╝██║     █████╗  ██████╔╝"
echo "  ██║╚██╔╝██║╚════██║╚════██║    ██╔══╝  ██║╚██╗██║██╔══██║██╔══██╗██║     ██╔══╝  ██╔══██╗"
echo "  ██║ ╚═╝ ██║███████║███████║    ███████╗██║ ╚████║██║  ██║██████╔╝███████╗███████╗██║  ██║"
echo "  ╚═╝     ╚═╝╚══════╝╚══════╝    ╚══════╝╚═╝  ╚═══╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚══════╝╚═╝  ╚═╝"
echo -e "${NC}"
echo -e "  ${BOLD}Mass/Bulk SMTP Sending Enabler — Mailu + Listmonk${NC}"
echo -e "  Mode: $([ "$INTERACTIVE" = true ] && echo 'Interactive' || echo 'Non-Interactive')"
echo ""

# ==============================================================================
# SECTION 1 — Read Mailu Configuration
# ==============================================================================
header "Step 1 — Reading Mailu Configuration"

MAILU_DIR="${MAILU_DIR:-/opt/mailu}"
ENV_FILE="$MAILU_DIR/.env"

[[ -f "$ENV_FILE" ]] || error "Mailu .env not found at $ENV_FILE. Set MAILU_DIR env var if different."

# Extract values from Mailu .env
get_env() { grep -E "^${1}=" "$ENV_FILE" 2>/dev/null | cut -d= -f2- | tr -d '"' || echo ""; }

MAILU_DOMAIN="$(get_env DOMAIN)"
MAILU_HOST="$(get_env HOSTNAMES)"
API_TOKEN="$(get_env API_TOKEN)"
MAILU_EXTERNAL_URL="$(get_env EXTERNAL_URL)"
CURRENT_RELAYNETS="$(get_env RELAYNETS)"

[[ -z "$MAILU_DOMAIN" ]] && error "Could not detect DOMAIN from $ENV_FILE"
[[ -z "$API_TOKEN" ]]    && error "API_TOKEN missing in $ENV_FILE — enable API first."

MAILU_API="${MAILU_API_URL:-http://127.0.0.1/api/v1}"

success "Detected Mailu domain:  ${MAILU_DOMAIN}"
success "Detected Mailu host:    ${MAILU_HOST}"
success "Detected API token:     ${API_TOKEN:0:8}…"
info    "Current RELAYNETS:      '${CURRENT_RELAYNETS:-<none>}'"

# ==============================================================================
# SECTION 2 — Detect Listmonk Docker Network Subnet
# ==============================================================================
header "Step 2 — Detecting Listmonk Network Subnet"

LISTMONK_CONTAINER="${LISTMONK_CONTAINER:-listmonk-app}"
LISTMONK_NET_NAME="${LISTMONK_NETWORK:-listmonk_listmonk_internal}"

# Try to auto-detect the subnet Listmonk is on
DETECTED_SUBNET=""
if docker inspect "$LISTMONK_CONTAINER" &>/dev/null; then
  DETECTED_SUBNET=$(docker inspect "$LISTMONK_CONTAINER" \
    --format '{{range $net, $cfg := .NetworkSettings.Networks}}{{$cfg.IPAddress}}{{end}}' \
    | head -1)
  if [[ -n "$DETECTED_SUBNET" ]]; then
    # Convert to /24 subnet
    DETECTED_SUBNET=$(echo "$DETECTED_SUBNET" | awk -F. '{print $1"."$2"."$3".0/24"}')
    info "Auto-detected Listmonk container subnet: ${DETECTED_SUBNET}"
  fi
fi

# Mailu's own front container network (Docker bridge default 172.x.x.x)
FRONT_SUBNET=""
if docker inspect mailu-front-1 &>/dev/null 2>&1 || docker inspect mailu_front_1 &>/dev/null 2>&1; then
  FRONT_CONTAINER=$(docker ps --filter "name=mailu.*front" --format "{{.Names}}" | head -1)
  if [[ -n "$FRONT_CONTAINER" ]]; then
    FRONT_SUBNET=$(docker inspect "$FRONT_CONTAINER" \
      --format '{{range $net, $cfg := .NetworkSettings.Networks}}{{$cfg.IPAddress}}{{end}}' \
      | head -1 | awk -F. '{print $1"."$2"."$3".0/24"}')
    info "Auto-detected Mailu front subnet: ${FRONT_SUBNET}"
  fi
fi

# Default fallback: Docker internal ranges
DEFAULT_RELAY_SUBNET="${DETECTED_SUBNET:-172.16.0.0/12}"

# ==============================================================================
# SECTION 3 — Gather MSS Configuration
# ==============================================================================
header "Step 3 — MSS Configuration"

prompt() {
  local var="$1" txt="$2" default="$3"
  if [ "$INTERACTIVE" = true ]; then
    read -rp "  ${BOLD}${txt}${NC} [${CYAN}${default}${NC}]: " inp
    eval "${var}=\"${inp:-$default}\""
  else
    eval "${var}=\"${default}\""
  fi
}

gen_pass() { tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24; }

DEFAULT_MSS_USER="${MSS_USER:-listmonk}"
DEFAULT_MSS_PASS="${MSS_PASS:-$(gen_pass)}"
DEFAULT_FROM_EMAIL="${MSS_FROM:-listmonk@${MAILU_DOMAIN}}"
DEFAULT_DISPLAY_NAME="${MSS_DISPLAY:-Listmonk Mailer}"
DEFAULT_QUOTA="${MSS_QUOTA:-0}"          # 0 = unlimited in Mailu
DEFAULT_RATE_LIMIT="${MSS_RATE_LIMIT:-}"  # blank = keep Mailu default
DEFAULT_RELAY_NETS="${RELAY_NETS:-${DEFAULT_RELAY_SUBNET}}"

echo -e "  ${BOLD}── MSS Mailbox ──────────────────────────────────${NC}"
prompt MSS_USER         "MSS mailbox username (local part)" "$DEFAULT_MSS_USER"
prompt MSS_PASS         "MSS mailbox password"              "$DEFAULT_MSS_PASS"
prompt FROM_EMAIL       "From email address"                "$DEFAULT_FROM_EMAIL"
prompt DISPLAY_NAME     "Display name for sender"           "$DEFAULT_DISPLAY_NAME"
prompt QUOTA            "Mailbox quota MB (0 = unlimited)"  "$DEFAULT_QUOTA"

echo ""
echo -e "  ${BOLD}── Relay & Rate ─────────────────────────────────${NC}"
echo -e "  ${YELLOW}RELAYNETS: trusted subnets that can relay via Mailu port 25 WITHOUT auth${NC}"
echo -e "  ${YELLOW}This allows Listmonk's internal Docker subnet to send without TLS overhead${NC}"
echo ""
prompt RELAY_NETS       "Subnet(s) to add to RELAYNETS (space-sep)" "$DEFAULT_RELAY_NETS"
prompt RATE_LIMIT_NEW   "Override global send rate (e.g. 1000/day, blank=skip)" "$DEFAULT_RATE_LIMIT"

# Full email address
MSS_EMAIL="${MSS_USER}@${MAILU_DOMAIN}"

echo ""
echo -e "${BOLD}${CYAN}── Summary ───────────────────────────────────────────────────────${NC}"
echo -e "  MSS mailbox:     ${GREEN}${MSS_EMAIL}${NC}"
echo -e "  Display name:    ${GREEN}${DISPLAY_NAME}${NC}"
echo -e "  Quota:           ${GREEN}${QUOTA} MB${NC}"
echo -e "  RELAYNETS add:   ${GREEN}${RELAY_NETS}${NC}"
[[ -n "$RATE_LIMIT_NEW" ]] && echo -e "  Rate limit:      ${GREEN}${RATE_LIMIT_NEW}${NC}"
echo -e "${BOLD}${CYAN}──────────────────────────────────────────────────────────────────${NC}"

if [ "$INTERACTIVE" = true ]; then
  echo ""
  read -rp "  Press ${BOLD}ENTER${NC} to apply or ${RED}Ctrl+C${NC} to abort... " _
fi

# ==============================================================================
# SECTION 4 — Create MSS Mailbox via Mailu API
# ==============================================================================
header "Step 4 — Creating MSS Mailbox in Mailu"

API_HEADERS=(-H "Authorization: ${API_TOKEN}" -H "Content-Type: application/json")

# Check if mailbox already exists
HTTP_STATUS=$(curl -sLk -o /dev/null -w "%{http_code}" \
  "${MAILU_API}/user/${MSS_EMAIL}" \
  "${API_HEADERS[@]}")

if [[ "$HTTP_STATUS" == "200" ]]; then
  warn "Mailbox ${MSS_EMAIL} already exists — updating password & quota only."
  PATCH_RESP=$(curl -sLk -w "\n%{http_code}" -X PATCH \
    "${MAILU_API}/user/${MSS_EMAIL}" \
    "${API_HEADERS[@]}" \
    -d "{
      \"raw_password\":  \"${MSS_PASS}\",
      \"displayed_name\": \"${DISPLAY_NAME}\",
      \"quota_bytes\":    $([ "$QUOTA" -eq 0 ] 2>/dev/null && echo "0" || echo "$((QUOTA * 1024 * 1024))"),
      \"enabled\":        true,
      \"change_pw_next_login\": false
    }")
  PATCH_CODE=$(echo "$PATCH_RESP" | tail -1)
  [[ "$PATCH_CODE" =~ ^2 ]] && success "Mailbox updated." || warn "Patch returned HTTP ${PATCH_CODE} — check manually."
else
  info "Creating mailbox ${MSS_EMAIL}..."
  CREATE_RESP=$(curl -sLk -w "\n%{http_code}" -X POST \
    "${MAILU_API}/user" \
    "${API_HEADERS[@]}" \
    -d "{
      \"email\":           \"${MSS_EMAIL}\",
      \"raw_password\":    \"${MSS_PASS}\",
      \"displayed_name\": \"${DISPLAY_NAME}\",
      \"quota_bytes\":    $([ "$QUOTA" -eq 0 ] 2>/dev/null && echo "0" || echo "$((QUOTA * 1024 * 1024))"),
      \"enabled\":        true,
      \"change_pw_next_login\": false,
      \"global_admin\":   false
    }")
  CREATE_CODE=$(echo "$CREATE_RESP" | tail -1)
  [[ "$CREATE_CODE" =~ ^2 ]] && success "Mailbox ${MSS_EMAIL} created." \
    || error "Failed to create mailbox (HTTP ${CREATE_CODE}). Body: $(echo "$CREATE_RESP" | head -1)"
fi

# ==============================================================================
# SECTION 5 — Update RELAYNETS in Mailu .env
# ==============================================================================
header "Step 5 — Configuring RELAYNETS for Internal Relay"

# Build new RELAYNETS value (merge existing + new subnets, deduplicate)
NEW_RELAYNETS=""
EXISTING_LIST="${CURRENT_RELAYNETS//,/ }"  # normalize comma-separated to spaces
ALL_NETS="$EXISTING_LIST $RELAY_NETS"
DEDUP_NETS=$(echo "$ALL_NETS" | tr ' ' '\n' | sort -u | grep -v '^$' | paste -sd ',' -)

if [[ -z "$CURRENT_RELAYNETS" ]]; then
  # Add fresh RELAYNETS line
  echo "RELAYNETS=${DEDUP_NETS}" >> "$ENV_FILE"
  success "Added RELAYNETS=${DEDUP_NETS} to Mailu .env"
elif [[ "$CURRENT_RELAYNETS" == "$DEDUP_NETS" ]]; then
  info "RELAYNETS already contains all required subnets — no change needed."
else
  # Update existing line
  sed -i "s|^RELAYNETS=.*|RELAYNETS=${DEDUP_NETS}|" "$ENV_FILE"
  success "Updated RELAYNETS to: ${DEDUP_NETS}"
fi

# ── Optional: update global rate limit too ────────────────────────────────────
if [[ -n "$RATE_LIMIT_NEW" ]]; then
  if grep -q "^MESSAGE_RATELIMIT=" "$ENV_FILE"; then
    sed -i "s|^MESSAGE_RATELIMIT=.*|MESSAGE_RATELIMIT=${RATE_LIMIT_NEW}|" "$ENV_FILE"
  else
    echo "MESSAGE_RATELIMIT=${RATE_LIMIT_NEW}" >> "$ENV_FILE"
  fi
  success "Set MESSAGE_RATELIMIT=${RATE_LIMIT_NEW}"
fi

# ==============================================================================
# SECTION 6 — Restart Affected Mailu Services
# ==============================================================================
header "Step 6 — Reloading Mailu Services"

cd "$MAILU_DIR"

info "Restarting Mailu front (SMTP relay) and admin containers..."
docker compose restart front admin 2>/dev/null \
  || docker compose up -d --no-deps front admin 2>/dev/null \
  || warn "Could not auto-restart — run 'docker compose restart front admin' in $MAILU_DIR manually."

# Brief wait for front to settle
sleep 3

# Verify front is up
FRONT_UP=$(docker compose ps front 2>/dev/null | grep -c "Up" || echo "0")
[[ "$FRONT_UP" -gt 0 ]] && success "Mailu front container is Up." || warn "Mailu front may be restarting; verify with: docker compose -f $MAILU_DIR/docker-compose.yml ps"

# ==============================================================================
# SECTION 7 — Output Listmonk SMTP Config Block
# ==============================================================================
header "Step 7 — Listmonk SMTP Configuration"

SMTP_BLOCK="[[smtp]]
enabled          = true
host             = \"front\"          # Mailu front container (internal Docker network)
port             = 25               # Plain SMTP via RELAYNETS — no TLS handshake
auth_protocol    = \"plain\"
username         = \"${MSS_EMAIL}\"
password         = \"${MSS_PASS}\"
email_headers    = []
max_conns        = 10
max_msg_retries  = 2
idle_timeout     = \"15s\"
wait_timeout     = \"5s\"
tls_type         = \"none\"           # Internal relay — TLS disabled for performance
tls_skip_verify  = false"

echo -e "${BOLD}${CYAN}── Paste this into your Listmonk config.toml ─────────────────────${NC}"
echo ""
echo -e "${YELLOW}${SMTP_BLOCK}${NC}"
echo ""
echo -e "${BOLD}${CYAN}──────────────────────────────────────────────────────────────────${NC}"

# ==============================================================================
# SECTION 8 — Save Summary
# ==============================================================================
header "Step 8 — Saving Credentials"

CRED_FILE="${MAILU_DIR}/mss-credentials.txt"
cat > "$CRED_FILE" <<CRED
# ── MSS (Mass SMTP Sending) Credentials ──────────────────────────────────────
# Generated: $(date +"%Y-%m-%d %H:%M:%S")
# Keep this file secure.

MSS Mailbox:       ${MSS_EMAIL}
Password:          ${MSS_PASS}
Display Name:      ${DISPLAY_NAME}
Quota (MB):        ${QUOTA} (0 = unlimited)

SMTP Config (for Listmonk /opt/listmonk/config.toml):
──────────────────────────────────────────────────────
${SMTP_BLOCK}
──────────────────────────────────────────────────────

Mailu RELAYNETS:   ${DEDUP_NETS}
CRED
chmod 600 "$CRED_FILE"
success "Credentials saved to ${CRED_FILE}"

# ── Final Summary ─────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  ✅  MSS Sending Enabled!${NC}"
echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  📧 MSS mailbox:  ${CYAN}${MSS_EMAIL}${NC}"
echo -e "  🔑 Password:     ${CYAN}${MSS_PASS}${NC}"
echo -e "  🌐 RELAYNETS:    ${CYAN}${DEDUP_NETS}${NC}"
echo -e "  📄 Saved to:     ${CYAN}${CRED_FILE}${NC}"
echo ""
echo -e "  ${BOLD}Next steps:${NC}"
echo -e "    1. Update ${YELLOW}/opt/listmonk/config.toml${NC} with the SMTP block above"
echo -e "    2. Restart Listmonk: ${YELLOW}docker compose -f /opt/listmonk/docker-compose.yml restart${NC}"
echo -e "    3. In Listmonk dashboard → Settings → SMTP → Send a test email to verify"
echo -e "    4. Check Mailu logs: ${YELLOW}docker compose -f ${MAILU_DIR}/docker-compose.yml logs front -f${NC}"
echo ""
echo -e "  ${BOLD}${YELLOW}Deliverability reminders:${NC}"
echo -e "    • Ensure SPF includes your sending IP"
echo -e "    • DKIM must be published in DNS (Mailu Admin → Domains → Regenerate DKIM)"
echo -e "    • DMARC policy should be at least ${YELLOW}p=quarantine${NC}"
echo -e "    • For warm-up: start with ${YELLOW}< 500 emails/day${NC} and ramp gradually"
echo ""
echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════════════════════${NC}"
