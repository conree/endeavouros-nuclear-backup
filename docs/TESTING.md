# Testing Guide 🧪

> **Comprehensive testing procedures for the EndeavourOS Nuclear Backup System**

## 🎯 Overview

The nuclear backup system includes extensive testing capabilities to verify all components are working correctly. Regular testing ensures your data protection remains bulletproof.

## 🚀 Quick Test

### Run the Complete Test Suite
```bash
# Run all 11 comprehensive tests
sudo scripts/tests/test-backup-system.sh
```

**Expected runtime**: 2-5 minutes  
**Expected result**: All tests should show `[PASS]` status

## 🔍 Test Categories

### **Test 1: Mount Point Verification**
**What it tests**: Backup drive accessibility and UUID-based mounting
```bash
# Manual verification
mountpoint -q /mnt/backup_drive && echo "✓ Mounted" || echo "✗ Not mounted"
```
**Failure causes**: Wrong UUID, drive not connected, permission issues

### **Test 2: Directory Structure**
**What it tests**: Required backup directories exist
```bash
# Manual verification
ls -la /mnt/backup_drive/
# Should show: borg-repo, config, disk_images, logs
```
**Failure causes**: Corrupted backup drive, incomplete setup

### **Test 3: Borg Repository Health**
**What it tests**: Backup repository integrity and encryption
```bash
# Manual verification
export BORG_PASSPHRASE="your-passphrase"
sudo -E borg check /mnt/backup_drive/borg-repo
```
**Failure causes**: Corrupted repository, wrong passphrase, damaged files

### **Test 4: Available Backup Archives**
**What it tests**: Backup history and retention policy
```bash
# Manual verification
sudo -E borg list /mnt/backup_drive/borg-repo
```
**Expected**: Multiple dated archives following retention rules
**Failure causes**: Backup failures, storage issues, pruning problems

### **Test 5: File Recovery Capability**
**What it tests**: Actual data extraction from backups
```bash
# Manual verification
mkdir -p /tmp/recovery_test
sudo -E borg extract /mnt/backup_drive/borg-repo::latest home/username/.bashrc
ls -la /tmp/recovery_test/home/username/.bashrc
rm -rf /tmp/recovery_test
```
**Failure causes**: Corrupted archives, permission issues, missing files

### **Test 6: Configuration Backup Validation**
**What it tests**: Configuration snapshot integrity
```bash
# Manual verification
ls -la /mnt/backup_drive/config/
tar -tzf /mnt/backup_drive/config/config_latest/essential_configs.tar.gz
```
**Failure causes**: Corrupted config backups, missing snapshots

### **Test 7: Disk Image Verification**
**What it tests**: Full system backup integrity
```bash
# Manual verification
cd /mnt/backup_drive/disk_images/
sha256sum -c *.sha256
```
**Expected**: All checksums should verify successfully
**Failure causes**: Corrupted images, incomplete backups, storage errors

### **Test 8: Storage Usage Analysis**
**What it tests**: Backup drive space and health
```bash
# Manual verification
df -h /mnt/backup_drive
```
**Warnings**:
- **>85% full**: Consider cleanup or larger drive
- **>70% full**: Monitor space usage

### **Test 9: Service Status**
**What it tests**: Automated backup scheduling
```bash
# Manual verification
systemctl status daily-backup.timer
systemctl status weekly-full-backup.timer
systemctl list-timers | grep backup
```
**Expected**: Both timers enabled and active with next run times

### **Test 10: Backup Schedule**
**What it tests**: Next scheduled backup times
```bash
# Manual verification
systemctl list-timers | grep backup
```
**Expected**:
- Daily backup: Every day at scheduled time
- Weekly backup: Sunday mornings

### **Test 11: Log Analysis**
**What it tests**: Recent backup success/failure status
```bash
# Manual verification
find /mnt/backup_drive/logs/ -name "*backup*" -mtime -7
tail /mnt/backup_drive/logs/daily_backup_$(date +%Y%m%d).log
```
**Expected**: Recent successful backup logs

## 📊 Test Results Interpretation

### **All Tests Pass (✓)**
```
[PASS] ✓ Backup drive accessible
[PASS] ✓ Borg repository healthy
[PASS] ✓ File recovery verified
[PASS] ✓ Configuration backups valid
[PASS] ✓ Disk images verified
[PASS] ✓ Services operational
```
**Status**: Nuclear backup system fully operational ✅

### **Partial Failures (⚠️)**
**Common warnings that don't require immediate action:**
- Storage usage 70-85%
- Older backup archives missing (normal with retention)
- Service enabled but not active (normal between runs)

