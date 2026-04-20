#!/bin/bash
# ==============================================================================
# Listmonk Automated Installer for Ubuntu 22.04/24.04
# Supports: Interactive (prompted) & Non-Interactive (env-var / flag) modes
# SMTP: Mailu internal connection WITHOUT SSL (no handshake overhead)
# ==============================================================================
# Usage:
#   Interactive:       sudo bash setup-listmonk.sh
#   Non-Interactive:   sudo bash setup-listmonk.sh --no-interaction
#   With env vars:     LISTMONK_DOMAIN=newsletter.example.com \
#                      SMTP_HOST=front SMTP_PORT=25 \
#                      sudo bash setup-listmonk.sh --no-interaction
# ==============================================================================

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
header()  { echo -e "\n${BOLD}${GREEN}══════════════════════════════════════════${NC}"; echo -e "${BOLD}${GREEN}  $*${NC}"; echo -e "${BOLD}${GREEN}══════════════════════════════════════════${NC}\n"; }

gen_secret() { tr -dc 'A-Za-z0-9!@#$%^&*' </dev/urandom | head -c "${1:-32}"; }
gen_pass()   { tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24; }

# ── Parse Flags ───────────────────────────────────────────────────────────────
INTERACTIVE=true
for arg in "$@"; do
  case "$arg" in
    --no-interaction|-y|--yes) INTERACTIVE=false ;;
    --interactive)             INTERACTIVE=true  ;;
  esac
done

# ── Root check ────────────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && error "Run as root: sudo bash $0 [--no-interaction]"

# ── Banner ────────────────────────────────────────────────────────────────────
clear
echo -e "${BOLD}${CYAN}"
echo "  ██╗     ██╗███████╗████████╗███╗   ███╗ ██████╗ ███╗   ██╗██╗  ██╗"
echo "  ██║     ██║██╔════╝╚══██╔══╝████╗ ████║██╔═══██╗████╗  ██║██║ ██╔╝"
echo "  ██║     ██║███████╗   ██║   ██╔████╔██║██║   ██║██╔██╗ ██║█████╔╝ "
echo "  ██║     ██║╚════██║   ██║   ██║╚██╔╝██║██║   ██║██║╚██╗██║██╔═██╗ "
echo "  ███████╗██║███████║   ██║   ██║ ╚═╝ ██║╚██████╔╝██║ ╚████║██║  ██╗"
echo "  ╚══════╝╚═╝╚══════╝   ╚═╝   ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═╝"
echo -e "${NC}"
echo -e "  ${BOLD}Automated Listmonk Installer — Mailu SMTP Edition${NC}"
echo -e "  Mode: $([ "$INTERACTIVE" = true ] && echo 'Interactive (Prompted)' || echo 'Non-Interactive (Automated)')"
echo ""

# ==============================================================================
# SECTION 1: Configuration
# ==============================================================================
header "Step 1 — Configuration"

# ── Defaults (override via env vars in non-interactive mode) ──────────────────
DEFAULT_DOMAIN="${LISTMONK_DOMAIN:-newsletter.example.com}"
DEFAULT_INSTALL_DIR="${LISTMONK_INSTALL_DIR:-/opt/listmonk}"
DEFAULT_ADMIN_USER="${LISTMONK_ADMIN_USER:-admin}"
DEFAULT_ADMIN_PASS="${LISTMONK_ADMIN_PASS:-$(gen_pass)}"
DEFAULT_DB_PASS="${LISTMONK_DB_PASS:-$(gen_pass)}"
DEFAULT_APP_PORT="${LISTMONK_APP_PORT:-9000}"
DEFAULT_PG_PORT="${LISTMONK_PG_PORT:-5432}"

