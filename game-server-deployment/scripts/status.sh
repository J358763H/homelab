#!/bin/bash
# =====================================================
# 🎮 Game Server Status Checker
# =====================================================
# Comprehensive status checker for all game server components
# Maintainer: J35867U
# Email: mrnash404@protonmail.com
# Last Updated: 2025-10-14
# =====================================================

set -e

# Configuration
SERVER_NAME="game-server"
ADMIN_EMAIL="mrnash404@protonmail.com"
LOGFILE="/var/log/game-server/status.log"
DATE=$(date '+%Y-%m-%d_%H-%M-%S')
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# NTFY Configuration (separate from homelab)
NTFY_SERVER=${NTFY_SERVER:-"https://ntfy.sh"}
NTFY_TOPIC_GAMESERVER=${NTFY_TOPIC_GAMESERVER:-"game-server-standalone"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Status counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

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
    local tags="${4:-gaming,status,check}"
    
    if [ -n "$NTFY_SERVER" ] && [ -n "$NTFY_TOPIC_GAMESERVER" ]; then
        curl -s \
            -H "Title: [Game Server] $title" \
            -H "Priority: $priority" \
            -H "Tags: $tags" \
            -d "$message" \
            "$NTFY_SERVER/$NTFY_TOPIC_GAMESERVER" >/dev/null 2>&1 || true
    fi
}

# Function to increment counters
increment_counter() {
    local status="$1"
    ((TOTAL_CHECKS++))
    
    case "$status" in
        "PASS")
            ((PASSED_CHECKS++))
            ;;
        "FAIL")
            ((FAILED_CHECKS++))
            ;;
        "WARN")
            ((WARNING_CHECKS++))
            ;;
    esac
}

# Function to check status and display result
check_status() {
    local description="$1"
    local command="$2"
    local success_pattern="$3"
    local warning_pattern="$4"
    
    printf "%-50s " "$description"
    
    if result=$(eval "$command" 2>&1); then
        if [ -n "$success_pattern" ] && echo "$result" | grep -q "$success_pattern"; then
            echo -e "${GREEN}✓ PASS${NC}"
            increment_counter "PASS"
            return 0
        elif [ -n "$warning_pattern" ] && echo "$result" | grep -q "$warning_pattern"; then
            echo -e "${YELLOW}⚠ WARN${NC}"
            increment_counter "WARN"
            return 1
        elif [ -z "$success_pattern" ]; then
            echo -e "${GREEN}✓ PASS${NC}"
            increment_counter "PASS"
            return 0
        else
            echo -e "${RED}✗ FAIL${NC}"
            increment_counter "FAIL"
            return 2
        fi
    else
        echo -e "${RED}✗ FAIL${NC}"
        increment_counter "FAIL"
        return 2
    fi
}

# Function to check service status
check_service() {
    local service="$1"
    local description="$2"
    
    printf "%-50s " "$description"
    
    if systemctl list-units --all | grep -q "$service"; then
        status=$(systemctl is-active "$service" 2>/dev/null || echo "unknown")
        enabled=$(systemctl is-enabled "$service" 2>/dev/null || echo "unknown")
        
        case "$status" in
            "active")
                echo -e "${GREEN}✓ ACTIVE${NC} ($enabled)"
                increment_counter "PASS"
                return 0
                ;;
            "inactive")
                echo -e "${YELLOW}⚠ INACTIVE${NC} ($enabled)"
                increment_counter "WARN"
                return 1
                ;;
            "failed")
                echo -e "${RED}✗ FAILED${NC} ($enabled)"
                increment_counter "FAIL"
                return 2
                ;;
            *)
                echo -e "${YELLOW}⚠ UNKNOWN${NC} ($status)"
                increment_counter "WARN"
                return 1
                ;;
        esac
    else
        echo -e "${RED}✗ NOT FOUND${NC}"
        increment_counter "FAIL"
        return 2
    fi
}

# Function to check port status
check_port() {
    local port="$1"
    local description="$2"
    local protocol="${3:-tcp}"
    
    printf "%-50s " "$description"
    
    if ss -${protocol}ln | grep -q ":$port "; then
        echo -e "${GREEN}✓ LISTENING${NC}"
        increment_counter "PASS"
        return 0
    else
        echo -e "${RED}✗ NOT LISTENING${NC}"
        increment_counter "FAIL"
        return 2
    fi
}

