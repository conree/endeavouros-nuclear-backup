#!/bin/bash
# Save package lists and system configuration

set -e

# Configuration
BACKUP_DRIVE_UUID="YOUR_BACKUP_DRIVE_UUID_HERE"
BACKUP_MOUNT_POINT="/mnt/backup_drive"
BACKUP_DIR="$BACKUP_MOUNT_POINT/config"
DATE=$(date +%Y%m%d_%H%M%S)
CONFIG_BACKUP="$BACKUP_DIR/config_$DATE"

# Ensure backup drive is mounted
ensure_backup_drive_mounted() {
    if ! mountpoint -q "$BACKUP_MOUNT_POINT"; then
        echo "Backup drive not mounted. Mounting by UUID..."
        sudo mkdir -p "$BACKUP_MOUNT_POINT"
        sudo mount UUID="$BACKUP_DRIVE_UUID" "$BACKUP_MOUNT_POINT" || {
            echo "ERROR: Failed to mount backup drive"
            exit 1
        }
    fi
}

ensure_backup_drive_mounted

mkdir -p "$BACKUP_DIR"
mkdir -p "$CONFIG_BACKUP"

echo "Saving system configuration at $(date)"

# Save package lists
echo "Saving package lists..."
pacman -Qqe > "$CONFIG_BACKUP/pkglist.txt"
pacman -Qqem > "$CONFIG_BACKUP/aurlist.txt"
pacman -Qe > "$CONFIG_BACKUP/pkglist_with_versions.txt"

# Detect AUR helper
if command -v yay >/dev/null 2>&1; then
    AUR_HELPER="yay"
elif command -v paru >/dev/null 2>&1; then
    AUR_HELPER="paru"
else
    AUR_HELPER="none"
fi
echo "$AUR_HELPER" > "$CONFIG_BACKUP/aur_helper.txt"

# Create targeted config backup (avoiding large browser data)
echo "Backing up essential configurations..."
TEMP_CONFIG="/tmp/essential_configs_$$"
mkdir -p "$TEMP_CONFIG"

# Copy critical config directories
cp -r /home/YOUR_USERNAME/.config/fish "$TEMP_CONFIG/" 2>/dev/null || true
cp -r /home/YOUR_USERNAME/.config/wezterm "$TEMP_CONFIG/" 2>/dev/null || true
cp -r /home/YOUR_USERNAME/.config/ghostty "$TEMP_CONFIG/" 2>/dev/null || true
cp -r /home/YOUR_USERNAME/.config/yazi "$TEMP_CONFIG/" 2>/dev/null || true
cp -r /home/YOUR_USERNAME/.config/fastfetch "$TEMP_CONFIG/" 2>/dev/null || true
cp -r /home/YOUR_USERNAME/.config/pop-shell "$TEMP_CONFIG/" 2>/dev/null || true
cp /home/YOUR_USERNAME/.config/starship.toml "$TEMP_CONFIG/" 2>/dev/null || true
cp /home/YOUR_USERNAME/.config/monitors.xml "$TEMP_CONFIG/" 2>/dev/null || true

# Copy other important directories
cp -r /home/YOUR_USERNAME/Keymapp "$TEMP_CONFIG/" 2>/dev/null || true
cp -r /home/YOUR_USERNAME/Documents "$TEMP_CONFIG/" 2>/dev/null || true
cp -r /home/YOUR_USERNAME/test-starship "$TEMP_CONFIG/" 2>/dev/null || true

# Copy important dotfiles
mkdir -p "$TEMP_CONFIG/dotfiles"
cp /home/YOUR_USERNAME/.bashrc "$TEMP_CONFIG/dotfiles/" 2>/dev/null || true
cp /home/YOUR_USERNAME/.gitconfig "$TEMP_CONFIG/dotfiles/" 2>/dev/null || true
cp -r /home/YOUR_USERNAME/.ssh "$TEMP_CONFIG/dotfiles/" 2>/dev/null || true

# Create the archive
tar -czf "$CONFIG_BACKUP/essential_configs.tar.gz" -C /tmp "essential_configs_$$"

# Clean up temp directory
rm -rf "$TEMP_CONFIG"

# System configs
echo "Backing up system configurations..."
sudo tar -czf "$CONFIG_BACKUP/etc_backup.tar.gz" /etc/ 2>/dev/null || true
sudo cp -r /etc/NetworkManager "$CONFIG_BACKUP/" 2>/dev/null || true

# Services
systemctl --user list-unit-files --state=enabled > "$CONFIG_BACKUP/user_services.txt" 2>/dev/null || true
sudo systemctl list-unit-files --state=enabled > "$CONFIG_BACKUP/system_services.txt" 2>/dev/null || true

# Package managers
if command -v flatpak >/dev/null 2>&1; then
    flatpak list --app > "$CONFIG_BACKUP/flatpak_list.txt" 2>/dev/null || true
fi
if command -v snap >/dev/null 2>&1; then
    snap list > "$CONFIG_BACKUP/snap_list.txt" 2>/dev/null || true
fi

# Create restore script
cat > "$CONFIG_BACKUP/restore_packages.sh" << 'EOOF'
#!/bin/bash
echo "Restoring packages..."
sudo pacman -S --needed - < pkglist.txt

AUR_HELPER=$(cat aur_helper.txt)
if [ "$AUR_HELPER" != "none" ] && [ -s aurlist.txt ]; then
    $AUR_HELPER -S --needed - < aurlist.txt
fi

echo "To restore configs:"
echo "1. tar -xzf essential_configs.tar.gz -C /tmp/"
echo "2. Copy configs back to ~/.config/ as needed"
echo "3. Review etc_backup.tar.gz before extracting to /"
EOOF

chmod +x "$CONFIG_BACKUP/restore_packages.sh"

# Clean up old backups (keep last 10)
ls -t "$BACKUP_DIR"/config_* 2>/dev/null | tail -n +11 | xargs -r rm -rf

echo "Configuration backup completed: $CONFIG_BACKUP"
echo "Essential configs backed up efficiently (avoiding large browser data)"
