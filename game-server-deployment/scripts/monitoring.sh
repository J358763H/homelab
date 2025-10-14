#!/bin/bash
# =====================================================
# 🎮 Game Server Monitoring Dashboard
# =====================================================
# Comprehensive monitoring for Moonlight GameStream + CoinOps
# Maintainer: J35867U
# Email: mrnash404@protonmail.com
# Last Updated: 2025-10-14
# =====================================================

set -e

# Configuration
SERVER_NAME="game-server"
ADMIN_EMAIL="mrnash404@protonmail.com"
LOGFILE="/var/log/game-server/monitoring.log"
DATE=$(date '+%Y-%m-%d_%H-%M-%S')
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# NTFY Configuration (separate from homelab)
NTFY_SERVER=${NTFY_SERVER:-"https://ntfy.sh"}
NTFY_TOPIC_GAMESERVER=${NTFY_TOPIC_GAMESERVER:-"game-server-standalone"}

# Thresholds
CPU_THRESHOLD=80
MEMORY_THRESHOLD=80
DISK_THRESHOLD=85
TEMP_THRESHOLD=75
LOAD_THRESHOLD=4.0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Create directories
mkdir -p "$(dirname "$LOGFILE")"

# Function to log messages
log_message() {
    echo "[$TIMESTAMP] $1" | tee -a "$LOGFILE"
}

# Function to send NTFY notifications
send_ntfy() {
    local title="$1"
    local message="$2"
    local priority="${3:-default}"
    local tags="${4:-gaming,monitoring,alert}"
    
    if [ -n "$NTFY_SERVER" ] && [ -n "$NTFY_TOPIC_GAMESERVER" ]; then
        curl -s \
            -H "Title: [Game Server] $title" \
            -H "Priority: $priority" \
            -H "Tags: $tags" \
            -d "$message" \
            "$NTFY_SERVER/$NTFY_TOPIC_GAMESERVER" >/dev/null 2>&1 || true
    fi
}

# Function to get status symbol and color
get_status_display() {
    local status="$1"
    case "$status" in
        "active"|"running"|"OK"|"healthy")
            echo -e "${GREEN}●${NC} $status"
            ;;
        "inactive"|"stopped"|"failed")
            echo -e "${RED}●${NC} $status"
            ;;
        "warning"|"degraded")
            echo -e "${YELLOW}●${NC} $status"
            ;;
        *)
            echo -e "${CYAN}●${NC} $status"
            ;;
    esac
}

