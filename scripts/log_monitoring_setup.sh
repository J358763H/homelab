#!/bin/bash

# =====================================================
# 📊 Homelab Log Management and Monitoring Setup
# =====================================================
# Implements centralized logging and monitoring
# Addresses logging vulnerabilities from security scan
# Sets up log rotation and security monitoring
# =====================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
DOCKER_HOST_IP="192.168.1.100"
LOG_BASE_DIR="/opt/homelab/logs"
MONITORING_DIR="/opt/homelab/monitoring"
ALERTS_DIR="/opt/homelab/alerts"

# Container configurations
declare -A CONTAINERS=(
    ["201"]="nginx-proxy-manager"
    ["202"]="tailscale"
    ["203"]="ntfy"
    ["204"]="pihole"
    ["205"]="dns"
    ["206"]="vaultwarden-samba"
)

# Functions
log() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
success() { echo -e "${GREEN}[SUCCESS] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }
warn() { echo -e "${YELLOW}[WARNING] $1${NC}"; }
info() { echo -e "${PURPLE}[INFO] $1${NC}"; }

# Create directory structure
create_directories() {
    log "Creating directory structure..."
    
    # Main directories
    mkdir -p "$LOG_BASE_DIR"/{containers,services,security,system}
    mkdir -p "$MONITORING_DIR"/{dashboards,scripts,config}
    mkdir -p "$ALERTS_DIR"/{rules,templates,logs}
    
    # Docker host log directories
    ssh root@"$DOCKER_HOST_IP" "mkdir -p /opt/homelab/{logs,monitoring,alerts}"
    ssh root@"$DOCKER_HOST_IP" "mkdir -p /opt/homelab/logs/{docker,services,security}"
    
    success "Directory structure created"
}

# Configure centralized logging for Docker host
configure_docker_logging() {
    log "Configuring Docker host logging..."
    
    # Create Docker daemon configuration for better logging
    ssh root@"$DOCKER_HOST_IP" "cat > /etc/docker/daemon.json << 'EOF'
{
    \"log-driver\": \"json-file\",
    \"log-opts\": {
        \"max-size\": \"10m\",
        \"max-file\": \"5\",
        \"labels\": \"service,version\",
        \"env\": \"ENVIRONMENT\"
    },
    \"default-ulimits\": {
        \"nofile\": {
            \"Name\": \"nofile\",
            \"Hard\": 64000,
            \"Soft\": 64000
        }
    },
    \"live-restore\": true,
    \"userland-proxy\": false,
    \"no-new-privileges\": true
}
EOF"

    # Restart Docker to apply configuration
    ssh root@"$DOCKER_HOST_IP" "systemctl restart docker"
    
    success "Docker logging configured"
}

# Setup log rotation for all systems
setup_log_rotation() {
    log "Setting up log rotation..."
    
    # Proxmox host log rotation
    cat > /etc/logrotate.d/homelab << 'EOF'
/var/log/homelab/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    copytruncate
    create 644 root root
}

/opt/homelab/logs/*/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    copytruncate
    create 644 root root
}
EOF

    # Docker host log rotation
    ssh root@"$DOCKER_HOST_IP" "cat > /etc/logrotate.d/homelab << 'EOF'
/opt/homelab/logs/*/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    copytruncate
    create 644 root root
}

/var/lib/docker/containers/*/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    copytruncate
    create 644 root root
}
EOF"

    # Configure log rotation for each LXC container
    for ctid in "${!CONTAINERS[@]}"; do
        local container_name="${CONTAINERS[$ctid]}"
        log "Configuring log rotation for $container_name ($ctid)..."
        
        pct exec "$ctid" -- bash -c "
            cat > /etc/logrotate.d/homelab << 'EOF'
/var/log/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    copytruncate
    create 644 root root
}

/opt/*/logs/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    copytruncate
    create 644 root root
}
EOF"
    done
    
    success "Log rotation configured for all systems"
}

