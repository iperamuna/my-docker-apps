#!/bin/bash
# ---------------------------------------------------------
# Mailu Optional Features Manager (ClamAV & FTS)
# ---------------------------------------------------------

MAILU_DIR="/opt/mailu"
ENV_FILE="$MAILU_DIR/.env"
COMPOSE_FILE="$MAILU_DIR/docker-compose.yml"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🛡️ Mailu Feature Manager${NC}"
echo "--------------------------"

# 1. Detect Status
ANTIVIRUS_STATUS=$(grep "ANTIVIRUS=" $ENV_FILE | cut -d= -f2)
FTS_STATUS=$(grep "FTS=" $ENV_FILE | cut -d= -f2)
WEBDAV_STATUS=$(grep "WEBDAV=" $ENV_FILE | cut -d= -f2)
[[ -p $MAILU_DIR/docker-compose.yml ]] || touch $MAILU_DIR/docker-compose.yml # Safety check

# Detect Tika (FTS Attachments)
if grep -q "fts_attachments:" $COMPOSE_FILE; then TIKA_STATUS="enabled"; else TIKA_STATUS="disabled"; fi
# Detect Fetchmail
if grep -q "fetchmail:" $COMPOSE_FILE; then FETCHMAIL_STATUS="enabled"; else FETCHMAIL_STATUS="disabled"; fi

[[ "$ANTIVIRUS_STATUS" == "none" ]] && AV_COLOR=$RED || AV_COLOR=$GREEN
[[ "$FTS_STATUS" == "none" ]] && FTS_COLOR=$RED || FTS_COLOR=$GREEN
[[ "${WEBDAV_STATUS:-none}" == "none" ]] && WEBDAV_COLOR=$RED || WEBDAV_COLOR=$GREEN
[[ "$TIKA_STATUS" == "disabled" ]] && TIKA_COLOR=$RED || TIKA_COLOR=$GREEN
[[ "$FETCHMAIL_STATUS" == "disabled" ]] && FETCHMAIL_COLOR=$RED || FETCHMAIL_COLOR=$GREEN

echo -e "1. ClamAV Antivirus: ${AV_COLOR}${ANTIVIRUS_STATUS}${NC}"
echo -e "2. Full-Text Search: ${FTS_COLOR}${FTS_STATUS}${NC}"
echo -e "3. Attachment Indexing (Tika): ${TIKA_COLOR}${TIKA_STATUS}${NC}"
echo -e "4. External Fetchmail: ${FETCHMAIL_COLOR}${FETCHMAIL_STATUS}${NC}"
echo -e "5. WebDAV / Calendar (Radicale): ${WEBDAV_COLOR}${WEBDAV_STATUS:-none}${NC}"
echo "--------------------------"

echo "What would you like to do?"
echo "a) Toggle ClamAV (Enable/Disable)"
echo "b) Toggle Full-Text Search (Enable/Disable)"
echo "c) Toggle Attachment Indexing (Apache Tika)"
echo "d) Toggle External Fetchmail"
echo "e) Toggle WebDAV / Calendar (Radicale)"
echo "q) Quit"
read -p "Selection: " CHOICE