# Function to check system resources
check_system_resources() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}🖥️  SYSTEM RESOURCES${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    
    # CPU Usage
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 | tr -d ' ')
    if (( $(echo "$CPU_USAGE > $CPU_THRESHOLD" | bc -l) )); then
        CPU_STATUS="${RED}HIGH${NC}"
        ALERT_CPU=true
    else
        CPU_STATUS="${GREEN}OK${NC}"
        ALERT_CPU=false
    fi
    
    # Memory Usage
    MEM_INFO=$(free | grep Mem)
    MEM_TOTAL=$(echo $MEM_INFO | awk '{print $2}')
    MEM_USED=$(echo $MEM_INFO | awk '{print $3}')
    MEM_USAGE=$(echo "scale=1; $MEM_USED * 100 / $MEM_TOTAL" | bc)
    MEM_USAGE_INT=${MEM_USAGE%.*}
    
    if [ "$MEM_USAGE_INT" -gt "$MEMORY_THRESHOLD" ]; then
        MEM_STATUS="${RED}HIGH${NC}"
        ALERT_MEMORY=true
    else
        MEM_STATUS="${GREEN}OK${NC}"
        ALERT_MEMORY=false
    fi
    
    # Disk Usage
    DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | cut -d'%' -f1)
    if [ "$DISK_USAGE" -gt "$DISK_THRESHOLD" ]; then
        DISK_STATUS="${RED}HIGH${NC}"
        ALERT_DISK=true
    else
        DISK_STATUS="${GREEN}OK${NC}"
        ALERT_DISK=false
    fi
    
    # System Load
    LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    if (( $(echo "$LOAD_AVG > $LOAD_THRESHOLD" | bc -l) )); then
        LOAD_STATUS="${RED}HIGH${NC}"
        ALERT_LOAD=true
    else
        LOAD_STATUS="${GREEN}OK${NC}"
        ALERT_LOAD=false
    fi
    
    # Temperature (if sensors available)
    if command -v sensors >/dev/null 2>&1; then
        TEMP=$(sensors 2>/dev/null | grep -i "Core 0" | awk '{print $3}' | grep -o '[0-9]*' | head -1)
        if [ -n "$TEMP" ] && [ "$TEMP" -gt "$TEMP_THRESHOLD" ]; then
            TEMP_STATUS="${RED}HIGH${NC}"
            ALERT_TEMP=true
        elif [ -n "$TEMP" ]; then
            TEMP_STATUS="${GREEN}OK${NC}"
            ALERT_TEMP=false
        else
            TEMP_STATUS="${YELLOW}N/A${NC}"
            ALERT_TEMP=false
        fi
    else
        TEMP="N/A"
        TEMP_STATUS="${YELLOW}N/A${NC}"
        ALERT_TEMP=false
    fi
    
    printf "%-20s %10s %s\n" "CPU Usage:" "${CPU_USAGE}%" "$CPU_STATUS"
    printf "%-20s %10s %s\n" "Memory Usage:" "${MEM_USAGE}%" "$MEM_STATUS"
    printf "%-20s %10s %s\n" "Disk Usage:" "${DISK_USAGE}%" "$DISK_STATUS"
    printf "%-20s %10s %s\n" "Load Average:" "$LOAD_AVG" "$LOAD_STATUS"
    printf "%-20s %10s %s\n" "Temperature:" "${TEMP}°C" "$TEMP_STATUS"
}

# Function to check game server services
check_game_services() {
    echo -e "\n${PURPLE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${PURPLE}🎮 GAME SERVER SERVICES${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════${NC}"
    
    # Define services to check
    declare -A SERVICES=(
        ["sunshine"]="Sunshine GameStream Server"
        ["coinops-web"]="CoinOps Web Interface"
        ["x11-server"]="X11 Display Server"
        ["openbox"]="Openbox Window Manager"
    )
    
    SERVICE_ISSUES=()
    
    for service in "${!SERVICES[@]}"; do
        if systemctl list-units --all | grep -q "$service"; then
            STATUS=$(systemctl is-active "$service" 2>/dev/null || echo "unknown")
            ENABLED=$(systemctl is-enabled "$service" 2>/dev/null || echo "unknown")
            
            case "$STATUS" in
                "active")
                    STATUS_DISPLAY=$(get_status_display "$STATUS")
                    ;;
                "inactive"|"failed")
                    STATUS_DISPLAY=$(get_status_display "$STATUS")
                    SERVICE_ISSUES+=("$service: $STATUS")
                    ;;
                *)
                    STATUS_DISPLAY=$(get_status_display "$STATUS")
                    SERVICE_ISSUES+=("$service: $STATUS")
                    ;;
            esac
            
            printf "%-25s %s (%s)\n" "${SERVICES[$service]}:" "$STATUS_DISPLAY" "$ENABLED"
        else
            printf "%-25s %s\n" "${SERVICES[$service]}:" "$(get_status_display "not installed")"
            SERVICE_ISSUES+=("$service: not installed")
        fi
    done
}

# Function to check network ports
check_network_ports() {
    echo -e "\n${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}🌐 NETWORK CONNECTIVITY${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    
    # Define expected ports
    declare -A PORTS=(
        ["47984"]="Sunshine GameStream"
        ["8080"]="CoinOps Web Interface"
        ["47989"]="Sunshine RTSP"
        ["47990"]="Sunshine Control"
    )
    
    PORT_ISSUES=()
    
    for port in "${!PORTS[@]}"; do
        if ss -tulpn | grep -q ":$port "; then
            printf "%-25s %s %s\n" "${PORTS[$port]}:" "Port $port" "$(get_status_display "listening")"
        else
            printf "%-25s %s %s\n" "${PORTS[$port]}:" "Port $port" "$(get_status_display "not listening")"
            PORT_ISSUES+=("${PORTS[$port]}: Port $port not listening")
        fi
    done
    
    # Check external connectivity
    echo -e "\n${CYAN}External Connectivity:${NC}"
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        printf "%-25s %s\n" "Internet:" "$(get_status_display "OK")"
    else
        printf "%-25s %s\n" "Internet:" "$(get_status_display "failed")"
        PORT_ISSUES+=("Internet connectivity: failed")
    fi
}

