#!/bin/bash
# =====================================================
# 🔍 HDD Health Check + SMART Monitoring
# =====================================================
# Monitors disk health and sends alerts for issues
# Maintainer: J35867U  
# Email: mrnash404@protonmail.com
# Last Updated: 2025-10-11
# =====================================================

set -e

# Source environment variables
if [ -f "/usr/local/etc/homelab-shv/config.env" ]; then
    source /usr/local/etc/homelab-shv/config.env
elif [ -f "$HOME/homelab-deployment/deployment/.env" ]; then
    source $HOME/homelab-deployment/deployment/.env
fi

# Default values
NTFY_SERVER=${NTFY_SERVER:-"https://ntfy.sh"}
NTFY_TOPIC_ALERTS=${NTFY_TOPIC_ALERTS:-"homelab-shv-alerts"}
SERVER_NAME=${SERVER_NAME:-"homelab-shv"}
LOGFILE="/var/log/homelab-shv/hdd_health.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Create log directory
mkdir -p "$(dirname "$LOGFILE")"

# Function to send notifications
send_ntfy() {
    local title="$1"
    local message="$2"
    local priority="${3:-default}"
    local tags="${4:-disk,health}"
    
    if [ -n "$NTFY_SERVER" ] && [ -n "$NTFY_TOPIC_ALERTS" ]; then
        curl -s \
            -H "Title: [$SERVER_NAME] $title" \
            -H "Priority: $priority" \
            -H "Tags: $tags" \
            -d "$message" \
            "$NTFY_SERVER/$NTFY_TOPIC_ALERTS" || true
    fi
}

# Function to log messages
log_message() {
    echo "[$DATE] $1" | tee -a "$LOGFILE"
}

log_message "🔍 Starting HDD health check for $SERVER_NAME"

# Initialize status tracking
ISSUES_FOUND=0
CRITICAL_ISSUES=0
WARNING_ISSUES=0
SMART_ISSUES=()
DISK_ISSUES=()
ZFS_ISSUES=()

# Check if smartctl is available
if ! command -v smartctl >/dev/null 2>&1; then
    log_message "⚠️ WARNING: smartmontools not installed - installing now..."
    if sudo apt-get update && sudo apt-get install -y smartmontools; then
        log_message "✅ smartmontools installed successfully"
    else
        log_message "❌ Failed to install smartmontools"
        send_ntfy "SMART Tools Missing" \
            "❌ Cannot monitor disk health - smartmontools not available
            
🔧 Manual installation required:
sudo apt-get install smartmontools" \
            "high" "x,disk,warning"
        exit 1
    fi
fi

# Get list of all block devices (excluding loop devices, ram disks, etc.)
DISKS=$(lsblk -dpno NAME | grep -E "^/dev/(sd|hd|nvme)" | grep -v -E "(loop|ram|sr)" || true)

if [ -z "$DISKS" ]; then
    log_message "⚠️ No physical disks found to monitor"
    send_ntfy "No Disks Found" \
        "⚠️ HDD health check found no physical disks to monitor
        
🔍 This might indicate:
• Virtual machine environment
• Different disk naming scheme
• Permission issues" \
        "default" "warning,disk"
    exit 0
fi

log_message "📀 Found disks to monitor: $(echo $DISKS | tr '\n' ' ')"

# Check each disk
for DISK in $DISKS; do
    log_message "🔍 Checking disk: $DISK"
    
    # Check if SMART is supported and enabled
    if ! smartctl -i "$DISK" >/dev/null 2>&1; then
        log_message "⚠️ $DISK: SMART not supported or accessible"
        WARNING_ISSUES=$((WARNING_ISSUES + 1))
        SMART_ISSUES+=("$DISK: SMART not accessible")
        continue
    fi
    
    # Get SMART health status
    SMART_STATUS=$(smartctl -H "$DISK" 2>/dev/null || echo "UNKNOWN")
    
    if echo "$SMART_STATUS" | grep -q "PASSED"; then
        log_message "✅ $DISK: SMART health PASSED"
    elif echo "$SMART_STATUS" | grep -q "FAILED"; then
        log_message "❌ $DISK: SMART health FAILED - CRITICAL"
        CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
        SMART_ISSUES+=("$DISK: SMART health FAILED")
    else
        log_message "⚠️ $DISK: SMART health UNKNOWN"
        WARNING_ISSUES=$((WARNING_ISSUES + 1))
        SMART_ISSUES+=("$DISK: SMART status unknown")
    fi
    
    # Check SMART attributes for warnings
    SMART_ATTRS=$(smartctl -A "$DISK" 2>/dev/null || true)
    
    # Check critical attributes
    if echo "$SMART_ATTRS" | grep -E "(Reallocated_Sector_Ct|Current_Pending_Sector|Offline_Uncorrectable)" | awk '$10 > 0 {exit 1}'; then
        log_message "⚠️ $DISK: Found reallocated or pending sectors"
        WARNING_ISSUES=$((WARNING_ISSUES + 1))
        SMART_ISSUES+=("$DISK: Has reallocated/pending sectors")
    fi
    
    # Check temperature (if available)
    TEMP=$(echo "$SMART_ATTRS" | grep -i temperature | awk '{print $10}' | head -1 || echo "")
    if [ -n "$TEMP" ] && [ "$TEMP" -gt 55 ]; then
        log_message "🌡️ $DISK: High temperature: ${TEMP}°C"
        WARNING_ISSUES=$((WARNING_ISSUES + 1))
        SMART_ISSUES+=("$DISK: High temperature (${TEMP}°C)")
    elif [ -n "$TEMP" ]; then
        log_message "🌡️ $DISK: Temperature: ${TEMP}°C (normal)"
    fi
    
    # Check disk space
    DISK_USAGE=$(df -h "$DISK"* 2>/dev/null | awk 'NR>1 {gsub(/%/, "", $5); if ($5 > 90) print $6 ":" $5}' || true)
    if [ -n "$DISK_USAGE" ]; then
        log_message "💿 $DISK: High disk usage detected"
        WARNING_ISSUES=$((WARNING_ISSUES + 1))
        DISK_ISSUES+=("High disk usage: $DISK_USAGE")
    fi
