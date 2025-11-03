#!/bin/bash

# Android Full Backup Script (Non-Rooted Device)
# Comprehensive backup with interactive menu, Aegis 2FA support, and pretty console output
# Run with phone connected, USB debugging enabled
# Requires ADB installed and in PATH

# ANSI Colors for Pretty Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
CHECKMARK="✓"
CROSS="✗"

# Config
BACKUP_DIR="./android_backup_$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$BACKUP_DIR/backup.log"
RESTORE_GUIDE="$BACKUP_DIR/restore_guide.txt"
AEGIS_PATH="/sdcard/Download/aegis_vault.json"
COMPRESS_BACKUP=false
MIN_DISK_SPACE_MB=5000  # 5GB minimum

# Initialize
mkdir -p "$BACKUP_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "=== Android Full Backup Script ==="
echo "Date: $(date)"
echo "Backup dir: $BACKUP_DIR"

# Function: Pretty Print
print_status() {
    local status="$1"
    local message="$2"
    if [ "$status" = "success" ]; then
        echo -e "${GREEN}${CHECKMARK} $message${NC}"
    elif [ "$status" = "error" ]; then
        echo -e "${RED}${CROSS} $message${NC}"
    elif [ "$status" = "warn" ]; then
        echo -e "${YELLOW}! $message${NC}"
    else
        echo -e "${BLUE}* $message${NC}"
    fi
}

# Function: Check Disk Space
check_disk_space() {
    local available=$(df -m . | tail -1 | awk '{print $4}')
    if [ "$available" -lt "$MIN_DISK_SPACE_MB" ]; then
        print_status error "Insufficient disk space ($available MB available, $MIN_DISK_SPACE_MB MB required)."
        exit 1
    fi
    print_status success "Disk space OK ($available MB available