# Function to check hardware acceleration
check_hardware_acceleration() {
    echo -e "\n${YELLOW}═══════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}🔧 HARDWARE ACCELERATION${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
    
    HW_ISSUES=()
    
    # Check VAAPI (Video Acceleration API)
    if command -v vainfo >/dev/null 2>&1; then
        if vainfo >/dev/null 2>&1; then
            VAAPI_STATUS="$(get_status_display "available")"
            VAAPI_DEVICE=$(vainfo 2>&1 | grep "Driver version" | head -1 | awk -F': ' '{print $2}' || echo "Unknown")
            printf "%-25s %s (%s)\n" "VAAPI:" "$VAAPI_STATUS" "$VAAPI_DEVICE"
        else
            VAAPI_STATUS="$(get_status_display "not available")"
            printf "%-25s %s\n" "VAAPI:" "$VAAPI_STATUS"
            HW_ISSUES+=("VAAPI: Hardware acceleration not available")
        fi
    else
        printf "%-25s %s\n" "VAAPI:" "$(get_status_display "not installed")"
        HW_ISSUES+=("VAAPI: vainfo command not found")
    fi
    
    # Check NVIDIA GPU (if present)
    if command -v nvidia-smi >/dev/null 2>&1; then
        if nvidia-smi >/dev/null 2>&1; then
            GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits | head -1)
            printf "%-25s %s (%s)\n" "NVIDIA GPU:" "$(get_status_display "detected")" "$GPU_NAME"
            
            # Check GPU utilization
            GPU_UTIL=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -1)
            GPU_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits | head -1)
            printf "%-25s %s (%s°C)\n" "GPU Utilization:" "${GPU_UTIL}%" "$GPU_TEMP"
        else
            printf "%-25s %s\n" "NVIDIA GPU:" "$(get_status_display "error")"
            HW_ISSUES+=("NVIDIA GPU: nvidia-smi command failed")
        fi
    else
        printf "%-25s %s\n" "NVIDIA GPU:" "$(get_status_display "not detected")"
    fi
    
    # Check Intel GPU (integrated graphics)
    if lspci | grep -i "intel.*graphics" >/dev/null 2>&1; then
        INTEL_GPU=$(lspci | grep -i "intel.*graphics" | head -1 | awk -F': ' '{print $2}')
        printf "%-25s %s (%s)\n" "Intel GPU:" "$(get_status_display "detected")" "$INTEL_GPU"
    else
        printf "%-25s %s\n" "Intel GPU:" "$(get_status_display "not detected")"
    fi
}

