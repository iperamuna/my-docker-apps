#!/bin/bash
# ---------------------------------------------------------
# Mailu Restore Script (Restic + rclone <- OneDrive)
# ---------------------------------------------------------

RESTIC_REPOSITORY="rclone:my_onedrive:mailu-backups"
# IMPORTANT: This must match the password in backup-mailu.sh!
export RESTIC_PASSWORD="change_this_to_a_strong_password"

RESTORE_DIR="/opt/mailu_restore_temp"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}       Mailu Data Restore Utility       ${NC}"
echo -e "${BLUE}========================================${NC}"

# 1. Verify requirements
if ! command -v restic &> /dev/null || ! command -v rclone &> /dev/null; then
    echo -e "${RED}❌ Error: 'restic' or 'rclone' is not installed.${NC}"
    exit 1
fi

# 2. Check repository connection and list snapshots
echo -e "${YELLOW}Fetching available backups from OneDrive...${NC}"
echo ""

if ! restic -r "$RESTIC_REPOSITORY" snapshots; then
    echo -e "${RED}❌ Failed to connect to the repository.${NC}"
    echo "Check your rclone config and password."
    exit 1
fi

echo ""
echo -e "${YELLOW}Please enter the ID of the snapshot you want to restore (or type 'latest' for the newest backup):${NC}"
read -p "Snapshot ID: " SNAPSHOT_ID

if [ -z "$SNAPSHOT_ID" ]; then
    echo -e "${RED}No snapshot ID provided. Exiting.${NC}"
    exit 1
fi

# 3. Perform Restore
echo -e "${BLUE}Preparing to restore snapshot: ${SNAPSHOT_ID} to ${RESTORE_DIR}${NC}"
mkdir -p "$RESTORE_DIR"

echo "Downloading files... (This may take some time depending on your data size and internet speed)"
restic -r "$RESTIC_REPOSITORY" restore "$SNAPSHOT_ID" --target "$RESTORE_DIR"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Restore completed successfully!${NC}"
    echo -e "Your files have been safely restored to: ${YELLOW}$RESTORE_DIR/opt/mailu${NC}"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. Verify the restored data in $RESTORE_DIR/opt/mailu"
    echo "2. Stop Mailu (cd /opt/mailu && docker-compose down)"
    echo "3. Replace the live files: (e.g., cp -a $RESTORE_DIR/opt/mailu/* /opt/mailu/)"
    echo "4. Start Mailu (cd /opt/mailu && docker-compose up -d)"
    echo ""
    echo -e "${RED}Don't forget to delete the temporary restore directory once you're done!${NC}"
    echo "rm -rf $RESTORE_DIR"
else
    echo -e "${RED}❌ Restore failed.${NC}"
    exit 1
fi