# ── SMTP Defaults (Mailu internal — NO SSL) ───────────────────────────────────
# When Listmonk joins the Mailu Docker network, use "front" as host on port 25.
# This avoids TLS handshake overhead for internal container-to-container mail.
DEFAULT_SMTP_HOST="${SMTP_HOST:-front}"
DEFAULT_SMTP_PORT="${SMTP_PORT:-25}"
DEFAULT_SMTP_USER="${SMTP_USER:-listmonk@example.com}"
DEFAULT_SMTP_PASS="${SMTP_PASS:-}"
DEFAULT_SMTP_FROM="${SMTP_FROM:-Listmonk <listmonk@example.com>}"
DEFAULT_SMTP_TLS="${SMTP_TLS:-false}"          # false = no SSL/TLS
DEFAULT_SMTP_STARTTLS="${SMTP_STARTTLS:-false}" # false = no STARTTLS
DEFAULT_MAILU_NETWORK="${MAILU_NETWORK:-mailu_default}"
DEFAULT_JOIN_MAILU_NET="${JOIN_MAILU_NETWORK:-true}"

# ── Nginx / Certbot ───────────────────────────────────────────────────────────
DEFAULT_SETUP_NGINX="${SETUP_NGINX:-true}"
DEFAULT_SETUP_SSL="${SETUP_SSL:-true}"
DEFAULT_ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"

prompt() {
  # prompt <var_name> <prompt_text> <default>
  local var_name="$1"
  local prompt_text="$2"
  local default="$3"
  if [ "$INTERACTIVE" = true ]; then
    read -rp "  ${BOLD}${prompt_text}${NC} [${CYAN}${default}${NC}]: " input
    eval "${var_name}=\"${input:-$default}\""
  else
    eval "${var_name}=\"${default}\""
  fi
}

prompt_yn() {
  # prompt_yn <var_name> <prompt_text> <default: true|false>
  local var_name="$1"
  local prompt_text="$2"
  local default="$3"
  if [ "$INTERACTIVE" = true ]; then
    local hint; hint=$([ "$default" = "true" ] && echo "Y/n" || echo "y/N")
    read -rp "  ${BOLD}${prompt_text}${NC} [${CYAN}${hint}${NC}]: " input
    input="${input,,}"
    if [[ "$input" == "y" || "$input" == "yes" ]]; then
      eval "${var_name}=true"
    elif [[ "$input" == "n" || "$input" == "no" ]]; then
      eval "${var_name}=false"
    else
      eval "${var_name}=${default}"
    fi
  else
    eval "${var_name}=${default}"
  fi
}

# ── Collect Config ────────────────────────────────────────────────────────────
echo -e "  ${BOLD}── Application ──────────────────────────────────${NC}"
prompt DOMAIN          "Public domain for Listmonk"       "$DEFAULT_DOMAIN"
prompt INSTALL_DIR     "Install directory"                 "$DEFAULT_INSTALL_DIR"
prompt APP_PORT        "Listmonk app port (internal)"      "$DEFAULT_APP_PORT"
prompt ADMIN_USER      "Admin username"                    "$DEFAULT_ADMIN_USER"
prompt ADMIN_PASS      "Admin password"                    "$DEFAULT_ADMIN_PASS"
prompt DB_PASS         "PostgreSQL password"               "$DEFAULT_DB_PASS"

echo ""
echo -e "  ${BOLD}── SMTP / Mailu ─────────────────────────────────${NC}"
echo -e "  ${YELLOW}Tip: For Mailu internal SMTP, use host=front port=25 (no SSL/TLS)${NC}"
echo -e "  ${YELLOW}     This avoids TLS handshake overhead on internal connections.${NC}"
echo ""
prompt SMTP_HOST       "SMTP host (Mailu front container)" "$DEFAULT_SMTP_HOST"
prompt SMTP_PORT       "SMTP port (25=plain, 587=STARTTLS)" "$DEFAULT_SMTP_PORT"
prompt SMTP_USER       "SMTP username (from@domain)"       "$DEFAULT_SMTP_USER"
prompt SMTP_PASS       "SMTP password"                     "$DEFAULT_SMTP_PASS"
prompt SMTP_FROM       "From address (Name <email>)"       "$DEFAULT_SMTP_FROM"
prompt_yn SMTP_TLS     "Enable TLS/SSL (false for internal)" "$DEFAULT_SMTP_TLS"
prompt_yn SMTP_STARTTLS "Enable STARTTLS (false for internal)" "$DEFAULT_SMTP_STARTTLS"
prompt_yn JOIN_MAILU_NET "Join the Mailu Docker network?"   "$DEFAULT_JOIN_MAILU_NET"
[ "$JOIN_MAILU_NET" = "true" ] && prompt MAILU_NETWORK "Mailu Docker network name" "$DEFAULT_MAILU_NETWORK"

