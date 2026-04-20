#!/bin/bash
# ---------------------------------------------------------
# Mailu Systematic Backup Script
# ---------------------------------------------------------

MAILU_DIR="/opt/mailu"
BACKUP_DIR="/opt/mailu_backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/mailu_backup_$TIMESTAMP.tar.gz"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📦 Starting Mailu Backup...${NC}"

# 1. Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# 2. Compress the entire Mailu directory
# We use --exclude if you want to skip something, but usually better to take all
echo "Compressing /opt/mailu and data..."
tar -czf "$BACKUP_FILE" -C /opt mailu

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Backup created successfully!${NC}"
    echo "Location: $BACKUP_FILE"
    echo "Size: $(du -sh $BACKUP_FILE | cut -f1)"
    echo "---------------------------------------------------"
    echo "TIP: Please move this file to an off-site location"
    echo "Example: scp $BACKUP_FILE user@remote-backup-server:/backups/"
    echo "---------------------------------------------------"
else
    echo -e "${RED}❌ Backup failed. Check disk space or permissions.${NC}"
fi

# 3. Optional: Delete backups older than 7 days to save space
# find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +7 -delete
