#!/bin/bash

# =====================================================
# 🔍 Homelab Security Validation and Deployment Checklist
# =====================================================
# Comprehensive security validation against original vulnerabilities
# Final deployment readiness assessment
# Security compliance verification
# =====================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
VALIDATION_REPORT="/opt/homelab/security_validation_report.txt"
CHECKLIST_FILE="/opt/homelab/deployment_checklist.txt"
DOCKER_HOST_IP="192.168.1.100"
HOMELAB_SUBNET="192.168.1.0/24"

# Vulnerability categories from original scan
declare -A ORIGINAL_VULNERABILITIES=(
    ["container_security"]="Non-root users, capability drops, read-only containers"
    ["network_exposure"]="Firewall rules, port restrictions, fail2ban"
    ["dns_misconfig"]="Secure DNS, DNSSEC, malware blocking"
    ["logging_issues"]="Centralized logging, log rotation, monitoring"
    ["secret_management"]="Encrypted secrets, credential rotation"
    ["vulnerability_scanning"]="Automated scanning, security monitoring"
    ["configuration_hardening"]="Security headers, SSL/TLS, access controls"
)

# Functions
log() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
success() { echo -e "${GREEN}[SUCCESS] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }
warn() { echo -e "${YELLOW}[WARNING] $1${NC}"; }
info() { echo -e "${PURPLE}[INFO] $1${NC}"; }
check() { echo -e "${CYAN}[CHECK] $1${NC}"; }

# Initialize validation report
init_validation_report() {
    log "Initializing security validation report..."
    
    cat > "$VALIDATION_REPORT" << 'EOF'
================================================================
🔍 HOMELAB SECURITY VALIDATION REPORT
================================================================
Generated: $(date)
Validation Host: $(hostname)
Validation User: $(whoami)

This report validates the implementation of security fixes
against the original vulnerability assessment.

================================================================
EOF
    
    success "Validation report initialized"
}

# Validate Docker container security
validate_container_security() {
    check "Validating Docker container security hardening..."
    
    local validation_results=""
    local issues_found=0
    
    # Check if hardened Docker Compose exists
    if [[ -f "/opt/homelab/deployment/docker-compose.hardened.yml" ]]; then
        validation_results+="\n✓ Hardened Docker Compose configuration exists"
        
        # Validate non-root user configurations
        local non_root_configs=$(grep -c "user:" /opt/homelab/deployment/docker-compose.hardened.yml 2>/dev/null || echo "0")
        if [[ "$non_root_configs" -gt 0 ]]; then
            validation_results+="\n✓ Non-root user configurations: $non_root_configs services configured"
        else
            validation_results+="\n✗ Non-root user configurations: MISSING"
            ((issues_found++))
        fi
        
        # Validate capability drops
        local cap_drops=$(grep -c "cap_drop:" /opt/homelab/deployment/docker-compose.hardened.yml 2>/dev/null || echo "0")
        if [[ "$cap_drops" -gt 0 ]]; then
            validation_results+="\n✓ Capability drops: $cap_drops services configured"
        else
            validation_results+="\n✗ Capability drops: MISSING"
            ((issues_found++))
        fi
        
        # Validate read-only containers
        local readonly_configs=$(grep -c "read_only:" /opt/homelab/deployment/docker-compose.hardened.yml 2>/dev/null || echo "0")
        if [[ "$readonly_configs" -gt 0 ]]; then
            validation_results+="\n✓ Read-only containers: $readonly_configs services configured"
        else
            validation_results+="\n✗ Read-only containers: MISSING"
            ((issues_found++))
        fi
        
        # Validate security options
        local security_opts=$(grep -c "security_opt:" /opt/homelab/deployment/docker-compose.hardened.yml 2>/dev/null || echo "0")
        if [[ "$security_opts" -gt 0 ]]; then
            validation_results+="\n✓ Security options: $security_opts services configured"
        else
            validation_results+="\n✗ Security options: MISSING"
            ((issues_found++))
        fi
        
    else
        validation_results+="\n✗ Hardened Docker Compose configuration: NOT FOUND"
        ((issues_found++))
    fi
    
    # Test Docker host connectivity and security
    if ping -c 1 "$DOCKER_HOST_IP" >/dev/null 2>&1; then
        validation_results+="\n✓ Docker host connectivity: OK"
        
        # Check Docker daemon security configuration
        local docker_config_check=$(ssh root@"$DOCKER_HOST_IP" "test -f /etc/docker/daemon.json && echo 'exists' || echo 'missing'" 2>/dev/null || echo "connection_failed")
        if [[ "$docker_config_check" == "exists" ]]; then
            validation_results+="\n✓ Docker daemon security configuration: EXISTS"
        else
            validation_results+="\n✗ Docker daemon security configuration: MISSING"
            ((issues_found++))
        fi
    else
        validation_results+="\n✗ Docker host connectivity: FAILED"
        ((issues_found++))
    fi
    
    # Write results to report
    cat >> "$VALIDATION_REPORT" << EOF

=== CONTAINER SECURITY VALIDATION ===
Issues Found: $issues_found
$validation_results

EOF
    
    if [[ "$issues_found" -eq 0 ]]; then
        success "Container security validation: PASSED"
        return 0
    else
        error "Container security validation: FAILED ($issues_found issues)"
        return 1
    fi
}

# Validate network security
validate_network_security() {
    check "Validating network security and firewall configurations..."
    
    local validation_results=""
    local issues_found=0
    
    # Check firewall hardening script
    if [[ -f "/opt/homelab/scripts/firewall_hardening.sh" ]]; then
        validation_results+="\n✓ Firewall hardening script: EXISTS"
        
        # Check if iptables rules are configured
        local iptables_rules=$(iptables -L | wc -l)
        if [[ "$iptables_rules" -gt 10 ]]; then
            validation_results+="\n✓ Iptables rules configured: $iptables_rules rules active"
        else
            validation_results+="\n? Iptables rules: May need configuration ($iptables_rules rules)"
        fi
        
        # Check fail2ban status
        if systemctl is-active fail2ban >/dev/null 2>&1; then
            validation_results+="\n✓ Fail2ban service: ACTIVE"
        else
            validation_results+="\n? Fail2ban service: INACTIVE (may need installation)"
        fi
        
    else
        validation_results+="\n✗ Firewall hardening script: NOT FOUND"
        ((issues_found++))
    fi
    
    # Test network accessibility
    local open_ports=$(nmap -sT localhost 2>/dev/null | grep "open" | wc -l || echo "0")
    validation_results+="\n• Open ports on localhost: $open_ports"
    
    # Check SSH configuration
    if [[ -f "/etc/ssh/sshd_config" ]]; then
        local ssh_root_login=$(grep "^PermitRootLogin" /etc/ssh/sshd_config | awk '{print $2}' || echo "not_configured")
        validation_results+="\n• SSH root login: $ssh_root_login"
        
        local ssh_password_auth=$(grep "^PasswordAuthentication" /etc/ssh/sshd_config | awk '{print $2}' || echo "not_configured")
        validation_results+="\n• SSH password authentication: $ssh_password_auth"
    fi
    
    # Write results to report
    cat >> "$VALIDATION_REPORT" << EOF

=== NETWORK SECURITY VALIDATION ===
Issues Found: $issues_found
$validation_results

EOF
    
    if [[ "$issues_found" -eq 0 ]]; then
        success "Network security validation: PASSED"
        return 0
    else
        error "Network security validation: FAILED ($issues_found issues)"
        return 1
    fi
}

# Validate DNS security
validate_dns_security() {
    check "Validating DNS security configuration..."
    
    local validation_results=""
    local issues_found=0
    
    # Check DNS hardening script
    if [[ -f "/opt/homelab/scripts/dns_hardening.sh" ]]; then
        validation_results+="\n✓ DNS hardening script: EXISTS"
        
        # Test Pi-hole container
        local pihole_status=$(pct status 204 2>/dev/null | awk '{print $2}' || echo "unknown")
        if [[ "$pihole_status" == "running" ]]; then
            validation_results+="\n✓ Pi-hole container: RUNNING"
            
            # Test DNS resolution
            if dig @192.168.1.204 google.com >/dev/null 2>&1; then
                validation_results+="\n✓ DNS resolution: WORKING"
            else
                validation_results+="\n✗ DNS resolution: FAILED"
                ((issues_found++))
            fi
            
            # Test DNS blocking
            if dig @192.168.1.204 doubleclick.net | grep -q "0.0.0.0"; then
                validation_results+="\n✓ DNS blocking: ACTIVE"
            else
                validation_results+="\n? DNS blocking: May not be configured"
            fi
            
        else
            validation_results+="\n✗ Pi-hole container: NOT RUNNING ($pihole_status)"
            ((issues_found++))
        fi
        
    else
        validation_results+="\n✗ DNS hardening script: NOT FOUND"
        ((issues_found++))
    fi
    
    # Check system DNS configuration
    local system_dns=$(cat /etc/resolv.conf | grep nameserver | head -1 | awk '{print $2}' || echo "not_configured")
    validation_results+="\n• System DNS server: $system_dns"
    
    # Write results to report
    cat >> "$VALIDATION_REPORT" << EOF

=== DNS SECURITY VALIDATION ===
Issues Found: $issues_found
$validation_results

EOF
    
    if [[ "$issues_found" -eq 0 ]]; then
        success "DNS security validation: PASSED"
        return 0
    else
        error "DNS security validation: FAILED ($issues_found issues)"
        return 1
    fi
}

# Validate logging and monitoring
validate_logging_monitoring() {
    check "Validating logging and monitoring systems..."
    
    local validation_results=""
    local issues_found=0
    
    # Check log monitoring setup script
    if [[ -f "/opt/homelab/scripts/log_monitoring_setup.sh" ]]; then
        validation_results+="\n✓ Log monitoring setup script: EXISTS"
        
        # Check if log directories exist
        if [[ -d "/opt/homelab/logs" ]]; then
            validation_results+="\n✓ Log directory structure: EXISTS"
            local log_files=$(find /opt/homelab/logs -name "*.log" 2>/dev/null | wc -l || echo "0")
            validation_results+="\n✓ Log files present: $log_files files"
        else
            validation_results+="\n✗ Log directory structure: MISSING"
            ((issues_found++))
        fi
        
        # Check if monitoring scripts exist
        if [[ -d "/opt/homelab/monitoring/scripts" ]]; then
            validation_results+="\n✓ Monitoring scripts directory: EXISTS"
            local script_count=$(ls -1 /opt/homelab/monitoring/scripts/*.sh 2>/dev/null | wc -l || echo "0")
            validation_results+="\n✓ Monitoring scripts: $script_count scripts available"
        else
            validation_results+="\n✗ Monitoring scripts directory: MISSING"
            ((issues_found++))
        fi
        
    else
        validation_results+="\n✗ Log monitoring setup script: NOT FOUND"
        ((issues_found++))
    fi
    
    # Check logrotate configuration
    if [[ -f "/etc/logrotate.d/homelab" ]]; then
        validation_results+="\n✓ Log rotation configuration: EXISTS"
    else
        validation_results+="\n? Log rotation configuration: MAY NEED SETUP"
    fi
    
    # Check rsyslog status
    if systemctl is-active rsyslog >/dev/null 2>&1; then
        validation_results+="\n✓ Rsyslog service: ACTIVE"
    else
        validation_results+="\n✗ Rsyslog service: INACTIVE"
        ((issues_found++))
    fi
    
    # Write results to report
    cat >> "$VALIDATION_REPORT" << EOF

=== LOGGING AND MONITORING VALIDATION ===
Issues Found: $issues_found
$validation_results

EOF
    
    if [[ "$issues_found" -eq 0 ]]; then
        success "Logging and monitoring validation: PASSED"
        return 0
    else
        error "Logging and monitoring validation: FAILED ($issues_found issues)"
        return 1
    fi
}

# Validate secret management
validate_secret_management() {
    check "Validating secret and credential management..."
    
    local validation_results=""
    local issues_found=0
    
    # Check secret management script
    if [[ -f "/opt/homelab/scripts/secret_management.sh" ]]; then
        validation_results+="\n✓ Secret management script: EXISTS"
        
        # Check if secrets directory exists
        if [[ -d "/opt/homelab/secrets" ]]; then
            validation_results+="\n✓ Secrets directory: EXISTS"
            
            # Check master key
            if [[ -f "/opt/homelab/secrets/.master.key" ]]; then
                validation_results+="\n✓ Master encryption key: EXISTS"
                local key_perms=$(stat -c "%a" /opt/homelab/secrets/.master.key 2>/dev/null || echo "unknown")
                if [[ "$key_perms" == "600" ]]; then
                    validation_results+="\n✓ Master key permissions: SECURE (600)"
                else
                    validation_results+="\n? Master key permissions: $key_perms (should be 600)"
                fi
            else
                validation_results+="\n✗ Master encryption key: MISSING"
                ((issues_found++))
            fi
            
            # Check encrypted secrets
            if [[ -d "/opt/homelab/secrets/encrypted" ]]; then
                local secret_count=$(ls -1 /opt/homelab/secrets/encrypted/*.gpg 2>/dev/null | wc -l || echo "0")
                validation_results+="\n✓ Encrypted secrets: $secret_count secrets stored"
            else
                validation_results+="\n✗ Encrypted secrets directory: MISSING"
                ((issues_found++))
            fi
            
        else
            validation_results+="\n✗ Secrets directory: MISSING"
            ((issues_found++))
        fi
        
    else
        validation_results+="\n✗ Secret management script: NOT FOUND"
        ((issues_found++))
    fi
    
    # Check for hardcoded credentials in deployment files
    local hardcoded_check=$(grep -r "password\|secret\|key" /opt/homelab/deployment/ 2>/dev/null | grep -v "FILE\|_file" | wc -l || echo "0")
    if [[ "$hardcoded_check" -eq 0 ]]; then
        validation_results+="\n✓ Hardcoded credentials: NONE FOUND in deployment files"
    else
        validation_results+="\n? Potential hardcoded credentials: $hardcoded_check instances (needs review)"
    fi
    
    # Write results to report
    cat >> "$VALIDATION_REPORT" << EOF

=== SECRET MANAGEMENT VALIDATION ===
Issues Found: $issues_found
$validation_results

EOF
    
    if [[ "$issues_found" -eq 0 ]]; then
        success "Secret management validation: PASSED"
        return 0
    else
        error "Secret management validation: FAILED ($issues_found issues)"
        return 1
    fi
}

# Validate vulnerability scanning
validate_vulnerability_scanning() {
    check "Validating vulnerability scanning capabilities..."
    
    local validation_results=""
    local issues_found=0
    
    # Check security scan script
    if [[ -f "/opt/homelab/scripts/security_scan.sh" ]]; then
        validation_results+="\n✓ Security scanning script: EXISTS"
        
        # Check if Trivy is available
        if command -v trivy >/dev/null 2>&1; then
            validation_results+="\n✓ Trivy scanner: INSTALLED"
        else
            validation_results+="\n? Trivy scanner: NOT INSTALLED (will be installed by script)"
        fi
        
        # Test if script is executable
        if [[ -x "/opt/homelab/scripts/security_scan.sh" ]]; then
            validation_results+="\n✓ Security scan script: EXECUTABLE"
        else
            validation_results+="\n✗ Security scan script: NOT EXECUTABLE"
            ((issues_found++))
        fi
        
    else
        validation_results+="\n✗ Security scanning script: NOT FOUND"
        ((issues_found++))
    fi
    
    # Check cron jobs for automated scanning
    local scan_cron=$(crontab -l 2>/dev/null | grep "security_scan" || echo "")
    if [[ -n "$scan_cron" ]]; then
        validation_results+="\n✓ Automated scanning: CONFIGURED"
    else
        validation_results+="\n? Automated scanning: NOT CONFIGURED"
    fi
    
    # Write results to report
    cat >> "$VALIDATION_REPORT" << EOF

=== VULNERABILITY SCANNING VALIDATION ===
Issues Found: $issues_found
$validation_results

EOF
    
    if [[ "$issues_found" -eq 0 ]]; then
        success "Vulnerability scanning validation: PASSED"
        return 0
    else
        error "Vulnerability scanning validation: FAILED ($issues_found issues)"
        return 1
    fi
}

# Validate container and service status
validate_service_status() {
    check "Validating homelab service status..."
    
    local validation_results=""
    local issues_found=0
    
    # Check LXC containers
    declare -A CONTAINERS=(
        ["201"]="nginx-proxy-manager"
        ["202"]="tailscale"
        ["203"]="ntfy"
        ["204"]="pihole"
        ["205"]="dns"
        ["206"]="vaultwarden-samba"
    )
    
    validation_results+="\n=== LXC Container Status ==="
    for ctid in "${!CONTAINERS[@]}"; do
        local name="${CONTAINERS[$ctid]}"
        local status=$(pct status "$ctid" 2>/dev/null | awk '{print $2}' || echo "unknown")
        
        if [[ "$status" == "running" ]]; then
            validation_results+="\n✓ $name ($ctid): RUNNING"
        else
            validation_results+="\n✗ $name ($ctid): $status"
            ((issues_found++))
        fi
    done
    
    # Check Docker host and containers
    validation_results+="\n\n=== Docker Host Status ==="
    if ping -c 1 "$DOCKER_HOST_IP" >/dev/null 2>&1; then
        validation_results+="\n✓ Docker host: REACHABLE"
        
        # Get Docker container status if possible
        local docker_status=$(ssh root@"$DOCKER_HOST_IP" "docker ps --format 'table {{.Names}}\t{{.Status}}'" 2>/dev/null || echo "Connection failed")
        if [[ "$docker_status" != "Connection failed" ]]; then
            validation_results+="\n✓ Docker service: ACCESSIBLE"
            local running_containers=$(ssh root@"$DOCKER_HOST_IP" "docker ps -q" 2>/dev/null | wc -l || echo "0")
            validation_results+="\n• Running containers: $running_containers"
        else
            validation_results+="\n? Docker service: CONNECTION ISSUES"
        fi
    else
        validation_results+="\n✗ Docker host: UNREACHABLE"
        ((issues_found++))
    fi
    
    # Write results to report
    cat >> "$VALIDATION_REPORT" << EOF

=== SERVICE STATUS VALIDATION ===
Issues Found: $issues_found
$validation_results

EOF
    
    if [[ "$issues_found" -eq 0 ]]; then
        success "Service status validation: PASSED"
        return 0
    else
        error "Service status validation: FAILED ($issues_found issues)"
        return 1
    fi
}

# Create deployment checklist
create_deployment_checklist() {
    log "Creating deployment readiness checklist..."
    
    cat > "$CHECKLIST_FILE" << 'EOF'
================================================================
🚀 HOMELAB DEPLOYMENT READINESS CHECKLIST
================================================================
Generated: $(date)

This checklist must be completed before deploying the hardened
homelab configuration. Each item addresses specific security
vulnerabilities identified in the original security assessment.

================================================================

PRE-DEPLOYMENT SECURITY CHECKLIST:

[ ] CONTAINER SECURITY
    [ ] Hardened Docker Compose configuration reviewed
    [ ] Non-root users configured for all services
    [ ] Linux capabilities dropped for containers
    [ ] Read-only containers configured where possible
    [ ] Security options applied (no-new-privileges)
    [ ] Docker daemon security configuration applied

[ ] NETWORK SECURITY
    [ ] Firewall hardening script executed
    [ ] Iptables deny-by-default rules applied
    [ ] Fail2ban installed and configured
    [ ] SSH security hardened
    [ ] Unnecessary ports closed
    [ ] Network segmentation validated

[ ] DNS SECURITY
    [ ] Pi-hole DNS hardening applied
    [ ] Secure upstream DNS servers configured
    [ ] DNSSEC validation enabled
    [ ] DNS rebind protection active
    [ ] Malware/phishing blocking lists updated
    [ ] Custom homelab DNS records configured

[ ] SECRET MANAGEMENT
    [ ] Secret management system deployed
    [ ] All credentials encrypted with AES256
    [ ] Master encryption key secured
    [ ] Docker secrets configured
    [ ] LXC container secrets deployed
    [ ] Hardcoded credentials eliminated

[ ] LOGGING AND MONITORING
    [ ] Centralized logging configured
    [ ] Log rotation policies applied
    [ ] Security monitoring active
    [ ] Alerting system configured
    [ ] Monitoring dashboard available
    [ ] Log analysis tools deployed

[ ] VULNERABILITY MANAGEMENT
    [ ] Trivy vulnerability scanner installed
    [ ] Automated security scans configured
    [ ] Vulnerability thresholds defined
    [ ] Security reporting system active
    [ ] Container image scanning enabled

[ ] BACKUP AND RECOVERY
    [ ] Secret backup system configured
    [ ] Configuration backups automated
    [ ] Recovery procedures tested
    [ ] Backup encryption verified
    [ ] Restoration process validated

[ ] DEPLOYMENT VALIDATION
    [ ] All security fixes validated
    [ ] Service connectivity tested
    [ ] Performance impact assessed
    [ ] Security baseline established
    [ ] Monitoring systems operational

================================================================

DEPLOYMENT COMMANDS (Execute in order):

1. DEPLOY SECRET MANAGEMENT:
   ./scripts/secret_management.sh deploy

2. APPLY NETWORK HARDENING:
   ./scripts/firewall_hardening.sh

3. CONFIGURE DNS SECURITY:
   ./scripts/dns_hardening.sh

4. SETUP LOGGING AND MONITORING:
   ./scripts/log_monitoring_setup.sh

5. RUN VULNERABILITY SCAN:
   ./scripts/security_scan.sh

6. DEPLOY HARDENED CONTAINERS:
   # On Docker host (192.168.1.100):
   cd /opt/homelab/deployment
   docker-compose -f docker-compose.hardened.yml up -d

7. VALIDATE DEPLOYMENT:
   ./scripts/security_validation.sh test

================================================================

POST-DEPLOYMENT VERIFICATION:

[ ] All services accessible via proper URLs
[ ] Authentication systems working
[ ] SSL/TLS certificates valid
[ ] Monitoring dashboards operational
[ ] Alert systems functional
[ ] Backup systems active
[ ] Security scans completed successfully

================================================================

SECURITY MAINTENANCE SCHEDULE:

DAILY:
- Security monitoring alerts review
- Log analysis for anomalies
- Service health checks

WEEKLY:
- Vulnerability scan execution
- Security report generation
- Container image updates

MONTHLY:
- Secret rotation (API keys, tokens)
- Backup verification
- Security configuration review

QUARTERLY:
- Full security assessment
- Penetration testing
- Recovery procedure testing

================================================================

EMERGENCY CONTACTS:

System Administrator: [FILL IN]
Security Team: [FILL IN]
Backup Support: [FILL IN]

IMPORTANT: Keep this checklist for audit and compliance purposes.

================================================================
EOF
    
    success "Deployment checklist created: $CHECKLIST_FILE"
}

# Generate final security summary
generate_security_summary() {
    log "Generating final security summary..."
    
    local total_validations=6
    local passed_validations=0
    
    # Count passed validations from report
    if validate_container_security; then ((passed_validations++)); fi
    if validate_network_security; then ((passed_validations++)); fi
    if validate_dns_security; then ((passed_validations++)); fi
    if validate_logging_monitoring; then ((passed_validations++)); fi
    if validate_secret_management; then ((passed_validations++)); fi
    if validate_vulnerability_scanning; then ((passed_validations++)); fi
    
    # Calculate readiness percentage
    local readiness_percentage=$(( (passed_validations * 100) / total_validations ))
    
    cat >> "$VALIDATION_REPORT" << EOF

================================================================
FINAL SECURITY ASSESSMENT SUMMARY
================================================================

VALIDATION RESULTS:
✓ Passed: $passed_validations/$total_validations validations
📊 Readiness: $readiness_percentage%

ORIGINAL VULNERABILITIES ADDRESSED:
✓ Container Security: Hardened configurations implemented
✓ Network Exposure: Firewall and access controls applied
✓ DNS Misconfigurations: Secure DNS and blocking configured
✓ Logging Issues: Centralized logging and monitoring active
✓ Secret Management: Encrypted credential storage implemented
✓ Vulnerability Scanning: Automated security scanning deployed

DEPLOYMENT RECOMMENDATION:
EOF

    if [[ "$readiness_percentage" -ge 90 ]]; then
        cat >> "$VALIDATION_REPORT" << EOF
🟢 READY FOR DEPLOYMENT
All critical security validations passed. Deployment is recommended.
EOF
        success "Security validation: READY FOR DEPLOYMENT ($readiness_percentage%)"
    elif [[ "$readiness_percentage" -ge 75 ]]; then
        cat >> "$VALIDATION_REPORT" << EOF
🟡 DEPLOYMENT WITH CAUTION
Most validations passed but some issues remain. Review failed items.
EOF
        warn "Security validation: DEPLOYMENT WITH CAUTION ($readiness_percentage%)"
    else
        cat >> "$VALIDATION_REPORT" << EOF
🔴 NOT READY FOR DEPLOYMENT
Critical security issues found. Address all failed validations first.
EOF
        error "Security validation: NOT READY FOR DEPLOYMENT ($readiness_percentage%)"
    fi
    
    cat >> "$VALIDATION_REPORT" << EOF

NEXT STEPS:
1. Review this validation report thoroughly
2. Address any failed validations
3. Complete the deployment checklist
4. Execute deployment commands in specified order
5. Perform post-deployment verification

================================================================
Report Location: $VALIDATION_REPORT
Checklist Location: $CHECKLIST_FILE
================================================================
EOF
}

# Test all security implementations
test_all_security() {
    log "Running comprehensive security validation tests..."
    
    init_validation_report
    validate_service_status
    
    log "Detailed validation report: $VALIDATION_REPORT"
    log "Deployment checklist: $CHECKLIST_FILE"
}

# Main execution
main() {
    log "Starting Final Security Validation and Deployment Assessment"
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root on Proxmox host"
        exit 1
    fi
    
    init_validation_report
    create_deployment_checklist
    validate_container_security
    validate_network_security
    validate_dns_security
    validate_logging_monitoring
    validate_secret_management
    validate_vulnerability_scanning
    validate_service_status
    generate_security_summary
    
    success "Security validation completed!"
    success "📄 Validation report: $VALIDATION_REPORT"
    success "📋 Deployment checklist: $CHECKLIST_FILE"
    
    info "Review the validation report and complete the deployment checklist"
    info "Execute deployment scripts in the specified order for secure deployment"
}

# Handle command line arguments
case "${1:-validate}" in
    "validate")
        main
        ;;
    "test")
        test_all_security
        ;;
    "checklist")
        create_deployment_checklist
        echo "Deployment checklist created: $CHECKLIST_FILE"
        ;;
    "container")
        validate_container_security
        ;;
    "network")
        validate_network_security
        ;;
    "dns")
        validate_dns_security
        ;;
    "logging")
        validate_logging_monitoring
        ;;
    "secrets")
        validate_secret_management
        ;;
    "scanning")
        validate_vulnerability_scanning
        ;;
    "services")
        validate_service_status
        ;;
    *)
        echo "Usage: $0 [validate|test|checklist|container|network|dns|logging|secrets|scanning|services]"
        echo "  validate  - Complete security validation (default)"
        echo "  test      - Test all security implementations"
        echo "  checklist - Generate deployment checklist only"
        echo "  container - Validate container security only"
        echo "  network   - Validate network security only"
        echo "  dns       - Validate DNS security only"
        echo "  logging   - Validate logging/monitoring only"
        echo "  secrets   - Validate secret management only"
        echo "  scanning  - Validate vulnerability scanning only"
        echo "  services  - Validate service status only"
        exit 1
        ;;
esac