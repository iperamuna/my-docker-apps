#!/bin/bash
# ==============================================================================
# Nextcloud Automated Installer for Ubuntu 22.04/24.04
# Supports: Interactive (prompted) & Non-Interactive (env-var / flag) modes
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

gen_pass()   { openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 24 || true; }

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
echo -e "${BOLD}${CYAN}"
echo "  ███╗   ██╗███████╗██╗  ██╗████████╗ ██████╗██╗      ██████╗ ██╗   ██╗██████╗ "
echo "  ████╗  ██║██╔════╝╚██╗██╔╝╚══██╔══╝██╔════╝██║     ██╔═══██╗██║   ██║██╔══██╗"
echo "  ██╔██╗ ██║█████╗   ╚███╔╝    ██║   ██║     ██║     ██║   ██║██║   ██║██║  ██║"
echo "  ██║╚██╗██║██╔══╝   ██╔██╗    ██║   ██║     ██║     ██║   ██║██║   ██║██║  ██║"
echo "  ██║ ╚████║███████╗██╔╝ ██╗   ██║   ╚██████╗███████╗╚██████╔╝╚██████╔╝██████╔╝"
echo "  ╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝   ╚═╝    ╚═════╝╚══════╝ ╚═════╝  ╚═════╝ ╚═════╝ "
echo -e "${NC}"
echo -e "  ${BOLD}Automated Nextcloud Installer${NC}"
echo -e "  Mode: $([ "$INTERACTIVE" = true ] && echo 'Interactive (Prompted)' || echo 'Non-Interactive (Automated)')"
echo ""

# ==============================================================================
# SECTION 1: Configuration
# ==============================================================================
header "Step 1 — Configuration"

# ── Defaults (override via env vars in non-interactive mode) ──────────────────
DEFAULT_DOMAIN="${NEXTCLOUD_DOMAIN:-cloud.ravact.com}"
DEFAULT_INSTALL_DIR="${NEXTCLOUD_INSTALL_DIR:-/opt/nextcloud}"
DEFAULT_APP_PORT="${NEXTCLOUD_APP_PORT:-8888}"
DEFAULT_DB_PASS="${NEXTCLOUD_DB_PASS:-$(gen_pass)}"

# ── Nginx / Certbot ───────────────────────────────────────────────────────────
DEFAULT_SETUP_NGINX="${SETUP_NGINX:-true}"
DEFAULT_SETUP_SSL="${SETUP_SSL:-true}"
DEFAULT_ADMIN_EMAIL="${ADMIN_EMAIL:-admin@ravact.com}"