case $CHOICE in
    a)
        if [[ "$ANTIVIRUS_STATUS" == "none" ]]; then
            echo "Enabling ClamAV... (Requires 2GB+ extra RAM)"
            sed -i 's/ANTIVIRUS=none/ANTIVIRUS=clamav/' $ENV_FILE
            if ! grep -q "antivirus:" $COMPOSE_FILE; then
                sed -i '/^networks:/i \
  antivirus:\n    image: clamav/clamav:latest\n    restart: always\n    env_file: .env\n    volumes:\n      - ./data/filter:/var/lib/clamav\n' $COMPOSE_FILE
            fi
        else
            echo "Disabling ClamAV..."
            sed -i 's/ANTIVIRUS=clamav/ANTIVIRUS=none/' $ENV_FILE
        fi
        ;;
    b)
        if [[ "$FTS_STATUS" == "none" ]]; then
            echo "Enabling Full-Text Search (Xapian)..."
            sed -i 's/FTS=none/FTS=xapian/' $ENV_FILE
        else
            echo "Disabling Full-Text Search..."
            sed -i 's/FTS=.*/FTS=none/' $ENV_FILE
        fi
        ;;
    c)
        if [[ "$TIKA_STATUS" == "disabled" ]]; then
            echo "Enabling Attachment Indexing (Tika)..."
            if ! grep -q "fts_attachments:" $COMPOSE_FILE; then
                sed -i '/^networks:/i \
  fts_attachments:\n    image: apache/tika:latest-full\n    restart: always\n' $COMPOSE_FILE
            fi
        else
            echo "Disabling Attachment Indexing..."
            echo "Note: Disabling Tika requires manual removal from docker-compose.yml."
        fi
        ;;
    d)
        if [[ "$FETCHMAIL_STATUS" == "disabled" ]]; then
            echo "Enabling Fetchmail..."
            if ! grep -q "fetchmail:" $COMPOSE_FILE; then
                sudo touch /opt/mailu/data/fetchids 2>/dev/null || touch /opt/mailu/data/fetchids
                sudo chown 101:101 /opt/mailu/data/fetchids 2>/dev/null || true
                sudo chmod 600 /opt/mailu/data/fetchids 2>/dev/null || true
                
                sed -i '/^networks:/i \
  fetchmail:\n    image: ghcr.io/mailu/fetchmail:2024.06\n    restart: always\n    env_file: .env\n    volumes:\n      - ./data:/data\n    depends_on:\n      - redis\n' $COMPOSE_FILE
            fi
        else
            echo "Disabling Fetchmail..."
            echo "Note: Disabling Fetchmail requires manual removal from docker-compose.yml."
        fi
        ;;
    e)
        if [[ "${WEBDAV_STATUS:-none}" == "none" ]]; then
            echo "Enabling WebDAV / Calendar (Radicale)..."
            if grep -q "WEBDAV=" $ENV_FILE; then
                sed -i 's/WEBDAV.*/WEBDAV=radicale/' $ENV_FILE
            else
                echo "WEBDAV=radicale" >> $ENV_FILE
            fi
            # Enable Roundcube Plugins for Calendar/Contacts
            if grep -q "ROUNDCUBE_PLUGINS=" $ENV_FILE; then
                sed -i 's/ROUNDCUBE_PLUGINS=.*/ROUNDCUBE_PLUGINS=archive,zipdownload,managesieve,enigma,carddav,calendar/' $ENV_FILE
            else
                echo "ROUNDCUBE_PLUGINS=archive,zipdownload,managesieve,enigma,carddav,calendar" >> $ENV_FILE
            fi
            if ! grep -q "webdav:" $COMPOSE_FILE; then
                sed -i '/^networks:/i \
  webdav:\n    image: ghcr.io/mailu/radicale:2024.06\n    restart: always\n    env_file: .env\n    volumes:\n      - ./data:/data\n' $COMPOSE_FILE
            fi
        else
            echo "Disabling WebDAV / Calendar..."
            sed -i 's/WEBDAV=.*/WEBDAV=none/' $ENV_FILE
            # Revert Roundcube Plugins to standard set (remove calendar/carddav)
            if grep -q "ROUNDCUBE_PLUGINS=" $ENV_FILE; then
                sed -i 's/ROUNDCUBE_PLUGINS=.*/ROUNDCUBE_PLUGINS=archive,zipdownload,managesieve,enigma/' $ENV_FILE
            fi
            echo "Note: Disabling WebDAV requires manual removal of 'webdav:' from docker-compose.yml."
        fi
        ;;
    q) exit 0 ;;
    *) echo "Invalid option"; exit 1 ;;
esac

# Restart services
echo "Applying changes..."
docker compose up -d --remove-orphans

echo "✅ Features updated successfully."
echo "Note: Your custom Hub and Branding were preserved."
