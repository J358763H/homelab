# =====================================================
# 📦 LXC Container Configurations
# =====================================================
# Maintainer: J35867U
# Email: mrnash404@protonmail.com
# Last Updated: 2025-10-11
# =====================================================

## Overview

This directory contains LXC container configurations and setup scripts for self-hosted services that complement your Docker-based homelab stack. These containers provide dedicated, lightweight environments for critical infrastructure services.

## Available Containers

### 📢 Ntfy Notification Server (`ntfy/`)
- **Purpose**: Self-hosted push notification service
- **Resources**: 512MB RAM, 2GB storage, 1 CPU core
- **Integration**: Replaces public ntfy.sh for privacy and reliability
- **Features**: Web UI, authentication, rate limiting, API access

## Directory Structure

```
lxc/
├── README.md                    # This file
└── ntfy/                        # Ntfy notification server
    ├── setup_ntfy_lxc.sh        # Automated setup script
    ├── server.yml.example       # Configuration template
    ├── configure_homelab.sh     # Homelab integration script
    └── README.md                # Ntfy-specific documentation
```

## Prerequisites

- **Proxmox VE** host with LXC support
- **Ubuntu 22.04 LTS** template downloaded
- **Network configuration** with available IP addresses
- **Root access** to Proxmox host

## Quick Start

1. **Choose a Container**
   ```bash
   cd lxc/ntfy/
   ```

2. **Review Configuration**
   ```bash
   # Edit network settings in setup script
   vi setup_ntfy_lxc.sh
   ```

3. **Run Setup**
   ```bash
   chmod +x setup_ntfy_lxc.sh
   ./setup_ntfy_lxc.sh
   ```

4. **Update Homelab**
   ```bash
   ./configure_homelab.sh
   ```

## Design Philosophy

### Why LXC Instead of Docker?

- **Resource Efficiency**: Lower overhead than Docker for system services
- **Isolation**: Better security isolation for infrastructure components
- **Persistence**: Easier backup and migration of complete environments
- **Independence**: Infrastructure services separate from application stack

### Container Sizing Guidelines

- **Micro Services** (≤256MB RAM): Single-purpose utilities
- **Small Services** (512MB RAM): Most infrastructure services
- **Medium Services** (1GB RAM): Database or heavy processing
- **Large Services** (≥2GB RAM): Complex applications or caching

## Network Planning

### Recommended IP Allocation

```bash
# Infrastructure Services
192.168.1.200    # Ntfy notifications
192.168.1.201    # Future: Monitoring (Prometheus)
192.168.1.202    # Future: Logging (Loki)
192.168.1.203    # Future: Secrets (Vault)
192.168.1.204    # Future: DNS (Pi-hole)

# Application Services  
192.168.1.210+   # Additional app containers
```

### Firewall Considerations

```bash
# Allow homelab network access
iptables -A INPUT -s 192.168.1.0/24 -j ACCEPT

# Allow specific service ports
iptables -A INPUT -p tcp --dport 80 -j ACCEPT   # Ntfy HTTP
iptables -A INPUT -p tcp --dport 443 -j ACCEPT  # Ntfy HTTPS
```

## Management Commands

### Container Lifecycle
```bash
# List all containers
pct list

# Start/stop containers
pct start 200
pct stop 200

# Enter container shell
pct enter 200

# Container status
pct status 200
```

### Resource Management
```bash
# View resource usage
pct exec 200 -- htop
pct exec 200 -- df -h
pct exec 200 -- free -h

# Resize resources (container must be stopped)
pct set 200 --memory 1024
pct set 200 --cores 2
```

### Backup and Restore
```bash
# Backup container
vzdump 200 --storage backup-storage --compress gzip

# Restore from backup
pct restore 200 /path/to/backup.tar.gz --storage local-lvm
```

## Integration with Docker Stack

These LXC containers complement your Docker-based homelab:

### Service Dependencies
- **Docker Stack**: Application services (Jellyfin, Servarr, etc.)
- **LXC Infrastructure**: Supporting services (notifications, monitoring, etc.)

### Communication Patterns
- **Docker → LXC**: Apps send notifications, metrics, logs
- **LXC → Docker**: Infrastructure monitors and manages app containers
- **External → LXC**: Admin access, configuration, troubleshooting

## Security Best Practices

### Container Security
- **Unprivileged containers**: Always use unprivileged mode
- **Resource limits**: Set appropriate CPU/memory limits
- **Network isolation**: Use dedicated VLANs where possible
- **Regular updates**: Keep container OS and services updated

### Access Control
- **SSH keys**: Use key-based authentication
- **Service accounts**: Dedicated users for service access
- **Firewall rules**: Restrict network access appropriately
- **Audit logging**: Enable logging for security events

## Monitoring Integration

### Health Checks
All containers should provide health check endpoints:
```bash
# Add to your monitoring scripts
curl -f http://192.168.1.200/health || alert "Ntfy container down"
```

### Resource Monitoring
```bash
# Container resource usage
pct exec 200 -- cat /proc/meminfo
pct exec 200 -- cat /proc/loadavg
```

## Troubleshooting

### Common Issues

1. **Container won't start**
   ```bash
   pct start 200 --debug
   journalctl -u pve-container@200
   ```

2. **Network connectivity problems**
   ```bash
   pct enter 200
   ping 8.8.8.8
   ip addr show
   ```

3. **Service not responding**
   ```bash
   pct exec 200 -- systemctl status service-name
   pct exec 200 -- journalctl -u service-name -f
   ```

### Log Locations
- **Proxmox logs**: `/var/log/pve/`
- **Container logs**: `journalctl -M 200`
- **Service logs**: Inside container at `/var/log/`

## Future Expansion

Planned container additions:

- **Prometheus**: Metrics collection and alerting
- **Grafana**: Visualization and dashboards  
- **Loki**: Log aggregation and analysis
- **Vault**: Secret management
- **Pi-hole**: DNS filtering and ad blocking
- **Wireguard**: VPN server for remote access

## Documentation Links

- [Proxmox LXC Documentation](https://pve.proxmox.com/wiki/Linux_Container)
- [Container Best Practices](https://pve.proxmox.com/wiki/Linux_Container#_best_practices)
- [Homelab-SHV Main Documentation](../README.md)