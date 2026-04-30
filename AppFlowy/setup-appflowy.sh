#!/bin/bash
# ==============================================================================
# AppFlowy Cloud Automated Installer for Ubuntu 22.04/24.04
# Supports: Interactive (prompted) & Non-Interactive (env-var / flag) modes
# ==============================================================================
# Usage:
#   Interactive:       sudo bash setup-appflowy.sh
#   Non-Interactive:   sudo bash setup-appflowy.sh --no-interaction
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
# clear (Removed for non-interactive compatibility)
echo -e "${BOLD}${CYAN}"
echo "  █████╗ ██████╗ ██████╗ ███████╗██╗      ██████╗ ██╗    ██╗██╗   ██╗"
echo "  ██╔══██╗██╔══██╗██╔══██╗██╔════╝██║     ██╔═══██╗██║    ██║╚██╗ ██╔╝"
echo "  ███████║██████╔╝██████╔╝█████╗  ██║     ██║   ██║██║ █╗ ██║ ╚████╔╝ "
echo "  ██╔══██║██╔═══╝ ██╔═══╝ ██╔══╝  ██║     ██║   ██║██║███╗██║  ╚██╔╝  "
echo "  ██║  ██║██║     ██║     ██║     ███████╗╚██████╔╝╚███╔███╔╝   ██║   "
echo "  ╚═╝  ╚═╝╚═╝     ╚═╝     ╚═╝     ╚══════╝ ╚═════╝  ╚══╝╚══╝    ╚═╝   "
echo -e "${NC}"
echo -e "  ${BOLD}Automated AppFlowy Cloud Installer${NC}"
echo -e "  Mode: $([ "$INTERACTIVE" = true ] && echo 'Interactive (Prompted)' || echo 'Non-Interactive (Automated)')"
echo ""

# ==============================================================================
# SECTION 1: Configuration
# ==============================================================================
header "Step 1 — Configuration"

# ── Defaults ──────────────────────────────────────────────────────────────────
DEFAULT_DOMAIN="${AF_DOMAIN:-af.siyalude.io}"
DEFAULT_INSTALL_DIR="${AF_INSTALL_DIR:-/opt/appflowy}"
DEFAULT_INTERNAL_PORT="${AF_PORT:-8080}"

# ── Nginx / Certbot ───────────────────────────────────────────────────────────
DEFAULT_SETUP_NGINX="${SETUP_NGINX:-true}"
DEFAULT_SETUP_SSL="${SETUP_SSL:-true}"
DEFAULT_ADMIN_EMAIL="${ADMIN_EMAIL:-admin@siyalude.io}"

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
prompt DOMAIN          "Public domain for AppFlowy"        "$DEFAULT_DOMAIN"
prompt INSTALL_DIR     "Install directory"                 "$DEFAULT_INSTALL_DIR"
prompt APP_PORT        "Internal Port for AppFlowy Nginx"  "$DEFAULT_INTERNAL_PORT"

echo ""
echo -e "  ${BOLD}── Nginx & SSL ──────────────────────────────────${NC}"
prompt_yn SETUP_NGINX  "Configure host Nginx reverse proxy?" "$DEFAULT_SETUP_NGINX"
if [ "$SETUP_NGINX" = "true" ]; then
  prompt_yn SETUP_SSL  "Request Let's Encrypt SSL cert?"   "$DEFAULT_SETUP_SSL"
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
  success "Docker is already installed: $(docker --version)"
fi

# Docker Compose
if ! docker compose version &>/dev/null; then
  info "Installing Docker Compose plugin..."
  apt-get update && apt-get install -y docker-compose-plugin
  success "Docker Compose installed."
else
  success "Docker Compose is available."
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
  apt-get install -y certbot python3-certbot-nginx
  success "Certbot installed."
fi

# Git
if ! command -v git &>/dev/null; then
  info "Installing Git..."
  apt-get install -y git
  success "Git installed."
fi

# ==============================================================================
# SECTION 3: Clone & Configure
# ==============================================================================
header "Step 3 — Setting up AppFlowy Cloud"

if [ ! -d "$INSTALL_DIR" ]; then
  info "Cloning AppFlowy Cloud repository..."
  git clone https://github.com/AppFlowy-IO/AppFlowy-Cloud.git "$INSTALL_DIR"
else
  info "Directory already exists, updating repo..."
  cd "$INSTALL_DIR" && git pull
fi

cd "$INSTALL_DIR"

info "Generating .env file..."
cp deploy.env .env

# Generate random secrets
JWT_SECRET=$(openssl rand -base64 32)
POSTGRES_PWD=$(openssl rand -base64 16)
ADMIN_PWD=$(openssl rand -base64 12)

# Update .env with our settings
sed -i "s|^FQDN=.*|FQDN=${DOMAIN}|" .env
sed -i "s|^SCHEME=.*|SCHEME=https|" .env
sed -i "s|^WS_SCHEME=.*|WS_SCHEME=wss|" .env
sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${POSTGRES_PWD}|" .env
sed -i "s|^GOTRUE_JWT_SECRET=.*|GOTRUE_JWT_SECRET=${JWT_SECRET}|" .env
sed -i "s|^GOTRUE_ADMIN_EMAIL=.*|GOTRUE_ADMIN_EMAIL=${ADMIN_EMAIL}|" .env
sed -i "s|^GOTRUE_ADMIN_PASSWORD=.*|GOTRUE_ADMIN_PASSWORD=${ADMIN_PWD}|" .env
sed -i "s|^GOTRUE_SITE_URL=.*|GOTRUE_SITE_URL=${SCHEME}://${DOMAIN}|" .env || echo "GOTRUE_SITE_URL=${SCHEME}://${DOMAIN}" >> .env
sed -i "s|^GOTRUE_URI_ALLOW_LIST=.*|GOTRUE_URI_ALLOW_LIST=${SCHEME}://${DOMAIN}/*|" .env || echo "GOTRUE_URI_ALLOW_LIST=${SCHEME}://${DOMAIN}/*" >> .env
sed -i "s|^NGINX_PORT=.*|NGINX_PORT=${APP_PORT}|" .env
sed -i "s|^NGINX_TLS_PORT=.*|NGINX_TLS_PORT=8443|" .env