# Function to check directory status
check_directory() {
    local dir="$1"
    local description="$2"
    local check_files="${3:-false}"
    
    printf "%-50s " "$description"
    
    if [ -d "$dir" ]; then
        if [ "$check_files" = "true" ]; then
            file_count=$(find "$dir" -type f 2>/dev/null | wc -l)
            if [ "$file_count" -gt 0 ]; then
                echo -e "${GREEN}✓ EXISTS${NC} ($file_count files)"
                increment_counter "PASS"
                return 0
            else
                echo -e "${YELLOW}⚠ EMPTY${NC}"
                increment_counter "WARN"
                return 1
            fi
        else
            echo -e "${GREEN}✓ EXISTS${NC}"
            increment_counter "PASS"
            return 0
        fi
    else
        echo -e "${RED}✗ MISSING${NC}"
        increment_counter "FAIL"
        return 2
    fi
}

# Function to check system resources
check_system_resources() {
    echo -e "\n${BLUE}══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}🖥️  SYSTEM RESOURCES${NC}"
    echo -e "${BLUE}══════════════════════════════════════════════════════${NC}"
    
    # CPU usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 | tr -d ' ')
    printf "%-50s " "CPU Usage"
    if (( $(echo "$cpu_usage < 80" | bc -l) )); then
        echo -e "${GREEN}✓ ${cpu_usage}%${NC}"
        increment_counter "PASS"
    elif (( $(echo "$cpu_usage < 90" | bc -l) )); then
        echo -e "${YELLOW}⚠ ${cpu_usage}%${NC}"
        increment_counter "WARN"
    else
        echo -e "${RED}✗ ${cpu_usage}%${NC}"
        increment_counter "FAIL"
    fi
    
    # Memory usage
    mem_info=$(free | grep Mem)
    mem_total=$(echo $mem_info | awk '{print $2}')
    mem_used=$(echo $mem_info | awk '{print $3}')
    mem_usage=$(echo "scale=1; $mem_used * 100 / $mem_total" | bc)
    mem_usage_int=${mem_usage%.*}
    
    printf "%-50s " "Memory Usage"
    if [ "$mem_usage_int" -lt 80 ]; then
        echo -e "${GREEN}✓ ${mem_usage}%${NC}"
        increment_counter "PASS"
    elif [ "$mem_usage_int" -lt 90 ]; then
        echo -e "${YELLOW}⚠ ${mem_usage}%${NC}"
        increment_counter "WARN"
    else
        echo -e "${RED}✗ ${mem_usage}%${NC}"
        increment_counter "FAIL"
    fi
    
    # Disk usage
    disk_usage=$(df / | tail -1 | awk '{print $5}' | cut -d'%' -f1)
    printf "%-50s " "Root Disk Usage"
    if [ "$disk_usage" -lt 80 ]; then
        echo -e "${GREEN}✓ ${disk_usage}%${NC}"
        increment_counter "PASS"
    elif [ "$disk_usage" -lt 90 ]; then
        echo -e "${YELLOW}⚠ ${disk_usage}%${NC}"
        increment_counter "WARN"
    else
        echo -e "${RED}✗ ${disk_usage}%${NC}"
        increment_counter "FAIL"
    fi
    
    # Load average
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    printf "%-50s " "System Load (1 min)"
    if (( $(echo "$load_avg < 2.0" | bc -l) )); then
        echo -e "${GREEN}✓ ${load_avg}${NC}"
        increment_counter "PASS"
    elif (( $(echo "$load_avg < 4.0" | bc -l) )); then
        echo -e "${YELLOW}⚠ ${load_avg}${NC}"
        increment_counter "WARN"
    else
        echo -e "${RED}✗ ${load_avg}${NC}"
        increment_counter "FAIL"
    fi
    
    # Temperature (if available)
    if command -v sensors >/dev/null 2>&1; then
        temp=$(sensors 2>/dev/null | grep -i "Core 0" | awk '{print $3}' | grep -o '[0-9]*' | head -1)
        if [ -n "$temp" ]; then
            printf "%-50s " "CPU Temperature"
            if [ "$temp" -lt 70 ]; then
                echo -e "${GREEN}✓ ${temp}°C${NC}"
                increment_counter "PASS"
            elif [ "$temp" -lt 80 ]; then
                echo -e "${YELLOW}⚠ ${temp}°C${NC}"
                increment_counter "WARN"
            else
                echo -e "${RED}✗ ${temp}°C${NC}"
                increment_counter "FAIL"
            fi
        fi
    fi
}

# Function to check game server services
check_game_services() {
    echo -e "\n${PURPLE}══════════════════════════════════════════════════════${NC}"
    echo -e "${PURPLE}🎮 GAME SERVER SERVICES${NC}"
    echo -e "${PURPLE}══════════════════════════════════════════════════════${NC}"
    
    check_service "sunshine" "Sunshine GameStream Server"
    check_service "coinops-web" "CoinOps Web Interface"
    check_service "x11-server" "X11 Display Server"
    check_service "openbox" "Openbox Window Manager"
    
    # Check if any processes are running even if systemd services aren't
    printf "%-50s " "Sunshine Process"
    if pgrep -x sunshine >/dev/null; then
        echo -e "${GREEN}✓ RUNNING${NC}"
        increment_counter "PASS"
    else
        echo -e "${RED}✗ NOT RUNNING${NC}"
        increment_counter "FAIL"
    fi
    
    # Check X11 display
    printf "%-50s " "X11 Display Server"
    if [ -n "$DISPLAY" ] || pgrep -x "Xorg\|Xvfb" >/dev/null; then
        echo -e "${GREEN}✓ ACTIVE${NC}"
        increment_counter "PASS"
    else
        echo -e "${RED}✗ NO DISPLAY${NC}"
        increment_counter "FAIL"
    fi
}