prompt() {
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
prompt DOMAIN          "Public domain for Nextcloud"       "$DEFAULT_DOMAIN"
prompt INSTALL_DIR     "Install directory"                 "$DEFAULT_INSTALL_DIR"
prompt APP_PORT        "Nextcloud app port (internal)"     "$DEFAULT_APP_PORT"
prompt DB_PASS         "PostgreSQL password"               "$DEFAULT_DB_PASS"

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

if ! docker compose version &>/dev/null; then
  info "Installing Docker Compose plugin..."
  apt-get install -y docker-compose-plugin 2>/dev/null
  success "Docker Compose installed."
else
  success "Docker Compose is available: $(docker compose version --short)"
fi

if [ "$SETUP_NGINX" = "true" ] && ! command -v nginx &>/dev/null; then
  info "Installing Nginx..."
  apt-get update -qq
  apt-get install -y nginx
  success "Nginx installed."
fi

if [ "${SETUP_SSL:-false}" = "true" ] && ! command -v certbot &>/dev/null; then
  info "Installing Certbot..."
  apt-get install -y certbot python3-certbot-nginx
  success "Certbot installed."
fi

# ==============================================================================
# SECTION 3: Directory & Files
# ==============================================================================
header "Step 3 — Creating Directory Structure"

mkdir -p "${INSTALL_DIR}"/data/{nextcloud_data,pg_data,redis_data}
cd "${INSTALL_DIR}"

info "Generating .env file..."
cat > "${INSTALL_DIR}/.env" <<ENV
# ── Nextcloud Environment ────────────────────────────────────────────────────
# Generated by setup-nextcloud.sh on $(date +"%Y-%m-%d %H:%M:%S")

# Postgres creds
POSTGRES_USER=nextcloud
POSTGRES_PASSWORD=${DB_PASS}
POSTGRES_DB=nextcloud

# Domain
NEXTCLOUD_TRUSTED_DOMAINS=${DOMAIN}
ENV
chmod 600 "${INSTALL_DIR}/.env"
success ".env written to ${INSTALL_DIR}/.env"

info "Generating docker-compose.yml..."
cat > "${INSTALL_DIR}/docker-compose.yml" <<COMPOSE
# ── Nextcloud Docker Compose ─────────────────────────────────────────────────
# Generated: $(date +"%Y-%m-%d %H:%M:%S")

version: "3"

services:
  db:
    container_name: nextcloud-db
    image: postgres:14-alpine
    restart: always
    env_file: .env
    volumes:
      - ./data/pg_data:/var/lib/postgresql/data
    networks:
      - nextcloud_net
    healthcheck:
      test: "pg_isready --username=\$\${POSTGRES_USER} && psql --username=\$\${POSTGRES_USER} --list"
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:alpine
    container_name: nextcloud-redis
    restart: always
    networks:
      - nextcloud_net
    volumes:
      - ./data/redis_data:/data

  app:
    container_name: nextcloud-app
    image: nextcloud:latest
    restart: always
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    env_file: .env
    environment:
      - POSTGRES_HOST=db
      - REDIS_HOST=redis
      - OVERWRITEPROTOCOL=https
      - OVERWRITEHOST=${DOMAIN}
      - OVERWRITECLIURL=https://${DOMAIN}
      - TRUSTED_PROXIES=127.0.0.1
    ports:
      - "127.0.0.1:${APP_PORT}:80"
    volumes:
      - ./data/nextcloud_data:/var/www/html
    networks:
      - nextcloud_net

networks:
  nextcloud_net:
    driver: bridge
COMPOSE
success "docker-compose.yml written."

# ==============================================================================
# SECTION 4: Deploy
# ==============================================================================
header "Step 4 — Deploying Nextcloud"

cd "${INSTALL_DIR}"

info "Pulling Docker images..."
docker compose pull

info "Starting Database & Redis..."
docker compose up -d db redis
info "Waiting for PostgreSQL to be ready..."
RETRIES=0
until docker compose exec -T db pg_isready -U nextcloud &>/dev/null; do
  RETRIES=$((RETRIES+1))
  [ $RETRIES -ge 30 ] && error "PostgreSQL did not become ready in time."
  sleep 2
done
success "PostgreSQL is ready."

info "Starting Nextcloud App..."
docker compose up -d
success "Nextcloud stack is running."

# ==============================================================================
# SECTION 5: Nginx Configuration
# ==============================================================================
if [ "$SETUP_NGINX" = "true" ]; then
  header "Step 5 — Nginx Reverse Proxy"

  NGINX_CONF="/etc/nginx/sites-available/nextcloud.conf"
  NGINX_LINK="/etc/nginx/sites-enabled/nextcloud.conf"

  cat > "$NGINX_CONF" <<NGINX
# ── Nextcloud Nginx Config ────────────────────────────────────────────────────
# Generated: $(date +"%Y-%m-%d %H:%M:%S")
server {
    listen 80;
    server_name ${DOMAIN};

    # Nextcloud specific settings
    client_max_body_size 512M;
    client_body_timeout 300s;

    # Headers
    add_header Strict-Transport-Security "max-age=15768000; includeSubDomains; preload;" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Robots-Tag "noindex, nofollow" always;
    add_header X-Download-Options "noopen" always;
    add_header X-Permitted-Cross-Domain-Policies "none" always;
    add_header Referrer-Policy "no-referrer" always;
    fastcgi_hide_header X-Powered-By;

    location / {
        proxy_pass         http://127.0.0.1:${APP_PORT};
        proxy_http_version 1.1;
        proxy_set_header   Host \$host;
        proxy_set_header   X-Real-IP \$remote_addr;
        proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_set_header   Upgrade \$http_upgrade;
        proxy_set_header   Connection "upgrade";
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }
    
    # Required for CalDAV/CardDAV discovery
    location = /.well-known/carddav {
      return 301 \$scheme://\$host/remote.php/dav;
    }
    location = /.well-known/caldav {
      return 301 \$scheme://\$host/remote.php/dav;
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
# ── Nextcloud Credentials ────────────────────────────────────────────────────
# Generated: $(date +"%Y-%m-%d %H:%M:%S")
# KEEP THIS FILE SECURE. Do not commit to version control.

Dashboard URL:   https://${DOMAIN}

PostgreSQL:
  Host:          nextcloud-db:5432
  Database:      nextcloud
  User:          nextcloud
  Password:      ${DB_PASS}

Install directory: ${INSTALL_DIR}
CRED
chmod 600 "$CRED_FILE"
success "Credentials saved to ${CRED_FILE}"

# ── Final Summary ─────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  ✅  Nextcloud Installation Complete!${NC}"
echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  🌐 Dashboard:   ${CYAN}https://${DOMAIN}${NC}"
echo -e "  📁 Install dir: ${CYAN}${INSTALL_DIR}${NC}"
echo -e "  📄 Credentials: ${CYAN}${CRED_FILE}${NC}"
echo ""
echo -e "  ${BOLD}Next Steps:${NC}"
echo -e "    1. Navigate to ${CYAN}https://${DOMAIN}${NC} to create your initial admin account."
echo -e "    2. The web interface will ask you for an admin username and password. Enter them and finish setup."
echo ""
echo -e "  ${BOLD}Useful commands:${NC}"
echo -e "    Logs:     ${YELLOW}docker compose -f ${INSTALL_DIR}/docker-compose.yml logs -f${NC}"
echo -e "    Restart:  ${YELLOW}docker compose -f ${INSTALL_DIR}/docker-compose.yml restart${NC}"
echo -e "    Stop:     ${YELLOW}docker compose -f ${INSTALL_DIR}/docker-compose.yml down${NC}"
echo ""
echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════════════════════${NC}"
