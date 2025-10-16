#!/bin/bash

# =====================================================
# 🔍 Homelab Security Vulnerability Scanner
# =====================================================
# Automated vulnerability scanning using Trivy
# Addresses critical security issues from bug scan
# =====================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCAN_RESULTS_DIR="/var/log/homelab/security-scans"
TRIVY_CACHE_DIR="/opt/homelab/trivy-cache"
CRITICAL_THRESHOLD=1
HIGH_THRESHOLD=5

# Functions
log() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
success() { echo -e "${GREEN}[SUCCESS] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }
warn() { echo -e "${YELLOW}[WARNING] $1${NC}"; }

# Ensure directories exist
setup_directories() {
    log "Setting up scan directories..."
    mkdir -p "$SCAN_RESULTS_DIR"
    mkdir -p "$TRIVY_CACHE_DIR"
    chmod 755 "$SCAN_RESULTS_DIR" "$TRIVY_CACHE_DIR"
}

# Install Trivy if not present
install_trivy() {
    if ! command -v trivy >/dev/null 2>&1; then
        log "Installing Trivy vulnerability scanner..."
        
        # Install Trivy
        curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
        
        if command -v trivy >/dev/null 2>&1; then
            success "Trivy installed successfully"
        else
            error "Failed to install Trivy"
            exit 1
        fi
    else
        log "Trivy already installed"
    fi
}

# Scan Docker images for vulnerabilities
scan_docker_images() {
    log "Scanning Docker images for vulnerabilities..."
    
    local scan_date=$(date +%Y%m%d_%H%M%S)
    local report_file="$SCAN_RESULTS_DIR/docker_scan_$scan_date.json"
    local summary_file="$SCAN_RESULTS_DIR/docker_scan_summary_$scan_date.txt"
    
    # Get list of running containers
    local containers=$(docker ps --format "{{.Image}}" | sort -u)
    
    if [[ -z "$containers" ]]; then
        warn "No running Docker containers found"
        return 0
    fi
    
    local total_critical=0
    local total_high=0
    local total_medium=0
    local total_low=0
    
    echo "Docker Image Vulnerability Scan Summary - $(date)" > "$summary_file"
    echo "=================================================" >> "$summary_file"
    echo >> "$summary_file"
    
    while IFS= read -r image; do
        log "Scanning image: $image"
        
        local image_report="$SCAN_RESULTS_DIR/$(echo "$image" | tr '/' '_' | tr ':' '_')_$scan_date.json"
        
        # Scan image and save results
        if trivy image --format json --output "$image_report" "$image" 2>/dev/null; then
            # Extract vulnerability counts
            local critical=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' "$image_report" 2>/dev/null || echo "0")
            local high=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="HIGH")] | length' "$image_report" 2>/dev/null || echo "0")
            local medium=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="MEDIUM")] | length' "$image_report" 2>/dev/null || echo "0")
            local low=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="LOW")] | length' "$image_report" 2>/dev/null || echo "0")
            
            # Update totals
            total_critical=$((total_critical + critical))
            total_high=$((total_high + high))
            total_medium=$((total_medium + medium))
            total_low=$((total_low + low))
            
            # Add to summary
            echo "Image: $image" >> "$summary_file"
            echo "  Critical: $critical" >> "$summary_file"
            echo "  High: $high" >> "$summary_file"
            echo "  Medium: $medium" >> "$summary_file"
            echo "  Low: $low" >> "$summary_file"
            echo >> "$summary_file"
            
            # Log results
            if [[ $critical -gt 0 ]]; then
                error "Image $image has $critical CRITICAL vulnerabilities"
            elif [[ $high -gt 0 ]]; then
                warn "Image $image has $high HIGH vulnerabilities"
            else
                success "Image $image has no critical/high vulnerabilities"
            fi
        else
            error "Failed to scan image: $image"
            echo "Image: $image - SCAN FAILED" >> "$summary_file"
            echo >> "$summary_file"
        fi
    done <<< "$containers"
    
    # Add totals to summary
    echo "TOTAL VULNERABILITIES:" >> "$summary_file"
    echo "Critical: $total_critical" >> "$summary_file"
    echo "High: $total_high" >> "$summary_file"
    echo "Medium: $total_medium" >> "$summary_file"
    echo "Low: $total_low" >> "$summary_file"
    
    # Check thresholds and exit with appropriate code
    if [[ $total_critical -gt $CRITICAL_THRESHOLD ]]; then
        error "CRITICAL: Found $total_critical critical vulnerabilities (threshold: $CRITICAL_THRESHOLD)"
        error "Review scan results: $summary_file"
        return 2
    elif [[ $total_high -gt $HIGH_THRESHOLD ]]; then
        warn "WARNING: Found $total_high high vulnerabilities (threshold: $HIGH_THRESHOLD)"
        warn "Review scan results: $summary_file"
        return 1
    else
        success "Vulnerability scan passed - no critical issues found"
        success "Scan results: $summary_file"
        return 0
    fi
}

