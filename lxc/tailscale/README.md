# 🔒 Tailscale LXC Container Setup

## Overview

This LXC container provides a dedicated Tailscale node that acts as a subnet router, enabling secure access to your entire homelab network from anywhere.

> 🛡️ **Privacy-Focused Setup**: See [PRIVACY_SETUP_GUIDE.md](./PRIVACY_SETUP_GUIDE.md) for enhanced privacy configuration options.

## Container Specifications

- **OS**: Ubuntu 22.04 LTS
- **RAM**: 512MB
- **Storage**: 2GB
- **CPU**: 1 core
- **Network**: Bridge mode with routing enabled
- **Privileges**: Privileged container (required for subnet routing)

## Features

- Subnet router for entire homelab network
- SSH access to homelab via Tailscale
- MagicDNS for easy service discovery
- Exit node capability (optional)
- Centralized access control via Tailscale ACLs

## Prerequisites

- Proxmox VE host
- Ubuntu 22.04 LTS template
- Tailscale account and auth key
- Network routing permissions

## Quick Setup

```bash
# Run the automated setup script
chmod +x setup_tailscale_lxc.sh
./setup_tailscale_lxc.sh
```

## Manual Setup Steps

### 1. Create LXC Container

```bash
# Create privileged container (required for routing)
pct create 202 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname tailscale-homelab \
  --memory 512 \
  --swap 256 \
  --cores 1 \
  --rootfs local-lvm:2 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.1.202/24,gw=192.168.1.1 \
  --features nesting=1 \
  --unprivileged 0 \
  --start 1
```

### 2. Container Configuration

```bash
# Enter container
pct enter 202

# Update system
apt update && apt upgrade -y

# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Enable IP forwarding
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.conf
sysctl -p
```

### 3. Configure Tailscale

```bash
# Authenticate with subnet router capability
# Replace YOUR_AUTH_KEY with your actual key
tailscale up --authkey=YOUR_AUTH_KEY \
  --advertise-routes=192.168.1.0/24 \
  --ssh \
  --accept-dns=true

# Enable auto-start
systemctl enable tailscaled
```

### 4. Configure Firewall Rules

```bash
# Allow forwarding (if using iptables)
iptables -A FORWARD -i tailscale0 -j ACCEPT
iptables -A FORWARD -o tailscale0 -j ACCEPT

# Make persistent
apt install iptables-persistent
iptables-save > /etc/iptables/rules.v4
```

## Tailscale Configuration

### Auth Key Generation
1. Visit [Tailscale Admin Console](https://login.tailscale.com/admin/settings/keys)
2. Create new auth key with these settings:
   - **Reusable**: ✅ Enabled
   - **Ephemeral**: ❌ Disabled
   - **Preauthorized**: ✅ Enabled
   - **Tags**: `tag:homelab-router`

### ACL Configuration
Add to your Tailscale ACL policy:

```json
{
  "tagOwners": {
    "tag:homelab-router": ["you@example.com"]
  },
  "acls": [
    {
      "action": "accept",
      "src": ["autogroup:members"],
      "dst": ["tag:homelab-router:*", "192.168.1.0/24:*"]
    }
  ]
}
```

## Network Architecture

```
Internet
    ↓
[Tailscale Mesh Network]
    ↓
[Your Device] → [Tailscale LXC] → [Homelab Network]
                192.168.1.202      192.168.1.0/24
                      ↓
                ┌─────────────────┐
                │ Homelab Services │
                │ • Docker Host    │ 192.168.1.100
                │ • NPM LXC       │ 192.168.1.201  
                │ • Ntfy LXC      │ 192.168.1.203
                │ • Media LXC     │ 192.168.1.204
                └─────────────────┘
```

## Usage Examples

### Access Services via Tailscale
```bash
# Direct service access (no NPM needed)
http://192.168.1.100:8096  # Jellyfin on Docker host
http://192.168.1.201:81    # NPM admin interface
http://192.168.1.203:80    # Ntfy notifications

# SSH to homelab servers
ssh user@192.168.1.100     # Docker host
ssh root@192.168.1.201     # NPM LXC
```

### MagicDNS Names (if enabled)
```bash
# Access via hostnames
http://docker-host:8096          # Jellyfin
http://npm-homelab:81           # NPM admin
http://tailscale-homelab:22     # SSH to this container
```

## Advanced Configuration

### Exit Node Setup (Optional)
Make this container an exit node for routing all traffic:

```bash
# Enable exit node
tailscale up --authkey=YOUR_AUTH_KEY \
  --advertise-routes=192.168.1.0/24 \
  --advertise-exit-node \
  --ssh
```

### Monitoring and Logs
```bash
# Check Tailscale status
tailscale status

# View network information
tailscale netcheck

# Check routes
ip route show

# View logs
journalctl -u tailscaled -f
```

## Security Considerations

- **Privileged Container**: Required for routing but increases attack surface
- **Network Access**: Has access to entire homelab network
- **Key Management**: Secure auth key storage and rotation
- **Updates**: Keep Tailscale client updated
- **Monitoring**: Monitor for unusual network activity

## Maintenance

### Update Tailscale
```bash
apt update && apt upgrade tailscale
systemctl restart tailscaled
```

### Backup Configuration
```bash
# Backup Tailscale state
cp -r /var/lib/tailscale /root/tailscale-backup-$(date +%Y%m%d)
```

### Key Rotation
```bash
# Get new auth key from admin console
tailscale up --authkey=NEW_AUTH_KEY \
  --advertise-routes=192.168.1.0/24 \
  --ssh
```

## Integration Benefits

With both NPM and Tailscale LXC containers:

1. **NPM LXC (192.168.1.201)**: Handles reverse proxy and SSL
2. **Tailscale LXC (192.168.1.202)**: Provides secure network access
3. **Combined Power**: 
   - Access NPM via Tailscale to configure proxies remotely
   - Use NPM to create clean URLs for Tailscale-accessed services
   - Both services are isolated and independently manageable

Perfect setup for secure, professional homelab access!