done

# Check ZFS pools if available
if command -v zpool >/dev/null 2>&1; then
    log_message "🏊 Checking ZFS pools..."
    
    ZFS_STATUS=$(zpool status 2>/dev/null || echo "No pools found")
    
    if echo "$ZFS_STATUS" | grep -q "DEGRADED\|FAULTED\|OFFLINE\|UNAVAIL"; then
        log_message "❌ ZFS: Pool issues detected"
        CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
        ZFS_ISSUES+=("ZFS pool degraded or has errors")
    elif echo "$ZFS_STATUS" | grep -q "ONLINE"; then
        log_message "✅ ZFS: All pools healthy"
    else
        log_message "ℹ️ ZFS: No pools found or ZFS not in use"
    fi
    
    # Check ZFS scrub status
    SCRUB_STATUS=$(zpool status | grep -A 1 "scan:" | tail -1 || echo "")
    if echo "$SCRUB_STATUS" | grep -q "errors"; then
        ERROR_COUNT=$(echo "$SCRUB_STATUS" | grep -o "[0-9]* errors" | awk '{print $1}')
        if [ "$ERROR_COUNT" -gt 0 ]; then
            log_message "⚠️ ZFS: Scrub found $ERROR_COUNT errors"
            WARNING_ISSUES=$((WARNING_ISSUES + 1))
            ZFS_ISSUES+=("ZFS scrub found $ERROR_COUNT errors")
        fi
    fi
fi

# Check filesystem health
log_message "📂 Checking filesystem health..."
FILESYSTEM_ERRORS=$(dmesg | grep -i "error\|fail" | grep -E "(ext[234]|xfs|btrfs)" | tail -5 || true)
if [ -n "$FILESYSTEM_ERRORS" ]; then
    log_message "⚠️ Recent filesystem errors detected in dmesg"
    WARNING_ISSUES=$((WARNING_ISSUES + 1))
    DISK_ISSUES+=("Recent filesystem errors detected")
fi

# Calculate total issues
TOTAL_ISSUES=$((CRITICAL_ISSUES + WARNING_ISSUES))

# Generate summary report
SUMMARY_REPORT="🔍 HDD Health Check Summary - $(date +'%Y-%m-%d %H:%M')

📊 Overall Status: "

if [ $CRITICAL_ISSUES -gt 0 ]; then
    SUMMARY_REPORT+="❌ CRITICAL ISSUES FOUND"
    PRIORITY="urgent"
    TAGS="rotating_light,disk,critical"
elif [ $WARNING_ISSUES -gt 0 ]; then
    SUMMARY_REPORT+="⚠️ WARNINGS DETECTED"
    PRIORITY="high"
    TAGS="warning,disk"
else
    SUMMARY_REPORT+="✅ ALL SYSTEMS HEALTHY"
    PRIORITY="default"
    TAGS="white_check_mark,disk"
fi

SUMMARY_REPORT+="

📈 Issue Summary:
• Critical Issues: $CRITICAL_ISSUES
• Warning Issues: $WARNING_ISSUES
• Total Disks Checked: $(echo $DISKS | wc -w)
• ZFS Status: $([ -n "$ZFS_STATUS" ] && echo "Checked" || echo "Not Available")"

# Add details if issues found
if [ $TOTAL_ISSUES -gt 0 ]; then
    SUMMARY_REPORT+="

🚨 Issues Found:"
    
    for issue in "${SMART_ISSUES[@]}"; do
        SUMMARY_REPORT+="
• $issue"
    done
    
    for issue in "${DISK_ISSUES[@]}"; do
        SUMMARY_REPORT+="
• $issue"
    done
    
    for issue in "${ZFS_ISSUES[@]}"; do
        SUMMARY_REPORT+="
• $issue"
    done
    
    SUMMARY_REPORT+="

🔧 Recommended Actions:
• Check logs: $LOGFILE
• Run manual SMART tests
• Consider disk replacement if critical
• Monitor closely"
fi

# Send notification
if [ $TOTAL_ISSUES -gt 0 ] || [ "$(date +%u)" -eq 1 ]; then  # Send weekly summary on Monday
    send_ntfy "HDD Health Check" "$SUMMARY_REPORT" "$PRIORITY" "$tags"
fi

# Log final status
log_message "📋 Health check completed - Found $CRITICAL_ISSUES critical and $WARNING_ISSUES warning issues"

# Exit with appropriate code
if [ $CRITICAL_ISSUES -gt 0 ]; then
    exit 2
elif [ $WARNING_ISSUES -gt 0 ]; then
    exit 1
else
    exit 0
fi