echo ""
echo -e "  ${BOLD}── Nginx & SSL ──────────────────────────────────${NC}"
prompt_yn SETUP_NGINX  "Configure Nginx reverse proxy?"    "$DEFAULT_SETUP_NGINX"
if [ "$SETUP_NGINX" = "true" ]; then
  prompt_yn SETUP_SSL  "Request Let's Encrypt SSL cert?"   "$DEFAULT_SETUP_SSL"
  [ "$SETUP_SSL" = "true" ] && prompt ADMIN_EMAIL "Email for Certbot"  "$DEFAULT_ADMIN_EMAIL"
fi

# ── Confirmation ──────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}── Configuration Summary ─────────────────────────────────────────${NC}"
echo -e "  Domain:          ${GREEN}${DOMAIN}${NC}"
echo -e "  Install dir:     ${GREEN}${INSTALL_DIR}${NC}"
echo -e "  App port:        ${GREEN}${APP_PORT}${NC}"
echo -e "  Admin user:      ${GREEN}${ADMIN_USER}${NC}"
echo -e "  SMTP host:       ${GREEN}${SMTP_HOST}:${SMTP_PORT}${NC}"
echo -e "  SMTP user:       ${GREEN}${SMTP_USER}${NC}"
echo -e "  SMTP TLS:        ${GREEN}${SMTP_TLS}${NC} / STARTTLS: ${GREEN}${SMTP_STARTTLS}${NC}"
echo -e "  Join Mailu net:  ${GREEN}${JOIN_MAILU_NET}${NC}"
[ "${JOIN_MAILU_NET:-false}" = "true" ] && echo -e "  Mailu network:   ${GREEN}${MAILU_NETWORK:-mailu_default}${NC}"
echo -e "  Setup Nginx:     ${GREEN}${SETUP_NGINX}${NC}"
[ "$SETUP_NGINX" = "true" ] && echo -e "  Setup SSL:       ${GREEN}${SETUP_SSL:-false}${NC}"
echo -e "${BOLD}${CYAN}──────────────────────────────────────────────────────────────────${NC}"

if [ "$INTERACTIVE" = true ]; then
  echo ""
  read -rp "  Press ${BOLD}ENTER${NC} to continue or ${RED}Ctrl+C${NC} to abort... " _
fi

# ==============================================================================
# SECTION 2: Prerequisites
# ==============================================================================
header "Step 2 — Prerequisites"

# Docker
if ! command -v docker &>/dev/null; then
  info "Installing Docker..."
  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  bash /tmp/get-docker.sh
  rm -f /tmp/get-docker.sh
  systemctl enable --now docker
  success "Docker installed."
else
  success "Docker is already installed: $(docker --version)"
fi

# Docker Compose (v2 plugin)
if ! docker compose version &>/dev/null; then
  info "Installing Docker Compose plugin..."
  apt-get install -y docker-compose-plugin 2>/dev/null \
    || { COMPOSE_VERSION="2.27.1"
         mkdir -p /usr/local/lib/docker/cli-plugins
         curl -SL "https://github.com/docker/compose/releases/download/v${COMPOSE_VERSION}/docker-compose-linux-x86_64" \
              -o /usr/local/lib/docker/cli-plugins/docker-compose
         chmod +x /usr/local/lib/docker/cli-plugins/docker-compose; }
  success "Docker Compose installed."
else
  success "Docker Compose is available: $(docker compose version --short)"
fi

# Nginx (optional)
if [ "$SETUP_NGINX" = "true" ] && ! command -v nginx &>/dev/null; then
  info "Installing Nginx..."
  apt-get update -qq
  apt-get install -y nginx
  success "Nginx installed."
