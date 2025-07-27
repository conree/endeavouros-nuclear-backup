# Installation Guide 🛠️

> **Complete step-by-step installation of the EndeavourOS Nuclear Backup System**

## 📋 Prerequisites

### System Requirements
- **Operating System**: EndeavourOS or Arch-based Linux
- **Storage**: External drive (1TB+ recommended for full protection)
- **Network**: Internet connection for dependency installation
- **Access**: Root/sudo privileges

### Hardware Recommendations
- **Backup Drive**: USB 3.0+ or eSATA for faster transfers
- **System Drive**: SSD recommended (faster backup creation)
- **RAM**: 4GB+ (for large file compression)

## 🚀 Step-by-Step Installation

### Step 1: Prepare Your Backup Drive

#### Option A: New Drive Setup
```bash
# List available drives
lsblk

# Format the backup drive (replace /dev/sdX with your drive - BE CAREFUL!)
sudo fdisk /dev/sdX
# Create new partition table (g for GPT)
# Create new partition (n, then accept defaults)
# Write changes (w)

# Format with ext4 filesystem
sudo mkfs.ext4 -L "BACKUP_DRIVE" /dev/sdX1

# Get the UUID (you'll need this later)
sudo blkid /dev/sdX1
# Copy the UUID value for later use
```

#### Option B: Existing Drive
```bash
# Get the UUID of your existing backup drive
sudo blkid /dev/sdX1

# Ensure it's unmounted
sudo umount /dev/sdX1

# Optional: Clear existing data
sudo rm -rf /mnt/backup_data/* # Only if you want fresh start
```

### Step 2: Install Dependencies

```bash
# Update system
sudo pacman -Syu

# Install required packages
sudo pacman -S borgbackup git

# Verify installation
borg --version
git --version
```

### Step 3: Download Nuclear Backup System

```bash
# Clone the repository
cd ~/Projects  # or your preferred directory
git clone https://github.com/conree/endeavouros-nuclear-backup.git
cd endeavouros-nuclear-backup

# Make scripts executable (safety check)
chmod +x scripts/*.sh
chmod +x scripts/tests/*.sh
```

### Step 4: Install Scripts

```bash
# Create nuclear backup directory
sudo mkdir -p /usr/local/bin/nuclear-backup

# Copy all scripts
sudo cp scripts/*.sh /usr/local/bin/nuclear-backup/
sudo cp scripts/tests/*.sh /usr/local/bin/nuclear-backup/

# Set proper permissions
sudo chmod +x /usr/local/bin/nuclear-backup/*.sh
sudo chown root:root /usr/local/bin/nuclear-backup/*.sh

# Verify installation
ls -la /usr/local/bin/nuclear-backup/
```

### Step 5: Configure Drive UUID

```bash
# Get your backup drive UUID (from Step 1)
BACKUP_UUID=$(sudo blkid -s UUID -o value /dev/sdX1)
echo "Your backup UUID: $BACKUP_UUID"

# Update all scripts with your UUID
sudo sed -i "s/YOUR_BACKUP_DRIVE_UUID_HERE/$BACKUP_UUID/g" /usr/local/bin/nuclear-backup/*.sh

# Verify the change worked
grep "BACKUP_DRIVE_UUID" /usr/local/bin/nuclear-backup/daily-backup.sh
```

### Step 6: Set Up Borg Encryption

```bash
# Generate a secure passphrase
BORG_PASSPHRASE=$(openssl rand -base64 32)
echo "Generated passphrase: $BORG_PASSPHRASE"
echo "SAVE THIS PASSPHRASE SAFELY - YOU NEED IT FOR RECOVERY!"

# Create secure directory for passphrase
sudo mkdir -p /etc/nuclear-backup
sudo chmod 700 /etc/nuclear-backup

# Store passphrase securely
echo "$BORG_PASSPHRASE" | sudo tee /etc/nuclear-backup/borg-passphrase
sudo chmod 600 /etc/nuclear-backup/borg-passphrase

# Update the daily backup script with your passphrase
sudo sed -i "s/CHANGE_THIS_PASSPHRASE/$BORG_PASSPHRASE/g" /usr/local/bin/nuclear-backup/daily-backup.sh

# Verify the change
sudo grep "BORG_PASSPHRASE=" /usr/local/bin/nuclear-backup/daily-backup.sh
```

