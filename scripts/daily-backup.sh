#!/bin/bash
# Daily incremental backup using Borg

set -e

# Configuration
BACKUP_DRIVE_UUID="YOUR_BACKUP_DRIVE_UUID_HERE"
BACKUP_MOUNT_POINT="/mnt/backup_drive"
REPO="$BACKUP_MOUNT_POINT/borg-repo"
BACKUP_NAME="${HOSTNAME}-$(date +%Y-%m-%d_%H%M%S)"
LOG_FILE="$BACKUP_MOUNT_POINT/logs/daily_backup_$(date +%Y%m%d).log"
export BORG_PASSPHRASE="YOUR_PASSPHRASE_HERE"

# Disable sleep during backup
echo "Disabling system sleep for backup..." | tee "$LOG_FILE"
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
        echo "Backup drive not mounted. Mounting by UUID..." | tee -a "$LOG_FILE"
        mkdir -p "$BACKUP_MOUNT_POINT"
        mount UUID="$BACKUP_DRIVE_UUID" "$BACKUP_MOUNT_POINT" || {
            echo "ERROR: Failed to mount backup drive" | tee -a "$LOG_FILE"
            exit 1
        }
    fi
}

ensure_backup_drive_mounted

# Create log directory
mkdir -p "$BACKUP_MOUNT_POINT/logs"

echo "Starting daily backup at $(date)" | tee -a "$LOG_FILE"

# Initialize repository if it doesn't exist
if [ ! -d "$REPO" ]; then
    echo "Initializing Borg repository..." | tee -a "$LOG_FILE"
    borg init --encryption=repokey "$REPO" 2>&1 | tee -a "$LOG_FILE"
fi

# Create backup (excluding large media directories)
echo "Creating incremental backup..." | tee -a "$LOG_FILE"
borg create \
    --verbose --filter AME \
    --list --stats --show-rc \
    --compression lz4 \
    --exclude-caches \
    --exclude '/home/*/Music/*' \
    --exclude '/home/*/Videos/*' \
    --exclude '/home/*/Pictures/*' \
    --exclude '/home/*/Dropbox/*' \
    --exclude '/home/*/.cache/*' \
    --exclude '/home/*/.local/share/Trash/*' \
    --exclude '/home/*/.mozilla/firefox/*/Cache/*' \
    --exclude '/home/*/.thumbnails/*' \
    --exclude '/home/*/Downloads/*.iso' \
    --exclude '/var/cache/*' \
    --exclude '/var/tmp/*' \
    --exclude '/tmp/*' \
    --exclude "$BACKUP_MOUNT_POINT/*" \
    --exclude '/media/*' \
    --exclude '*.pyc' \
    "$REPO::$BACKUP_NAME" \
    /etc \
    /home \
    /usr/local \
    /var/log \
    2>&1 | tee -a "$LOG_FILE"

backup_exit=$?

echo "Pruning repository..." | tee -a "$LOG_FILE"
borg prune \
    --list \
    --glob-archives "${HOSTNAME}-*" \
    --show-rc \
    --keep-daily 7 \
    --keep-weekly 4 \
    --keep-monthly 6 \
    "$REPO" 2>&1 | tee -a "$LOG_FILE"

prune_exit=$?

# Use highest exit code as global exit code
global_exit=$(( backup_exit > prune_exit ? backup_exit : prune_exit ))

if [ ${global_exit} -eq 0 ]; then
    echo "Backup and Prune finished successfully" | tee -a "$LOG_FILE"
elif [ ${global_exit} -eq 1 ]; then
    echo "Backup and/or Prune finished with warnings" | tee -a "$LOG_FILE"
else
    echo "Backup and/or Prune finished with errors" | tee -a "$LOG_FILE"
fi

echo "Daily backup completed at $(date)" | tee -a "$LOG_FILE"
exit ${global_exit}
