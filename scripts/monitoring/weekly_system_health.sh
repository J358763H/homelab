#!/bin/bash
# =====================================================
# 📊 Weekly System Health Check + Ntfy Report
# =====================================================
# Comprehensive weekly system health assessment
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
LOGFILE="/var/log/homelab/weekly_health.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')
START=$(date +%s)

# Create log directory
mkdir -p "$(dirname "$LOGFILE")"

# Function to send notifications
send_ntfy() {
    local title="$1"
    local message="$2"
    local priority="${3:-default}"
    local tags="${4:-weekly,health}"
    
    if [ -n "$NTFY_SERVER" ] && [ -n "$NTFY_TOPIC_SUMMARY" ]; then
        curl -s \
            -H "Title: [$SERVER_NAME] $title" \
            -H "Priority: $priority" \
            -H "Tags: $tags" \
            -d "$message" \
            "$NTFY_SERVER/$NTFY_TOPIC_SUMMARY" || true
    fi
}

# Function to log messages
log_message() {
    echo "[$DATE] $1" | tee -a "$LOGFILE"
}

log_message "📊 Starting weekly system health check for $SERVER_NAME"

# Initialize health metrics
HEALTH_SCORE=100
CRITICAL_ISSUES=0
WARNING_ISSUES=0
INFO_ITEMS=0
HEALTH_DETAILS=()

# Function to add health item
add_health_item() {
    local type="$1"    # critical, warning, info, good
    local message="$2"
    local score_impact="${3:-0}"
    
    case $type in
        critical)
            CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
            HEALTH_SCORE=$((HEALTH_SCORE - score_impact))
            HEALTH_DETAILS+=("❌ $message")
            ;;
        warning)
            WARNING_ISSUES=$((WARNING_ISSUES + 1))
            HEALTH_SCORE=$((HEALTH_SCORE - score_impact))
            HEALTH_DETAILS+=("⚠️ $message")
            ;;
        info)
            INFO_ITEMS=$((INFO_ITEMS + 1))
            HEALTH_DETAILS+=("ℹ️ $message")
            ;;
        good)
            HEALTH_DETAILS+=("✅ $message")
            ;;
    esac
    
    log_message "$type: $message"
}

# 1. System Uptime and Load
log_message "🖥️ Checking system performance..."
UPTIME_DAYS=$(awk '{print int($1/86400)}' /proc/uptime)
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
LOAD_THRESHOLD=2.0

if [ "$UPTIME_DAYS" -lt 1 ]; then
    add_health_item "warning" "System recently rebooted (${UPTIME_DAYS} days uptime)" 5
elif [ "$UPTIME_DAYS" -gt 365 ]; then
    add_health_item "info" "Long uptime detected (${UPTIME_DAYS} days) - consider planned reboot"
else
    add_health_item "good" "System uptime: ${UPTIME_DAYS} days"
fi

if (( $(echo "$LOAD_AVG > $LOAD_THRESHOLD" | bc -l) )); then
    add_health_item "warning" "High system load: $LOAD_AVG" 10
else
    add_health_item "good" "System load normal: $LOAD_AVG"
fi

# 2. Memory Usage
log_message "🧠 Checking memory usage..."
MEMORY_USAGE=$(free | awk 'NR==2{printf "%.1f", $3*100/$2}')
MEMORY_THRESHOLD=85.0

if (( $(echo "$MEMORY_USAGE > $MEMORY_THRESHOLD" | bc -l) )); then
    add_health_item "warning" "High memory usage: ${MEMORY_USAGE}%" 10
else
    add_health_item "good" "Memory usage: ${MEMORY_USAGE}%"
fi

# 3. Disk Space
log_message "💿 Checking disk usage..."
DISK_ISSUES=$(df -h | awk 'NR>1 && $5+0 > 90 {print $6 ":" $5}')
if [ -n "$DISK_ISSUES" ]; then
    while read -r disk_issue; do
        add_health_item "warning" "High disk usage: $disk_issue" 15
    done <<< "$DISK_ISSUES"
else
    add_health_item "good" "Disk usage within normal limits"
fi

# Check /data specifically
DATA_USAGE=$(df -h /data 2>/dev/null | awk 'NR==2 {print $5}' | sed 's/%//' || echo "0")
if [ "$DATA_USAGE" -gt 80 ]; then
    add_health_item "warning" "/data directory ${DATA_USAGE}% full" 10
elif [ "$DATA_USAGE" -gt 90 ]; then
    add_health_item "critical" "/data directory ${DATA_USAGE}% full - urgent attention needed" 20
else
    add_health_item "good" "/data directory usage: ${DATA_USAGE}%"
fi