### Step 7: Set Up Mount Point

```bash
# Create mount point
sudo mkdir -p /mnt/backup_drive

# Add to fstab for automatic mounting
echo "UUID=$BACKUP_UUID /mnt/backup_drive ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab

# Test mounting
sudo mount -a
df -h | grep backup_drive

# If successful, you should see your backup drive mounted
```

### Step 8: Install Systemd Services

```bash
# Copy service and timer files
sudo cp systemd/*.service /etc/systemd/system/
sudo cp systemd/*.timer /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload

# Enable timers (but don't start yet - we'll test first)
sudo systemctl enable daily-backup.timer
sudo systemctl enable weekly-full-backup.timer
```

### Step 9: Initial Testing

#### Test 1: Configuration Backup
```bash
# Test the configuration backup (safest test)
sudo /usr/local/bin/nuclear-backup/save-config.sh

# Check results
ls -la /mnt/backup_drive/config/
```

#### Test 2: Borg Initialization
```bash
# Test the daily backup (this initializes Borg repository)
sudo /usr/local/bin/nuclear-backup/daily-backup.sh

# This will take a few minutes for the first run
# Check results
ls -la /mnt/backup_drive/borg-repo/
```

#### Test 3: Verify Borg Access
```bash
# Test Borg repository access
export BORG_PASSPHRASE=$(sudo cat /etc/nuclear-backup/borg-passphrase)
sudo -E borg list /mnt/backup_drive/borg-repo

# You should see your first backup archive
```

### Step 10: Start Automation

```bash
# Start the timers
sudo systemctl start daily-backup.timer
sudo systemctl start weekly-full-backup.timer

# Check timer status
systemctl list-timers | grep backup

# Check service status
systemctl status daily-backup.timer
systemctl status weekly-full-backup.timer
```

### Step 11: Run Comprehensive Test

```bash
# Run the complete test suite to verify everything works
sudo /usr/local/bin/nuclear-backup/test-backup-system.sh

# Should show all tests passing:
# [PASS] ✓ Backup drive accessible
# [PASS] ✓ Borg repository healthy
# [PASS] ✓ File recovery verified
# [PASS] ✓ Configuration backups valid
# [PASS] ✓ Disk images verified
# [PASS] ✓ Services operational
```

## 🧪 Verification Steps

### Backup Recovery Test
```bash
# Test file recovery from Borg backup
export BORG_PASSPHRASE=$(sudo cat /etc/nuclear-backup/borg-passphrase)
mkdir -p /tmp/backup_test

# Extract a configuration file
sudo -E borg extract /mnt/backup_drive/borg-repo::$(sudo -E borg list /mnt/backup_drive/borg-repo | head -1 | awk '{print $1}') home/$(whoami)/.config/fish/config.fish

# Check if extraction worked
ls -la /tmp/backup_test/home/$(whoami)/.config/fish/

# Clean up test
rm -rf /tmp/backup_test
```

### System Status Check
```bash
echo "=== NUCLEAR BACKUP SYSTEM STATUS ==="

echo "1. Scripts installed:"
ls -la /usr/local/bin/nuclear-backup/

echo "2. Mount point active:"
df -h | grep backup_drive

echo "3. Timers enabled:"
systemctl list-timers | grep backup

echo "4. Borg repository:"
ls -la /mnt/backup_drive/borg-repo/

echo "5. Configuration backups:"
ls -la /mnt/backup_drive/config/

echo "=== INSTALLATION COMPLETE ==="
```

## 🛡️ Nuclear Protection Layers

### Layer 1: Configuration Snapshots
- **Essential app configs**: Fish, Wezterm, Yazi, etc.
- **Package lists & AUR packages**
- **System settings & network configs**
- **Size**: ~13MB | **Speed**: 30 seconds

### Layer 2: Incremental File Backups (Borg)
- **Encrypted, deduplicated daily backups**
- **File-level recovery from any date**
- **Size**: ~21GB first run, changes only after
- **Retention**: 7 daily, 4 weekly, 6 monthly

### Layer 3: Complete Disk Images
- **Bit-for-bit bootable system clones**
- **Nuclear disaster recovery option**
- **Size**: ~210GB compressed | **Complete restoration**
- **Frequency**: Weekly automated creation

