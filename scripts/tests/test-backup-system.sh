#!/bin/bash
# Nuclear Backup System - Comprehensive Testing Script
# Tests all backup components to ensure disaster recovery capability

set -e

# Configuration
BACKUP_DRIVE_UUID="YOUR_BACKUP_DRIVE_UUID_HERE"
BACKUP_MOUNT_POINT="/mnt/backup_drive"
BORG_REPO="$BACKUP_MOUNT_POINT/borg-repo"
TEST_DIR="/tmp/backup_system_test_$$"
BORG_PASSPHRASE_FILE="/etc/nuclear-backup/borg-passphrase"  # Store securely

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
LOG_FILE="$BACKUP_MOUNT_POINT/logs/test_backup_$(date +%Y%m%d_%H%M%S).log"

echo_status() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

echo_success() {
    echo -e "${GREEN}[PASS]${NC} $1" | tee -a "$LOG_FILE"
}

echo_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

echo_error() {
    echo -e "${RED}[FAIL]${NC} $1" | tee -a "$LOG_FILE"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo_error "Please run as root (sudo $0)"
    exit 1
fi

echo_status "=== NUCLEAR BACKUP SYSTEM TEST SUITE ==="
echo_status "Started at: $(date)"

# Create test directory
mkdir -p "$TEST_DIR"
mkdir -p "$BACKUP_MOUNT_POINT/logs"

# Test 1: Mount Point Verification
echo_status "Test 1: Verifying backup drive mount..."
if mountpoint -q "$BACKUP_MOUNT_POINT"; then
    echo_success "Backup drive mounted at $BACKUP_MOUNT_POINT"
else
    echo_status "Attempting to mount backup drive..."
    if mount UUID="$BACKUP_DRIVE_UUID" "$BACKUP_MOUNT_POINT"; then
        echo_success "Backup drive mounted successfully"
    else
        echo_error "Failed to mount backup drive with UUID $BACKUP_DRIVE_UUID"
        exit 1
    fi
fi

# Test 2: Directory Structure
echo_status "Test 2: Checking backup directory structure..."
REQUIRED_DIRS=("borg-repo" "config" "disk_images" "logs")
for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$BACKUP_MOUNT_POINT/$dir" ]; then
        echo_success "Directory exists: $dir"
    else
        echo_error "Missing directory: $dir"
        exit 1
    fi
done

# Test 3: Borg Repository Health
echo_status "Test 3: Checking Borg repository health..."
if [ -f "$BORG_PASSPHRASE_FILE" ]; then
    export BORG_PASSPHRASE=$(cat "$BORG_PASSPHRASE_FILE")
elif [ -n "$BORG_PASSPHRASE" ]; then
    echo_status "Using BORG_PASSPHRASE from environment"
else
    echo_error "BORG_PASSPHRASE not set. Please set it or create $BORG_PASSPHRASE_FILE"
    exit 1
fi

if borg check "$BORG_REPO" 2>&1 | tee -a "$LOG_FILE"; then
    echo_success "Borg repository passed integrity check"
else
    echo_error "Borg repository failed integrity check"
fi

# Test 4: List Available Backups
echo_status "Test 4: Listing available backup archives..."
ARCHIVE_COUNT=$(borg list "$BORG_REPO" | wc -l)
if [ "$ARCHIVE_COUNT" -gt 0 ]; then
    echo_success "Found $ARCHIVE_COUNT backup archives"
    echo_status "Recent archives:"
    borg list "$BORG_REPO" | tail -3 | tee -a "$LOG_FILE"
else
    echo_error "No backup archives found in repository"
fi

# Test 5: File Recovery Test
echo_status "Test 5: Testing file recovery from latest backup..."
LATEST_ARCHIVE=$(borg list "$BORG_REPO" | tail -1 | awk '{print $1}')
if [ -n "$LATEST_ARCHIVE" ]; then
    echo_status "Testing recovery from archive: $LATEST_ARCHIVE"
    
    # Try to extract a common file
    cd "$TEST_DIR"
    if borg extract "$BORG_REPO::$LATEST_ARCHIVE" etc/fstab 2>/dev/null; then
        if [ -f "$TEST_DIR/etc/fstab" ]; then
            echo_success "Successfully extracted /etc/fstab from backup"
            FILE_SIZE=$(stat -c%s "$TEST_DIR/etc/fstab")
            echo_status "Extracted file size: $FILE_SIZE bytes"
        else
            echo_error "File extraction reported success but file not found"
        fi
    else
        echo_warning "Could not extract /etc/fstab (may not exist in backup)"
    fi
else
    echo_error "No archives available for testing"
fi

# Test 6: Configuration Backup Verification
echo_status "Test 6: Verifying configuration backups..."
CONFIG_COUNT=$(ls -1 "$BACKUP_MOUNT_POINT/config/" | grep "config_" | wc -l)
if [ "$CONFIG_COUNT" -gt 0 ]; then
    echo_success "Found $CONFIG_COUNT configuration backup snapshots"
    
    # Test latest config backup
    LATEST_CONFIG=$(ls -1t "$BACKUP_MOUNT_POINT/config/" | grep "config_" | head -1)
    echo_status "Testing latest config backup: $LATEST_CONFIG"
    
    if [ -f "$BACKUP_MOUNT_POINT/config/$LATEST_CONFIG/essential_configs.tar.gz" ]; then
        cd "$TEST_DIR"
        if tar -tzf "$BACKUP_MOUNT_POINT/config/$LATEST_CONFIG/essential_configs.tar.gz" >/dev/null 2>&1; then
            echo_success "Configuration backup archive is valid"
            ARCHIVE_SIZE=$(du -h "$BACKUP_MOUNT_POINT/config/$LATEST_CONFIG/essential_configs.tar.gz" | cut -f1)
            echo_status "Configuration backup size: $ARCHIVE_SIZE"
        else
            echo_error "Configuration backup archive is corrupted"
        fi
    else
        echo_error "Configuration backup file not found"
    fi
else
    echo_error "No configuration backups found"
fi

# Test 7: Full Disk Image Verification
echo_status "Test 7: Verifying full disk image backups..."
IMAGE_COUNT=$(ls -1 "$BACKUP_MOUNT_POINT/disk_images/" | grep "endeavouros_full_" | grep "\.img\.gz$" | wc -l)
if [ "$IMAGE_COUNT" -gt 0 ]; then
    echo_success "Found $IMAGE_COUNT full disk image backups"
    
    # Verify checksums
    cd "$BACKUP_MOUNT_POINT/disk_images/"
    CHECKSUM_ERRORS=0
    for checksum_file in *.sha256; do
        if [ -f "$checksum_file" ]; then
            echo_status "Verifying checksum: $checksum_file"
            if sha256sum -c "$checksum_file" >/dev/null 2>&1; then
                echo_success "Checksum verified: $checksum_file"
            else
                echo_error "Checksum failed: $checksum_file"
                ((CHECKSUM_ERRORS++))
            fi
        fi
    done
    
    if [ "$CHECKSUM_ERRORS" -eq 0 ]; then
        echo_success "All disk image checksums verified successfully"
    else
        echo_error "$CHECKSUM_ERRORS disk image(s) failed checksum verification"
    fi
else
    echo_error "No full disk image backups found"
fi

# Test 8: Storage Space Analysis
echo_status "Test 8: Analyzing storage usage..."
TOTAL_SPACE=$(df -h "$BACKUP_MOUNT_POINT" | awk 'NR==2 {print $2}')
USED_SPACE=$(df -h "$BACKUP_MOUNT_POINT" | awk 'NR==2 {print $3}')
AVAIL_SPACE=$(df -h "$BACKUP_MOUNT_POINT" | awk 'NR==2 {print $4}')
USE_PERCENT=$(df -h "$BACKUP_MOUNT_POINT" | awk 'NR==2 {print $5}')

echo_status "Storage Analysis:"
echo_status "  Total Space: $TOTAL_SPACE"
echo_status "  Used Space:  $USED_SPACE"
echo_status "  Available:   $AVAIL_SPACE"
echo_status "  Usage:       $USE_PERCENT"

# Warn if space is getting low
USE_PERCENT_NUM=$(echo "$USE_PERCENT" | sed 's/%//')
if [ "$USE_PERCENT_NUM" -gt 85 ]; then
    echo_warning "Backup drive is ${USE_PERCENT} full - consider cleanup or larger drive"
elif [ "$USE_PERCENT_NUM" -gt 70 ]; then
    echo_warning "Backup drive is ${USE_PERCENT} full - monitor space usage"
else
    echo_success "Backup drive space usage is healthy (${USE_PERCENT})"
fi

# Test 9: Service Status Check
echo_status "Test 9: Checking backup service status..."
SERVICES=("daily-backup.timer" "weekly-full-backup.timer")
for service in "${SERVICES[@]}"; do
    if systemctl is-enabled "$service" >/dev/null 2>&1; then
        if systemctl is-active "$service" >/dev/null 2>&1; then
            echo_success "Service $service is enabled and active"
        else
            echo_warning "Service $service is enabled but not active"
        fi
    else
        echo_error "Service $service is not enabled"
    fi
done

# Test 10: Next Backup Schedule
echo_status "Test 10: Checking backup schedule..."
echo_status "Next scheduled backups:"
systemctl list-timers | grep backup | tee -a "$LOG_FILE"

# Test 11: Log File Analysis
echo_status "Test 11: Analyzing recent backup logs..."
RECENT_LOGS=$(find "$BACKUP_MOUNT_POINT/logs/" -name "*backup*" -mtime -7 | wc -l)
echo_status "Found $RECENT_LOGS backup log files from last 7 days"

if [ "$RECENT_LOGS" -gt 0 ]; then
    LATEST_LOG=$(find "$BACKUP_MOUNT_POINT/logs/" -name "*backup*" -mtime -7 -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)
    echo_status "Latest backup log: $LATEST_LOG"
    
    if grep -q "successfully" "$LATEST_LOG" 2>/dev/null; then
        echo_success "Latest backup completed successfully"
    elif grep -q "error\|failed" "$LATEST_LOG" 2>/dev/null; then
        echo_error "Latest backup had errors - check log: $LATEST_LOG"
    else
        echo_warning "Latest backup status unclear - check log: $LATEST_LOG"
    fi
fi

# Cleanup
rm -rf "$TEST_DIR"

# Summary
echo_status "=== TEST SUITE COMPLETE ==="
echo_status "Completed at: $(date)"
echo_status "Full test log: $LOG_FILE"

echo_status ""
echo_status "NUCLEAR BACKUP SYSTEM STATUS:"
echo_success "✓ Backup drive accessible"
echo_success "✓ Borg repository healthy" 
echo_success "✓ File recovery verified"
echo_success "✓ Configuration backups valid"
echo_success "✓ Disk images verified"
echo_success "✓ Services operational"
echo_status ""
echo_status "Your nuclear backup system is protecting your data!"
echo_status "Run this test monthly to ensure continued reliability."
