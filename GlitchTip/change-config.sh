#!/bin/bash
# ==============================================================================
# GlitchTip Configuration Modifier
# ==============================================================================

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_DIR="/opt/glitchtip"
ENV_FILE="${INSTALL_DIR}/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}[ERROR]${NC} .env file not found at ${ENV_FILE}"
    exit 1
fi

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }

update_env() {
    local key="$1"
    local value="$2"
    if grep -q "^${key}=" "$ENV_FILE"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
    else
        echo "${key}=${value}" >> "$ENV_FILE"
    fi
}

echo -e "${BOLD}${CYAN}GlitchTip Configuration Update${NC}"
echo "--------------------------------"

# Current values
CUR_UPTIME=$(grep "^GLITCHTIP_ENABLE_UPTIME=" "$ENV_FILE" | cut -d'=' -f2- || echo "True")
CUR_LOGS=$(grep "^GLITCHTIP_ENABLE_LOGS=" "$ENV_FILE" | cut -d'=' -f2- || echo "True")
CUR_ADMIN=$(grep "^ENABLE_ADMIN=" "$ENV_FILE" | cut -d'=' -f2- || echo "False")
CUR_EMAIL=$(grep "^DEFAULT_FROM_EMAIL=" "$ENV_FILE" | cut -d'=' -f2- || echo "")
CUR_SMTP=$(grep "^EMAIL_URL=" "$ENV_FILE" | cut -d'=' -f2- || echo "")

echo -e "1) ${BOLD}Uptime Monitoring${NC} [Currently: ${CYAN}${CUR_UPTIME}${NC}]"
echo -e "2) ${BOLD}Log Ingestion${NC}     [Currently: ${CYAN}${CUR_LOGS}${NC}]"
echo -e "3) ${BOLD}Django Admin${NC}      [Currently: ${CYAN}${CUR_ADMIN}${NC}]"
echo -e "4) ${BOLD}From Email${NC}        [Currently: ${CYAN}${CUR_EMAIL}${NC}]"
echo -e "5) ${BOLD}SMTP URL${NC}          [Currently: ${CYAN}${CUR_SMTP}${NC}]"
echo -e "6) ${BOLD}Test SMTP Settings${NC}"
echo -e "q) ${BOLD}Quit${NC}"

read -rp "Select option to toggle/change: " choice

case "$choice" in
    1)
        NEW_VAL=$([ "$CUR_UPTIME" == "True" ] && echo "False" || echo "True")
        update_env "GLITCHTIP_ENABLE_UPTIME" "$NEW_VAL"
        success "Uptime Monitoring set to ${NEW_VAL}"
        ;;
    2)
        NEW_VAL=$([ "$CUR_LOGS" == "True" ] && echo "False" || echo "True")
        update_env "GLITCHTIP_ENABLE_LOGS" "$NEW_VAL"
        success "Log Ingestion set to ${NEW_VAL}"
        ;;
    3)
        NEW_VAL=$([ "$CUR_ADMIN" == "True" ] && echo "False" || echo "True")
        update_env "ENABLE_ADMIN" "$NEW_VAL"
        success "Django Admin set to ${NEW_VAL}"
        ;;
    4)
        read -rp "Enter new From Email: " NEW_EMAIL
        update_env "DEFAULT_FROM_EMAIL" "$NEW_EMAIL"
        success "From Email updated."
        ;;
    5)
        echo -e "\n${BOLD}SMTP URL Builder${NC}"
        echo -e "${YELLOW}Note: Port 587 (STARTTLS) is generally more compatible than 465.${NC}"
        read -rp "  Host (e.g. smtp.gmail.com): " SMTP_HOST
        read -rp "  Port (e.g. 587 or 465):     " SMTP_PORT
        read -rp "  User (e.g. info@domain.com): " SMTP_USER
        read -s -rp "  Password:                   " SMTP_PASS
        echo ""
        echo -e "  Security Type:"
        echo -e "    1) None"
        echo -e "    2) TLS (STARTTLS - recommended for 587)"
        echo -e "    3) SSL (Implicit - recommended for 465)"
        read -rp "  Select [1-3]: " SEC_CHOICE
        
        # URL encode password (basic)
        ENCODED_PASS=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$SMTP_PASS'''))")
        
        PROTO="smtp"
        case "$SEC_CHOICE" in
            2) PROTO="smtp+tls" ;;
            3) PROTO="smtp+ssl" ;;
            *) PROTO="smtp" ;;
        esac
        
        NEW_SMTP="${PROTO}://${SMTP_USER}:${ENCODED_PASS}@${SMTP_HOST}:${SMTP_PORT}"
        update_env "EMAIL_URL" "$NEW_SMTP"
        success "SMTP URL (${PROTO}) generated and updated."
        ;;
    6)
        read -rp "Enter recipient email address: " TEST_RECIPIENT
        info "Sending test email to ${TEST_RECIPIENT}..."
        
        # Run the test and capture output
        TEST_OUT=$(docker exec glitchtip-web-1 ./manage.py shell -c "
import sys
from django.core.mail import send_mail
try:
    result = send_mail(
        'GlitchTip SMTP Test',
        'If you received this, your GlitchTip SMTP settings are working correctly!',
        None,
        ['$TEST_RECIPIENT'],
        fail_silently=False
    )
    if result == 1:
        print('SMTP_TEST_SUCCESS')
    else:
        print('SMTP_TEST_FAILED: No email sent')
except Exception as e:
    print(f'SMTP_TEST_ERROR: {str(e)}')
    sys.exit(1)
" 2>&1)

        if echo "$TEST_OUT" | grep -q "SMTP_TEST_SUCCESS"; then
            success "Test email sent successfully! Please check your inbox."
        else
            echo -e "${RED}Test Failed!${NC}"
            echo -e "${YELLOW}Reason:${NC}"
            echo "$TEST_OUT" | grep -E "SMTP_TEST_ERROR|SMTP_TEST_FAILED" || echo "$TEST_OUT"
            echo -e "\n${BOLD}Common fixes:${NC}"
            echo "1. If using Port 465 and it hangs, try Port 587 with 'Use SSL/TLS: n'."
            echo "2. Ensure you have restarted GlitchTip (Option 5 updates .env but needs restart)."
            echo "3. Check if your SMTP provider requires a specific 'From Email' (Option 4)."
        fi
        exit 0
        ;;
    q)
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid choice.${NC}"
        exit 1
        ;;
esac

info "Restarting GlitchTip to apply changes..."
cd "$INSTALL_DIR" && docker compose up -d --force-recreate
success "Done!"
