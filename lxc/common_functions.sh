#!/bin/bash

# =====================================================
# 🔧 Common LXC Setup Functions
# =====================================================
# Shared functions for all LXC setup scripts
# Source this file in your LXC setup scripts
# =====================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Enhanced logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $1${NC}"
}

# Check if running in automated mode
check_automated_mode() {
    AUTOMATED_MODE=false
    if [[ "$1" == "--automated" ]]; then
        AUTOMATED_MODE=true
        log "Running in automated mode"
    fi
    export AUTOMATED_MODE
}

# Enhanced container existence check
handle_existing_container() {
    local ctid=$1
    
    if pct status "$ctid" >/dev/null 2>&1; then
        warn "Container $ctid already exists!"
        
        if [[ "$AUTOMATED_MODE" == "true" ]]; then
            log "Automated mode: Stopping and destroying existing container $ctid..."
            pct stop "$ctid" 2>/dev/null || true
            sleep 2
            pct destroy "$ctid" 2>/dev/null || true
            sleep 2
            
            # Verify container is gone
            if pct status "$ctid" >/dev/null 2>&1; then
                error "Failed to destroy existing container $ctid"
                return 1
            fi
            success "Existing container $ctid removed"
        else
            read -p "Do you want to destroy and recreate it? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                log "Stopping and destroying container $ctid..."
                pct stop "$ctid" 2>/dev/null || true
                sleep 2
                pct destroy "$ctid" 2>/dev/null || true
                sleep 2
            else
                error "Aborted. Choose a different container ID or use --automated flag."
                return 1
            fi
        fi
    fi
    return 0
}

# Wait for container to be ready with proper health check
wait_for_container_ready() {
    local ctid=$1
    local max_attempts=${2:-30}
    local attempt=1
    
    log "Waiting for container $ctid to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        # Check if container is running
        if ! pct status "$ctid" 2>/dev/null | grep -q "running"; then
            log "Container $ctid is not running, attempt $attempt/$max_attempts"
            sleep 3
            ((attempt++))
            continue
        fi
        
        # Check if system is ready
        if pct exec "$ctid" -- systemctl is-system-running --wait >/dev/null 2>&1; then
            success "Container $ctid is ready (attempt $attempt)"
            return 0
        fi
        
        log "Container $ctid system not ready, attempt $attempt/$max_attempts"
        sleep 3
        ((attempt++))
    done
    
    error "Container $ctid failed to become ready after $max_attempts attempts"
    return 1
}

# Wait for network connectivity in container
wait_for_network() {
    local ctid=$1
    local max_attempts=${2:-20}
    local attempt=1
    
    log "Waiting for network connectivity in container $ctid..."
    
    while [ $attempt -le $max_attempts ]; do
        if pct exec "$ctid" -- ping -c 1 8.8.8.8 >/dev/null 2>&1; then
            success "Network connectivity established (attempt $attempt)"
            return 0
        fi
        
        log "Network not ready, attempt $attempt/$max_attempts"
        sleep 2
        ((attempt++))
    done
    
    error "Network connectivity failed after $max_attempts attempts"
    return 1
}

# Wait for service to be ready on specific port
wait_for_service_port() {
    local ctid=$1
    local port=$2
    local service_name=${3:-"service"}
    local max_attempts=${4:-60}
    local attempt=1
    
    log "Waiting for $service_name on port $port in container $ctid..."
    
    while [ $attempt -le $max_attempts ]; do
        if pct exec "$ctid" -- netstat -tln 2>/dev/null | grep -q ":$port "; then
            success "$service_name is ready on port $port (attempt $attempt)"
            return 0
        fi
        
        log "$service_name not ready on port $port, attempt $attempt/$max_attempts"
        sleep 2
        ((attempt++))
    done
    
    error "$service_name failed to start on port $port after $max_attempts attempts"
    return 1
}

