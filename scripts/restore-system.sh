#!/bin/bash
# System restoration script

set -e

echo "=== ENDEAVOUROS SYSTEM RESTORE UTILITY ==="
echo "WARNING: This will restore your system from backup!"
echo "Make sure you're running this from a live USB/rescue environment."
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo $0)"
    exit 1
fi

BACKUP_DIR="/mnt/nas_backup"

# Mount backup drive if needed
if ! mountpoint -q "$BACKUP_DIR"; then
    echo "Backup drive not mounted. Attempting to mount..."
    mount /dev/sdX1 "$BACKUP_DIR" || {
        echo "Failed to mount backup drive!"
        echo "Please mount your backup drive to $BACKUP_DIR"
        exit 1
    }
fi

echo "Available full backups:"
ls -la "$BACKUP_DIR/disk_images/"endeavouros_full_*.img.gz 2>/dev/null | head -5

echo ""
read -p "Enter the backup filename (without path): " BACKUP_FILE
BACKUP_PATH="$BACKUP_DIR/disk_images/$BACKUP_FILE"

if [ ! -f "$BACKUP_PATH" ]; then
    echo "Backup file not found: $BACKUP_PATH"
    exit 1
fi

# Verify checksum if available
CHECKSUM_FILE="${BACKUP_PATH%.*}.sha256"
if [ -f "$CHECKSUM_FILE" ]; then
    echo "Verifying backup integrity..."
    cd "$BACKUP_DIR/disk_images/"
    if sha256sum -c "$CHECKSUM_FILE"; then
        echo "Checksum verified successfully!"
    else
        echo "Checksum verification failed! Backup may be corrupted."
        read -p "Continue anyway? (y/N): " CONTINUE
        if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ]; then
            exit 1
        fi
    fi
fi

TARGET_DISK="/dev/nvmeXn1"
echo ""
echo "Target disk: $TARGET_DISK"
echo "WARNING: This will COMPLETELY OVERWRITE $TARGET_DISK"
echo "Current disk contents:"
lsblk "$TARGET_DISK"

echo ""
read -p "Are you ABSOLUTELY sure you want to continue? Type 'YES' to proceed: " CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    echo "Restore cancelled."
    exit 0
fi

echo ""
echo "Starting restore process..."
echo "Restoring $BACKUP_PATH to $TARGET_DISK"

# Restore the backup
gunzip -c "$BACKUP_PATH" | dd of="$TARGET_DISK" bs=64K status=progress

echo ""
echo "Restore completed successfully!"
echo "You can now reboot into your restored system."
echo ""
echo "After booting, you may want to:"
echo "1. Check /mnt/nas_backup/config/ for configuration backups"
echo "2. Restore any additional files from Borg backups"
echo "3. Update your system: sudo pacman -Syu"