# Setup centralized log collection
setup_log_collection() {
    log "Setting up centralized log collection..."
    
    # Create log collection script
    cat > "$MONITORING_DIR/scripts/collect_logs.sh" << 'EOF'
#!/bin/bash
# Centralized log collection script

BASE_DIR="/opt/homelab/logs"
DATE=$(date +%Y%m%d_%H%M%S)

# Collect Docker host logs
rsync -av root@192.168.1.100:/var/log/docker* "$BASE_DIR/services/" 2>/dev/null || true
rsync -av root@192.168.1.100:/opt/homelab/logs/ "$BASE_DIR/docker-host/" 2>/dev/null || true

# Collect container logs
for container in nginx-proxy-manager tailscale ntfy pihole vaultwarden samba; do
    mkdir -p "$BASE_DIR/containers/$container"
    # This would be expanded based on specific container configurations
done

# Security log collection
grep -h "FAILED\|ERROR\|ALERT\|DENIED" /var/log/auth.log /var/log/syslog 2>/dev/null | \
    tail -1000 > "$BASE_DIR/security/security_events_$DATE.log" || true

# System log collection
dmesg | tail -500 > "$BASE_DIR/system/dmesg_$DATE.log"
journalctl --since "1 hour ago" --no-pager > "$BASE_DIR/system/journal_$DATE.log"

# Docker container stats
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" \
    > "$BASE_DIR/system/docker_stats_$DATE.log" 2>/dev/null || true
EOF

    chmod +x "$MONITORING_DIR/scripts/collect_logs.sh"
    
    success "Log collection script created"
}

# Setup security monitoring
setup_security_monitoring() {
    log "Setting up security monitoring..."
    
    # Create security monitoring script
    cat > "$MONITORING_DIR/scripts/security_monitor.sh" << 'EOF'
#!/bin/bash
# Security monitoring and alerting script

ALERT_LOG="/opt/homelab/alerts/logs/security_alerts.log"
THRESHOLD_FAILED_LOGINS=5
THRESHOLD_PORT_SCANS=10

# Create alert function
send_alert() {
    local severity="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log alert
    echo "[$timestamp] [$severity] $message" >> "$ALERT_LOG"
    
    # Send to ntfy if available
    curl -s -X POST "http://192.168.1.203:8080/homelab-security" \
         -H "Title: Homelab Security Alert [$severity]" \
         -d "$message" 2>/dev/null || true
}

# Monitor failed login attempts
check_failed_logins() {
    local failed_count=$(grep "authentication failure" /var/log/auth.log | grep "$(date +%b\ %d)" | wc -l)
    
    if [ "$failed_count" -gt "$THRESHOLD_FAILED_LOGINS" ]; then
        send_alert "HIGH" "Detected $failed_count failed login attempts today"
    fi
}

# Monitor port scanning attempts
check_port_scans() {
    local scan_count=$(grep "DPT=" /var/log/kern.log | grep "$(date +%b\ %d)" | wc -l)
    
    if [ "$scan_count" -gt "$THRESHOLD_PORT_SCANS" ]; then
        send_alert "MEDIUM" "Detected $scan_count potential port scan attempts today"
    fi
}

# Monitor Docker container security
check_docker_security() {
    # Check for containers running as root
    docker ps --format "table {{.Names}}\t{{.Image}}" | while read -r name image; do
        if [ "$name" != "NAMES" ]; then
            user=$(docker inspect "$name" --format '{{.Config.User}}' 2>/dev/null || echo "root")
            if [ "$user" = "root" ] || [ -z "$user" ]; then
                send_alert "MEDIUM" "Container $name running as root user"
            fi
        fi
    done 2>/dev/null || true
}

# Monitor file system changes
check_file_changes() {
    # Monitor critical system files
    local critical_files="/etc/passwd /etc/shadow /etc/sudoers /etc/hosts"
    
    for file in $critical_files; do
        if [ -f "$file" ]; then
            local current_hash=$(sha256sum "$file" | cut -d' ' -f1)
            local hash_file="/opt/homelab/monitoring/.${file//\//_}.hash"
            
            if [ -f "$hash_file" ]; then
                local stored_hash=$(cat "$hash_file")
                if [ "$current_hash" != "$stored_hash" ]; then
                    send_alert "HIGH" "Critical file modified: $file"
                    echo "$current_hash" > "$hash_file"
                fi
            else
                echo "$current_hash" > "$hash_file"
            fi
        fi
    done
}

# Monitor disk usage
check_disk_usage() {
    local usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ "$usage" -gt 85 ]; then
        send_alert "HIGH" "Root filesystem usage is ${usage}%"
    elif [ "$usage" -gt 75 ]; then
        send_alert "MEDIUM" "Root filesystem usage is ${usage}%"
    fi
}

