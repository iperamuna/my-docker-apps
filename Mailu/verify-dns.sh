#!/bin/bash
# ---------------------------------------------------------
# RavactHub DNS Health Audit Tool (v2024.06)
# ---------------------------------------------------------

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. Input
read -p "Enter Domain (e.g. ravact.com): " DOMAIN
read -p "Enter Mail Hostname (e.g. mail.ravact.com): " MAIL_HOST

# Get Server IP
IP=$(dig +short $MAIL_HOST | head -n1)
if [[ -z "$IP" ]]; then
    IP=$(curl -s https://ifconfig.me)
fi

echo -e "\n${BLUE}🔍 Starting Comprehensive DNS Audit for $DOMAIN ($IP)...${NC}\n"

# 2. PTR Check (Reverse DNS)
echo -ne "PTR Record (Reverse DNS): "
PTR=$(dig +short -x $IP | sed 's/\.$//')
if [[ "$PTR" == "$MAIL_HOST" ]]; then
    echo -e "${GREEN}PASS${NC} (Points to $PTR)"
else
    echo -e "${RED}FAIL${NC} (Found: $PTR, Expected: $MAIL_HOST)"
fi

# 3. Main Domain SPF Check
echo -ne "Main Domain SPF:        "
SPF=$(dig +short txt $DOMAIN | grep "v=spf1")
if [[ $SPF == *"v=spf1"* ]]; then
    echo -e "${GREEN}PASS${NC} ($SPF)"
else
    echo -e "${RED}FAIL${NC} (No SPF record found on $DOMAIN)"
fi

# 4. Hostname SPF Check (HELO)
echo -ne "Hostname SPF (HELO):    "
HSPF=$(dig +short txt $MAIL_HOST | grep "v=spf1")
if [[ $HSPF == *"v=spf1"* ]]; then
    echo -e "${GREEN}PASS${NC} ($HSPF)"
else
    echo -e "${YELLOW}WARN${NC} (No record on $MAIL_HOST - Recommended for SpamAssassin)"
fi

# 5. DKIM Check (New Selector)
echo -ne "DKIM Record (dkim._dk): "
DKIM=$(dig +short txt dkim._domainkey.$DOMAIN)
if [[ $DKIM == *"v=DKIM1"* ]]; then
    echo -e "${GREEN}PASS${NC} (Selector: dkim)"
else
    # Fallback check for legacy selector
    L_DKIM=$(dig +short txt mail._domainkey.$DOMAIN)
    if [[ $L_DKIM == *"v=DKIM1"* ]]; then
        echo -e "${YELLOW}WARN${NC} (Found legacy selector 'mail' - Switch to 'dkim' for persistence)"
    else
        echo -e "${RED}FAIL${NC} (No DKIM record found at dkim._domainkey.$DOMAIN)"
    fi
fi

# 6. DMARC Check
echo -ne "DMARC Policy:           "
DMARC=$(dig +short txt _dmarc.$DOMAIN)
if [[ $DMARC == *"v=DMARC1"* ]]; then
    if [[ $DMARC == *"p=reject"* || $DMARC == *"p=quarantine"* ]]; then
        echo -e "${GREEN}PASS${NC} ($DMARC)"
    else
        echo -e "${YELLOW}INFO${NC} ($DMARC - Policy is weak 'none')"
    fi
else
    echo -e "${RED}FAIL${NC} (No DMARC record found at _dmarc.$DOMAIN)"
fi

# 7. SMTP Banner Check
echo -ne "SMTP Banner (Port 25):  "
BANNER=$(echo "QUIT" | nc -w 5 $MAIL_HOST 25 2>/dev/null | grep "220")
if [[ $BANNER == *"$MAIL_HOST"* ]]; then
    echo -e "${GREEN}PASS${NC} ($BANNER)"
else
    echo -e "${RED}FAIL${NC} (Banner doesn't match hostname or connection failed)"
fi

echo -e "\n${BLUE}🏁 Audit Complete.${NC}"
echo -e "Note: For .online domains, SpamAssassin may still apply a small reputation penalty (-1.9).\n"
