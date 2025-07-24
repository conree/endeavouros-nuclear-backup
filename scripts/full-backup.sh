#!/bin/bash
# Full system image backup using dd with compression

set -e

# Configuration
BACKUP_DRIVE_UUID="YOUR_BACKUP_DRIVE_UUID_HERE"
BACKUP_MOUNT_POINT="/mnt/backup_drive"
SOURCE_DISK="/dev/YOUR_NVME-sdX_DEVICE"
BACKUP_DIR="$BACKUP_MOUNT_POINT/disk_images"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="endeavouros_full_${DATE}"
LOG_FILE="$BACKUP_MOUNT_POINT/logs/full_backup_${DATE}.log"

# Disable sleep during backup
echo "Disabling system sleep for backup..."
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target >/dev/null 2>&1

# Ensure sleep is re-enabled on script exit (success or failure)
cleanup_sleep() {
    echo "Re-enabling system sleep..." | tee -a "$LOG_FILE"
    systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target >/dev/null 2>&1
}
trap cleanup_sleep EXIT

# Ensure backup drive is mounted
ensure_backup_drive_mounted() {
    if ! mountpoint -q "$BACKUP_MOUNT_POINT"; then
        echo "Backup drive not mounted. Mounting by UUID..."
        mkdir -p "$BACKUP_MOUNT_POINT"
        mount UUID="$BACKUP_DRIVE_UUID" "$BACKUP_MOUNT_POINT" || {
            echo "ERROR: Failed to mount backup drive"
            exit 1
        }
    fi
}

ensure_backup_drive_mounted

# Create directories
mkdir -p "$BACKUP_DIR"
mkdir -p "$BACKUP_MOUNT_POINT/logs"

echo "Starting full disk backup at $(date)" | tee "$LOG_FILE"
echo "Source: $SOURCE_DISK" | tee -a "$LOG_FILE"
echo "Destination: $BACKUP_DIR/$BACKUP_NAME.img.gz" | tee -a "$LOG_FILE"

# Check available space
DISK_SIZE=$(blockdev --getsize64 $SOURCE_DISK)
DISK_SIZE_GB=$((DISK_SIZE / 1024 / 1024 / 1024))
AVAIL_SPACE=$(df "$BACKUP_MOUNT_POINT" | awk 'NR==2 {print $4}')
AVAIL_SPACE_GB=$((AVAIL_SPACE / 1024 / 1024))

echo "Disk size: ${DISK_SIZE_GB}GB" | tee -a "$LOG_FILE"
echo "Available space: ${AVAIL_SPACE_GB}GB" | tee -a "$LOG_FILE"

if [ $AVAIL_SPACE_GB -lt $((DISK_SIZE_GB / 2)) ]; then
    echo "WARNING: Low space available!" | tee -a "$LOG_FILE"
fi

# Create the backup with progress
echo "Creating compressed disk image..." | tee -a "$LOG_FILE"
echo "This will take a while - backing up entire ${DISK_SIZE_GB}GB disk..." | tee -a "$LOG_FILE"

dd if="$SOURCE_DISK" bs=64K status=progress | \
    gzip -c > "$BACKUP_DIR/$BACKUP_NAME.img.gz" 2>&1 | tee -a "$LOG_FILE"

# Verify backup was created
if [ -f "$BACKUP_DIR/$BACKUP_NAME.img.gz" ]; then
    BACKUP_SIZE=$(ls -lh "$BACKUP_DIR/$BACKUP_NAME.img.gz" | awk '{print $5}')
    echo "Backup completed successfully!" | tee -a "$LOG_FILE"
    echo "Backup size: $BACKUP_SIZE" | tee -a "$LOG_FILE"
    
    # Create checksum
    echo "Creating checksum..." | tee -a "$LOG_FILE"
    cd "$BACKUP_DIR"
    sha256sum "$BACKUP_NAME.img.gz" > "$BACKUP_NAME.sha256"
    
    # Clean up old backups (keep last 3)
    echo "Cleaning up old backups..." | tee -a "$LOG_FILE"
    ls -t endeavouros_full_*.img.gz 2>/dev/null | tail -n +4 | xargs -r rm -v | tee -a "$LOG_FILE"
    ls -t endeavouros_full_*.sha256 2>/dev/null | tail -n +4 | xargs -r rm -v | tee -a "$LOG_FILE"
    
else
    echo "ERROR: Backup failed!" | tee -a "$LOG_FILE"
    exit 1
fi

echo "Full backup completed at $(date)" | tee -a "$LOG_FILE"