# Scan configuration files
scan_config_files() {
    log "Scanning configuration files..."
    
    local scan_date=$(date +%Y%m%d_%H%M%S)
    local config_report="$SCAN_RESULTS_DIR/config_scan_$scan_date.txt"
    
    echo "Configuration Security Scan - $(date)" > "$config_report"
    echo "=======================================" >> "$config_report"
    echo >> "$config_report"
    
    # Scan Docker Compose files
    find /opt/homelab -name "docker-compose*.yml" -type f | while read -r compose_file; do
        log "Scanning Docker Compose file: $compose_file"
        echo "File: $compose_file" >> "$config_report"
        
        if trivy config --format table "$compose_file" >> "$config_report" 2>&1; then
            success "Scanned $compose_file"
        else
            warn "Issues found in $compose_file"
        fi
        echo >> "$config_report"
    done
    
    # Scan for hardcoded secrets
    log "Scanning for hardcoded secrets..."
    echo "HARDCODED SECRETS SCAN:" >> "$config_report"
    echo "======================" >> "$config_report"
    
    # Use grep to find potential secrets
    find /opt/homelab -type f \( -name "*.yml" -o -name "*.yaml" -o -name "*.env" -o -name "*.sh" \) -exec grep -Hn -E "(password|secret|key|token).*=" {} \; 2>/dev/null >> "$config_report" || true
    
    success "Configuration scan completed: $config_report"
}

# Generate security report
generate_security_report() {
    log "Generating comprehensive security report..."
    
    local report_date=$(date +%Y%m%d_%H%M%S)
    local security_report="$SCAN_RESULTS_DIR/security_report_$report_date.txt"
    
    {
        echo "HOMELAB SECURITY REPORT"
        echo "======================="
        echo "Generated: $(date)"
        echo "Host: $(hostname)"
        echo
        
        echo "SYSTEM INFORMATION:"
        echo "==================="
        echo "OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")"
        echo "Kernel: $(uname -r)"
        echo "Docker Version: $(docker --version 2>/dev/null || echo "Not installed")"
        echo "Container Count: $(docker ps -q | wc -l 2>/dev/null || echo "0")"
        echo
        
        echo "NETWORK CONFIGURATION:"
        echo "======================"
        echo "Open Ports:"
        netstat -tuln 2>/dev/null | grep LISTEN || echo "netstat not available"
        echo
        
        echo "Docker Networks:"
        docker network ls 2>/dev/null || echo "Docker not available"
        echo
        
        echo "RECENT SCAN RESULTS:"
        echo "===================="
        
        # Include latest scan summaries
        local latest_docker_scan=$(ls -t "$SCAN_RESULTS_DIR"/docker_scan_summary_*.txt 2>/dev/null | head -1)
        if [[ -n "$latest_docker_scan" ]]; then
            echo "Latest Docker Scan:"
            cat "$latest_docker_scan"
            echo
        fi
        
        echo "RECOMMENDATIONS:"
        echo "================"
        echo "1. Update all containers with critical/high vulnerabilities"
        echo "2. Review and rotate any hardcoded secrets found"
        echo "3. Implement network segmentation for sensitive services"
        echo "4. Enable automated vulnerability scanning in CI/CD"
        echo "5. Set up log monitoring and alerting"
        echo
        
    } > "$security_report"
    
    success "Security report generated: $security_report"
}

# Main execution
main() {
    log "Starting Homelab Security Scan"
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root for complete system access"
        exit 1
    fi
    
    setup_directories
    install_trivy
    
    local exit_code=0
    
    # Run scans
    if ! scan_docker_images; then
        exit_code=$?
    fi
    
    scan_config_files
    generate_security_report
    
    if [[ $exit_code -eq 0 ]]; then
        success "Security scan completed successfully"
    elif [[ $exit_code -eq 1 ]]; then
        warn "Security scan completed with warnings"
    else
        error "Security scan found critical issues"
    fi
    
    log "Scan results available in: $SCAN_RESULTS_DIR"
    exit $exit_code
}

# Handle command line arguments
case "${1:-scan}" in
    "scan")
        main
        ;;
    "install")
        setup_directories
        install_trivy
        ;;
    "report")
        generate_security_report
        ;;
    *)
        echo "Usage: $0 [scan|install|report]"
        echo "  scan    - Run full security scan (default)"
        echo "  install - Install Trivy scanner only"
        echo "  report  - Generate security report only"
        exit 1
        ;;
esac