# 4. Docker Container Health
log_message "🐳 Checking Docker containers..."
if command -v docker >/dev/null 2>&1; then
    TOTAL_CONTAINERS=$(docker ps -a -q | wc -l)
    RUNNING_CONTAINERS=$(docker ps -q | wc -l)
    UNHEALTHY_CONTAINERS=$(docker ps --filter "health=unhealthy" -q | wc -l)
    EXITED_CONTAINERS=$(docker ps -a --filter "status=exited" -q | wc -l)
    
    if [ "$UNHEALTHY_CONTAINERS" -gt 0 ]; then
        UNHEALTHY_NAMES=$(docker ps --filter "health=unhealthy" --format "{{.Names}}" | tr '\n' ', ' | sed 's/,$//')
        add_health_item "critical" "$UNHEALTHY_CONTAINERS unhealthy containers: $UNHEALTHY_NAMES" 25
    fi
    
    if [ "$EXITED_CONTAINERS" -gt 0 ]; then
        add_health_item "warning" "$EXITED_CONTAINERS containers in exited state" 10
    fi
    
    if [ "$RUNNING_CONTAINERS" -eq "$TOTAL_CONTAINERS" ] && [ "$UNHEALTHY_CONTAINERS" -eq 0 ]; then
        add_health_item "good" "All $TOTAL_CONTAINERS containers running healthy"
    else
        add_health_item "info" "Container status: $RUNNING_CONTAINERS/$TOTAL_CONTAINERS running"
    fi
else
    add_health_item "critical" "Docker not available" 30
fi

# 5. Service Health Checks
log_message "🔧 Checking critical services..."

# Check key containers specifically
KEY_SERVICES=("gluetun" "sonarr" "radarr" "prowlarr" "jellyfin" "qbittorrent")
FAILED_SERVICES=()

for service in "${KEY_SERVICES[@]}"; do
    if docker ps --filter "name=$service" --format "{{.Names}}" | grep -q "^$service$"; then
        # Container is running, check if it's responsive
        case $service in
            "gluetun")
                if docker exec "$service" curl -f -s http://localhost:8000/health >/dev/null 2>&1; then
                    add_health_item "good" "$service: Running and healthy"
                else
                    add_health_item "warning" "$service: Running but not responding to health check" 8
                fi
                ;;
            "jellyfin")
                if curl -f -s "http://localhost:8096/health" >/dev/null 2>&1; then
                    add_health_item "good" "$service: Running and accessible"
                else
                    add_health_item "warning" "$service: Running but not accessible" 8
                fi
                ;;
            *)
                add_health_item "good" "$service: Running"
                ;;
        esac
    else
        add_health_item "critical" "$service: Not running" 15
        FAILED_SERVICES+=("$service")
    fi
done

# 6. Network Connectivity
log_message "🌐 Checking network connectivity..."

# Internet connectivity
if curl -s --max-time 10 google.com >/dev/null 2>&1; then
    add_health_item "good" "Internet connectivity: OK"
else
    add_health_item "critical" "Internet connectivity: FAILED" 25
fi

# VPN connectivity (if gluetun is running)
if docker ps --filter "name=gluetun" --format "{{.Names}}" | grep -q gluetun; then
    VPN_IP=$(docker exec gluetun curl -s --max-time 10 ifconfig.me 2>/dev/null || echo "FAILED")
    LOCAL_IP=$(curl -s --max-time 10 ifconfig.me 2>/dev/null || echo "FAILED")
    
    if [ "$VPN_IP" != "FAILED" ] && [ "$VPN_IP" != "$LOCAL_IP" ]; then
        add_health_item "good" "VPN: Active and masking IP"
    else
        add_health_item "warning" "VPN: May not be working properly" 15
    fi
fi

# 7. Backup Status
log_message "💾 Checking backup status..."
BACKUP_LOG="/var/log/homelab/restic_backup.log"
if [ -f "$BACKUP_LOG" ]; then
    LAST_BACKUP=$(stat -c %Y "$BACKUP_LOG" 2>/dev/null || echo 0)
    CURRENT_TIME=$(date +%s)
    BACKUP_AGE_HOURS=$(( (CURRENT_TIME - LAST_BACKUP) / 3600 ))
    
    if [ "$BACKUP_AGE_HOURS" -lt 48 ]; then
        if tail -10 "$BACKUP_LOG" | grep -q "completed successfully"; then
            add_health_item "good" "Backup: Recent successful backup (${BACKUP_AGE_HOURS}h ago)"
        else
            add_health_item "warning" "Backup: Recent backup may have failed" 10
        fi
    else
        add_health_item "critical" "Backup: No recent backup found (${BACKUP_AGE_HOURS}h ago)" 20
    fi
else
    add_health_item "warning" "Backup: No backup log found" 15
fi

