#!/bin/bash
# ==============================================================================
# Invoice Ninja Octane Automated Teardown
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
header()  { echo -e "\n${BOLD}${RED}══════════════════════════════════════════${NC}"; echo -e "${BOLD}${RED}  $*${NC}"; echo -e "${BOLD}${RED}══════════════════════════════════════════${NC}\n"; }

# ── Root check ────────────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && error "Run as root: sudo bash $0"

# ── Banner ────────────────────────────────────────────────────────────────────
echo -e "${BOLD}${RED}"
echo "  ████████╗███████╗ █████╗ ██████╗ ██████╗  ██████╗ ██╗    ██╗███╗   ██╗"
echo "  ╚══██╔══╝██╔════╝██╔══██╗██╔══██╗██╔══██╗██╔═══██╗██║    ██║████╗  ██║"
echo "     ██║   █████╗  ███████║██████╔╝██║  ██║██║   ██║██║ █╗ ██║██╔██╗ ██║"
echo "     ██║   ██╔══╝  ██╔══██║██╔══██╗██║  ██║██║   ██║██║███╗██║██║╚██╗██║"
echo "     ██║   ███████╗██║  ██║██║  ██║██████╔╝╚██████╔╝╚███╔███╔╝██║ ╚████║"
echo "     ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝  ╚═════╝  ╚══╝╚══╝ ╚═╝  ╚═══╝"
echo -e "${NC}"
echo -e "  ${BOLD}Invoice Ninja Octane Teardown Utility${NC}"
echo ""

prompt() {
  local var_name="$1"
  local prompt_text="$2"
  local default="$3"
  read -rp "  ${BOLD}${prompt_text}${NC} [${CYAN}${default}${NC}]: " input
  eval "${var_name}=\"${input:-$default}\""
}

prompt_yn() {
  local var_name="$1"
  local prompt_text="$2"
  local default="$3"
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
}

DEFAULT_INSTALL_DIR="/opt/invoiceninja"
DEFAULT_DOMAIN="invoice.siyalude.io"

# ── Collect Config ────────────────────────────────────────────────────────────
header "Teardown Questionnaire"

prompt_yn STOP_CONTAINERS "Do you want to stop and remove Invoice Ninja containers?" "true"
if [ "$STOP_CONTAINERS" = "true" ]; then
    prompt INSTALL_DIR "  Install directory" "$DEFAULT_INSTALL_DIR"
fi

prompt_yn REMOVE_DATA "Do you want to permanently delete application data and files?" "false"
if [ "$REMOVE_DATA" = "true" ] && [ "$STOP_CONTAINERS" = "false" ]; then
    # In case they didn't ask to stop containers but want to remove data
    prompt INSTALL_DIR "  Install directory to delete" "$DEFAULT_INSTALL_DIR"
fi

prompt_yn REMOVE_NGINX "Do you want to remove the Nginx site block and SSL certificate?" "false"
if [ "$REMOVE_NGINX" = "true" ]; then
    prompt DOMAIN "  Domain name for Nginx/Certbot removal" "$DEFAULT_DOMAIN"
fi

prompt_yn PRUNE_IMAGES "Do you want to prune Docker images used by Invoice Ninja?" "false"

echo ""
echo -e "${BOLD}${RED}── Teardown Summary ──────────────────────────────────────────────${NC}"
echo -e "  Stop Containers: ${CYAN}${STOP_CONTAINERS}${NC}"
[ "$STOP_CONTAINERS" = "true" ] || [ "$REMOVE_DATA" = "true" ] && echo -e "  Install dir:     ${CYAN}${INSTALL_DIR}${NC}"
echo -e "  Remove Data:     ${CYAN}${REMOVE_DATA}${NC}"
echo -e "  Remove Nginx:    ${CYAN}${REMOVE_NGINX}${NC}"
[ "$REMOVE_NGINX" = "true" ] && echo -e "  Domain:          ${CYAN}${DOMAIN}${NC}"
echo -e "  Prune Images:    ${CYAN}${PRUNE_IMAGES}${NC}"
echo -e "${BOLD}${RED}──────────────────────────────────────────────────────────────────${NC}"
echo ""

read -rp "  Press ${BOLD}ENTER${NC} to execute teardown or ${RED}Ctrl+C${NC} to abort... " _

# ==============================================================================
# EXECUTION
# ==============================================================================
echo ""

if [ "$STOP_CONTAINERS" = "true" ]; then
    info "Stopping and removing containers..."
    if [ -d "$INSTALL_DIR" ]; then
        cd "$INSTALL_DIR"
        if command -v docker &>/dev/null; then
            docker compose down -v || warn "Failed to run docker compose down. Maybe containers are already removed?"
            success "Containers and networks removed."
        else
            warn "Docker is not installed."
        fi
    else
        warn "Install directory ${INSTALL_DIR} does not exist. Skipping container stop."
    fi
fi

if [ "$REMOVE_DATA" = "true" ]; then
    info "Deleting application data..."
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
        success "Deleted directory: ${INSTALL_DIR}"
    else
        warn "Install directory ${INSTALL_DIR} does not exist. Skipping data removal."
    fi
fi

if [ "$REMOVE_NGINX" = "true" ]; then
    info "Removing Nginx configuration..."
    NGINX_CONF="/etc/nginx/sites-available/invoiceninja.conf"
    NGINX_LINK="/etc/nginx/sites-enabled/invoiceninja.conf"
    
    rm -f "$NGINX_CONF" "$NGINX_LINK"
    success "Removed Nginx configuration files."
    
    if command -v nginx &>/dev/null; then
        nginx -t && systemctl reload nginx
        success "Nginx reloaded."
    else
        warn "Nginx is not installed or failed to reload."
    fi

    info "Removing Let's Encrypt SSL certificate..."
    if command -v certbot &>/dev/null; then
        certbot delete --cert-name "$DOMAIN" --non-interactive || warn "Certbot failed to delete cert for $DOMAIN. It might not exist."
        success "SSL certificate removal attempted."
    else
        warn "Certbot is not installed."
    fi
fi

if [ "$PRUNE_IMAGES" = "true" ]; then
    info "Pruning Docker images..."
    if command -v docker &>/dev/null; then
        # specifically targeted images to avoid deleting unrelated stuff
        docker rmi invoiceninja/invoiceninja-octane:latest mariadb:10.11 redis:alpine 2>/dev/null || true
        success "Specific Invoice Ninja images removed."
    else
        warn "Docker is not installed."
    fi
fi

echo ""
header "Teardown Complete"
echo -e "  The system has been cleaned up according to your preferences."
echo ""
