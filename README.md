# android-adb-backup

A comprehensive Bash script for backing up all accessible data from an Android device using ADB (Android Debug Bridge), designed for both non-rooted and rooted devices. This script is ideal for users preparing for a factory reset, ensuring critical data like Aegis Authenticator 2FA seeds, photos, apps, settings, and more are securely backed up. Features include an interactive menu, pretty console output, root detection, and detailed restore instructions.FeaturesComprehensive Backup:Aegis 2FA Seeds: Supports manual export of encrypted JSON vault and root-based app data backup.
Internal Storage: Pulls /sdcard (photos, videos, documents).
Apps and Data: Uses adb backup for non-rooted devices; pulls /data/data for rooted devices.
APKs: Extracts all installed app APKs for reinstallation.
SMS and Call Logs: Backs up telephony data, with root access for direct database pulls.
Contacts: Exports contacts to .vcf (auto or manual).
Wi-Fi Settings: Non-root backup via adb backup; root pulls /data/misc/wifi.
System Settings (Root): Backs up system configuration files (e.g., /data/system/users/0).

Root Support:Automatically detects root via adb root or su command.
Falls back to user confirmation if detection fails.
Enables deeper backups (app data, system files) for rooted devices.

Interactive Menu: Choose specific tasks or run all backups.
Pretty Console Output: Color-coded status (✓ success, ✗ error) and summary table.
Verification: Checks file sizes, MD5 sums for Aegis, and backup integrity.
Restore Guide: Generates a detailed restore_guide.txt for post-reset recovery.
Compression: Optional .tar.gz compression to save space.
Logging: Detailed log file for troubleshooting.

RequirementsOperating System: Linux or macOS (Bash). Windows users can use Git Bash or WSL (PowerShell version available on request).
Tools:ADB (Android Debug Bridge) installed and in PATH.
tar and md5sum (standard on Linux/macOS).

Android Device:USB debugging enabled (Settings > Developer Options > USB Debugging).
For rooted devices: su binary (e.g., Magisk, SuperSU) installed and ADB authorized for root.

Storage: At least 5GB free disk space on the computer (configurable in script).
Aegis Authenticator: For 2FA seed backup, manually export the vault to /sdcard/Download/aegis_vault.json (or specify custom path).

InstallationClone the Repository:bash


