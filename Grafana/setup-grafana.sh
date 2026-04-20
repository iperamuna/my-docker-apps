#!/bin/bash
# ==============================================================================
# Grafana + Prometheus Automated Installer for Ubuntu 22.04/24.04
# Supports: Interactive (prompted) & Non-Interactive (env-var / flag) modes
# ==============================================================================
# Usage:
#   Interactive:       sudo bash setup-grafana.sh
#   Non-Interactive:   sudo bash setup-grafana.sh --no-interaction
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
echo "   ██████╗ ██████╗  █████╗ ███████╗███████╗███╗   ██╗ █████╗ "
echo "  ██╔════╝ ██╔══██╗██╔══██╗██╔════╝██╔════╝████╗  ██║██╔══██╗"
echo "  ██║  ███╗██████╔╝███████║█████╗  █████╗  ██╔██╗ ██║███████║"
echo "  ██║   ██║██╔══██╗██╔══██║██╔══╝  ██╔══╝  ██║╚██╗██║██╔══██║"
echo "  ╚██████╔╝██║  ██║██║  ██║██║     ███████╗██║ ╚████║██║  ██║"
echo "   ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚══════╝╚═╝  ╚═══╝╚═╝  ╚═╝"
echo -e "${NC}"
echo -e "  ${BOLD}Automated Grafana & Prometheus Installer${NC}"
echo -e "  Mode: $([ "$INTERACTIVE" = true ] && echo 'Interactive (Prompted)' || echo 'Non-Interactive (Automated)')"
echo ""

# ==============================================================================
# SECTION 1: Configuration
# ==============================================================================
header "Step 1 — Configuration"

# ── Defaults (override via env vars in non-interactive mode) ──────────────────
DEFAULT_DOMAIN="${GRAFANA_DOMAIN:-monitor.example.com}"
DEFAULT_INSTALL_DIR="${GRAFANA_INSTALL_DIR:-/opt/grafana}"
DEFAULT_ADMIN_USER="${GRAFANA_ADMIN_USER:-admin}"
DEFAULT_ADMIN_PASS="${GRAFANA_ADMIN_PASS:-$(gen_pass)}"
DEFAULT_GRAFANA_PORT="${GRAFANA_PORT:-3000}"
DEFAULT_PROMETHEUS_PORT="${PROMETHEUS_PORT:-9090}"

# ── Nginx / Certbot ───────────────────────────────────────────────────────────
DEFAULT_SETUP_NGINX="${SETUP_NGINX:-true}"
DEFAULT_SETUP_SSL="${SETUP_SSL:-true}"
DEFAULT_ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"

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
prompt DOMAIN          "Public domain for Grafana"         "$DEFAULT_DOMAIN"
prompt INSTALL_DIR     "Install directory"                 "$DEFAULT_INSTALL_DIR"
prompt GRAFANA_PORT    "Grafana app port (internal)"       "$DEFAULT_GRAFANA_PORT"
prompt ADMIN_USER      "Admin username"                    "$DEFAULT_ADMIN_USER"
prompt ADMIN_PASS      "Admin password"                    "$DEFAULT_ADMIN_PASS"

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
echo -e "  Admin user:      ${GREEN}${ADMIN_USER}${NC}"
echo -e "  Grafana Port:    ${GREEN}${GRAFANA_PORT}${NC}"
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

# ==============================================================================
# SECTION 3: Directory & Files
# ==============================================================================
header "Step 3 — Creating Directory Structure"

mkdir -p "${INSTALL_DIR}"/{grafana-storage,prometheus-storage,prometheus-config}
cd "${INSTALL_DIR}"

chown -R 472:472 "${INSTALL_DIR}/grafana-storage" # Grafana user
chown -R 65534:65534 "${INSTALL_DIR}/prometheus-storage" # Nobody user for prometheus

info "Generating .env file..."
cat > "${INSTALL_DIR}/.env" <<ENV
# ── Grafana/Prometheus Environment ───────────────────────────────────────────
# Generated by setup-grafana.sh on $(date +"%Y-%m-%d %H:%M:%S")

GRAFANA_DOMAIN=${DOMAIN}
GRAFANA_PORT=${GRAFANA_PORT}
PROMETHEUS_PORT=${DEFAULT_PROMETHEUS_PORT}

GF_SECURITY_ADMIN_USER=${ADMIN_USER}
GF_SECURITY_ADMIN_PASSWORD=${ADMIN_PASS}
ENV
success ".env written to ${INSTALL_DIR}/.env"