fi

# Certbot (optional)
if [ "${SETUP_SSL:-false}" = "true" ] && ! command -v certbot &>/dev/null; then
  info "Installing Certbot..."
  apt-get install -y certbot python3-certbot-nginx
  success "Certbot installed."
fi

# ==============================================================================
# SECTION 3: Directory & Files
# ==============================================================================
header "Step 3 — Creating Directory Structure"

mkdir -p "${INSTALL_DIR}"/{uploads,static}
cd "${INSTALL_DIR}"

info "Generating .env file..."
cat > "${INSTALL_DIR}/.env" <<ENV
# ── Listmonk Environment ─────────────────────────────────────────────────────
# Generated by setup-listmonk.sh on $(date +"%Y-%m-%d %H:%M:%S")

LISTMONK_DOMAIN=${DOMAIN}
LISTMONK_APP_PORT=${APP_PORT}

# PostgreSQL
POSTGRES_PASSWORD=${DB_PASS}
POSTGRES_USER=listmonk
POSTGRES_DB=listmonk

# Admin credentials (first run only — change after login)
LISTMONK_ADMIN_USER=${ADMIN_USER}
LISTMONK_ADMIN_PASSWORD=${ADMIN_PASS}

# SMTP ─ Mailu internal (no SSL/TLS for internal container-to-container)
SMTP_HOST=${SMTP_HOST}
SMTP_PORT=${SMTP_PORT}
SMTP_USER=${SMTP_USER}
SMTP_PASS=${SMTP_PASS}
SMTP_FROM=${SMTP_FROM}
SMTP_TLS=${SMTP_TLS}
SMTP_STARTTLS=${SMTP_STARTTLS}
ENV
success ".env written to ${INSTALL_DIR}/.env"

# ── config.toml ───────────────────────────────────────────────────────────────
info "Generating config.toml..."
cat > "${INSTALL_DIR}/config.toml" <<TOML
# ── Listmonk Configuration ────────────────────────────────────────────────────
# Generated: $(date +"%Y-%m-%d %H:%M:%S")
# SMTP is configured for Mailu INTERNAL connection (no SSL, no TLS handshake).

[app]
address = "0.0.0.0:9000"
admin_username = "${ADMIN_USER}"
admin_password = "${ADMIN_PASS}"

[db]
host = "listmonk-db"
port = 5432
user = "listmonk"
password = "${DB_PASS}"
database = "listmonk"
ssl_mode = "disable"
max_open = 25
max_idle = 25
max_lifetime = "300s"

# ─────────────────────────────────────────────────────────────────────────────
# SMTP: Mailu internal connection — no SSL/TLS
# Connecting via internal Docker network to Mailu's 'front' container.
# Port 25 = plain SMTP (no encryption handshake) — ideal for trusted internal.
# ─────────────────────────────────────────────────────────────────────────────
[[smtp]]
enabled   = true
host      = "${SMTP_HOST}"
port      = ${SMTP_PORT}
auth_protocol = "plain"
username  = "${SMTP_USER}"
password  = "${SMTP_PASS}"
email_headers = []
max_conns      = 10
max_msg_retries = 2
idle_timeout   = "15s"
wait_timeout   = "5s"
tls_type       = "$([ "${SMTP_TLS}" = "true" ] && echo 'TLS' || ([ "${SMTP_STARTTLS}" = "true" ] && echo 'STARTTLS' || echo 'none'))"
tls_skip_verify = false
TOML
success "config.toml written to ${INSTALL_DIR}/config.toml"

# ── docker-compose.yml ────────────────────────────────────────────────────────
info "Generating docker-compose.yml..."

NETWORKS_SECTION=""
NETWORKS_TOP_LEVEL=""
if [ "${JOIN_MAILU_NET:-false}" = "true" ]; then
  NETWORKS_SECTION="    networks:
      - listmonk_internal
      - ${MAILU_NETWORK:-mailu_default}"
  NETWORKS_TOP_LEVEL="networks:
  listmonk_internal:
    driver: bridge
  ${MAILU_NETWORK:-mailu_default}:
    external: true"
