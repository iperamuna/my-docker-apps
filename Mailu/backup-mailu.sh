#!/bin/bash
# ---------------------------------------------------------
# Mailu Incremental Backup Script (Restic + rclone -> OneDrive)
# ---------------------------------------------------------

# The directory containing your Mailu installation and data
MAILU_DIR="/opt/mailu"
SUMMARY_LOG="/opt/mailu/mailu-backup.log"
VERBOSE_LOG="/opt/mailu/backup-verbose.log"

# Restic Repository Configuration
# Replace 'my_onedrive' with the name of your rclone remote
RESTIC_REPOSITORY="rclone:my_onedrive:mailu-backups"

# Your Restic repository password (KEEP THIS SECRET!)
# IMPORTANT: Change this before running!
export RESTIC_PASSWORD="change_this_to_a_strong_password"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ==========================================
# SETUP MODE (--setup)
# ==========================================
if [ "$1" == "--setup" ]; then
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Mailu Automated Backup Setup Utility  ${NC}"
    echo -e "${BLUE}========================================${NC}"

    # 1. Verify requirements
    if ! command -v restic &> /dev/null || ! command -v rclone &> /dev/null; then
        echo -e "${RED}❌ Error: 'restic' or 'rclone' is not installed.${NC}"
        echo "Please install them first: sudo apt install restic rclone"
        exit 1
    fi

    echo -e "${YELLOW}Testing connection to the backup repository...${NC}"
    if ! restic snapshots >/dev/null 2>&1; then
        echo -e "${RED}❌ Connection test failed!${NC}"
        echo "Please ensure rclone is configured correctly ('rclone config') and the repository is initialized:"
        echo "restic -r $RESTIC_REPOSITORY init"
        exit 1
    fi
    echo -e "${GREEN}✅ Connection successful!${NC}"

    # 2. Ask for frequency
    echo ""
    echo "How often would you like the backup to run automatically?"
    echo "1) Every 15 minutes"
    echo "2) Every 30 minutes"
    echo "3) Hourly"
    echo "4) Daily (at midnight)"
    echo "5) Cancel"
    read -p "Select an option [1-5]: " cron_choice

    case $cron_choice in
        1) cron_schedule="*/15 * * * *" ;;
        2) cron_schedule="*/30 * * * *" ;;
        3) cron_schedule="0 * * * *" ;;
        4) cron_schedule="0 0 * * *" ;;
        5) echo "Setup cancelled."; exit 0 ;;
        *) echo -e "${RED}Invalid option.${NC}"; exit 1 ;;
    esac

    # 3. Setup cronjob
    script_path=$(realpath "$0")
    # All verbose output goes to verbose log, while summary log handles the 1-liner rotation
    cron_cmd="$cron_schedule $script_path >> $VERBOSE_LOG 2>&1"

    # Remove existing backup cronjob if it exists, then add the new one
    (crontab -l 2>/dev/null | grep -v "$script_path"; echo "$cron_cmd") | crontab -

    echo -e "${GREEN}✅ Cronjob successfully installed!${NC}"
    echo "The backup will now run automatically."
    echo "Schedule: $cron_schedule"
    echo "Verbose logs: $VERBOSE_LOG"
    echo "Summary logs (last 100 backups): $SUMMARY_LOG"
    exit 0

# ==========================================
# CHANGE PASSWORD MODE (--change-password)
# ==========================================
elif [ "$1" == "--change-password" ]; then
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}    Mailu Backup Password Utility       ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${YELLOW}This will change the master password for all your backups.${NC}"
    
    # 1. Verify requirements
    if ! command -v restic &> /dev/null || ! command -v rclone &> /dev/null; then
        echo -e "${RED}❌ Error: 'restic' or 'rclone' is not installed.${NC}"
        exit 1
    fi

    # Unset the exported password so restic asks for the OLD password explicitly to verify
    unset RESTIC_PASSWORD
    
    # Let restic handle the secure prompt for old and new passwords natively
    if restic -r "$RESTIC_REPOSITORY" key passwd; then
        echo ""
        echo -e "${GREEN}✅ Repository password changed successfully!${NC}"
        echo -e "${RED}⚠️ CRITICAL ACTION REQUIRED ⚠️${NC}"
        echo -e "You MUST now manually update the RESTIC_PASSWORD variable in these files:"
        echo "1. /opt/mailu/backup-mailu.sh"
        echo "2. /opt/mailu/restore-mailu.sh"
        echo "If you fail to do this, your automated backups will break!"
        exit 0
    else
        echo -e "${RED}❌ Password change failed.${NC}"
        exit 1
    fi
fi

# ==========================================
# NORMAL BACKUP MODE
# ==========================================

START_TIME=$(date +"%Y-%m-%d %H:%M:%S")
START_SECONDS=$SECONDS

echo -e "${BLUE}📦 Starting Mailu Incremental Backup to OneDrive...${NC}"

# Helper function to write to the summary log and rotate it
write_summary() {
    local status="$1"
    local duration=$(($SECONDS - $START_SECONDS))
    local log_line="[$START_TIME] $status (Duration: ${duration}s)"
    
    # Append to log
    echo "$log_line" >> "$SUMMARY_LOG"
    
    # Rotate log to keep only the last 100 lines
    if [ -f "$SUMMARY_LOG" ]; then
        tail -n 100 "$SUMMARY_LOG" > "${SUMMARY_LOG}.tmp"
        mv "${SUMMARY_LOG}.tmp" "$SUMMARY_LOG"
    fi
}

# 1. Check if restic and rclone are installed
if ! command -v restic &> /dev/null || ! command -v rclone &> /dev/null; then
    echo -e "${RED}❌ Error: 'restic' or 'rclone' is not installed.${NC}"
    write_summary "❌ FAILED: Tools missing"
    exit 1
fi

# 2. Check if the repository is initialized
if ! restic snapshots >/dev/null 2>&1; then
    echo -e "${RED}❌ Error: Restic repository is not initialized or accessible.${NC}"
    write_summary "❌ FAILED: Repository not accessible"
    exit 1
fi

# 3. Perform the Backup
echo "Syncing $MAILU_DIR to OneDrive..."
restic -r "$RESTIC_REPOSITORY" backup "$MAILU_DIR" --verbose

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Backup completed successfully!${NC}"
    
    # 4. Cleanup old backups (Retention Policy)
    echo -e "${BLUE}🧹 Pruning old backups based on retention policy...${NC}"
    restic -r "$RESTIC_REPOSITORY" forget --keep-hourly 24 --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Maintenance completed!${NC}"
        write_summary "✅ SUCCESS: Backed up and pruned"
    else
        echo -e "${YELLOW}⚠️ Backup succeeded but pruning failed!${NC}"
        write_summary "⚠️ WARNING: Backup OK, Prune failed"
    fi
else
    echo -e "${RED}❌ Backup failed. Check network connection or rclone config.${NC}"
    write_summary "❌ FAILED: Backup command error"
    exit 1
fi
