#!/bin/bash
# =====================================================
# 🔧 Maintenance Dashboard + Orchestrator
# =====================================================
# Coordinates daily maintenance tasks and reporting
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
LOGFILE="/var/log/homelab/maintenance_dashboard.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')
START=$(date +%s)

# Create log directory
mkdir -p "$(dirname "$LOGFILE")"

# Function to send notifications
send_ntfy() {
    local title="$1"
    local message="$2"
    local priority="${3:-default}"
    local tags="${4:-maintenance}"
    
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

# Function to run maintenance task
run_maintenance_task() {
    local task_name="$1"
    local command="$2"
    local timeout="${3:-300}"  # Default 5 minute timeout
    local icon="${4:-🔧}"
    
    log_message "$icon Starting: $task_name"
    
    local start_time=$(date +%s)
    local task_logfile="/tmp/maintenance_${task_name//[^a-zA-Z0-9]/_}.log"
    
    # Run command with timeout
    if timeout "$timeout" bash -c "$command" > "$task_logfile" 2>&1; then
        local duration=$(($(date +%s) - start_time))
        log_message "✅ $task_name completed in ${duration}s"
        return 0
    else
        local exit_code=$?
        local duration=$(($(date +%s) - start_time))
        
        if [ $exit_code -eq 124 ]; then
            log_message "⏰ $task_name timed out after ${timeout}s"
            echo "⏰ $task_name: Timed out (${timeout}s)"
        else
            log_message "❌ $task_name failed (exit code: $exit_code) after ${duration}s"
            echo "❌ $task_name: Failed (exit $exit_code)"
        fi
        
        # Log error details
        if [ -f "$task_logfile" ]; then
            echo "Error output:" >> "$LOGFILE"
            tail -10 "$task_logfile" >> "$LOGFILE"
        fi
        
        return $exit_code
    fi
}

log_message "🚀 Starting maintenance dashboard for $SERVER_NAME"

# Initialize task tracking
TASKS_RUN=0
TASKS_SUCCESS=0
TASKS_FAILED=0
TASK_RESULTS=()

# Task 1: Container Health Check
TASKS_RUN=$((TASKS_RUN + 1))
if run_maintenance_task "Container Health Check" \
    "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' && docker system df" \
    60 "🐳"; then
    TASKS_SUCCESS=$((TASKS_SUCCESS + 1))
    TASK_RESULTS+=("🐳 Container Health Check: ✅ Success")
else
    TASKS_FAILED=$((TASKS_FAILED + 1))
    TASK_RESULTS+=("🐳 Container Health Check: ❌ Failed")
fi

# Task 2: System Resource Check
TASKS_RUN=$((TASKS_RUN + 1))
if run_maintenance_task "System Resource Check" \
    "free -h && df -h && uptime && sensors 2>/dev/null || echo 'Sensors not available'" \
    30 "💻"; then
    TASKS_SUCCESS=$((TASKS_SUCCESS + 1))
    TASK_RESULTS+=("💻 System Resource Check: ✅ Success")
else
    TASKS_FAILED=$((TASKS_FAILED + 1))
    TASK_RESULTS+=("💻 System Resource Check: ❌ Failed")
fi

# Task 3: Log Rotation and Cleanup
TASKS_RUN=$((TASKS_RUN + 1))
if run_maintenance_task "Log Rotation" \
    "journalctl --vacuum-time=30d && find /var/log -name '*.log' -size +50M -exec truncate -s 10M {} \; && find /tmp -name 'maintenance_*.log' -mtime +7 -delete" \
    120 "📝"; then
    TASKS_SUCCESS=$((TASKS_SUCCESS + 1))
    TASK_RESULTS+=("📝 Log Rotation: ✅ Success")
else
    TASKS_FAILED=$((TASKS_FAILED + 1))
    TASK_RESULTS+=("📝 Log Rotation: ❌ Failed")
fi

# Task 4: Docker Cleanup
TASKS_RUN=$((TASKS_RUN + 1))
if run_maintenance_task "Docker Cleanup" \
    "docker system prune -f && docker image prune -f --filter 'until=72h'" \
    180 "🧹"; then
    TASKS_SUCCESS=$((TASKS_SUCCESS + 1))
    TASK_RESULTS+=("🧹 Docker Cleanup: ✅ Success")
else
    TASKS_FAILED=$((TASKS_FAILED + 1))
    TASK_RESULTS+=("🧹 Docker Cleanup: ❌ Failed")
fi

# Task 5: Network Connectivity Test
TASKS_RUN=$((TASKS_RUN + 1))
if run_maintenance_task "Network Test" \
    "ping -c 3 8.8.8.8 && curl -s --max-time 10 google.com >/dev/null && if docker ps --filter 'name=gluetun' -q | grep -q .; then docker exec gluetun curl -s --max-time 10 ifconfig.me; fi" \
    60 "🌐"; then
    TASKS_SUCCESS=$((TASKS_SUCCESS + 1))
    TASK_RESULTS+=("🌐 Network Test: ✅ Success")
else
    TASKS_FAILED=$((TASKS_FAILED + 1))
    TASK_RESULTS+=("🌐 Network Test: ❌ Failed")
fi

# Task 6: Service Endpoint Check
TASKS_RUN=$((TASKS_RUN + 1))
if run_maintenance_task "Service Endpoint Check" \
    "curl -f -s http://localhost:8096/health >/dev/null || curl -f -s http://localhost:8096 >/dev/null; curl -f -s http://localhost:8989 >/dev/null; curl -f -s http://localhost:7878 >/dev/null" \
    60 "🔍"; then
    TASKS_SUCCESS=$((TASKS_SUCCESS + 1))
    TASK_RESULTS+=("🔍 Service Endpoint Check: ✅ Success")
else
    TASKS_FAILED=$((TASKS_FAILED + 1))
    TASK_RESULTS+=("🔍 Service Endpoint Check: ❌ Failed")
fi

# Task 7: Backup Verification
TASKS_RUN=$((TASKS_RUN + 1))
if run_maintenance_task "Backup Verification" \
    "test -f /var/log/homelab/restic_backup.log && tail -10 /var/log/homelab/restic_backup.log | grep -q 'completed successfully'" \
    30 "💾"; then
    TASKS_SUCCESS=$((TASKS_SUCCESS + 1))
    TASK_RESULTS+=("💾 Backup Verification: ✅ Success")
else
    TASKS_FAILED=$((TASKS_FAILED + 1))
    TASK_RESULTS+=("💾 Backup Verification: ❌ Failed")
fi

# Task 8: Permission Check
TASKS_RUN=$((TASKS_RUN + 1))
if run_maintenance_task "Permission Check" \
    "test -d /data && ls -la /data/ && find /data -type d ! -perm -755 | head -5" \
    60 "🔒"; then
    TASKS_SUCCESS=$((TASKS_SUCCESS + 1))
    TASK_RESULTS+=("🔒 Permission Check: ✅ Success")
else
    TASKS_FAILED=$((TASKS_FAILED + 1))
    TASK_RESULTS+=("🔒 Permission Check: ❌ Failed")
fi

# Task 9: Cron Job Verification
TASKS_RUN=$((TASKS_RUN + 1))
if run_maintenance_task "Cron Job Check" \
    "sudo crontab -l | grep -q 'homelab' && echo 'Homelab cron jobs found'" \
    30 "⏰"; then
    TASKS_SUCCESS=$((TASKS_SUCCESS + 1))
    TASK_RESULTS+=("⏰ Cron Job Check: ✅ Success")
else
    TASKS_FAILED=$((TASKS_FAILED + 1))
    TASK_RESULTS+=("⏰ Cron Job Check: ❌ Failed")
fi

# Task 10: Weekly Task Trigger (Sundays)
if [ "$(date +%u)" -eq 7 ]; then  # Sunday
    TASKS_RUN=$((TASKS_RUN + 1))
    if run_maintenance_task "Weekly Health Check" \
        "/usr/local/bin/weekly_system_health.sh" \
        600 "📊"; then
        TASKS_SUCCESS=$((TASKS_SUCCESS + 1))
        TASK_RESULTS+=("📊 Weekly Health Check: ✅ Success")
    else
        TASKS_FAILED=$((TASKS_FAILED + 1))
        TASK_RESULTS+=("📊 Weekly Health Check: ❌ Failed")
    fi
fi

# Calculate total duration
TOTAL_DURATION=$(( $(date +%s) - START ))

# Determine overall status
SUCCESS_RATE=$(( (TASKS_SUCCESS * 100) / TASKS_RUN ))

if [ $TASKS_FAILED -eq 0 ]; then
    OVERALL_STATUS="✅ ALL TASKS SUCCESSFUL"
    PRIORITY="default"
    TAGS="white_check_mark,maintenance"
elif [ $SUCCESS_RATE -ge 80 ]; then
    OVERALL_STATUS="⚠️ MOSTLY SUCCESSFUL"
    PRIORITY="default"
    TAGS="warning,maintenance"
else
    OVERALL_STATUS="❌ MULTIPLE FAILURES"
    PRIORITY="high"
    TAGS="x,maintenance,warning"
fi

# Get current system snapshot
CURRENT_LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
CURRENT_MEMORY=$(free | awk 'NR==2{printf "%.1f%%", $3*100/$2}')
CURRENT_DISK=$(df -h /data 2>/dev/null | awk 'NR==2 {print $5}' || echo "N/A")
RUNNING_CONTAINERS=$(docker ps -q | wc -l)

# Build maintenance report
MAINTENANCE_REPORT="🔧 Maintenance Dashboard - $(date +'%Y-%m-%d %H:%M')

$OVERALL_STATUS

📊 Task Summary:
• Total Tasks: $TASKS_RUN
• Successful: $TASKS_SUCCESS
• Failed: $TASKS_FAILED
• Success Rate: ${SUCCESS_RATE}%

📈 Current System Status:
• Load Average: $CURRENT_LOAD
• Memory Usage: $CURRENT_MEMORY
• Disk Usage (/data): $CURRENT_DISK
• Running Containers: $RUNNING_CONTAINERS

🔍 Task Results:"

# Add all task results
for result in "${TASK_RESULTS[@]}"; do
    MAINTENANCE_REPORT+="
$result"
done

MAINTENANCE_REPORT+="

⏱️ Total Duration: ${TOTAL_DURATION}s
📅 Next Run: $(date -d '+1 day' +'%Y-%m-%d %H:%M')"

# Send notification (daily summary)
send_ntfy "Maintenance Dashboard" "$MAINTENANCE_REPORT" "$PRIORITY" "$TAGS"

# If there are failures, also send to alerts
if [ $TASKS_FAILED -gt 0 ]; then
    ALERT_MESSAGE="⚠️ Maintenance dashboard found $TASKS_FAILED failed tasks:

$(printf "%s\n" "${TASK_RESULTS[@]}" | grep "❌")

🔍 Check detailed logs: $LOGFILE
📊 Success Rate: ${SUCCESS_RATE}%"

    curl -s \
        -H "Title: [$SERVER_NAME] Maintenance Failures" \
        -H "Priority: default" \
        -H "Tags: warning,maintenance" \
        -d "$ALERT_MESSAGE" \
        "$NTFY_SERVER/${NTFY_TOPIC_ALERTS:-homelab-alerts}" || true
fi

# Log final status
log_message "🏁 Maintenance dashboard completed - $TASKS_SUCCESS/$TASKS_RUN tasks successful"

# Cleanup temporary files
find /tmp -name "maintenance_*.log" -mtime +1 -delete 2>/dev/null || true

# Exit with appropriate code
if [ $TASKS_FAILED -gt 0 ]; then
    exit 1
else
    exit 0
fi