### **Critical Failures (❌)**
**Issues requiring immediate attention:**
- Mount point inaccessible
- Borg repository corrupted
- No recent backup archives
- All disk image checksums failing

## 🛠️ Troubleshooting Guide

### **Backup Drive Issues**
```bash
# Check drive connection
lsblk | grep BACKUP_DRIVE

# Check UUID
sudo blkid | grep "your-uuid"

# Manual mount attempt
sudo mount UUID=your-uuid /mnt/backup_drive
```

### **Borg Repository Problems**
```bash
# Verify passphrase
echo $BORG_PASSPHRASE

# Check repository path
ls -la /mnt/backup_drive/borg-repo/

# Repository repair (use with caution)
sudo -E borg check --repair /mnt/backup_drive/borg-repo
```

### **Service Issues**
```bash
# Restart timers
sudo systemctl daemon-reload
sudo systemctl restart daily-backup.timer
sudo systemctl restart weekly-full-backup.timer

# Check logs
journalctl -u daily-backup.service -f
```

### **Storage Problems**
```bash
# Clean old backups manually
sudo find /mnt/backup_drive/disk_images/ -name "*.img.gz" -mtime +30 -delete

# Borg repository cleanup
sudo -E borg prune /mnt/backup_drive/borg-repo --keep-daily=7 --keep-weekly=4
```

## 📅 Testing Schedule

### **Daily Automated Testing**
The backup system performs self-checks during each backup:
- Repository integrity
- Available space
- Service health

### **Manual Testing Frequency**

**Weekly**: Quick test run
```bash
sudo scripts/tests/test-backup-system.sh
```

**Monthly**: Full verification + recovery test
```bash
# Run full test suite
sudo scripts/tests/test-backup-system.sh

# Perform actual file recovery test
mkdir /tmp/recovery_verification
sudo -E borg extract /mnt/backup_drive/borg-repo::latest home/username/.config/
# Verify recovered files, then cleanup
rm -rf /tmp/recovery_verification
```

**Quarterly**: Disaster simulation
- Test full system restore on spare hardware/VM
- Verify disk image bootability
- Document any changes needed

## 🔧 Test Environment Setup

### **Prerequisites for Testing**
```bash
# Ensure you have the passphrase
sudo cat /etc/nuclear-backup/borg-passphrase

# Verify backup drive is mounted
mountpoint /mnt/backup_drive

# Check available space for test operations
df -h /mnt/backup_drive
```

### **Safe Testing Practices**
- **Never test on production data** without backups
- **Use temporary directories** for recovery tests
- **Verify space** before running tests
- **Keep test logs** for troubleshooting

## 📋 Test Report Template

### **Monthly Test Report**
```
Date: ___________
Tester: ___________

Test Results:
□ Mount Point: PASS/FAIL
□ Borg Health: PASS/FAIL  
□ File Recovery: PASS/FAIL
□ Config Backups: PASS/FAIL
□ Disk Images: PASS/FAIL
□ Services: PASS/FAIL

Storage Usage: _____%
Archive Count: _____
Issues Found: _____
Actions Taken: _____

Next Test Date: ___________
```

## 🚨 Emergency Procedures

### **If All Tests Fail**
1. **Check physical connections** (USB, power)
2. **Verify drive health** with `smartctl`
3. **Try different USB port** or cable
4. **Boot from live USB** and test drive access

### **If Borg Repository Corrupted**
1. **Do not panic** - disk images provide full recovery
2. **Check disk image integrity** first
3. **Consider repository rebuild** from disk image
4. **Contact support** if needed

### **If Services Not Running**
1. **Check system logs** for errors
2. **Verify timer configuration** files
3. **Restart systemd services**
4. **Reinstall if necessary**

## 📚 Advanced Testing

### **Performance Testing**
```bash
# Time backup operations
time sudo /usr/local/bin/nuclear-backup/daily-backup.sh

# Monitor I/O during backup
iostat -x 1 10
```

### **Network Testing (if applicable)**
```bash
# Test network backup destinations
ping backup-server.local
nc -zv backup-server.local 22
```

### **Security Testing**
```bash
# Verify encryption
sudo -E borg info /mnt/backup_drive/borg-repo

# Check file permissions
ls -la /etc/nuclear-backup/
```

## 📖 Additional Resources

- **[Recovery Guide](RECOVERY.md)** - Disaster recovery procedures
- **[Architecture Guide](ARCHITECTURE.md)** - System design details
- **[Customization Guide](CUSTOMIZATION.md)** - Adapting the system
- **[Main README](../README.md)** - Complete overview

---

> **"Testing is not about proving the system works - it's about proving you can get your data back when you need it most."**

**🧪 Test regularly. Sleep soundly. 🛡️**