# Function to check network connectivity
check_network() {
    echo -e "\n${CYAN}══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}🌐 NETWORK CONNECTIVITY${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"
    
    # Check important ports
    check_port "47984" "Sunshine GameStream Port (47984)"
    check_port "8080" "CoinOps Web Interface (8080)"
    check_port "47989" "Sunshine RTSP Port (47989)"
    check_port "47990" "Sunshine Control Port (47990)"
    
    # Check external connectivity
    printf "%-50s " "Internet Connectivity"
    if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        echo -e "${GREEN}✓ ONLINE${NC}"
        increment_counter "PASS"
    else
        echo -e "${RED}✗ OFFLINE${NC}"
        increment_counter "FAIL"
    fi
    
    # Check DNS resolution
    printf "%-50s " "DNS Resolution"
    if nslookup google.com >/dev/null 2>&1; then
        echo -e "${GREEN}✓ WORKING${NC}"
        increment_counter "PASS"
    else
        echo -e "${RED}✗ FAILED${NC}"
        increment_counter "FAIL"
    fi
}

# Function to check hardware acceleration
check_hardware() {
    echo -e "\n${YELLOW}══════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}🔧 HARDWARE ACCELERATION${NC}"
    echo -e "${YELLOW}══════════════════════════════════════════════════════${NC}"
    
    # Check VAAPI
    printf "%-50s " "VAAPI (Video Acceleration API)"
    if command -v vainfo >/dev/null 2>&1 && vainfo >/dev/null 2>&1; then
        echo -e "${GREEN}✓ AVAILABLE${NC}"
        increment_counter "PASS"
    else
        echo -e "${YELLOW}⚠ NOT AVAILABLE${NC}"
        increment_counter "WARN"
    fi
    
    # Check NVIDIA GPU
    printf "%-50s " "NVIDIA GPU Support"
    if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
        echo -e "${GREEN}✓ DETECTED${NC}"
        increment_counter "PASS"
    else
        echo -e "${YELLOW}⚠ NOT DETECTED${NC}"
        increment_counter "WARN"
    fi
    
    # Check Intel GPU
    printf "%-50s " "Intel GPU Support"
    if lspci | grep -i "intel.*graphics" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ DETECTED${NC}"
        increment_counter "PASS"
    else
        echo -e "${YELLOW}⚠ NOT DETECTED${NC}"
        increment_counter "WARN"
    fi
}

# Function to check gaming directories and files
check_gaming_setup() {
    echo -e "\n${GREEN}══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🎯 GAMING SETUP${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
    
    # Check directories
    check_directory "/opt/coinops/roms" "ROM Directory" "true"
    check_directory "/opt/coinops/saves" "Save Games Directory" "false"
    check_directory "/home/gameuser/.config" "User Configuration Directory" "false"
    check_directory "/etc/sunshine" "Sunshine Configuration Directory" "false"
    
    # Check web interface response
    printf "%-50s " "CoinOps Web Interface Response"
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 2>/dev/null | grep -q "200"; then
        echo -e "${GREEN}✓ RESPONDING${NC}"
        increment_counter "PASS"
    else
        echo -e "${RED}✗ NOT RESPONDING${NC}"
        increment_counter "FAIL"
    fi
    
    # Check RetroArch
    printf "%-50s " "RetroArch Installation"
    if command -v retroarch >/dev/null 2>&1; then
        echo -e "${GREEN}✓ INSTALLED${NC}"
        increment_counter "PASS"
    else
        echo -e "${YELLOW}⚠ NOT INSTALLED${NC}"
        increment_counter "WARN"
    fi
    
    # Check game user
    printf "%-50s " "Game User Account"
    if id gameuser >/dev/null 2>&1; then
        echo -e "${GREEN}✓ EXISTS${NC}"
        increment_counter "PASS"
    else
        echo -e "${RED}✗ MISSING${NC}"
        increment_counter "FAIL"
    fi
}