# ── prometheus.yml ────────────────────────────────────────────────────────────
info "Generating prometheus.yml..."
cat > "${INSTALL_DIR}/prometheus-config/prometheus.yml" <<YAML
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
YAML
success "prometheus.yml written to ${INSTALL_DIR}/prometheus-config/prometheus.yml"

# ── docker-compose.yml ────────────────────────────────────────────────────────
info "Generating docker-compose.yml..."
cat > "${INSTALL_DIR}/docker-compose.yml" <<COMPOSE
services:
  grafana:
    image: grafana/grafana-enterprise:latest
    container_name: grafana
    restart: unless-stopped
    ports:
      - "127.0.0.1:\${GRAFANA_PORT}:3000"
    user: "472"
    volumes:
      - ./grafana-storage:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_USER=\${GF_SECURITY_ADMIN_USER}
      - GF_SECURITY_ADMIN_PASSWORD=\${GF_SECURITY_ADMIN_PASSWORD}
      - GF_SERVER_ROOT_URL=https://\${GRAFANA_DOMAIN}/
      - GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-simple-json-datasource
    networks:
      - monitor-net
    depends_on:
      - prometheus

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    volumes:
      - ./prometheus-config/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./prometheus-storage:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
      - '--storage.tsdb.retention.time=15d' # Keep metrics for 15 days
    ports:
      - "127.0.0.1:\${PROMETHEUS_PORT}:9090"
    user: "65534"
    networks:
      - monitor-net

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc|rootfs/var/lib/docker/containers|rootfs/var/lib/docker/overlay2|rootfs/run/docker/netns|rootfs/var/lib/docker/aufs)($$|/)'
    networks:
      - monitor-net

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:v0.49.1
    container_name: cadvisor
    restart: unless-stopped
    privileged: true
    devices:
      - /dev/kmsg:/dev/kmsg
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    networks:
      - monitor-net

networks:
  monitor-net:
    driver: bridge
COMPOSE
success "docker-compose.yml written."

# ==============================================================================
# SECTION 4: Deploy
# ==============================================================================
header "Step 4 — Deploying Stack"

cd "${INSTALL_DIR}"
info "Pulling Docker images..."
docker compose pull
info "Starting Stack..."
docker compose up -d
success "Monitoring stack is running."

# ==============================================================================
# SECTION 5: Nginx Configuration
# ==============================================================================
if [ "$SETUP_NGINX" = "true" ]; then
  header "Step 5 — Nginx Reverse Proxy"

  NGINX_CONF="/etc/nginx/sites-available/grafana.conf"
  NGINX_LINK="/etc/nginx/sites-enabled/grafana.conf"

  cat > "$NGINX_CONF" <<NGINX
# ── Grafana Nginx Config ─────────────────────────────────────────────────────
# Generated: $(date +"%Y-%m-%d %H:%M:%S")
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass         http://127.0.0.1:${GRAFANA_PORT};
        proxy_http_version 1.1;
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_set_header   Upgrade \$http_upgrade;
        proxy_set_header   Connection "upgrade";
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
# ── Grafana Credentials ─────────────────────────────────────────────────────
# Generated: $(date +"%Y-%m-%d %H:%M:%S")
# KEEP THIS FILE SECURE. Do not commit to version control.

Dashboard URL:   https://${DOMAIN}
Admin Username:  ${ADMIN_USER}
Admin Password:  ${ADMIN_PASS}

Prometheus (Internal): 
  Target URL inside Grafana: http://prometheus:9090

Install directory: ${INSTALL_DIR}
CRED
chmod 600 "$CRED_FILE"
success "Credentials saved to ${CRED_FILE}"

# ── Final Summary ─────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  ✅  Grafana & Prometheus Installation Complete!${NC}"
echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  🌐 Dashboard:   ${CYAN}https://${DOMAIN}${NC}"
echo -e "  👤 Admin:       ${CYAN}${ADMIN_USER}${NC} / ${CYAN}${ADMIN_PASS}${NC}"
echo -e "  📁 Install dir: ${CYAN}${INSTALL_DIR}${NC}"
echo -e "  📄 Credentials: ${CYAN}${CRED_FILE}${NC}"
echo ""
echo -e "  ${BOLD}Useful commands:${NC}"
echo -e "    Logs:     ${YELLOW}docker compose -f ${INSTALL_DIR}/docker-compose.yml logs -f${NC}"
echo -e "    Restart:  ${YELLOW}docker compose -f ${INSTALL_DIR}/docker-compose.yml restart${NC}"
echo -e "    Stop:     ${YELLOW}docker compose -f ${INSTALL_DIR}/docker-compose.yml down${NC}"
echo ""
echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════════════════════${NC}"
