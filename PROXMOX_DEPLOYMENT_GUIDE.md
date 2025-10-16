# 🏥 Proxmox LXC Deployment Guide

## Quick Pre-Deployment Check
```bash
./validate_deployment_readiness.sh
```

## Critical Proxmox LXC Requirements

### 1. Container Configuration (LXC Host)
Add to your LXC container config (`/etc/pve/lxc/{CTID}.conf`):
```
# Enable TUN device for Gluetun VPN
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net dev/net none bind,create=dir

# Enable Docker/container nesting
lxc.apparmor.profile: unconfined
lxc.cgroup2.devices.allow: a proc:rw sys:rw

# Increase resource limits
lxc.prlimit.nofile: 1048576
```

### 2. Container Setup (Inside LXC)
```bash
# Create TUN device
mknod /dev/net/tun c 10 200
chmod 666 /dev/net/tun

# Verify TUN device
ls -la /dev/net/tun
```

### 3. DNS Bootstrap Configuration
**CRITICAL**: Prevent DNS loops with Pi-hole

Edit `/etc/resolv.conf` BEFORE starting containers:
```
nameserver 8.8.8.8
nameserver 1.1.1.1
```

### 4. Deployment Order (Prevents Race Conditions)
```bash
# 1. Start VPN first
docker-compose up -d gluetun

# 2. Wait for VPN connection
sleep 30

# 3. Start Tailscale
docker-compose up -d tailscale

# 4. Start core services
docker-compose up -d pihole nginx-proxy-manager

# 5. Wait for Pi-hole
sleep 30

# 6. Start remaining services
docker-compose up -d
```

## Automated Deployment
Use the enhanced deployment script:
```bash
./deploy_homelab_master.sh
```

This script now includes:
- ✅ Proxmox LXC validation
- ✅ TUN device checks
- ✅ DNS loop prevention
- ✅ Staged container startup
- ✅ Race condition handling

## Common Issues & Fixes

### Issue: Gluetun fails to start
**Solution**: Check TUN device
```bash
ls -la /dev/net/tun
# If missing:
mknod /dev/net/tun c 10 200
chmod 666 /dev/net/tun
```

### Issue: Docker permission denied
**Solution**: Enable nesting in LXC config
```
lxc.apparmor.profile: unconfined
```

### Issue: Pi-hole DNS loop
**Solution**: Set external DNS before startup
```bash
echo "nameserver 8.8.8.8" > /etc/resolv.conf
```

### Issue: Containers fail to network
**Solution**: Check kernel modules
```bash
modprobe bridge
modprobe veth
```

## Validation Commands
```bash
# Check environment
./validate_deployment_readiness.sh

# Test TUN device
cat /dev/net/tun

# Test DNS resolution
nslookup google.com

# Check Docker
docker version

# Check network
ip route show
```