# Resend SMTP Configuration
sed -i "s|^GOTRUE_SMTP_HOST=.*|GOTRUE_SMTP_HOST=smtp.resend.com|" .env
sed -i "s|^GOTRUE_SMTP_PORT=.*|GOTRUE_SMTP_PORT=465|" .env
sed -i "s|^GOTRUE_SMTP_USER=.*|GOTRUE_SMTP_USER=resend|" .env
sed -i "s|^GOTRUE_SMTP_PASS=.*|GOTRUE_SMTP_PASS=re_iUC1yTMM_6NffDCDywYjT3yRuTWc1AiRu|" .env
sed -i "s|^GOTRUE_SMTP_ADMIN_EMAIL=.*|GOTRUE_SMTP_ADMIN_EMAIL=AF SiyaludeIO <info@siyalude.io>|" .env
sed -i "s|^APPFLOWY_MAILER_SMTP_HOST=.*|APPFLOWY_MAILER_SMTP_HOST=smtp.resend.com|" .env
sed -i "s|^APPFLOWY_MAILER_SMTP_PORT=.*|APPFLOWY_MAILER_SMTP_PORT=465|" .env
sed -i "s|^APPFLOWY_MAILER_SMTP_USERNAME=.*|APPFLOWY_MAILER_SMTP_USERNAME=resend|" .env
sed -i "s|^APPFLOWY_MAILER_SMTP_EMAIL=.*|APPFLOWY_MAILER_SMTP_EMAIL=AF SiyaludeIO <info@siyalude.io>|" .env
sed -i "s|^APPFLOWY_MAILER_SMTP_PASSWORD=.*|APPFLOWY_MAILER_SMTP_PASSWORD=re_iUC1yTMM_6NffDCDywYjT3yRuTWc1AiRu|" .env
sed -i "s|^APPFLOWY_MAILER_SMTP_TLS_KIND=.*|APPFLOWY_MAILER_SMTP_TLS_KIND=wrapper|" .env
sed -i "s|^GOTRUE_MAILER_AUTOCONFIRM=.*|GOTRUE_MAILER_AUTOCONFIRM=false|" .env

success ".env file configured."

# ==============================================================================
# SECTION 4: Deploy
# ==============================================================================
header "Step 4 — Deploying Application"

info "Pulling Docker images..."
docker compose pull
info "Starting AppFlowy Cloud (this may take a few minutes)..."
docker compose up -d

success "AppFlowy Cloud containers started."

# ==============================================================================
# SECTION 5: Nginx Configuration
# ==============================================================================
if [ "$SETUP_NGINX" = "true" ]; then
  header "Step 5 — Host Nginx Reverse Proxy"

  NGINX_CONF="/etc/nginx/sites-available/appflowy.conf"
  NGINX_LINK="/etc/nginx/sites-enabled/appflowy.conf"

  cat > "$NGINX_CONF" <<NGINX
# ── AppFlowy Cloud Nginx Config ──────────────────────────────────────────────
# Generated: $(date +"%Y-%m-%d %H:%M:%S")
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
        proxy_set_header   Upgrade           \$http_upgrade;
        proxy_set_header   Connection        "upgrade";
        
        # Increase timeouts for large uploads/syncs
        proxy_connect_timeout 600s;
        proxy_send_timeout    600s;
        proxy_read_timeout    600s;
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
    info "Requesting certificate for ${DOMAIN}..."
    certbot --nginx -d "${DOMAIN}" --non-interactive --agree-tos \
      --email "${ADMIN_EMAIL}" --redirect \
      && success "SSL certificate installed for ${DOMAIN}." \
      || warn "Certbot failed — ensure DNS for ${DOMAIN} points to this server."
  fi
fi

# ==============================================================================
# SECTION 6: Summary
# ==============================================================================
header "Step 6 — Installation Complete"

echo -e "  🌐 Dashboard:       ${CYAN}https://${DOMAIN}${NC}"
echo -e "  🔧 Admin Console:    ${CYAN}https://${DOMAIN}/console${NC}"
echo -e "  📁 Install dir:     ${CYAN}${INSTALL_DIR}${NC}"
echo -e "  🔑 Admin Email:     ${GREEN}${ADMIN_EMAIL}${NC}"
echo -e "  🔑 Admin Password:  ${YELLOW}${ADMIN_PWD}${NC}"
echo ""
echo -e "  ${YELLOW}IMPORTANT:${NC} Save your Admin Password above! You'll need it to log in."
echo ""
echo -e "  ${BOLD}Useful commands:${NC}"
echo -e "    Logs:     ${YELLOW}cd ${INSTALL_DIR} && docker compose logs -f${NC}"
echo -e "    Restart:  ${YELLOW}cd ${INSTALL_DIR} && docker compose restart${NC}"
echo -e "    Status:   ${YELLOW}cd ${INSTALL_DIR} && docker compose ps${NC}"
echo ""
echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════════════════════${NC}"
