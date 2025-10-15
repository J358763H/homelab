#!/bin/bash
# =====================================================
# 💾 Restic Backup with Ntfy Alerts
# =====================================================
# Automated backup script with notification support
# Maintainer: J35867U
# Email: mrnash404@protonmail.com
# Last Updated: 2025-10-11
# =====================================================

set -e

# Source environment variables
if [ -f "/usr/local/etc/homelab/config.env" ]; then
    source /usr/local/etc/homelab/config.env
elif [ -f "$HOME/homelab-deployment/deployment/.env" ]; then
    source $HOME/homelab-deployment/deployment/.env
fi

# Default values if not set in environment
RESTIC_REPOSITORY=${RESTIC_REPOSITORY:-""}
RESTIC_PASSWORD=${RESTIC_PASSWORD:-""}
BACKUP_PATHS=${BACKUP_PATHS:-"/data/docker /data/media"}
NTFY_SERVER=${NTFY_SERVER:-"https://ntfy.sh"}
NTFY_TOPIC_ALERTS=${NTFY_TOPIC_ALERTS:-"homelab-alerts"}
SERVER_NAME=${SERVER_NAME:-"homelab"}

LOGFILE="/var/log/homelab/restic_backup.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')
START=$(date +%s)

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOGFILE")"

# Function to send notifications
send_ntfy() {
    local title="$1"
    local message="$2"
    local priority="${3:-default}"
    local tags="${4:-backup}"
    
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

# Check if Restic is configured
if [ -z "$RESTIC_REPOSITORY" ] || [ -z "$RESTIC_PASSWORD" ]; then
    log_message "❌ ERROR: Restic repository or password not configured"
    send_ntfy "Backup Configuration Error" "Restic repository or password not set in environment" "high" "warning,backup"
    exit 1
fi

# Export Restic environment variables
export RESTIC_REPOSITORY
export RESTIC_PASSWORD

log_message "🚀 Starting Restic backup for $SERVER_NAME"

# Initialize repository if it doesn't exist
if ! restic snapshots >/dev/null 2>&1; then
    log_message "📦 Initializing new Restic repository..."
    if restic init; then
        log_message "✅ Repository initialized successfully"
    else
        log_message "❌ Failed to initialize repository"
        send_ntfy "Backup Init Failed" "Could not initialize Restic repository" "high" "warning,backup"
        exit 1
    fi
fi

# Perform backup
log_message "📁 Backing up paths: $BACKUP_PATHS"

if restic backup $BACKUP_PATHS --verbose 2>&1 | tee -a "$LOGFILE"; then
    BACKUP_DURATION=$(( $(date +%s) - START ))
    
    # Get backup statistics
    BACKUP_SIZE=$(restic stats --mode raw-data 2>/dev/null | grep "Total Size" | awk '{print $3, $4}' || echo "Unknown")
    SNAPSHOT_COUNT=$(restic snapshots --json 2>/dev/null | jq length 2>/dev/null || echo "Unknown")
    
    log_message "✅ Backup completed successfully in ${BACKUP_DURATION}s"
    
    send_ntfy "Backup Completed" \
        "✅ Backup successful
        
📊 Statistics:
• Duration: ${BACKUP_DURATION}s
• Total Size: $BACKUP_SIZE
• Snapshots: $SNAPSHOT_COUNT
• Paths: $BACKUP_PATHS" \
        "default" "white_check_mark,backup"
        
else
    log_message "❌ Backup failed"
    send_ntfy "Backup Failed" \
        "❌ Restic backup failed
        
🔍 Check logs: $LOGFILE
⏰ Failed at: $DATE" \
        "high" "x,backup,warning"
    exit 1
fi

# Cleanup old snapshots
log_message "🧹 Cleaning up old snapshots..."
if restic forget \
    --keep-daily 7 \
    --keep-weekly 4 \
    --keep-monthly 6 \
    --keep-yearly 2 \
    --prune \
    --verbose 2>&1 | tee -a "$LOGFILE"; then
    
    log_message "✅ Cleanup completed successfully"
else
    log_message "⚠️ Cleanup had issues (non-critical)"
    send_ntfy "Backup Cleanup Warning" \
        "⚠️ Backup completed but cleanup had issues
        
🔍 Check logs: $LOGFILE" \
        "default" "warning,backup"
fi

# Final status
TOTAL_DURATION=$(( $(date +%s) - START ))
log_message "🏁 Backup process completed in ${TOTAL_DURATION}s"

# Check repository integrity (weekly)
if [ "$(date +%u)" -eq 1 ]; then  # Monday
    log_message "🔍 Running weekly repository check..."
    if restic check --verbose 2>&1 | tee -a "$LOGFILE"; then
        log_message "✅ Repository integrity verified"
        send_ntfy "Repository Check OK" \
            "✅ Weekly repository integrity check passed
            
📊 Repository health: Good
🗓️ Next check: Next Monday" \
            "default" "white_check_mark,backup"
    else
        log_message "❌ Repository integrity check failed"
        send_ntfy "Repository Check Failed" \
            "❌ Weekly repository integrity check failed
            
⚠️ Repository may be corrupted
🔍 Check logs: $LOGFILE" \
            "high" "x,backup,warning"
    fi
fi

log_message "📝 Backup log saved to: $LOGFILE"