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
    print_status success "Disk space OK ($available MB available)."
}

# Function: Check ADB
check_adb() {
    adb devices | grep -q device || {
        print_status error "No device found. Connect phone and enable USB debugging."
        exit 1
    }
    print_status success "Device connected: $(adb get-state)"
}

# Function: Write Restore Instructions
write_restore_guide() {
    cat > "$RESTORE_GUIDE" << EOL
=== Android Backup Restore Guide ===
Generated: $(date)
Backup Dir: $BACKUP_DIR

1. **Aegis 2FA Seeds**:
   - Reinstall Aegis: adb install $BACKUP_DIR/apks/aegis.apk
   - Copy vault: adb push $BACKUP_DIR/sdcard$(dirname $AEGIS_PATH)/$(basename $AEGIS_PATH) $AEGIS_PATH
   - Open Aegis, import vault with your password.

2. **Internal Storage**:
   - Restore: adb push $BACKUP_DIR/sdcard /sdcard
   - Or manually copy files to phone.

3. **Apps and Data**:
   - Restore: adb restore $BACKUP_DIR/complete_backup.ab
   - Confirm on phone.

4. **SMS/Call Logs**:
   - Restore: adb restore $BACKUP_DIR/sms.ab
   - Confirm on phone.

5. **Contacts**:
   - Copy: adb push $BACKUP_DIR/contacts.vcf /sdcard/contacts.vcf
   - Import via Contacts app.

6. **APKs**:
   - Install: for apk in $BACKUP_DIR/apks/*.apk; do adb install \$apk; done

7. **Wi-Fi Settings** (if backed up):
   - Restore: adb restore $BACKUP_DIR/wifi.ab

Note: Verify all files before restoring. Check $LOG_FILE for details.
EOL
    print_status success "Restore guide created: $RESTORE_GUIDE"
}

# Function: Interactive Menu
show_menu() {
    echo -e "${BLUE}=== Backup Tasks (Select with numbers, e.g., '1 3 5' or 'all') ===${NC}"
    echo "1. Aegis Authenticator 2FA Seeds"
    echo "2. Internal Storage (/sdcard)"
    echo "3. Apps and Data (ADB Backup)"
    echo "4. APKs"
    echo "5. SMS and Call Logs"
    echo "6. Contacts Export"
    echo "7. Wi-Fi Settings"
    echo "8. All of the above"
    echo -e "${YELLOW}Enter choices (space-separated) or 'all':${NC}"
    read -r choices
}

# Function: Backup Aegis
backup_aegis() {
    print_status info "Backing up Aegis 2FA seeds..."
    echo -e "${YELLOW}MANUAL STEP: In Aegis, go to Settings > Backups > Export, save as encrypted JSON to $AEGIS_PATH${NC}"
    read -p "Custom path (or press Enter for default): " custom_path
    [ -n "$custom_path" ] && AEGIS_PATH="$custom_path"
    adb pull "$AEGIS_PATH" "$BACKUP_DIR/sdcard$(dirname $AEGIS_PATH)/$(basename $AEGIS_PATH)" 2>/dev/null || {
        print_status warn "Aegis file not found at $AEGIS_PATH. Checking /sdcard/Aegis..."
        adb pull /sdcard/Aegis "$BACKUP_DIR/sdcard/Aegis" 2>/dev/null || {
            print_status error "Aegis backup failed. Export manually and retry."
            return 1
        }
    }
    if [ -s "$BACKUP_DIR/sdcard$(dirname $AEGIS_PATH)/$(basename $AEGIS_PATH)" ]; then
        md5sum "$BACKUP_DIR/sdcard$(dirname $AEGIS_PATH)/$(basename $AEGIS_PATH)" > "$BACKUP_DIR/aegis_md5.txt"
        print_status success "Aegis backup complete: $(du -h "$BACKUP_DIR/sdcard$(dirname $AEGIS_PATH)/$(basename $AEGIS_PATH)")"
    else
        print_status error "Aegis file empty or missing!"
        return 1
    fi
}

# Function: Backup Internal Storage
backup_storage() {
    print_status info "Backing up /sdcard..."
    adb pull /sdcard "$BACKUP_DIR/sdcard" 2>/dev/null || print_status warn "Partial pull (some files may be inaccessible)."
    print_status success "Storage backup: $(du -sh "$BACKUP_DIR/sdcard")"
}

# Function: Backup Apps and Data
backup_apps_data() {
    print_status info "Running ADB backup for apps and data..."
    adb backup -apk -shared -all -system -f "$BACKUP_DIR/complete_backup.ab"
    [ -s "$BACKUP_DIR/complete_backup.ab" ] && print_status success "ADB backup: $(du -h "$BACKUP_DIR/complete_backup.ab")" || print_status error "ADB backup failed."
}

# Function: Backup APKs
backup_apks() {
    print_status info "Pulling APKs..."
    mkdir -p "$BACKUP_DIR/apks"
    while IFS= read -r package; do
        package_name=$(echo "$package" | cut -d':' -f2)
        apk_path=$(adb shell pm path "$package_name" 2>/dev/null | cut -d':' -f2)
        if [ -n "$apk_path" ]; then
            adb pull "$apk_path" "$BACKUP_DIR/apks/${package_name}.apk" 2>/dev/null && print_status success "Pulled $package_name" || print_status warn "Skipped $package_name"
        fi
    done < <(adb shell pm list packages)
    print_status success "APKs backed up: $(find "$BACKUP_DIR/apks" -type f | wc -l) files"
}

# Function: Backup SMS and Call Logs
backup_sms_calls() {
    print_status info "Backing up SMS and Call Logs..."
    adb backup -f "$BACKUP_DIR/sms.ab" com.android.providers.telephony
    [ -s "$BACKUP_DIR/sms.ab" ] && print_status success "SMS/Call backup: $(du -h "$BACKUP_DIR/sms.ab")" || print_status error "SMS/Call backup failed."
}

# Function: Backup Contacts
backup_contacts() {
    print_status info "Exporting contacts..."
    adb shell am start -a android.intent.action.EXPORT -n com.android.contacts/.activities.ContactExportActivity 2>/dev/null || print_status warn "Auto-export not supported. Export manually in Contacts app."
    sleep 5  # Wait for export
    adb pull /sdcard/contacts.vcf "$BACKUP_DIR/contacts.vcf" 2>/dev/null && print_status success "Contacts: $(du -h "$BACKUP_DIR/contacts.vcf")" || print_status warn "Contacts export not found."
}

# Function: Backup Wi-Fi Settings
backup_wifi() {
    print_status info "Backing up Wi-Fi settings..."
    adb backup -f "$BACKUP_DIR/wifi.ab" com.android.providers.settings 2>/dev/null
    [ -s "$BACKUP_DIR/wifi.ab" ] && print_status success "Wi-Fi backup: $(du -h "$BACKUP_DIR/wifi.ab")" || print_status warn "Wi-Fi backup limited (non-root)."
}

# Function: Compress Backup
compress_backup() {
    if [ "$COMPRESS_BACKUP" = true ]; then
        print_status info "Compressing backup..."
        tar -czf "$BACKUP_DIR.tar.gz" -C "$BACKUP_DIR" . && print_status success "Compressed: $(du -h "$BACKUP_DIR.tar.gz")"
    fi
}

# Main
check_disk_space
check_adb
show_menu

# Process Choices
if [ "$choices" = "all" ] || [[ "$choices" =~ 8 ]]; then
    tasks=(1 2 3 4 5 6 7)
else
    tasks=($choices)
fi

for task in "${tasks[@]}"; do
    case $task in
        1) backup_aegis ;;
        2) backup_storage ;;
        3) backup_apps_data ;;
        4) backup_apks ;;
        5) backup_sms_calls ;;
        6) backup_contacts ;;
        7) backup_wifi ;;
        *) print_status error "Invalid choice: $task" ;;
    esac
done

# Final Steps
compress_backup
write_restore_guide

# Summary
echo -e "${BLUE}=== Backup Summary ===${NC}"
printf "%-20s | %-10s | %-10s\n" "Component" "Status" "Size"
echo "----------------------------------------"
[ -s "$BACKUP_DIR/sdcard$(dirname $AEGIS_PATH)/$(basename $AEGIS_PATH)" ] && printf "%-20s | %-10s | %-10s\n" "Aegis Seeds" "OK" "$(du -h "$BACKUP_DIR/sdcard$(dirname $AEGIS_PATH)/$(basename $AEGIS_PATH)" | cut -f1)"
[ -d "$BACKUP_DIR/sdcard" ] && printf "%-20s | %-10s | %-10s\n" "Internal Storage" "OK" "$(du -sh "$BACKUP_DIR/sdcard" | cut -f1)"
[ -s "$BACKUP_DIR/complete_backup.ab" ] && printf "%-20s | %-10s | %-10s\n" "Apps/Data" "OK" "$(du -h "$BACKUP_DIR/complete_backup.ab" | cut -f1)"
[ -d "$BACKUP_DIR/apks" ] && printf "%-20s | %-10s | %-10s\n" "APKs" "OK" "$(find "$BACKUP_DIR/apks" -type f | wc -l) files"
[ -s "$BACKUP_DIR/sms.ab" ] && printf "%-20s | %-10s | %-10s\n" "SMS/Calls" "OK" "$(du -h "$BACKUP_DIR/sms.ab" | cut -f1)"
[ -s "$BACKUP_DIR/contacts.vcf" ] && printf "%-20s | %-10s | %-10s\n" "Contacts" "OK" "$(du -h "$BACKUP_DIR/contacts.vcf" | cut -f1)"
[ -s "$BACKUP_DIR/wifi.ab" ] && printf "%-20s | %-10s | %-10s\n" "Wi-Fi" "OK" "$(du -h "$BACKUP_DIR/wifi.ab" | cut -f1)"
echo "----------------------------------------"
print_status success "Backup complete! Total size: $(du -sh "$BACKUP_DIR" | cut -f1)"
print_status info "Log: $LOG_FILE"
print_status info "Restore guide: $RESTORE_GUIDE"
print_status warn "Test Aegis backup by importing into another device!"