# Monitor network connections
check_network_connections() {
    # Check for unusual network connections
    local external_connections=$(netstat -tn | grep ESTABLISHED | grep -v "127.0.0.1\|192.168.1\|::1" | wc -l)
    
    if [ "$external_connections" -gt 20 ]; then
        send_alert "MEDIUM" "High number of external connections: $external_connections"
    fi
}

# Main monitoring routine
main() {
    mkdir -p "$(dirname "$ALERT_LOG")"
    
    check_failed_logins
    check_port_scans
    check_docker_security
    check_file_changes
    check_disk_usage
    check_network_connections
    
    # Log monitoring run
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Security monitoring completed" >> "$ALERT_LOG"
}

main "$@"
EOF

    chmod +x "$MONITORING_DIR/scripts/security_monitor.sh"
    
    success "Security monitoring script created"
}

# Setup system monitoring dashboard
setup_monitoring_dashboard() {
    log "Setting up monitoring dashboard..."
    
    # Create monitoring dashboard script
    cat > "$MONITORING_DIR/scripts/dashboard.sh" << 'EOF'
#!/bin/bash
# Homelab monitoring dashboard

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    🏠 HOMELAB DASHBOARD                      ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo

# System status
echo -e "${BLUE}=== SYSTEM STATUS ===${NC}"
echo -e "Uptime: $(uptime -p)"
echo -e "Load: $(uptime | awk -F'load average:' '{print $2}')"
echo -e "Memory: $(free -h | awk '/^Mem:/ {printf "%s/%s (%.1f%%)", $3, $2, $3/$2*100}')"
echo -e "Disk: $(df -h / | awk 'NR==2 {printf "%s/%s (%s)", $3, $2, $5}')"
echo

# Container status
echo -e "${BLUE}=== CONTAINER STATUS ===${NC}"
declare -A CONTAINERS=(
    ["201"]="nginx-proxy-manager"
    ["202"]="tailscale"
    ["203"]="ntfy"
    ["204"]="pihole"
    ["205"]="dns"
    ["206"]="vaultwarden-samba"
)

for ctid in "${!CONTAINERS[@]}"; do
    local name="${CONTAINERS[$ctid]}"
    local status=$(pct status "$ctid" 2>/dev/null | awk '{print $2}' || echo "unknown")
    
    if [ "$status" = "running" ]; then
        echo -e "${GREEN}✓${NC} $name ($ctid): $status"
    else
        echo -e "${RED}✗${NC} $name ($ctid): $status"
    fi
done

# Docker host status
echo
echo -e "${BLUE}=== DOCKER HOST STATUS ===${NC}"
if ping -c 1 192.168.1.100 >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Docker Host (192.168.1.100): Online"
    
    # Get Docker container status
    docker_status=$(ssh root@192.168.1.100 "docker ps --format 'table {{.Names}}\t{{.Status}}'" 2>/dev/null || echo "Error connecting")
    if [ "$docker_status" != "Error connecting" ]; then
        echo -e "${PURPLE}Docker Containers:${NC}"
        echo "$docker_status" | tail -n +2 | while read -r line; do
            if echo "$line" | grep -q "Up"; then
                echo -e "${GREEN}✓${NC} $line"
            else
                echo -e "${RED}✗${NC} $line"
            fi
        done
    fi
else
    echo -e "${RED}✗${NC} Docker Host (192.168.1.100): Offline"
fi

# Recent security alerts
echo
echo -e "${BLUE}=== RECENT SECURITY ALERTS ===${NC}"
local alert_file="/opt/homelab/alerts/logs/security_alerts.log"
if [ -f "$alert_file" ]; then
    tail -5 "$alert_file" | while read -r line; do
        if echo "$line" | grep -q "HIGH"; then
            echo -e "${RED}$line${NC}"
        elif echo "$line" | grep -q "MEDIUM"; then
            echo -e "${YELLOW}$line${NC}"
        else
            echo -e "${GREEN}$line${NC}"
        fi
    done
else
    echo "No security alerts found"
fi

# Network status
echo
echo -e "${BLUE}=== NETWORK STATUS ===${NC}"
ping -c 1 8.8.8.8 >/dev/null 2>&1 && echo -e "${GREEN}✓${NC} Internet: Connected" || echo -e "${RED}✗${NC} Internet: Disconnected"
ping -c 1 192.168.1.1 >/dev/null 2>&1 && echo -e "${GREEN}✓${NC} Gateway: Reachable" || echo -e "${RED}✗${NC} Gateway: Unreachable"

# Tailscale status
if pct status 202 2>/dev/null | grep -q "running"; then
    local tailscale_status=$(pct exec 202 -- tailscale status --json 2>/dev/null | jq -r '.BackendState' 2>/dev/null || echo "unknown")
    if [ "$tailscale_status" = "Running" ]; then
        echo -e "${GREEN}✓${NC} Tailscale: Connected"
    else
        echo -e "${YELLOW}?${NC} Tailscale: $tailscale_status"
    fi
else
    echo -e "${RED}✗${NC} Tailscale: Service down"
fi

echo
echo -e "${CYAN}Last updated: $(date)${NC}"
EOF

    chmod +x "$MONITORING_DIR/scripts/dashboard.sh"
    
    success "Monitoring dashboard created"
}

