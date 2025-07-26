#!/bin/bash
# Master backup script that runs different backup types

set -e

BACKUP_TYPE="${1:-incremental}"
LOG_FILE="/mnt/backup_drive/logs/master_backup_$(date +%Y%m%d).log"

mkdir -p "/mnt/backup_drive/logs"

echo "=== Master Backup Started: $BACKUP_TYPE at $(date) ===" | tee "$LOG_FILE"

case "$BACKUP_TYPE" in
    "full")
        echo "Running full system backup..." | tee -a "$LOG_FILE"
        /usr/local/bin/configured/nuclear-backup/save-config.sh 2>&1 | tee -a "$LOG_FILE"
        /usr/local/bin/configured/nuclear-backup/full-backup.sh 2>&1 | tee -a "$LOG_FILE"
        ;;
    "incremental")
        echo "Running incremental backup..." | tee -a "$LOG_FILE"
        /usr/local/bin/configured/nuclear-backup/save-config.sh 2>&1 | tee -a "$LOG_FILE"
        /usr/local/bin/configured/nuclear-backup/daily-backup.sh 2>&1 | tee -a "$LOG_FILE"
        ;;
    "config")
        echo "Running configuration backup only..." | tee -a "$LOG_FILE"
        /usr/local/bin/configured/nuclear-backup/save-config.sh 2>&1 | tee -a "$LOG_FILE"
        ;;
    *)
        echo "Usage: $0 [full|incremental|config]" | tee -a "$LOG_FILE"
        echo "Default: incremental" | tee -a "$LOG_FILE"
        exit 1
        ;;
esac

echo "=== Master Backup Completed: $BACKUP_TYPE at $(date) ===" | tee -a "$LOG_FILE"
