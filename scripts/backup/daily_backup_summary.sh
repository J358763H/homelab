#!/bin/bash
# =====================================================
# 📊 Daily Backup Summary + Ntfy Alerts  
# =====================================================
# Collects backup statistics and sends daily summary
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

# Default values
NTFY_SERVER=${NTFY_SERVER:-"https://ntfy.sh"}
NTFY_TOPIC_SUMMARY=${NTFY_TOPIC_SUMMARY:-"homelab-summary"}
SERVER_NAME=${SERVER_NAME:-"homelab"}
LOGFILE="/var/log/homelab/daily_backup_summary.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')
START=$(date +%s)

# Create log directory
mkdir -p "$(dirname "$LOGFILE")"

# Function to send notifications
send_ntfy() {
    local title="$1"
    local message="$2"
    local priority="${3:-default}"
    local tags="${4:-summary}"
    
    if [ -n "$NTFY_SERVER" ] && [ -n "$NTFY_TOPIC_SUMMARY" ]; then
        curl -s \
            -H "Title: [$SERVER_NAME] $title" \
            -H "Priority: $priority" \
            -H "Tags: $tags" \
            -d "$message" \
            "$NTFY_SERVER/$NTFY_TOPIC_SUMMARY" || true
    fi
}

# Function to run a task and track success/failure
run_task() {
    local task_name="$1"
    local command="$2"
    local icon="${3:-📋}"
    
    echo "[$DATE] Running: $task_name" >> "$LOGFILE"
    
    if eval "$command" >> "$LOGFILE" 2>&1; then
        echo "$icon $task_name: ✅ Success"
        return 0
    else
        echo "$icon $task_name: ❌ Failed"
        return 1
    fi
}

# Initialize task results array
TASKS=()

echo "[$DATE] Starting daily backup summary for $SERVER_NAME" >> "$LOGFILE"

# Task: Docker container health check
TASKS+=("$(run_task "Container Health Check" \
    "docker ps --format 'table {{.Names}}\t{{.Status}}' | grep -E '(Up|healthy)' | wc -l" \
    "🐳")")

# Task: Backup verification
TASKS+=("$(run_task "Backup Status Check" \
    "test -f /var/log/homelab/restic_backup.log && tail -1 /var/log/homelab/restic_backup.log | grep -q 'completed successfully'" \
    "💾")")

# Task: Disk space check
TASKS+=("$(run_task "Disk Space Check" \
    "df -h /data | awk 'NR==2 {if (substr(\$5,1,length(\$5)-1) < 90) exit 0; else exit 1}'" \
    "💿")")

# Task: VPN connectivity check
TASKS+=("$(run_task "VPN Connectivity" \
    "docker exec gluetun curl -s --max-time 10 ifconfig.me > /dev/null 2>&1" \
    "🔒")")

# Task: Media library sync
TASKS+=("$(run_task "Media Library Sync" \
    "test -d /data/media/movies && test -d /data/media/shows && find /data/media -name '*.mkv' -o -name '*.mp4' | head -1 | grep -q '.'" \
    "🎬")")

# Task: System load check
TASKS+=("$(run_task "System Load Check" \
    "uptime | awk '{if (\$(NF-2) < 2.0) exit 0; else exit 1}'" \
    "⚡")")

# Task: Log rotation
TASKS+=("$(run_task "Log Rotation" \
    "find /var/log/homelab -name '*.log' -size +10M -exec truncate -s 1M {} \;" \
    "📝")")

# Calculate duration
DURATION=$(( $(date +%s) - START ))

# Count successful vs failed tasks
TOTAL_TASKS=${#TASKS[@]}
SUCCESS_COUNT=$(echo "${TASKS[@]}" | grep -o "✅" | wc -l)
FAILED_COUNT=$(echo "${TASKS[@]}" | grep -o "❌" | wc -l)

# Determine overall status
if [ $FAILED_COUNT -eq 0 ]; then
    OVERALL_STATUS="✅ All Systems Healthy"
    PRIORITY="default"
    TAGS="white_check_mark,summary"
elif [ $FAILED_COUNT -lt 3 ]; then
    OVERALL_STATUS="⚠️ Minor Issues Detected"
    PRIORITY="default"
    TAGS="warning,summary"
else
    OVERALL_STATUS="❌ Multiple Issues Detected"
    PRIORITY="high"
    TAGS="x,warning,summary"
fi

# Get system stats
UPTIME=$(uptime | awk '{print $3,$4}' | sed 's/,//')
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}')
DISK_USAGE=$(df -h /data | awk 'NR==2 {print $5}')
MEMORY_USAGE=$(free | awk 'NR==2{printf "%.1f%%", $3*100/$2 }')

# Container status
RUNNING_CONTAINERS=$(docker ps -q | wc -l)
TOTAL_CONTAINERS=$(docker ps -a -q | wc -l)

# Build summary message
SUMMARY="📊 Daily System Summary - $(date +'%Y-%m-%d')

$OVERALL_STATUS

📈 System Stats:
• Uptime: $UPTIME
• Load: $LOAD_AVG
• Disk Usage: $DISK_USAGE
• Memory: $MEMORY_USAGE
• Containers: $RUNNING_CONTAINERS/$TOTAL_CONTAINERS running

🔍 Task Results ($SUCCESS_COUNT/$TOTAL_TASKS successful):
$(printf "%s\n" "${TASKS[@]}")

⏱️ Summary Duration: ${DURATION}s"

# Send notification
send_ntfy "Daily Summary" "$SUMMARY" "$PRIORITY" "$TAGS"

# Log final status
echo "[$DATE] Daily summary completed - $SUCCESS_COUNT/$TOTAL_TASKS tasks successful" >> "$LOGFILE"

# If there are failures, also send to alerts channel
if [ $FAILED_COUNT -gt 0 ]; then
    ALERT_MESSAGE="⚠️ Daily backup summary found $FAILED_COUNT failed tasks:

$(echo "${TASKS[@]}" | grep "❌" | head -5)

🔍 Check detailed logs: $LOGFILE
📅 Date: $(date +'%Y-%m-%d %H:%M')"

    curl -s \
        -H "Title: [$SERVER_NAME] Daily Check Failures" \
        -H "Priority: default" \
        -H "Tags: warning,alert" \
        -d "$ALERT_MESSAGE" \
        "$NTFY_SERVER/${NTFY_TOPIC_ALERTS:-homelab-alerts}" || true
fi

echo "Daily backup summary completed at $DATE"