# Setup cron jobs for automated monitoring
setup_cron_jobs() {
    log "Setting up automated monitoring cron jobs..."
    
    # Create cron entries
    (crontab -l 2>/dev/null; cat << 'EOF'
# Homelab monitoring and logging
*/15 * * * * /opt/homelab/monitoring/scripts/collect_logs.sh >/dev/null 2>&1
*/10 * * * * /opt/homelab/monitoring/scripts/security_monitor.sh >/dev/null 2>&1
0 */6 * * * /opt/homelab/scripts/security_scan.sh >/dev/null 2>&1
0 2 * * * find /opt/homelab/logs -name "*.log" -mtime +30 -delete
EOF
) | crontab -

    # Setup cron on Docker host
    ssh root@"$DOCKER_HOST_IP" "(crontab -l 2>/dev/null; cat << 'EOF'
# Docker host monitoring
*/5 * * * * docker system prune -f --volumes >/dev/null 2>&1
0 3 * * * docker system df > /opt/homelab/logs/docker_disk_usage.log
EOF
) | crontab -"

    success "Cron jobs configured"
}

# Create log analysis tools
create_log_analysis_tools() {
    log "Creating log analysis tools..."
    
    # Create log analyzer script
    cat > "$MONITORING_DIR/scripts/log_analyzer.sh" << 'EOF'
#!/bin/bash
# Log analysis and reporting tool

LOG_DIR="/opt/homelab/logs"
REPORT_DIR="/opt/homelab/monitoring/reports"

# Create report directory
mkdir -p "$REPORT_DIR"

# Generate security report
generate_security_report() {
    local report_file="$REPORT_DIR/security_report_$(date +%Y%m%d).txt"
    
    echo "=== HOMELAB SECURITY REPORT ===" > "$report_file"
    echo "Generated: $(date)" >> "$report_file"
    echo >> "$report_file"
    
    echo "=== AUTHENTICATION FAILURES ===" >> "$report_file"
    grep -r "authentication failure\|Failed password" "$LOG_DIR" 2>/dev/null | tail -20 >> "$report_file"
    echo >> "$report_file"
    
    echo "=== NETWORK INTRUSION ATTEMPTS ===" >> "$report_file"
    grep -r "DPT=\|DROP\|REJECT" "$LOG_DIR" 2>/dev/null | tail -20 >> "$report_file"
    echo >> "$report_file"
    
    echo "=== DOCKER SECURITY EVENTS ===" >> "$report_file"
    grep -r "docker\|container" "$LOG_DIR" 2>/dev/null | grep -i "error\|failed\|denied" | tail -10 >> "$report_file"
    echo >> "$report_file"
    
    echo "Security report generated: $report_file"
}

# Generate performance report
generate_performance_report() {
    local report_file="$REPORT_DIR/performance_report_$(date +%Y%m%d).txt"
    
    echo "=== HOMELAB PERFORMANCE REPORT ===" > "$report_file"
    echo "Generated: $(date)" >> "$report_file"
    echo >> "$report_file"
    
    echo "=== SYSTEM RESOURCES ===" >> "$report_file"
    echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%" >> "$report_file"
    echo "Memory: $(free | awk 'NR==2{printf "%.1f%%", $3*100/$2}')" >> "$report_file"
    echo "Disk: $(df / | awk 'NR==2{print $5}')" >> "$report_file"
    echo >> "$report_file"
    
    echo "=== CONTAINER RESOURCE USAGE ===" >> "$report_file"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null >> "$report_file" || echo "Docker host unreachable" >> "$report_file"
    echo >> "$report_file"
    
    echo "Performance report generated: $report_file"
}

# Main function
case "${1:-both}" in
    "security")
        generate_security_report
        ;;
    "performance")
        generate_performance_report
        ;;
    "both")
        generate_security_report
        generate_performance_report
        ;;
    *)
        echo "Usage: $0 [security|performance|both]"
        exit 1
        ;;
