#!/bin/bash

# 🔍 Pre-Deployment Validation Script
# Comprehensive check for files that need configuration before deployment

set -euo pipefail

# 🎨 Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# 📋 Configuration
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_DIR="$REPO_ROOT/deployment"
LXC_DIR="$REPO_ROOT/lxc"

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

print_header() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}================================${NC}"
}

print_section() {
    echo -e "\n${BLUE}📋 $1${NC}"
    echo -e "${BLUE}$(printf '=%.0s' {1..50})${NC}"
}

print_check() {
    local status=$1
    local message=$2
    local detail=${3:-""}
    
    ((TOTAL_CHECKS++))
    
    case $status in
        "PASS")
            echo -e "${GREEN}✅ $message${NC}"
            ((PASSED_CHECKS++))
            ;;
        "FAIL")
            echo -e "${RED}❌ $message${NC}"
            if [ -n "$detail" ]; then
                echo -e "${RED}   └─ $detail${NC}"
            fi
            ((FAILED_CHECKS++))
            ;;
        "WARN")
            echo -e "${YELLOW}⚠️  $message${NC}"
            if [ -n "$detail" ]; then
                echo -e "${YELLOW}   └─ $detail${NC}"
            fi
            ((WARNING_CHECKS++))
            ;;
        "INFO")
            echo -e "${CYAN}ℹ️  $message${NC}"
            if [ -n "$detail" ]; then
                echo -e "${CYAN}   └─ $detail${NC}"
            fi
            ;;
    esac
}

# 🔍 Check if file exists
check_file_exists() {
    local file_path=$1
    local description=$2
    
    if [ -f "$file_path" ]; then
        print_check "PASS" "$description exists"
        return 0
    else
        print_check "FAIL" "$description missing" "Expected: $file_path"
        return 1
    fi
}

