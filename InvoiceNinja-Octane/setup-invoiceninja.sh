#!/bin/bash
# ==============================================================================
# Invoice Ninja Octane Automated Installer for Ubuntu 22.04/24.04
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
echo "  ██╗███╗   ██╗██╗   ██╗ ██████╗ ██╗ ██████╗███████╗    ███╗   ██╗██╗███╗   ██╗     ██╗ █████╗ "
echo "  ██║████╗  ██║██║   ██║██╔═══██╗██║██╔════╝██╔════╝    ████╗  ██║██║████╗  ██║     ██║██╔══██╗"
echo "  ██║██╔██╗ ██║██║   ██║██║   ██║██║██║     █████╗      ██╔██╗ ██║██║██╔██╗ ██║     ██║███████║"
echo "  ██║██║╚██╗██║╚██╗ ██╔╝██║   ██║██║██║     ██╔══╝      ██║╚██╗██║██║██║╚██╗██║██   ██║██╔══██║"
echo "  ██║██║ ╚████║ ╚████╔╝ ╚██████╔╝██║╚██████╗███████╗    ██║ ╚████║██║██║ ╚████║╚█████╔╝██║  ██║"
echo "  ╚═╝╚═╝  ╚═══╝  ╚═══╝   ╚═════╝ ╚═╝ ╚═════╝╚══════╝    ╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝ ╚════╝ ╚═╝  ╚═╝"
echo -e "${NC}"
echo -e "  ${BOLD}Invoice Ninja Octane Installer${NC}"
echo -e "  Mode: $([ "$INTERACTIVE" = true ] && echo 'Interactive (Prompted)' || echo 'Non-Interactive (Automated)')"
echo ""

# ==============================================================================
# SECTION 1: Configuration
# ==============================================================================
header "Step 1 — Configuration"

DEFAULT_DOMAIN="invoice.siyalude.io"
DEFAULT_INSTALL_DIR="/opt/invoiceninja"
DEFAULT_APP_PORT="9121"
DEFAULT_ADMIN_EMAIL="admin@siyalude.io"

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
prompt DOMAIN          "Public domain for Invoice Ninja"   "$DEFAULT_DOMAIN"
prompt INSTALL_DIR     "Install directory"                 "$DEFAULT_INSTALL_DIR"
prompt APP_PORT        "Internal Port for Octane"          "$DEFAULT_APP_PORT"

echo ""
echo -e "  ${BOLD}── Nginx & SSL ──────────────────────────────────${NC}"
prompt_yn SETUP_NGINX  "Configure host Nginx reverse proxy?" "true"
if [ "$SETUP_NGINX" = "true" ]; then
  prompt_yn SETUP_SSL  "Request Let's Encrypt SSL cert?"   "true"
  [ "$SETUP_SSL" = "true" ] && prompt ADMIN_EMAIL "Email for Certbot"  "$DEFAULT_ADMIN_EMAIL"
fi

# ── Confirmation ──────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}── Configuration Summary ─────────────────────────────────────────${NC}"
echo -e "  Domain:          ${GREEN}${DOMAIN}${NC}"
echo -e "  Install dir:     ${GREEN}${INSTALL_DIR}${NC}"
echo -e "  Internal Port:   ${GREEN}${APP_PORT}${NC}"
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
  success "Docker is already installed."
fi

# Nginx
if [ "$SETUP_NGINX" = "true" ] && ! command -v nginx &>/dev/null; then
  info "Installing Nginx..."
  apt-get update -qq
  apt-get install -y nginx
  success "Nginx installed."
fi

# Certbot
if [ "${SETUP_SSL:-false}" = "true" ] && ! command -v certbot &>/dev/null; then
  info "Installing Certbot..."
  apt-get update -qq
  apt-get install -y certbot python3-certbot-nginx
  success "Certbot installed."
fi

# ==============================================================================
# SECTION 3: Files & Configuration
# ==============================================================================
header "Step 3 — Setting up Invoice Ninja"

mkdir -p "$INSTALL_DIR"
# Copy files from current directory to install dir if running from repo
if [ -f "docker-compose.yml" ]; then
    cp docker-compose.yml "$INSTALL_DIR/"
    cp .env.example "$INSTALL_DIR/"
fi

cd "$INSTALL_DIR"