else
  NETWORKS_SECTION="    networks:
      - listmonk_internal"
  NETWORKS_TOP_LEVEL="networks:
  listmonk_internal:
    driver: bridge"
fi

cat > "${INSTALL_DIR}/docker-compose.yml" <<COMPOSE
# ── Listmonk Docker Compose ───────────────────────────────────────────────────
# Generated: $(date +"%Y-%m-%d %H:%M:%S")
# SMTP: Internal Mailu connection — TLS disabled for no-handshake performance.

services:

  listmonk:
    image: listmonk/listmonk:latest
    container_name: listmonk-app
    restart: unless-stopped
    ports:
      - "127.0.0.1:${APP_PORT}:9000"   # Only bind to localhost; Nginx fronts it
    volumes:
      - ./config.toml:/listmonk/config.toml:ro
      - ./uploads:/listmonk/uploads
      - ./static:/listmonk/static
    environment:
      - LISTMONK_db__host=listmonk-db
      - LISTMONK_db__port=5432
      - LISTMONK_db__user=listmonk
      - LISTMONK_db__password=\${POSTGRES_PASSWORD}
      - LISTMONK_db__database=listmonk
      - LISTMONK_db__ssl_mode=disable
    depends_on:
      listmonk-db:
        condition: service_healthy
    command: ["./listmonk", "--config", "/listmonk/config.toml"]
${NETWORKS_SECTION}

  listmonk-db:
    image: postgres:16-alpine
    container_name: listmonk-db
    restart: unless-stopped
    volumes:
      - ./pgdata:/var/lib/postgresql/data
    environment:
      - POSTGRES_USER=listmonk
      - POSTGRES_PASSWORD=\${POSTGRES_PASSWORD}
      - POSTGRES_DB=listmonk
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U listmonk"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - listmonk_internal

${NETWORKS_TOP_LEVEL}
COMPOSE
success "docker-compose.yml written."

# ==============================================================================
# SECTION 4: Deploy
# ==============================================================================
header "Step 4 — Deploying Listmonk"

cd "${INSTALL_DIR}"

info "Pulling Docker images..."
docker compose pull

info "Starting PostgreSQL first (health check)..."
docker compose up -d listmonk-db
info "Waiting for PostgreSQL to be ready..."
RETRIES=0
until docker compose exec -T listmonk-db pg_isready -U listmonk &>/dev/null; do
  RETRIES=$((RETRIES+1))
  [ $RETRIES -ge 30 ] && error "PostgreSQL did not become ready in time."
  sleep 2
done
success "PostgreSQL is ready."

info "Running Listmonk DB migration/install..."
docker compose run --rm listmonk ./listmonk --config /listmonk/config.toml --install --yes \
  2>&1 | grep -E "(error|Error|success|Success|done|Done|skipping|Skipping|INFO)" || true

info "Starting Listmonk..."
docker compose up -d
success "Listmonk stack is running."

# ==============================================================================
# SECTION 5: Nginx Configuration
# ==============================================================================
if [ "$SETUP_NGINX" = "true" ]; then
  header "Step 5 — Nginx Reverse Proxy"

  NGINX_CONF="/etc/nginx/sites-available/listmonk.conf"
  NGINX_LINK="/etc/nginx/sites-enabled/listmonk.conf"

  cat > "$NGINX_CONF" <<NGINX