# Function to check gaming performance metrics
check_gaming_metrics() {
    echo -e "\n${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🎯 GAMING PERFORMANCE METRICS${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    
    # Check if CoinOps web interface is responding
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 2>/dev/null | grep -q "200"; then
        printf "%-25s %s\n" "CoinOps Web API:" "$(get_status_display "responding")"
    else
        printf "%-25s %s\n" "CoinOps Web API:" "$(get_status_display "not responding")"
    fi
    
    # Check Sunshine status via log
    if [ -f "/var/log/sunshine.log" ]; then
        SUNSHINE_ERRORS=$(tail -100 /var/log/sunshine.log 2>/dev/null | grep -c "ERROR" || echo "0")
        if [ "$SUNSHINE_ERRORS" -eq 0 ]; then
            printf "%-25s %s\n" "Sunshine Status:" "$(get_status_display "healthy")"
        else
            printf "%-25s %s (%s errors)\n" "Sunshine Status:" "$(get_status_display "warnings")" "$SUNSHINE_ERRORS"
        fi
    else
        printf "%-25s %s\n" "Sunshine Logs:" "$(get_status_display "not found")"
    fi
    
    # Check display server
    if [ -n "$DISPLAY" ] || pgrep -x "Xorg\|Xvfb" >/dev/null; then
        printf "%-25s %s\n" "Display Server:" "$(get_status_display "running")"
        
        # Try to get display information
        if command -v xrandr >/dev/null 2>&1 && [ -n "$DISPLAY" ]; then
            RESOLUTION=$(xrandr 2>/dev/null | grep '\*' | awk '{print $1}' | head -1 || echo "Unknown")
            printf "%-25s %s\n" "Display Resolution:" "$RESOLUTION"
        fi
    else
        printf "%-25s %s\n" "Display Server:" "$(get_status_display "not running")"
    fi
    
    # Check ROM directory
    ROM_DIR="/opt/coinops/roms"
    if [ -d "$ROM_DIR" ]; then
        ROM_COUNT=$(find "$ROM_DIR" -type f \( -name "*.zip" -o -name "*.7z" -o -name "*.iso" \) 2>/dev/null | wc -l)
        ROM_SIZE=$(du -sh "$ROM_DIR" 2>/dev/null | cut -f1 || echo "Unknown")
        printf "%-25s %s (%s ROMs)\n" "ROM Collection:" "$ROM_SIZE" "$ROM_COUNT"
    else
        printf "%-25s %s\n" "ROM Directory:" "$(get_status_display "not found")"
    fi
}

# Function to check storage and backups
check_storage_backups() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}💾 STORAGE & BACKUPS${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    
    # Game data directories
    declare -A DIRECTORIES=(
        ["/opt/coinops/roms"]="ROM Files"
        ["/opt/coinops/saves"]="Save Games"
        ["/home/gameuser/.config"]="User Configs"
        ["/data/backups"]="Backup Storage"
    )
    
    for dir in "${!DIRECTORIES[@]}"; do
        if [ -d "$dir" ]; then
            SIZE=$(du -sh "$dir" 2>/dev/null | cut -f1 || echo "Unknown")
            FILES=$(find "$dir" -type f 2>/dev/null | wc -l || echo "Unknown")
            printf "%-25s %s (%s files)\n" "${DIRECTORIES[$dir]}:" "$SIZE" "$FILES"
        else
            printf "%-25s %s\n" "${DIRECTORIES[$dir]}:" "$(get_status_display "not found")"
        fi
    done
    
    # Check backup freshness
    BACKUP_DIR="/data/backups/game-server"
    if [ -d "$BACKUP_DIR" ]; then
        LATEST_BACKUP=$(find "$BACKUP_DIR" -name "*.tar.gz" -type f -printf '%T+ %p\n' 2>/dev/null | sort -r | head -1 | cut -d' ' -f2-)
        if [ -n "$LATEST_BACKUP" ]; then
            BACKUP_AGE=$(stat -c %Y "$LATEST_BACKUP" 2>/dev/null || echo "0")
            CURRENT_TIME=$(date +%s)
            AGE_HOURS=$(( (CURRENT_TIME - BACKUP_AGE) / 3600 ))
            
            if [ "$AGE_HOURS" -lt 48 ]; then
                printf "%-25s %s (%s hours old)\n" "Latest Backup:" "$(get_status_display "recent")" "$AGE_HOURS"
            else
                printf "%-25s %s (%s hours old)\n" "Latest Backup:" "$(get_status_display "old")" "$AGE_HOURS"
            fi
        else
            printf "%-25s %s\n" "Latest Backup:" "$(get_status_display "none found")"
        fi
    else
        printf "%-25s %s\n" "Backup Directory:" "$(get_status_display "not found")"
    fi
}