# 🔍 Check for placeholder values in file
check_placeholders() {
    local file_path=$1
    local description=$2
    
    if [ ! -f "$file_path" ]; then
        print_check "FAIL" "$description - File not found"
        return 1
    fi
    
    # Common placeholder patterns
    local placeholders=(
        "your_.*_here"
        "changeme"
        "replace_me"
        "TODO"
        "FIXME"
        "example\.com"
        "password123"
        "admin123"
    )
    
    local found_placeholders=()
    
    for pattern in "${placeholders[@]}"; do
        if grep -q "$pattern" "$file_path" 2>/dev/null; then
            local matches=$(grep -n "$pattern" "$file_path" | head -3)
            found_placeholders+=("$pattern: $matches")
        fi
    done
    
    if [ ${#found_placeholders[@]} -eq 0 ]; then
        print_check "PASS" "$description - No placeholders found"
        return 0
    else
        print_check "FAIL" "$description - Placeholders found"
        for placeholder in "${found_placeholders[@]}"; do
            echo -e "${RED}      $placeholder${NC}"
        done
        return 1
    fi
}

# 🔍 Check required environment variables
check_env_variables() {
    local env_file="$DEPLOYMENT_DIR/.env"
    
    if [ ! -f "$env_file" ]; then
        print_check "FAIL" ".env file not found" "Run: cp deployment/.env.example deployment/.env"
        return 1
    fi
    
    # Required variables that must not be placeholders
    local required_vars=(
        "TZ"
        "VPN_SERVICE_PROVIDER"
        "WIREGUARD_PUBLIC_KEY"
        "WIREGUARD_PRIVATE_KEY"
        "DB_PASS"
        "JWT_SECRET"
        "NTFY_TOPIC_ALERTS"
        "NTFY_TOPIC_SUMMARY"
        "ADMIN_EMAIL"
    )
    
    # Variables that are OK to have placeholder values (will be configured during deployment)
    local optional_vars=(
        "RADARR_API_KEY"
        "SONARR_API_KEY"
        "NTFY_AUTH_TOKEN"
    )
    
    local missing_vars=()
    local placeholder_vars=()
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^$var=" "$env_file"; then
            missing_vars+=("$var")
        elif grep -q "^$var=.*your_.*_here\|^$var=.*changeme\|^$var=.*replace_me" "$env_file"; then
            placeholder_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -eq 0 ] && [ ${#placeholder_vars[@]} -eq 0 ]; then
        print_check "PASS" "All required environment variables configured"
        return 0
    else
        if [ ${#missing_vars[@]} -gt 0 ]; then
            print_check "FAIL" "Missing required environment variables"
            for var in "${missing_vars[@]}"; do
                echo -e "${RED}      $var${NC}"
            done
        fi
        if [ ${#placeholder_vars[@]} -gt 0 ]; then
            print_check "FAIL" "Environment variables with placeholder values"
            for var in "${placeholder_vars[@]}"; do
                echo -e "${RED}      $var${NC}"
            done
        fi
        return 1
    fi
}

# 🔍 Check WireGuard configuration
check_wireguard_config() {
    local wg_file="$DEPLOYMENT_DIR/wg0.conf"
    
    if [ ! -f "$wg_file" ]; then
        print_check "FAIL" "WireGuard config not found" "Run: cp deployment/wg0.conf.example deployment/wg0.conf"
        return 1
    fi
    
    # Check for placeholder patterns in WireGuard config
    if grep -q "your_.*_here\|example\.com" "$wg_file"; then
        print_check "FAIL" "WireGuard config has placeholder values"
        grep -n "your_.*_here\|example\.com" "$wg_file" | while read -r line; do
            echo -e "${RED}      $line${NC}"
        done
        return 1
    else
        print_check "PASS" "WireGuard configuration appears complete"
        return 0
    fi
}

# 🔍 Check LXC configurations
check_lxc_configs() {
    local lxc_issues=()
    
    # Check if setup scripts exist and are executable
    local lxc_scripts=(
        "$LXC_DIR/nginx-proxy-manager/setup_npm_lxc.sh"
        "$LXC_DIR/tailscale/setup_tailscale_lxc.sh"
        "$LXC_DIR/ntfy/setup_ntfy_lxc.sh"
        "$LXC_DIR/samba/setup_samba_lxc.sh"
        "$LXC_DIR/pihole/setup_pihole_lxc.sh"
        "$LXC_DIR/vaultwarden/setup_vaultwarden_lxc.sh"
    )
    
    for script in "${lxc_scripts[@]}"; do
        if [ -f "$script" ]; then
            if [ -x "$script" ]; then
                print_check "PASS" "$(basename "$script") is executable"
            else
                print_check "WARN" "$(basename "$script") is not executable" "Run: chmod +x $script"
                lxc_issues+=("$script not executable")
            fi
        else
            print_check "FAIL" "$(basename "$script") missing"
            lxc_issues+=("$script missing")
        fi
    done
    
    # Check if Tailscale auth key is available
    if [ -f "$REPO_ROOT/TAILSCALE_DEPLOYMENT_READY.md" ]; then
        if grep -q "tskey-auth-" "$REPO_ROOT/TAILSCALE_DEPLOYMENT_READY.md"; then
            print_check "PASS" "Tailscale auth key is documented"
        else
            print_check "WARN" "Tailscale auth key format not found"
        fi
    else
        print_check "WARN" "Tailscale deployment readiness not documented"
    fi
    
    if [ ${#lxc_issues[@]} -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# 🔍 Check network configuration
check_network_config() {
    # Check if Pi-hole has been configured with proper password
    local pihole_script="$LXC_DIR/pihole/setup_pihole_lxc.sh"
    
    if [ -f "$pihole_script" ]; then
        if grep -q 'WEBPASSWORD="\${PIHOLE_WEBPASSWORD:-' "$pihole_script"; then
            print_check "PASS" "Pi-hole password uses secure environment variable"
        elif grep -q 'WEBPASSWORD="admin123"' "$pihole_script"; then
            print_check "WARN" "Pi-hole still has default password" "Consider changing from 'admin123'"
        else
            print_check "PASS" "Pi-hole password appears customized"
        fi
    fi
    
    # Check if Vaultwarden domain is configured
    local vaultwarden_script="$LXC_DIR/vaultwarden/setup_vaultwarden_lxc.sh"
    
    if [ -f "$vaultwarden_script" ]; then
        if grep -q 'DOMAIN_NAME="homelab-vault.local"' "$vaultwarden_script"; then
            print_check "PASS" "Vaultwarden domain is configured"
        elif grep -q 'DOMAIN_NAME="vault.local"' "$vaultwarden_script"; then
            print_check "WARN" "Vaultwarden has default domain name"
        else
            print_check "PASS" "Vaultwarden domain appears customized"
        fi
    fi
    
    # Check if network addressing scheme is documented
    if [ -f "$REPO_ROOT/NETWORK_ADDRESSING_SCHEME.md" ]; then
        print_check "PASS" "Network addressing scheme is documented"
    else
        print_check "WARN" "Network addressing scheme not documented"
    fi
}

# 🔍 Check documentation completeness
check_documentation() {
    local docs=(
        "$REPO_ROOT/README.md"
        "$REPO_ROOT/LXC_CONFIGURATION_GUIDE.md"
        "$REPO_ROOT/PORT_TESTING_GUIDE.md"
        "$REPO_ROOT/PREDEPLOYMENT_CHECKLIST.txt"
        "$DEPLOYMENT_DIR/README_START_HERE.md"
        "$DEPLOYMENT_DIR/TROUBLESHOOTING.md"
    )
    
    for doc in "${docs[@]}"; do
        if [ -f "$doc" ]; then
            print_check "PASS" "$(basename "$doc") exists"
        else
            print_check "WARN" "$(basename "$doc") missing"
        fi
    done
}

# 🔍 Check for sensitive information
check_sensitive_info() {
    local sensitive_patterns=(
        "password.*=.*[^[:space:]]+$"
        "key.*=.*[A-Za-z0-9]{20,}"
        "token.*=.*[A-Za-z0-9]{20,}"
        "secret.*=.*[A-Za-z0-9]{20,}"
    )
    
    local sensitive_files=(
        "$DEPLOYMENT_DIR/.env"
        "$DEPLOYMENT_DIR/wg0.conf"
    )
    
    local found_sensitive=false
    
    for file in "${sensitive_files[@]}"; do
        if [ -f "$file" ]; then
            for pattern in "${sensitive_patterns[@]}"; do
                if grep -i "$pattern" "$file" >/dev/null 2>&1; then
                    if [ "$found_sensitive" = false ]; then
                        print_check "INFO" "Sensitive information detected (this is normal)"
                        found_sensitive=true
                    fi
                    break
                fi
            done
        fi
    done
    
    if [ "$found_sensitive" = false ]; then
        print_check "WARN" "No sensitive information detected" "This might indicate incomplete configuration"
    fi
    
    # Check if .env is in .gitignore
    if grep -q "\.env$" "$REPO_ROOT/.gitignore" 2>/dev/null; then
        print_check "PASS" ".env file is properly ignored by git"
    else
        print_check "WARN" ".env file may not be ignored by git"
    fi
}

# 🔍 Generate deployment readiness report
generate_summary() {
    print_header "📊 DEPLOYMENT READINESS SUMMARY"
    
    echo -e "${BLUE}Test Results:${NC}"
    echo -e "  ✅ Passed: ${GREEN}$PASSED_CHECKS${NC}"
    echo -e "  ❌ Failed: ${RED}$FAILED_CHECKS${NC}"
    echo -e "  ⚠️  Warnings: ${YELLOW}$WARNING_CHECKS${NC}"
    echo -e "  📊 Total: $TOTAL_CHECKS checks"
    echo
    
    if [ $FAILED_CHECKS -eq 0 ]; then
        echo -e "${GREEN}🎉 DEPLOYMENT READY!${NC}"
        echo -e "${GREEN}All critical requirements are satisfied.${NC}"
        if [ $WARNING_CHECKS -gt 0 ]; then
            echo -e "${YELLOW}Note: There are $WARNING_CHECKS warnings that you may want to address.${NC}"
        fi
        echo
        echo -e "${BLUE}Next Steps:${NC}"
        echo -e "  1. 🚀 Deploy LXC containers: ${WHITE}./homelab.sh lxc${NC}"
        echo -e "  2. 🐳 Deploy Docker stack: ${WHITE}cd deployment && docker-compose up -d${NC}"
        echo -e "  3. 🔍 Test connectivity: ${WHITE}./scripts/monitoring/homelab_network_test.sh${NC}"
        echo -e "  4. 🌐 Configure external access via NPM"
        return 0
    else
        echo -e "${RED}❌ NOT READY FOR DEPLOYMENT${NC}"
        echo -e "${RED}Please fix the $FAILED_CHECKS failed checks above.${NC}"
        echo
        echo -e "${BLUE}Common Fixes:${NC}"
        echo -e "  • Copy templates: ${WHITE}cp deployment/.env.example deployment/.env${NC}"
        echo -e "  • Edit .env file: ${WHITE}nano deployment/.env${NC}"
        echo -e "  • Set permissions: ${WHITE}chmod +x lxc/*/setup_*_lxc.sh${NC}"
        echo -e "  • Generate Tailscale auth key (see TAILSCALE_DEPLOYMENT_READY.md)"
        return 1
    fi
}

# 🚀 Main execution
main() {
    print_header "🔍 HOMELAB PRE-DEPLOYMENT VALIDATION"
    echo -e "${CYAN}Checking homelab configuration for deployment readiness...${NC}"
    echo
    
    print_section "Essential Configuration Files"
    check_file_exists "$DEPLOYMENT_DIR/.env" "Docker environment file"
    check_file_exists "$DEPLOYMENT_DIR/wg0.conf" "WireGuard configuration"
    check_file_exists "$DEPLOYMENT_DIR/docker-compose.yml" "Docker Compose configuration"
    
    print_section "Environment Variables"
    check_env_variables
    
    print_section "Configuration Placeholders"
    check_placeholders "$DEPLOYMENT_DIR/.env" "Docker environment file"
    check_wireguard_config
    
    print_section "LXC Container Setup"
    check_lxc_configs
    
    print_section "Network Configuration"
    check_network_config
    
    print_section "Documentation"
    check_documentation
    
    print_section "Security Checks"
    check_sensitive_info
    
    echo
    generate_summary
}

# Run the validation
main "$@"