## 📅 Backup Schedule

After installation, your system will automatically:

- **Daily Backups**: Every day, 30 minutes after boot + daily at midnight
- **Weekly Full Images**: Every Sunday at 2:00 AM
- **Configuration Snapshots**: With each backup run

## 🔧 Customization Options

### Change Backup Schedule
```bash
# Edit timer files
sudo systemctl edit daily-backup.timer
sudo systemctl edit weekly-full-backup.timer

# Reload after changes
sudo systemctl daemon-reload
```

### Modify Backup Exclusions
```bash
# Edit daily backup script
sudo nano /usr/local/bin/nuclear-backup/daily-backup.sh

# Look for --exclude lines and modify as needed
```

### Adjust Retention Policy
```bash
# Edit the retention settings in daily-backup.sh
# Look for --keep-daily, --keep-weekly, --keep-monthly
sudo nano /usr/local/bin/nuclear-backup/daily-backup.sh
```

## 🚨 Important Security Notes

### Passphrase Management
- **Save your Borg passphrase securely** - Without it, encrypted backups are unrecoverable
- **Consider using a password manager** - Store the passphrase safely
- **Test recovery regularly** - Ensure you can access your backups

### Access Control
- **Scripts run as root** - They need system-level access
- **Backup drive should be encrypted** - Additional layer of security
- **Physical security** - Keep backup drives in secure locations

## 🔍 Troubleshooting

### Common Issues

#### Mount Fails
```bash
# Check UUID is correct
sudo blkid /dev/sdX1

# Check fstab entry
grep backup_drive /etc/fstab

# Manual mount test
sudo mount UUID=your-uuid /mnt/backup_drive
```

#### Borg Permission Errors
```bash
# Ensure you're using sudo with -E flag for environment variables
sudo -E borg list /mnt/backup_drive/borg-repo

# Check repository ownership
ls -la /mnt/backup_drive/borg-repo/
```

#### Timer Issues
```bash
# Check timer status
systemctl status daily-backup.timer

# Check logs
journalctl -u daily-backup.service -f

# Restart timers if needed
sudo systemctl restart daily-backup.timer
```

#### Passphrase Issues
```bash
# Verify passphrase file exists and is readable
sudo cat /etc/nuclear-backup/borg-passphrase

# Check script has correct passphrase
sudo grep "BORG_PASSPHRASE=" /usr/local/bin/nuclear-backup/daily-backup.sh

# They should match exactly
```

### Log Locations
- **Backup logs**: `/mnt/backup_drive/logs/`
- **System logs**: `journalctl -u daily-backup.service`
- **Timer logs**: `journalctl -u daily-backup.timer`

## 📝 Post-Installation Checklist

- [ ] Backup drive UUID configured in all scripts
- [ ] Borg passphrase set and securely stored
- [ ] Mount point working automatically
- [ ] Configuration backup tested successfully
- [ ] Borg repository initialized and tested
- [ ] Timers enabled and showing next run times
- [ ] File recovery test completed successfully
- [ ] Full backup schedule confirmed (weekly on Sunday)
- [ ] Comprehensive test suite passes all tests

## 🎯 Next Steps

1. **[📖 Read Testing Guide](docs/TESTING.md)** - Learn testing procedures
2. **[🔧 Review Recovery Options](../README.md#recovery-scenarios)** - Understand disaster recovery
3. **Schedule Regular Tests** - Run monthly verification
4. **Monitor Logs** - Check backup status regularly

## 📊 Storage Requirements

| Backup Type | Initial Size | Growth Rate | Purpose |
|-------------|--------------|-------------|---------|
| **Configuration** | ~13MB | Minimal | Quick app restoration |
| **Incremental** | ~21GB | Daily changes only | File-level recovery |
| **Full Disk** | ~210GB | Weekly replacement | Nuclear disaster recovery |
| **Total Usage** | ~230GB | ~1GB/week | Complete protection |

---

**🎉 Congratulations! Your nuclear backup system is now active and protecting your data 24/7.**

> **Remember**: The best backup system is worthless if you don't test recovery. Schedule regular recovery tests to ensure your data is truly safe.

**🛡️ Your data is now indestructible. Sleep well! ☢️🚀**
