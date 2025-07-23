#!/bin/bash
# EndeavourOS Nuclear Restore Script

echo "=== ENDEAVOUROS NUCLEAR RESTORE ==="
echo "WARNING: This will COMPLETELY OVERWRITE the target drive!"
echo ""

# List available backups
echo "Available backups:"
ls -la /mnt/backup_drive/disk_images/endeavouros_full_*.img.gz

echo ""
read -p "Enter backup filename: " BACKUP_FILE
read -p "Enter target drive (e.g., /dev/sda): " TARGET_DRIVE

echo ""
echo "About to restore $BACKUP_FILE to $TARGET_DRIVE"
echo "This will DESTROY all data on $TARGET_DRIVE"
read -p "Type 'YES' to continue: " CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    echo "Restore cancelled."
    exit 0
fi

echo "Starting restore..."
gunzip -c "/mnt/backup_drive/disk_images/$BACKUP_FILE" | dd of="$TARGET_DRIVE" bs=64K status=progress

echo ""
echo "Restore completed! You can now reboot into your restored system."