# Function to check backup status
check_backup_status() {
    echo -e "\n${BLUE}══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}💾 BACKUP STATUS${NC}"
    echo -e "${BLUE}══════════════════════════════════════════════════════${NC}"
    
    # Check backup directory
    check_directory "/data/backups/game-server" "Backup Directory" "false"
    
    # Check for recent backups
    printf "%-50s " "Recent Backup (24 hours)"
    if [ -d "/data/backups/game-server" ]; then
        recent_backup=$(find /data/backups/game-server -name "*.tar.gz*" -mtime -1 2>/dev/null | head -1)
        if [ -n "$recent_backup" ]; then
            echo -e "${GREEN}✓ FOUND${NC}"
            increment_counter "PASS"
        else
            echo -e "${YELLOW}⚠ NOT FOUND${NC}"
            increment_counter "WARN"
        fi
    else
        echo -e "${RED}✗ NO BACKUP DIR${NC}"
        increment_counter "FAIL"
    fi
}

# Function to display summary
display_summary() {
    echo -e "\n${BOLD}══════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}📊 STATUS CHECK SUMMARY${NC}"
    echo -e "${BOLD}══════════════════════════════════════════════════════${NC}"
    
    local pass_percentage=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    local overall_status
    
    if [ "$FAILED_CHECKS" -eq 0 ] && [ "$WARNING_CHECKS" -eq 0 ]; then
        overall_status="${GREEN}EXCELLENT${NC}"
    elif [ "$FAILED_CHECKS" -eq 0 ]; then
        overall_status="${YELLOW}GOOD${NC}"
    elif [ "$pass_percentage" -ge 70 ]; then
        overall_status="${YELLOW}DEGRADED${NC}"
    else
        overall_status="${RED}CRITICAL${NC}"
    fi
    
    echo -e "Server: ${BOLD}$SERVER_NAME${NC}"
    echo -e "Time: $(date)"
    echo -e "Overall Status: $overall_status"
    echo ""
    echo -e "Total Checks: ${BOLD}$TOTAL_CHECKS${NC}"
    echo -e "✓ Passed: ${GREEN}$PASSED_CHECKS${NC}"
    echo -e "⚠ Warnings: ${YELLOW}$WARNING_CHECKS${NC}"
    echo -e "✗ Failed: ${RED}$FAILED_CHECKS${NC}"
    echo -e "Success Rate: ${BOLD}${pass_percentage}%${NC}"
    
    # Log summary
    log_message "Status check completed - Passed: $PASSED_CHECKS, Warnings: $WARNING_CHECKS, Failed: $FAILED_CHECKS"
    
    # Send notification if there are issues
    if [ "$FAILED_CHECKS" -gt 0 ] || [ "$WARNING_CHECKS" -gt 5 ]; then
        ALERT_MESSAGE="🚨 Game Server Status Issues

Overall Status: $(echo -e "$overall_status" | sed 's/\\033\[[0-9;]*m//g')
✓ Passed: $PASSED_CHECKS
⚠ Warnings: $WARNING_CHECKS  
✗ Failed: $FAILED_CHECKS
Success Rate: ${pass_percentage}%

🕐 Check Time: $(date +'%Y-%m-%d %H:%M')
🖥️ Server: $SERVER_NAME
📧 Contact: $ADMIN_EMAIL"

        send_ntfy "Status Alert" "$ALERT_MESSAGE" "high" "gaming,status,alert"
    fi
    
    return $FAILED_CHECKS
}

# Main execution function
main() {
    echo -e "${CYAN}🎮 GAME SERVER STATUS CHECKER${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"
    echo -e "Server: $SERVER_NAME"
    echo -e "Time: $(date)"
    echo -e "Maintainer: $ADMIN_EMAIL"
    
    log_message "Starting comprehensive game server status check"
    
    # Run all checks
    check_system_resources
    check_game_services
    check_network
    check_hardware
    check_gaming_setup
    check_backup_status
    
    # Display summary and return appropriate exit code
    if display_summary; then
        echo -e "\n${GREEN}✅ Game server status check completed successfully${NC}"
        log_message "Status check completed successfully - all systems operational"
        return 0
    else
        echo -e "\n${RED}❌ Game server status check found issues${NC}"
        log_message "Status check completed with $FAILED_CHECKS failures and $WARNING_CHECKS warnings"
        return 1
    fi
}

# Handle command line arguments
case "${1:-}" in
    "quick")
        check_system_resources
        check_game_services
        display_summary
        ;;
    "services")
        check_game_services
        check_network
        display_summary
        ;;
    "full")
        main
        ;;
    "help"|"-h"|"--help")
        echo "Game Server Status Checker"
        echo ""
        echo "Usage: $0 [OPTION]"
        echo ""
        echo "Options:"
        echo "  quick       Quick check (system resources and services)"
        echo "  services    Check services and network only"
        echo "  full        Full comprehensive check (default)"
        echo "  help        Show this help message"
        echo ""
        echo "Exit codes:"
        echo "  0 = All checks passed"
        echo "  1 = Some checks failed"
        ;;
    *)
        main
        ;;
esac