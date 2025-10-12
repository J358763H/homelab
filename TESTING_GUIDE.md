# Homelab-SHV Testing Guide

## No-VM Testing (Configuration Validation)

### 1. Docker Compose Validation
```bash
# Syntax check
docker compose -f deployment/docker-compose.yml config

# Service dependency check  
docker compose -f deployment/docker-compose.yml config --services

# Network validation
docker compose -f deployment/docker-compose.yml config --volumes
```

### 2. Environment File Testing
```bash
# Check for placeholders
grep -n "changeme\|your_.*_here\|replace_me" deployment/.env
# Should return no results

# Validate required variables
grep -E "^(PUID|PGID|TZ|DB_PASS|JWT_SECRET)=" deployment/.env
```

### 3. Script Syntax Validation
```bash
# Check all shell scripts
find . -name "*.sh" -exec bash -n {} \;

# LXC script validation
bash -n lxc/nginx-proxy-manager/setup_npm_lxc.sh
bash -n lxc/tailscale/setup_tailscale_lxc.sh
```

## Minimal VM Testing (Basic Services)

### Test-Safe Services (No VPN Required)
Create a minimal docker-compose-test.yml:

```yaml
version: "3.8"

networks:
  homelab-test:
    driver: bridge

services:
  # Database testing
  jellystat-db:
    image: postgres:15
    container_name: jellystat-db-test
    environment:
      - POSTGRES_DB=jfstat
      - POSTGRES_USER=testuser
      - POSTGRES_PASSWORD=testpass123
    networks:
      homelab-test:
    restart: no

  # Web service testing  
  jellyfin:
    image: lscr.io/linuxserver/jellyfin:latest
    container_name: jellyfin-test
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Phoenix
    volumes:
      - ./test-data:/config
    ports:
      - "8096:8096"
    networks:
      homelab-test:
    restart: no
```

### Test Commands
```bash
# Deploy test stack
docker compose -f docker-compose-test.yml up -d

# Check service health
docker compose -f docker-compose-test.yml ps

# Test connectivity
curl http://localhost:8096

# Cleanup
docker compose -f docker-compose-test.yml down -v
```

## Full VM Testing Requirements

### VM Specifications
- **OS**: Ubuntu 22.04 LTS Server
- **RAM**: 8GB minimum (16GB for transcoding)
- **CPU**: 4+ cores with VT-x/AMD-V
- **Storage**: 100GB+ (SSD recommended)
- **Network**: Bridge/NAT with port forwarding

### Intel Quick Sync (i5-8400) VM Setup
- **GPU Passthrough**: Enable iGPU passthrough to VM
- **Video Memory**: 128MB+ allocated to VM
- **Render Group**: Ensure user 1000 in render group (GID 105)
- **Devices**: VM must access /dev/dri/renderD128

### VM Setup Commands
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
sudo systemctl enable docker

# Clone repository
git clone https://github.com/J35867U/homelab-SHV.git
cd homelab-SHV

# Run bootstrap
sudo deployment/bootstrap.sh

# Configure environment
cp deployment/.env.example deployment/.env
# Edit .env with test values

# Deploy full stack
docker compose -f deployment/docker-compose.yml up -d
```

## Testing Checklist

### Configuration Testing (No VM)
- [ ] docker-compose.yml syntax validates
- [ ] .env.example has all required variables  
- [ ] Shell scripts pass syntax check
- [ ] No broken variable references
- [ ] Documentation links work

### Service Testing (Minimal VM)
- [ ] Individual containers start
- [ ] Database connections work
- [ ] Web interfaces accessible
- [ ] Basic functionality works
- [ ] Logs show no critical errors

### Integration Testing (Full VM)  
- [ ] VPN container connects successfully
- [ ] Download client shows VPN IP
- [ ] All services accessible
- [ ] Service-to-service communication works
- [ ] Intel Quick Sync hardware acceleration enabled
- [ ] Transcoding uses GPU (check via intel_gpu_top)
- [ ] Storage paths accessible
- [ ] Backup scripts function

### LXC Testing (Proxmox Required)
- [ ] NPM LXC deploys successfully
- [ ] Tailscale LXC connects to tailnet
- [ ] NPM can proxy to Docker services
- [ ] Subnet routing works through Tailscale
- [ ] SSL certificates generate properly

### Troubleshooting Test Issues

### Common VM Test Problems
```bash
# Container won't start
docker logs <container-name>

# Network issues
docker network ls
docker network inspect homelab-deployment_homelab

# Permission problems
sudo chown -R 1000:1000 /data

# VPN not working
docker exec gluetun curl ifconfig.me
```

### Intel Quick Sync Validation
```bash
# Check if GPU is accessible
ls -la /dev/dri/
# Should show renderD128 (and card0)

# Check render group membership
id 1000
# Should include group 105 (render)

# Test hardware acceleration in Jellyfin container
docker exec jellyfin ls -la /dev/dri/
docker exec jellyfin groups

# Monitor GPU usage during transcoding
sudo apt install intel-gpu-tools
intel_gpu_top
# Should show activity when transcoding

# Check Jellyfin hardware acceleration status
# Go to Admin > Dashboard > Playback > Hardware Acceleration
# Should show "Intel Quick Sync (QSV)" available
```

### Test Environment Cleanup
```bash
# Remove test containers
docker compose down -v

# Clean up test data
sudo rm -rf ./test-data

# Remove unused images
docker system prune -a
```