# Function to generate alerts
generate_alerts() {
    local alerts=()
    
    # Collect all issues
    [ "$ALERT_CPU" = true ] && alerts+=("High CPU usage: ${CPU_USAGE}%")
    [ "$ALERT_MEMORY" = true ] && alerts+=("High memory usage: ${MEM_USAGE}%")
    [ "$ALERT_DISK" = true ] && alerts+=("High disk usage: ${DISK_USAGE}%")
    [ "$ALERT_LOAD" = true ] && alerts+=("High system load: ${LOAD_AVG}")
    [ "$ALERT_TEMP" = true ] && alerts+=("High temperature: ${TEMP}°C")
    
    # Add service issues
    for issue in "${SERVICE_ISSUES[@]}"; do
        alerts+=("Service issue: $issue")
    done
    
    # Add port issues
    for issue in "${PORT_ISSUES[@]}"; do
        alerts+=("Network issue: $issue")
    done
    
    # Add hardware issues
    for issue in "${HW_ISSUES[@]}"; do
        alerts+=("Hardware issue: $issue")
    done
    
    # Send alerts if any found
    if [ ${#alerts[@]} -gt 0 ]; then
        echo -e "\n${RED}⚠️  ALERTS DETECTED${NC}"
        echo -e "${RED}═══════════════════════════════════════════════════════${NC}"
        
        for alert in "${alerts[@]}"; do
            echo -e "${RED}• $alert${NC}"
            log_message "ALERT: $alert"
        done
        
        # Send consolidated NTFY alert
        ALERT_MESSAGE="🚨 Game Server Issues Detected

$(printf '%s\n' "${alerts[@]}" | head -10)
$([ ${#alerts[@]} -gt 10 ] && echo "... and $((${#alerts[@]} - 10)) more issues")

🕐 Time: $(date)
🖥️ Server: $(hostname)
📧 Contact: $ADMIN_EMAIL"

        send_ntfy "System Alert" "$ALERT_MESSAGE" "high" "gaming,alert,critical"
        
        return 1  # Return error code to indicate issues found
    else
        echo -e "\n${GREEN}✅ ALL SYSTEMS OPERATIONAL${NC}"
        log_message "INFO: All systems operational - no issues detected"
        return 0
    fi
}

# Main execution
main() {
    echo -e "${CYAN}🎮 GAME SERVER MONITORING DASHBOARD${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "Server: $SERVER_NAME"
    echo -e "Time: $(date)"
    echo -e "Uptime: $(uptime -p)"
    
    log_message "Starting game server monitoring check"
    
    # Run all checks
    check_system_resources
    check_game_services
    check_network_ports
    check_hardware_acceleration
    check_gaming_metrics
    check_storage_backups
    
    # Generate summary and alerts
    if generate_alerts; then
        log_message "Monitoring completed - all systems healthy"
        
        # Send success notification (daily only)
        if [ "$(date +%H:%M)" = "08:00" ]; then
            SUCCESS_MESSAGE="🎮 Daily Game Server Report

✅ All systems operational
🖥️ Server: $(hostname)  
📊 CPU: ${CPU_USAGE}% | RAM: ${MEM_USAGE}% | Disk: ${DISK_USAGE}%
🎯 Services: All running normally
🌐 Network: All ports accessible
⚡ Hardware: Acceleration available

🕐 Report Time: $(date +'%Y-%m-%d %H:%M')
📧 Maintainer: $ADMIN_EMAIL"

            send_ntfy "Daily Status Report" "$SUCCESS_MESSAGE" "low" "gaming,daily,status"
        fi
    else
        log_message "Monitoring completed - issues detected and reported"
    fi
    
    echo -e "\n${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}📊 Monitoring completed at $(date)${NC}"
    echo -e "${CYAN}💾 Logs: $LOGFILE${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
}

# Handle command line arguments
case "${1:-}" in
    "quick")
        check_system_resources
        check_game_services
        ;;
    "services")
        check_game_services
        check_network_ports
        ;;
    "performance")
        check_hardware_acceleration
        check_gaming_metrics
        ;;
    "storage")
        check_storage_backups
        ;;
    "alerts")
        check_system_resources
        check_game_services
        generate_alerts
        ;;
    "help"|"-h"|"--help")
        echo "Game Server Monitoring Dashboard"
        echo ""
        echo "Usage: $0 [OPTION]"
        echo ""
        echo "Options:"
        echo "  quick       Quick system resource check"
        echo "  services    Check services and network ports"
        echo "  performance Check hardware acceleration and gaming metrics"
        echo "  storage     Check storage and backup status"
        echo "  alerts      Check for alerts only"
        echo "  help        Show this help message"
        echo ""
        echo "Without options, runs full monitoring dashboard"
        ;;
    *)
        main
        ;;
esac