# ── Listmonk Nginx Config ─────────────────────────────────────────────────────
# Generated: $(date +"%Y-%m-%d %H:%M:%S")
server {
    listen 80;
    server_name ${DOMAIN};

    client_max_body_size 64M;

    # Listmonk app
    location / {
        proxy_pass         http://127.0.0.1:${APP_PORT};
        proxy_http_version 1.1;
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_read_timeout 120s;
        proxy_send_timeout 120s;
    }

    # Subscription / unsubscribe pixel — no auth, cache aggressively
    location ~ ^/(subscription|link|p)/ {
        proxy_pass         http://127.0.0.1:${APP_PORT};
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        add_header         Cache-Control     "no-store";
    }
}
NGINX

  ln -sf "$NGINX_CONF" "$NGINX_LINK"

  if nginx -t; then
    systemctl reload nginx
    success "Nginx configured and reloaded for ${DOMAIN}."
  else
    warn "Nginx config test failed — check ${NGINX_CONF} manually."
  fi

  # ── SSL ─────────────────────────────────────────────────────────────────────
  if [ "${SETUP_SSL:-false}" = "true" ]; then
    header "Step 5b — Let's Encrypt SSL"
    info "Requesting certificate for ${DOMAIN}..."
    certbot --nginx -d "${DOMAIN}" --non-interactive --agree-tos \
      --email "${ADMIN_EMAIL:-admin@${DOMAIN}}" --redirect \
      && success "SSL certificate installed for ${DOMAIN}." \
      || warn "Certbot failed — ensure DNS for ${DOMAIN} points to this server."
  fi
fi

# ==============================================================================
# SECTION 6: Credentials & Summary
# ==============================================================================
header "Step 6 — Saving Credentials"

CRED_FILE="${INSTALL_DIR}/credentials.txt"
cat > "$CRED_FILE" <<CRED
# ── Listmonk Credentials ─────────────────────────────────────────────────────
# Generated: $(date +"%Y-%m-%d %H:%M:%S")
# KEEP THIS FILE SECURE. Do not commit to version control.

Dashboard URL:   https://${DOMAIN}
Admin Username:  ${ADMIN_USER}
Admin Password:  ${ADMIN_PASS}

PostgreSQL:
  Host:          listmonk-db:5432
  Database:      listmonk
  User:          listmonk
  Password:      ${DB_PASS}

SMTP (Mailu Internal):
  Host:          ${SMTP_HOST}
  Port:          ${SMTP_PORT}
  User:          ${SMTP_USER}
  TLS:           ${SMTP_TLS}
  STARTTLS:      ${SMTP_STARTTLS}
  From:          ${SMTP_FROM}

Install directory: ${INSTALL_DIR}
CRED
chmod 600 "$CRED_FILE"
success "Credentials saved to ${CRED_FILE}"

# ── Final Summary ─────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  ✅  Listmonk Installation Complete!${NC}"
echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  🌐 Dashboard:   ${CYAN}https://${DOMAIN}${NC}"
echo -e "  👤 Admin:       ${CYAN}${ADMIN_USER}${NC} / ${CYAN}${ADMIN_PASS}${NC}"
echo -e "  📧 SMTP:        ${CYAN}${SMTP_HOST}:${SMTP_PORT}${NC}  (TLS: ${SMTP_TLS}, STARTTLS: ${SMTP_STARTTLS})"
echo -e "  📁 Install dir: ${CYAN}${INSTALL_DIR}${NC}"
echo -e "  📄 Credentials: ${CYAN}${CRED_FILE}${NC}"
echo ""
echo -e "  ${BOLD}Useful commands:${NC}"
echo -e "    Logs:     ${YELLOW}docker compose -f ${INSTALL_DIR}/docker-compose.yml logs -f${NC}"
echo -e "    Restart:  ${YELLOW}docker compose -f ${INSTALL_DIR}/docker-compose.yml restart${NC}"
echo -e "    Stop:     ${YELLOW}docker compose -f ${INSTALL_DIR}/docker-compose.yml down${NC}"
echo ""
echo -e "  ${BOLD}Mailu SMTP notes:${NC}"
echo -e "    • Port ${SMTP_PORT} with ${SMTP_TLS}/${SMTP_STARTTLS} = no TLS handshake on internal traffic"
echo -e "    • Listmonk is $([ "${JOIN_MAILU_NET:-false}" = "true" ] && echo "joined to ${MAILU_NETWORK:-mailu_default} Docker network" || echo "NOT joined to the Mailu network (use host IP if needed)")"
[ "${JOIN_MAILU_NET:-false}" = "true" ] && \
  echo -e "    • Make sure the Mailu mailbox '${SMTP_USER}' exists and relay is allowed"
echo ""
echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════════════════════${NC}"