# Generate random secrets
DB_PWD=$(openssl rand -hex 16)
DB_ROOT_PWD=$(openssl rand -hex 16)

info "Generating .env file..."
if [ ! -f .env ]; then
    cat > .env <<EOF
APP_URL=https://${DOMAIN}
APP_KEY=base64:$(openssl rand -base64 32)
APP_DEBUG=false
APP_ENV=production
IN_USER_EMAIL=${ADMIN_EMAIL}
IN_PASSWORD=$(openssl rand -base64 12)
APP_PORT=${APP_PORT}

DB_TYPE=mysql
DB_STRICT=false
DB_HOST=db
DB_DATABASE=ninja
DB_USERNAME=ninja
DB_PASSWORD=${DB_PWD}

REDIS_HOST=redis
REDIS_PORT=6379

PDF_GENERATOR=snappdf
SNAPP_PDF_ENABLED=true

REQUIRE_HTTPS=true
TRUSTED_PROXIES=*
PHANTOMJS_PDF_GENERATION=false

MARIADB_DATABASE=ninja
MARIADB_USER=ninja
MARIADB_PASSWORD=${DB_PWD}
MARIADB_ROOT_PASSWORD=${DB_ROOT_PWD}
EOF
    success ".env file created with generated secrets."
else
    warn ".env file already exists, skipping generation."
fi

# Ensure storage and public directories exist and have correct permissions
mkdir -p storage public docker/mysql/data
chmod -R 777 storage public
# Attempt to set ownership if running as root
chown -R 1500:1500 storage public || true

# ==============================================================================
# SECTION 4: Deploy
# ==============================================================================
header "Step 4 — Deploying Application"

info "Starting Invoice Ninja containers..."
docker compose up -d

success "Invoice Ninja containers started."

# ==============================================================================
# SECTION 5: Nginx Configuration
# ==============================================================================
if [ "$SETUP_NGINX" = "true" ]; then
  header "Step 5 — Host Nginx Reverse Proxy"

  NGINX_CONF="/etc/nginx/sites-available/invoiceninja.conf"
  NGINX_LINK="/etc/nginx/sites-enabled/invoiceninja.conf"

  cat > "$NGINX_CONF" <<NGINX
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass         http://127.0.0.1:${APP_PORT};
        proxy_http_version 1.1;
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        
        client_max_body_size  100M;
    }
}
NGINX

  ln -sf "$NGINX_CONF" "$NGINX_LINK"

  if nginx -t; then
    systemctl reload nginx
    success "Host Nginx configured and reloaded for ${DOMAIN}."
  else
    warn "Nginx config test failed — check ${NGINX_CONF} manually."
  fi

  # ── SSL ─────────────────────────────────────────────────────────────────────
  if [ "${SETUP_SSL:-false}" = "true" ]; then
    header "Step 5b — Let's Encrypt SSL"
    certbot --nginx -d "${DOMAIN}" --non-interactive --agree-tos \
      --email "${ADMIN_EMAIL}" --redirect \
      && success "SSL certificate installed for ${DOMAIN}." \
      || warn "Certbot failed — ensure DNS for ${DOMAIN} points to this server."
  fi
fi

# ==============================================================================
# SECTION 6: Post-Install
# ==============================================================================
header "Step 6 — Finalizing"

info "Running migrations and optimization..."
# Give DB time to start
info "Waiting for database to be ready..."
sleep 15
docker compose exec -it server php artisan migrate --force
docker compose exec -it server php artisan optimize

header "Installation Complete"

echo -e "  🌐 URL:             ${CYAN}https://${DOMAIN}${NC}"
echo -e "  📁 Install dir:     ${CYAN}${INSTALL_DIR}${NC}"
echo ""
echo -e "  ${BOLD}Next Steps:${NC}"
echo -e "    1. Visit the URL and complete the setup wizard."
echo -e "    2. Use the database credentials from ${INSTALL_DIR}/.env if prompted."
echo ""
echo -e "  ${BOLD}Useful commands:${NC}"
echo -e "    Logs:     ${YELLOW}cd ${INSTALL_DIR} && docker compose logs -f${NC}"
echo -e "    Restart:  ${YELLOW}cd ${INSTALL_DIR} && docker compose restart${NC}"
echo -e "    Status:   ${YELLOW}cd ${INSTALL_DIR} && docker compose ps${NC}"
echo ""
echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════════════════════${NC}"
