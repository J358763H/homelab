#!/usr/bin/env bash
# =====================================================
# 🔍 Homelab Deployment Validation Script
# =====================================================
# Maintainer: J35867U
# Email: mrnash404@protonmail.com
# Created: 2025-10-14
# 
# Comprehensive validation of homelab deployment
# including LXC containers, Docker services, and
# network connectivity testing
# =====================================================

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
VALIDATION_REPORT="/tmp/homelab_validation_$(date +%Y%m%d_%H%M%S).html"
DOCKER_HOST="192.168.1.100"

# Counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNING=0

# Functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[✅ PASS]${NC} $1"
    ((TESTS_PASSED++))
}

fail() {
    echo -e "${RED}[❌ FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

warning() {
    echo -e "${YELLOW}[⚠️  WARN]${NC} $1"
    ((TESTS_WARNING++))
}

test_section() {
    echo -e "${PURPLE}▶️  $1${NC}"
    echo "----------------------------------------"
}

# Initialize HTML report
init_html_report() {
    cat > "$VALIDATION_REPORT" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Homelab Validation Report</title>
    <style>
        body { font-family: 'Courier New', monospace; margin: 20px; background: #1a1a1a; color: #00ff00; }
        .header { text-align: center; border-bottom: 2px solid #00ff00; padding-bottom: 20px; }
        .section { margin: 20px 0; }
        .pass { color: #00ff00; }
        .fail { color: #ff0000; }
        .warn { color: #ffff00; }
        .info { color: #00ffff; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { border: 1px solid #333; padding: 8px; text-align: left; }
        th { background: #333; }
        .status-ok { background: #004400; }
        .status-error { background: #440000; }
        .status-warning { background: #444400; }
        pre { background: #222; padding: 10px; border-left: 3px solid #00ff00; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🏠 HOMELAB VALIDATION REPORT</h1>
        <p>Generated: $(date)</p>
        <p>Primary Server: 192.168.1.50 | Docker Host: 192.168.1.100</p>
    </div>
EOF
}

# Add to HTML report
add_to_report() {
    echo "$1" >> "$VALIDATION_REPORT"
}

# Test Proxmox host status
test_proxmox_host() {
    test_section "Testing Proxmox Host Status"
    
    add_to_report '<div class="section"><h2>🖥️ Proxmox Host Status</h2><table>'
    add_to_report '<tr><th>Component</th><th>Status</th><th>Details</th></tr>'
    
    # Check Proxmox services
    if systemctl is-active pve-cluster >/dev/null 2>&1; then
        success "Proxmox cluster service is running"
        add_to_report '<tr class="status-ok"><td>PVE Cluster</td><td class="pass">Running</td><td>Active</td></tr>'
    else
        fail "Proxmox cluster service is not running"
        add_to_report '<tr class="status-error"><td>PVE Cluster</td><td class="fail">Stopped</td><td>Inactive</td></tr>'
    fi
    
    # Check storage
    local storage_usage=$(df -h / | awk 'NR==2{print $5}' | sed 's/%//')
    if [[ $storage_usage -lt 80 ]]; then
        success "Root storage usage: ${storage_usage}%"
        add_to_report "<tr class=\"status-ok\"><td>Root Storage</td><td class=\"pass\">${storage_usage}%</td><td>Available</td></tr>"
    else
        warning "Root storage usage high: ${storage_usage}%"
        add_to_report "<tr class=\"status-warning\"><td>Root Storage</td><td class=\"warn\">${storage_usage}%</td><td>High Usage</td></tr>"
    fi
    
    # Check memory
    local mem_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    if [[ $mem_usage -lt 85 ]]; then
        success "Memory usage: ${mem_usage}%"
        add_to_report "<tr class=\"status-ok\"><td>Memory</td><td class=\"pass\">${mem_usage}%</td><td>Available</td></tr>"
    else
        warning "Memory usage high: ${mem_usage}%"
        add_to_report "<tr class=\"status-warning\"><td>Memory</td><td class=\"warn\">${mem_usage}%</td><td>High Usage</td></tr>"
    fi
    
    add_to_report '</table></div>'
    echo ""
}

# Test LXC containers
test_lxc_containers() {
    test_section "Testing LXC Containers"
    
    add_to_report '<div class="section"><h2>📦 LXC Container Status</h2><table>'
    add_to_report '<tr><th>VMID</th><th>Name</th><th>Status</th><th>IP Address</th><th>Service</th></tr>'
    
    declare -A LXC_SERVICES=(
        ["201"]="nginx-proxy-manager"
        ["202"]="tailscale"
        ["203"]="ntfy"
        ["204"]="samba"
        ["205"]="pihole"
        ["206"]="vaultwarden"
    )
    
    for vmid in "${!LXC_SERVICES[@]}"; do
        service="${LXC_SERVICES[$vmid]}"
        expected_ip="192.168.1.${vmid}"
        
        # Check container status
        if pct status "$vmid" 2>/dev/null | grep -q "running"; then
            success "LXC $vmid ($service) is running"
            
            # Test network connectivity
            if ping -c 1 -W 2 "$expected_ip" >/dev/null 2>&1; then
                success "LXC $vmid network connectivity OK"
                add_to_report "<tr class=\"status-ok\"><td>$vmid</td><td>$service</td><td class=\"pass\">Running</td><td>$expected_ip</td><td>Active</td></tr>"
            else
                fail "LXC $vmid network connectivity failed"
                add_to_report "<tr class=\"status-error\"><td>$vmid</td><td>$service</td><td class=\"fail\">Network Issue</td><td>$expected_ip</td><td>No Response</td></tr>"
            fi
        else
            fail "LXC $vmid ($service) is not running"
            add_to_report "<tr class=\"status-error\"><td>$vmid</td><td>$service</td><td class=\"fail\">Stopped</td><td>$expected_ip</td><td>Inactive</td></tr>"
        fi
    done
    
    add_to_report '</table></div>'
    echo ""
}

# Test Docker services
test_docker_services() {
    test_section "Testing Docker Services"
    
    add_to_report '<div class="section"><h2>🐳 Docker Service Status</h2>'
    
    # Check if Docker host is reachable
    if ! ping -c 1 -W 2 "$DOCKER_HOST" >/dev/null 2>&1; then
        fail "Docker host ($DOCKER_HOST) is not reachable"
        add_to_report '<p class="fail">❌ Docker host not reachable</p>'
        return 1
    fi
    
    success "Docker host ($DOCKER_HOST) is reachable"
    
    # Get Docker service status
    add_to_report '<table><tr><th>Service</th><th>Status</th><th>Port</th><th>Health</th></tr>'
    
    # Check if Docker is running on the host
    if pct exec 100 -- docker --version >/dev/null 2>&1; then
        success "Docker is installed on host"
        
        # Get service status from docker-compose
        local docker_status
        docker_status=$(pct exec 100 -- bash -c "cd /opt/homelab 2>/dev/null && docker-compose ps --format json 2>/dev/null" | head -20)
        
        if [[ -n "$docker_status" ]]; then
            success "Docker Compose stack is deployed"
            add_to_report '<tr class="status-ok"><td>Docker Compose</td><td class="pass">Active</td><td>Multiple</td><td>Running</td></tr>'
        else
            warning "Docker Compose stack status unknown"
            add_to_report '<tr class="status-warning"><td>Docker Compose</td><td class="warn">Unknown</td><td>Multiple</td><td>Check Required</td></tr>'
        fi
    else
        fail "Docker is not installed on host"
        add_to_report '<tr class="status-error"><td>Docker Engine</td><td class="fail">Not Installed</td><td>N/A</td><td>Missing</td></tr>'
    fi
    
    add_to_report '</table></div>'
    echo ""
}

# Test service endpoints
test_service_endpoints() {
    test_section "Testing Service Endpoints"
    
    add_to_report '<div class="section"><h2>🌐 Service Endpoint Tests</h2><table>'
    add_to_report '<tr><th>Service</th><th>URL</th><th>Status</th><th>Response Time</th></tr>'
    
    declare -A SERVICE_ENDPOINTS=(
        ["Jellyfin"]="http://192.168.1.100:8096"
        ["Sonarr"]="http://192.168.1.100:8989"
        ["Radarr"]="http://192.168.1.100:7878"
        ["Prowlarr"]="http://192.168.1.100:9696"
        ["qBittorrent"]="http://192.168.1.100:8080"
        ["Nginx Proxy Manager"]="http://192.168.1.201:81"
        ["Pi-hole Admin"]="http://192.168.1.205/admin/"
        ["Vaultwarden"]="http://192.168.1.206"
    )
    
    for service in "${!SERVICE_ENDPOINTS[@]}"; do
        url="${SERVICE_ENDPOINTS[$service]}"
        
        # Test HTTP response
        local response_time
        response_time=$(curl -o /dev/null -s -w "%{time_total}" --connect-timeout 5 "$url" 2>/dev/null || echo "timeout")
        
        if [[ "$response_time" != "timeout" ]] && [[ "$response_time" != "000.000" ]]; then
            success "$service is responding (${response_time}s)"
            add_to_report "<tr class=\"status-ok\"><td>$service</td><td>$url</td><td class=\"pass\">OK</td><td>${response_time}s</td></tr>"
        else
            fail "$service is not responding"
            add_to_report "<tr class=\"status-error\"><td>$service</td><td>$url</td><td class=\"fail\">No Response</td><td>Timeout</td></tr>"
        fi
    done
    
    add_to_report '</table></div>'
    echo ""
}

# Test network connectivity
test_network_connectivity() {
    test_section "Testing Network Connectivity"
    
    add_to_report '<div class="section"><h2>🌐 Network Connectivity</h2><table>'
    add_to_report '<tr><th>Target</th><th>IP Address</th><th>Status</th><th>Latency</th></tr>'
    
    declare -A NETWORK_TARGETS=(
        ["Gateway"]="192.168.1.1"
        ["Primary Server"]="192.168.1.50"
        ["Docker Host"]="192.168.1.100"
        ["Pi-hole"]="192.168.1.205"
        ["Google DNS"]="8.8.8.8"
        ["Cloudflare DNS"]="1.1.1.1"
    )
    
    for target in "${!NETWORK_TARGETS[@]}"; do
        ip="${NETWORK_TARGETS[$target]}"
        
        # Test ping with timing
        local ping_result
        ping_result=$(ping -c 1 -W 2 "$ip" 2>/dev/null | grep "time=" | sed 's/.*time=\([0-9.]*\).*/\1/' || echo "fail")
        
        if [[ "$ping_result" != "fail" ]]; then
            success "$target ($ip) - ${ping_result}ms"
            add_to_report "<tr class=\"status-ok\"><td>$target</td><td>$ip</td><td class=\"pass\">Reachable</td><td>${ping_result}ms</td></tr>"
        else
            fail "$target ($ip) - unreachable"
            add_to_report "<tr class=\"status-error\"><td>$target</td><td>$ip</td><td class=\"fail\">Unreachable</td><td>N/A</td></tr>"
        fi
    done
    
    add_to_report '</table></div>'
    echo ""
}

# Test DNS resolution
test_dns_resolution() {
    test_section "Testing DNS Resolution"
    
    add_to_report '<div class="section"><h2>🔍 DNS Resolution Tests</h2><table>'
    add_to_report '<tr><th>Domain</th><th>DNS Server</th><th>Status</th><th>IP Resolved</th></tr>'
    
    local dns_servers=("192.168.1.205" "8.8.8.8" "1.1.1.1")
    local test_domains=("google.com" "github.com" "docker.io")
    
    for dns in "${dns_servers[@]}"; do
        for domain in "${test_domains[@]}"; do
            local resolved_ip
            resolved_ip=$(nslookup "$domain" "$dns" 2>/dev/null | grep "Address:" | tail -1 | awk '{print $2}' || echo "failed")
            
            if [[ "$resolved_ip" != "failed" ]] && [[ -n "$resolved_ip" ]]; then
                success "DNS resolution: $domain via $dns -> $resolved_ip"
                add_to_report "<tr class=\"status-ok\"><td>$domain</td><td>$dns</td><td class=\"pass\">Resolved</td><td>$resolved_ip</td></tr>"
            else
                fail "DNS resolution failed: $domain via $dns"
                add_to_report "<tr class=\"status-error\"><td>$domain</td><td>$dns</td><td class=\"fail\">Failed</td><td>N/A</td></tr>"
            fi
        done
    done
    
    add_to_report '</table></div>'
    echo ""
}

# Test storage and resources
test_storage_resources() {
    test_section "Testing Storage and Resources"
    
    add_to_report '<div class="section"><h2>💾 Storage and Resource Status</h2>'
    
    # Check ZFS if available
    if command -v zpool >/dev/null 2>&1; then
        if zpool status homelab-storage >/dev/null 2>&1; then
            local zfs_health
            zfs_health=$(zpool status homelab-storage | grep "state:" | awk '{print $2}')
            
            if [[ "$zfs_health" == "ONLINE" ]]; then
                success "ZFS pool 'homelab-storage' is healthy"
                add_to_report '<p class="pass">✅ ZFS Pool: homelab-storage is ONLINE</p>'
            else
                fail "ZFS pool 'homelab-storage' health: $zfs_health"
                add_to_report "<p class=\"fail\">❌ ZFS Pool: homelab-storage is $zfs_health</p>"
            fi
        else
            warning "ZFS pool 'homelab-storage' not found"
            add_to_report '<p class="warn">⚠️ ZFS Pool: homelab-storage not configured</p>'
        fi
    else
        warning "ZFS not available"
        add_to_report '<p class="warn">⚠️ ZFS: Not installed</p>'
    fi
    
    # Check disk space
    add_to_report '<h3>Disk Usage:</h3><pre>'
    df -h | head -10 | while read line; do
        add_to_report "$line"
    done
    add_to_report '</pre></div>'
    
    echo ""
}

# Generate final report summary
finalize_report() {
    local total_tests=$((TESTS_PASSED + TESTS_FAILED + TESTS_WARNING))
    local pass_rate=0
    
    if [[ $total_tests -gt 0 ]]; then
        pass_rate=$(( (TESTS_PASSED * 100) / total_tests ))
    fi
    
    add_to_report '<div class="section">'
    add_to_report '<h2>📊 Validation Summary</h2>'
    add_to_report '<table>'
    add_to_report "<tr><th>Total Tests</th><td>$total_tests</td></tr>"
    add_to_report "<tr class=\"status-ok\"><th>Passed</th><td>$TESTS_PASSED</td></tr>"
    add_to_report "<tr class=\"status-error\"><th>Failed</th><td>$TESTS_FAILED</td></tr>"
    add_to_report "<tr class=\"status-warning\"><th>Warnings</th><td>$TESTS_WARNING</td></tr>"
    add_to_report "<tr><th>Pass Rate</th><td>${pass_rate}%</td></tr>"
    add_to_report '</table>'
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        add_to_report '<h3 class="pass">🎉 DEPLOYMENT VALIDATION SUCCESSFUL!</h3>'
        add_to_report '<p>Your homelab is ready for production use.</p>'
    elif [[ $TESTS_FAILED -lt 3 ]]; then
        add_to_report '<h3 class="warn">⚠️ DEPLOYMENT MOSTLY SUCCESSFUL</h3>'
        add_to_report '<p>Some minor issues detected. Review failed tests above.</p>'
    else
        add_to_report '<h3 class="fail">❌ DEPLOYMENT NEEDS ATTENTION</h3>'
        add_to_report '<p>Multiple critical issues detected. Please resolve before proceeding.</p>'
    fi
    
    add_to_report '</div>'
    add_to_report '</body></html>'
    
    # Console summary
    echo ""
    echo "=========================================="
    echo "📊 VALIDATION SUMMARY"
    echo "=========================================="
    echo "Total Tests: $total_tests"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    echo -e "Warnings: ${YELLOW}$TESTS_WARNING${NC}"
    echo "Pass Rate: ${pass_rate}%"
    echo ""
    echo "📄 Detailed report: $VALIDATION_REPORT"
    echo "=========================================="
}

# Main execution
main() {
    echo "=========================================="
    echo "🔍 HOMELAB DEPLOYMENT VALIDATION"
    echo "=========================================="
    echo ""
    
    init_html_report
    
    test_proxmox_host
    test_lxc_containers
    test_docker_services
    test_service_endpoints
    test_network_connectivity
    test_dns_resolution
    test_storage_resources
    
    finalize_report
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        success "All critical tests passed! 🎉"
        exit 0
    else
        error "Some tests failed. Check the report for details."
        exit 1
    fi
}

# Execute main function
main "$@"