# Wait for HTTP endpoint to be ready
wait_for_http_endpoint() {
    local ctid=$1
    local endpoint=$2
    local service_name=${3:-"service"}
    local max_attempts=${4:-60}
    local attempt=1
    
    log "Waiting for $service_name HTTP endpoint: $endpoint..."
    
    while [ $attempt -le $max_attempts ]; do
        local http_code=$(pct exec "$ctid" -- curl -s -o /dev/null -w '%{http_code}' "$endpoint" 2>/dev/null || echo "000")
        
        # Accept any HTTP response (not connection refused)
        if [[ "$http_code" != "000" && "$http_code" != "7" ]]; then
            success "$service_name HTTP endpoint is responding (HTTP $http_code, attempt $attempt)"
            return 0
        fi
        
        log "$service_name endpoint not ready (HTTP $http_code), attempt $attempt/$max_attempts"
        sleep 3
        ((attempt++))
    done
    
    error "$service_name HTTP endpoint failed to respond after $max_attempts attempts"
    return 1
}

# Validate service is running via systemctl
validate_systemd_service() {
    local ctid=$1
    local service_name=$2
    local max_attempts=${3:-30}
    local attempt=1
    
    log "Validating systemd service: $service_name in container $ctid..."
    
    while [ $attempt -le $max_attempts ]; do
        if pct exec "$ctid" -- systemctl is-active "$service_name" >/dev/null 2>&1; then
            success "Service $service_name is active (attempt $attempt)"
            return 0
        fi
        
        log "Service $service_name not active, attempt $attempt/$max_attempts"
        sleep 2
        ((attempt++))
    done
    
    error "Service $service_name failed to become active after $max_attempts attempts"
    return 1
}

# Enhanced Docker service validation
validate_docker_service() {
    local ctid=$1
    local container_name=$2
    local max_attempts=${3:-30}
    local attempt=1
    
    log "Validating Docker service: $container_name in container $ctid..."
    
    while [ $attempt -le $max_attempts ]; do
        if pct exec "$ctid" -- docker ps --format "table {{.Names}}" | grep -q "^$container_name$"; then
            local status=$(pct exec "$ctid" -- docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null)
            if [ "$status" = "running" ]; then
                success "Docker service $container_name is running (attempt $attempt)"
                return 0
            fi
        fi
        
        log "Docker service $container_name not ready, attempt $attempt/$max_attempts"
        sleep 3
        ((attempt++))
    done
    
    error "Docker service $container_name failed to start properly after $max_attempts attempts"
    return 1
}

# Display final status and access information
display_service_info() {
    local service_name=$1
    local ctid=$2
    local ip=$3
    local port=$4
    local additional_info=${5:-""}
    
    success "$service_name setup completed successfully!"
    echo
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  $service_name Access Information${NC}"
    echo -e "${BLUE}================================${NC}"
    echo -e "Container ID: ${GREEN}$ctid${NC}"
    echo -e "IP Address:   ${GREEN}$ip${NC}"
    echo -e "Service URL:  ${GREEN}http://$ip:$port${NC}"
    
    if [[ -n "$additional_info" ]]; then
        echo -e "$additional_info"
    fi
    
    echo
    echo -e "${BLUE}Container Management:${NC}"
    echo -e "Enter container: ${GREEN}pct enter $ctid${NC}"
    echo -e "Stop container:  ${GREEN}pct stop $ctid${NC}"
    echo -e "Start container: ${GREEN}pct start $ctid${NC}"
    echo -e "Container logs:  ${GREEN}pct exec $ctid -- journalctl -f${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
       error "This script must be run as root (on Proxmox host)"
       exit 1
    fi
}

# Validate required tools
check_dependencies() {
    local required_tools=("pct" "curl" "wget")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        error "Missing required tools: ${missing_tools[*]}"
        error "Please install missing dependencies"
        return 1
    fi
    
    return 0
}

# Export all functions for use in other scripts
export -f log warn error success check_automated_mode handle_existing_container
export -f wait_for_container_ready wait_for_network wait_for_service_port
export -f wait_for_http_endpoint validate_systemd_service validate_docker_service
export -f display_service_info check_root check_dependencies