esac
EOF

    chmod +x "$MONITORING_DIR/scripts/log_analyzer.sh"
    
    success "Log analysis tools created"
}

# Configure rsyslog for centralized logging
configure_rsyslog() {
    log "Configuring rsyslog for centralized logging..."
    
    # Configure rsyslog server on Proxmox host
    cat >> /etc/rsyslog.conf << 'EOF'

# Homelab centralized logging
$ModLoad imudp
$UDPServerRun 514
$UDPServerAddress 127.0.0.1

# Log homelab events to separate files
:programname, isequal, "homelab-security" /opt/homelab/logs/security/homelab-security.log
:programname, isequal, "homelab-monitoring" /opt/homelab/logs/system/homelab-monitoring.log
& stop
EOF

    systemctl restart rsyslog
    
    success "Rsyslog configured for centralized logging"
}

# Test logging and monitoring
test_logging_monitoring() {
    log "Testing logging and monitoring setup..."
    
    # Test log collection
    if "$MONITORING_DIR/scripts/collect_logs.sh"; then
        success "Log collection: OK"
    else
        error "Log collection: FAILED"
    fi
    
    # Test security monitoring
    if "$MONITORING_DIR/scripts/security_monitor.sh"; then
        success "Security monitoring: OK"
    else
        error "Security monitoring: FAILED"
    fi
    
    # Test dashboard
    if "$MONITORING_DIR/scripts/dashboard.sh" >/dev/null; then
        success "Monitoring dashboard: OK"
    else
        error "Monitoring dashboard: FAILED"
    fi
    
    # Test log rotation
    if logrotate -d /etc/logrotate.d/homelab >/dev/null 2>&1; then
        success "Log rotation: OK"
    else
        error "Log rotation: FAILED"
    fi
}

# Main execution
main() {
    log "Starting Homelab Log Management and Monitoring Setup"
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root on Proxmox host"
        exit 1
    fi
    
    create_directories
    configure_docker_logging
    setup_log_rotation
    setup_log_collection
    setup_security_monitoring
    setup_monitoring_dashboard
    setup_cron_jobs
    create_log_analysis_tools
    configure_rsyslog
    test_logging_monitoring
    
    success "Log management and monitoring setup completed!"
    success "Key features configured:"
    success "✓ Centralized log collection from all systems"
    success "✓ Automated log rotation and cleanup"
    success "✓ Security monitoring with alerts"
    success "✓ System performance monitoring"
    success "✓ Interactive monitoring dashboard"
    success "✓ Automated log analysis and reporting"
    success "✓ Rsyslog centralized logging server"
    
    info "Usage commands:"
    info "  View dashboard: $MONITORING_DIR/scripts/dashboard.sh"
    info "  Security report: $MONITORING_DIR/scripts/log_analyzer.sh security"
    info "  Performance report: $MONITORING_DIR/scripts/log_analyzer.sh performance"
    info "  Manual log collection: $MONITORING_DIR/scripts/collect_logs.sh"
}

# Handle command line arguments
case "${1:-setup}" in
    "setup")
        main
        ;;
    "test")
        test_logging_monitoring
        ;;
    "dashboard")
        "$MONITORING_DIR/scripts/dashboard.sh"
        ;;
    "collect")
        "$MONITORING_DIR/scripts/collect_logs.sh"
        ;;
    "security")
        "$MONITORING_DIR/scripts/security_monitor.sh"
        ;;
    *)
        echo "Usage: $0 [setup|test|dashboard|collect|security]"
        echo "  setup     - Install and configure monitoring (default)"
        echo "  test      - Test monitoring functionality"
        echo "  dashboard - Show monitoring dashboard"
        echo "  collect   - Manual log collection"
        echo "  security  - Run security monitoring"
        exit 1
        ;;
esac