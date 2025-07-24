# EndeavourOS Nuclear Backup System 🛡️☢️

> **Enterprise-grade nuclear backup system with triple-redundancy protection, automated scheduling, and complete disaster recovery**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/shell_script-%23121011.svg?style=flat&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![EndeavourOS](https://img.shields.io/badge/EndeavourOS-%237F52FF.svg?style=flat&logo=endeavouros&logoColor=white)](https://endeavouros.com)

## 🚀 Why Nuclear Backup?

**Traditional backup solutions fail when you need them most.** This system provides **nuclear-grade protection** with multiple recovery scenarios:

- 💀 **Hardware dies** → Boot from live USB, restore complete disk image
- 🔥 **System corrupted** → Extract clean files from incremental backups  
- 🗑️ **Accidental deletion** → Recover individual files from any backup date
- ⚙️ **Config destroyed** → Restore app settings from configuration snapshots

## 🏗️ Triple-Redundancy Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    NUCLEAR PROTECTION LAYERS                │
├─────────────────────────────────────────────────────────────┤
│  LAYER 1: Configuration Snapshots                          │
│  • Essential app configs (Fish, Wezterm, Yazi, etc.)      │
│  • Package lists & AUR packages                            │
│  • System settings & network configs                       │
│  • Size: ~13MB | Speed: 30 seconds                        │
├─────────────────────────────────────────────────────────────┤
│  LAYER 2: Incremental File Backups (Borg)                 │
│  • Encrypted, deduplicated daily backups                   │
│  • File-level recovery from any date                       │
│  • Size: ~21GB first run, changes only after              │
│  • Retention: 7 daily, 4 weekly, 6 monthly                │
├─────────────────────────────────────────────────────────────┤
│  LAYER 3: Complete Disk Images                             │
│  • Bit-for-bit bootable system clones                      │
│  • Nuclear disaster recovery option                        │
│  • Size: ~210GB compressed | Complete restoration          │
│  • Frequency: Weekly automated creation                     │
└─────────────────────────────────────────────────────────────┘
```

## ⚡ Key Features

### 🔒 **Security & Reliability**
- **UUID-based drive mounting** - Never fails due to device name changes
- **Encrypted Borg backups** - Your data stays private
- **Checksum verification** - Detect corruption immediately
- **Sleep-safe operation** - Automatic power management

### 🤖 **Complete Automation**
- **Daily incremental backups** - 30 minutes after boot + daily schedule
- **Weekly full disk imaging** - Every Sunday at 2 AM
- **Automatic cleanup** - Maintains optimal storage usage
- **Self-monitoring** - Comprehensive logging system

### 🛠️ **Professional Features**
- **Multiple recovery scenarios** - From single files to bare metal
- **Battle-tested reliability** - Verified recovery procedures
- **Enterprise-grade retention** - Intelligent backup rotation
- **Community-driven** - Open source and extensible

## 🔧 Recovery Scripts Explained

### Two-Tier Recovery System:

**`RESTORE_SYSTEM.sh` (Emergency Recovery)**
- **Location**: Automatically copied to backup drive
- **Purpose**: Complete bare-metal system restoration
- **Usage**: Boot from live USB when system won't start
- **Scenario**: "My computer is dead, I need everything back"
- **Features**: Streamlined for disaster scenarios

**`restore-system.sh` (Guided Recovery)**  
- **Location**: `/usr/local/bin/nuclear-backup/`
- **Purpose**: Interactive file and configuration recovery
- **Usage**: Run from working EndeavourOS system
- **Scenario**: "I need to recover specific files or configs"
- **Features**: Detailed options and interactive guidance

**Note on Naming**: CAPS = Emergency/Nuclear recovery, lowercase = Guided/Surgical recovery

## 📋 System Requirements

- **OS**: EndeavourOS (Arch-based systems)
- **Storage**: External drive (1TB+ recommended)
- **Dependencies**: `borgbackup`, `systemd`
- **Privileges**: Root access for system-level backups

## 🚀 Quick Start

### 1. **Clone Repository**
```bash
git clone https://github.com/conree/endeavouros-nuclear-backup.git
cd endeavouros-nuclear-backup
```

### 2. **Prepare External Drive**
```bash
# Format your backup drive (replace /dev/sdX with your drive)
sudo mkfs.ext4 -L "BACKUP_DRIVE" /dev/sdX1

# Get the UUID for configuration
sudo blkid /dev/sdX1
```

### 3. **Install System**
```bash
# Install dependencies
sudo pacman -S borgbackup

# Copy scripts
sudo cp scripts/* /usr/local/bin/nuclear-backup/
sudo chmod +x /usr/local/bin/nuclear-backup/*.sh

# Install systemd services
sudo cp systemd/* /etc/systemd/system/

# Update UUIDs in scripts (replace with your actual UUID)
sudo sed -i 's/YOUR_BACKUP_DRIVE_UUID_HERE/actual-uuid-from-blkid/g' /usr/local/bin/nuclear-backup/*.sh
```

### 4. **Configure & Enable**
```bash
# Set your Borg encryption passphrase
sudo nano /usr/local/bin/nuclear-backup/daily-backup.sh
# Change: export BORG_PASSPHRASE="CHANGE_THIS_PASSPHRASE"

# Enable automated backups
sudo systemctl daemon-reload
sudo systemctl enable --now daily-backup.timer
sudo systemctl enable --now weekly-full-backup.timer
```

### 5. **Test Your Protection**
```bash
# Test configuration backup
sudo /usr/local/bin/nuclear-backup/save-config.sh

# Test incremental backup (initializes Borg repository)
sudo /usr/local/bin/nuclear-backup/daily-backup.sh

# Check system status
systemctl list-timers | grep backup
```

## 📚 Documentation

- **[📖 Installation Guide](INSTALLATION.md)** - Detailed setup instructions
- **[🔧 Recovery Procedures](docs/RECOVERY.md)** - Complete disaster recovery guide
- **[🏗️ System Architecture](docs/ARCHITECTURE.md)** - Technical design details
- **[🧪 Testing Guide](docs/TESTING.md)** - Verify your backups work
- **[⚙️ Customization](docs/CUSTOMIZATION.md)** - Adapt for your setup

## 🛡️ Recovery Scenarios

### **Scenario 1: File Recovery**
```bash
# List available backups
export BORG_PASSPHRASE="your-passphrase"
sudo borg list /mnt/backup_drive/borg-repo

# Extract specific file
sudo borg extract /mnt/backup_drive/borg-repo::archive-name path/to/file
```

### **Scenario 2: Configuration Recovery**
```bash
# Restore app configurations
cd /tmp
tar -xzf /mnt/backup_drive/config/config_DATE/essential_configs.tar.gz
# Copy desired configs back to ~/.config/
```

### **Scenario 3: Nuclear Recovery**
```bash
# Boot from live USB
# Mount backup drive
mount UUID=your-uuid /mnt/backup_drive

# Run automated restore
/mnt/backup_drive/RESTORE_SYSTEM.sh

# Select backup and target drive
# System restored identically
```

## 🧪 Testing Your Backup System

### Monthly Health Check
```bash
# Run comprehensive test suite
sudo /usr/local/bin/nuclear-backup/test-backup-system.sh
```

### What Gets Tested
- ✅ Borg repository health and integrity
- ✅ File recovery capability
- ✅ Configuration backup validation
- ✅ Disk image checksum verification
- ✅ Storage usage analysis
- ✅ Service status and scheduling
- ✅ Backup log analysis

**Run this test monthly to ensure your nuclear backup system remains bulletproof!**

## 📊 Storage Requirements

| Backup Type | Initial Size | Growth Rate | Purpose |
|-------------|--------------|-------------|---------|
| **Configuration** | ~13MB | Minimal | Quick app restoration |
| **Incremental** | ~21GB | Daily changes only | File-level recovery |
| **Full Disk** | ~210GB | Weekly replacement | Nuclear disaster recovery |
| **Total Usage** | ~230GB | ~1GB/week | Complete protection |

## 🤝 Contributing

We welcome contributions! This system was battle-tested through real disaster scenarios and community feedback makes it stronger.

- **🐛 Bug Reports**: Open an issue with system details
- **💡 Feature Requests**: Describe your use case
- **📝 Documentation**: Help improve guides
- **🔧 Code**: Submit pull requests

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **EndeavourOS Community** - For the amazing Arch-based distribution
- **Borg Backup** - For the excellent deduplication backup tool  
- **SystemD** - For reliable service management
- **Real-world testing** - This system survived actual disasters

## ⚠️ Important Notes

- **Test your backups regularly** - Verify recovery procedures work
- **Keep multiple backup drives** - Redundancy for your redundancy
- **Document your setup** - Future you will thank present you
- **Update passphrases** - Security is an ongoing process

---

> **"The best backup system is the one that works when you desperately need it."**  
> This system has been battle-tested through real disasters. Your data is safe.

**🛡️ Stay Protected. Stay Nuclear. ☢️🚀**
