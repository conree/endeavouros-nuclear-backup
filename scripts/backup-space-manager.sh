#!/bin/bash

# Backup disk space management script
# Add this to your main backup script

BACKUP_DRIVE="/mnt/backup_drive"
DISK_IMAGES_DIR="$BACKUP_DRIVE/disk_images"
MIN_FREE_SPACE_GB=300  # Keep at least 300GB free (your backups are large!)
KEEP_RECENT_BACKUPS=3  # Always keep the 3 most recent backups

# Function to convert human-readable sizes to bytes
size_to_bytes() {
    local size=$1
    local num=$(echo "$size" | sed 's/[^0-9.]//g')
    local unit=$(echo "$size" | sed 's/[0-9.]//g' | tr '[:lower:]' '[:upper:]')
    
    case $unit in
        G|GB) echo $(echo "$num * 1024 * 1024 * 1024" | bc -l | cut -d. -f1) ;;
        T|TB) echo $(echo "$num * 1024 * 1024 * 1024 * 1024" | bc -l | cut -d. -f1) ;;
        *) echo "$num" ;;
    esac
}

# Function to get available space in GB
get_available_space_gb() {
    df -BG "$BACKUP_DRIVE" | awk 'NR==2 {gsub(/G/, "", $4); print $4}'
}

# Function to estimate next backup size (use largest recent backup as estimate)
estimate_next_backup_size_gb() {
    local latest_size=$(ls -la "$DISK_IMAGES_DIR"/*.img.gz 2>/dev/null | tail -3 | awk '{print $5}' | sort -n | tail -1)
    if [[ -n "$latest_size" ]]; then
        echo $((latest_size / 1024 / 1024 / 1024 + 10))  # Add 10GB buffer
    else
        echo 50  # Default estimate
    fi
}

# Function to clean old backups
cleanup_old_backups() {
    echo "[INFO] Starting backup cleanup process..."
    
    # Get list of all disk image backups sorted by date (oldest first)
    local backup_list=$(ls -t "$DISK_IMAGES_DIR"/*.img.gz 2>/dev/null | tac)
    local backup_count=$(echo "$backup_list" | wc -l)
    
    if [[ $backup_count -le $KEEP_RECENT_BACKUPS ]]; then
        echo "[INFO] Only $backup_count backups found. Keeping all (minimum: $KEEP_RECENT_BACKUPS)."
        return 0
    fi
    
    # Calculate how many to remove (keep the most recent ones)
    local remove_count=$((backup_count - KEEP_RECENT_BACKUPS))
    local removed_count=0
    
    echo "[INFO] Found $backup_count disk image backups"
    echo "[INFO] Will remove up to $remove_count old backups (keeping newest $KEEP_RECENT_BACKUPS)"
    
    # Remove oldest backups until we have enough space or reach minimum count
    for backup_file in $backup_list; do
        if [[ $removed_count -ge $remove_count ]]; then
            break
        fi
        
        local available_space=$(get_available_space_gb)
        local estimated_need=$(estimate_next_backup_size_gb)
        
        if [[ $available_space -gt $((MIN_FREE_SPACE_GB + estimated_need)) ]]; then
            echo "[INFO] Sufficient space available ($available_space GB). Stopping cleanup."
            break
        fi
        
        echo "[INFO] Removing old backup: $(basename "$backup_file")"
        local file_size=$(ls -lh "$backup_file" | awk '{print $5}')
        
        # Remove the backup file and its checksum
        rm -f "$backup_file"
        rm -f "${backup_file%.img.gz}.sha256"
        
        echo "[INFO] Freed up $file_size of space"
        removed_count=$((removed_count + 1))
    done
    
    echo "[INFO] Cleanup complete. Removed $removed_count old backups."
}

# Function to check if cleanup is needed before backup
check_space_before_backup() {
    local available_space=$(get_available_space_gb)
    local estimated_need=$(estimate_next_backup_size_gb)
    local total_needed=$((MIN_FREE_SPACE_GB + estimated_need))
    
    echo "[INFO] Space check before backup:"
    echo "[INFO]   Available space: ${available_space}GB"
    echo "[INFO]   Estimated backup size: ${estimated_need}GB"
    echo "[INFO]   Minimum free space required: ${MIN_FREE_SPACE_GB}GB"
    echo "[INFO]   Total space needed: ${total_needed}GB"
    
    if [[ $available_space -lt $total_needed ]]; then
        echo "[WARN] Insufficient space for backup. Starting cleanup..."
        cleanup_old_backups
        
        # Re-check after cleanup
        available_space=$(get_available_space_gb)
        if [[ $available_space -lt $total_needed ]]; then
            echo "[ERROR] Still insufficient space after cleanup!"
            echo "[ERROR] Available: ${available_space}GB, Needed: ${total_needed}GB"
            return 1
        else
            echo "[INFO] Cleanup successful. Proceeding with backup."
        fi
    else
        echo "[INFO] Sufficient space available. Proceeding with backup."
    fi
    
    return 0
}

# Function to show current backup inventory
show_backup_inventory() {
    echo "[INFO] Current backup inventory:"
    echo "[INFO] Disk Image Backups:"
    ls -lh "$DISK_IMAGES_DIR"/*.img.gz 2>/dev/null | while read -r line; do
        echo "[INFO]   $(echo "$line" | awk '{print $9, $5, $6, $7, $8}' | sed "s|$DISK_IMAGES_DIR/||")"
    done
    
    local total_size=$(du -sh "$DISK_IMAGES_DIR" | awk '{print $1}')
    local available_space=$(get_available_space_gb)
    echo "[INFO] Total disk images size: $total_size"
    echo "[INFO] Available space: ${available_space}GB"
}

# Main execution (uncomment the function you want to run)
case "${1:-check}" in
    "check")
        check_space_before_backup
        ;;
    "cleanup")
        cleanup_old_backups
        ;;
    "inventory")
        show_backup_inventory
        ;;
    *)
        echo "Usage: $0 {check|cleanup|inventory}"
        echo "  check    - Check space and cleanup if needed before backup"
        echo "  cleanup  - Force cleanup of old backups"
        echo "  inventory - Show current backup inventory"
        exit 1
        ;;
esac