# 8. Security Updates
log_message "🔒 Checking for security updates..."
if command -v apt >/dev/null 2>&1; then
    SECURITY_UPDATES=$(apt list --upgradable 2>/dev/null | grep -c "security" || echo 0)
    TOTAL_UPDATES=$(apt list --upgradable 2>/dev/null | wc -l)
    
    if [ "$SECURITY_UPDATES" -gt 0 ]; then
        add_health_item "warning" "$SECURITY_UPDATES security updates available" 5
    fi
    
    if [ "$TOTAL_UPDATES" -gt 20 ]; then
        add_health_item "info" "$TOTAL_UPDATES total updates available"
    elif [ "$TOTAL_UPDATES" -eq 0 ]; then
        add_health_item "good" "System packages up to date"
    fi
fi

# 9. Log Analysis
log_message "📝 Analyzing system logs..."
ERROR_COUNT=$(journalctl --since "1 week ago" --priority=err | wc -l)
if [ "$ERROR_COUNT" -gt 100 ]; then
    add_health_item "warning" "High error count in logs: $ERROR_COUNT errors this week" 5
elif [ "$ERROR_COUNT" -gt 0 ]; then
    add_health_item "info" "$ERROR_COUNT errors logged this week"
else
    add_health_item "good" "No errors in system logs this week"
fi

# 10. Temperature Check (if sensors available)
log_message "🌡️ Checking system temperatures..."
if command -v sensors >/dev/null 2>&1; then
    CPU_TEMP=$(sensors 2>/dev/null | grep -E "(Core|Tctl|temp1)" | head -1 | grep -o "+[0-9]*" | sed 's/+//' || echo "0")
    if [ "$CPU_TEMP" -gt 80 ]; then
        add_health_item "critical" "High CPU temperature: ${CPU_TEMP}°C" 15
    elif [ "$CPU_TEMP" -gt 70 ]; then
        add_health_item "warning" "Elevated CPU temperature: ${CPU_TEMP}°C" 5
    elif [ "$CPU_TEMP" -gt 0 ]; then
        add_health_item "good" "CPU temperature: ${CPU_TEMP}°C"
    fi
fi

# Calculate final health score
if [ "$HEALTH_SCORE" -lt 0 ]; then
    HEALTH_SCORE=0
fi

# Determine overall status
if [ "$HEALTH_SCORE" -ge 90 ]; then
    OVERALL_STATUS="🟢 EXCELLENT"
    PRIORITY="default"
    TAGS="white_check_mark,weekly,health"
elif [ "$HEALTH_SCORE" -ge 75 ]; then
    OVERALL_STATUS="🟡 GOOD"
    PRIORITY="default"
    TAGS="weekly,health"
elif [ "$HEALTH_SCORE" -ge 50 ]; then
    OVERALL_STATUS="🟠 FAIR"
    PRIORITY="default"
    TAGS="warning,weekly,health"
else
    OVERALL_STATUS="🔴 POOR"
    PRIORITY="high"
    TAGS="rotating_light,weekly,health"
fi

# Calculate duration
DURATION=$(( $(date +%s) - START ))

# Build comprehensive report
REPORT="📊 Weekly Health Report - $(date +'%Y-%m-%d')

🏥 Overall Health: $OVERALL_STATUS (Score: $HEALTH_SCORE/100)

📈 Issue Summary:
• Critical Issues: $CRITICAL_ISSUES
• Warnings: $WARNING_ISSUES
• Info Items: $INFO_ITEMS

🔍 System Overview:
• Uptime: ${UPTIME_DAYS} days
• Load Average: $LOAD_AVG
• Memory Usage: ${MEMORY_USAGE}%
• /data Usage: ${DATA_USAGE}%
• Containers: $RUNNING_CONTAINERS/$TOTAL_CONTAINERS running

📋 Detailed Findings:"

# Add all health details
for detail in "${HEALTH_DETAILS[@]}"; do
    REPORT+="
$detail"
done

if [ ${#FAILED_SERVICES[@]} -gt 0 ]; then
    REPORT+="

🚨 Failed Services: ${FAILED_SERVICES[*]}"
fi

REPORT+="

⏱️ Check Duration: ${DURATION}s
📅 Next Check: $(date -d '+1 week' +'%Y-%m-%d')"

# Send notification
send_ntfy "Weekly Health Report" "$REPORT" "$PRIORITY" "$TAGS"

# Log completion
log_message "📋 Weekly health check completed - Health Score: $HEALTH_SCORE/100"
log_message "📊 Found $CRITICAL_ISSUES critical issues, $WARNING_ISSUES warnings"

# Exit with appropriate code
if [ "$CRITICAL_ISSUES" -gt 0 ]; then
    exit 2
elif [ "$WARNING_ISSUES" -gt 5 ]; then  # Only exit 1 if many warnings
    exit 1
else
    exit 0
fi