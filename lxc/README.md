# 📦 LXC Container Services

Self-hosted infrastructure services running in dedicated LXC containers on Proxmox. These complement the Docker-based homelab stack with dedicated environments for critical networking and infrastructure services.

**Updated:** October 16, 2025
**Integration:** Works alongside `containers/` Docker services

## Quick Start

### Prerequisites
- Proxmox VE host
- Ubuntu 22.04 LTS template downloaded
- Static IP addresses available (192.168.1.201-206)

### Simple Deployment
```bash
# Deploy individual service
cd lxc/nginx-proxy-manager
./setup_npm_lxc.sh

# Or deploy with homelab stack
cd setup
./deploy-all.sh --include-lxc
```

## Available Services

### 🌐 **Nginx Proxy Manager** (CT 201)
- **Purpose**: Reverse proxy and SSL certificate management
- **IP**: 192.168.1.201:81
- **Integration**: Proxies to Docker services
- **Resources**: 1GB RAM, 4GB storage

### 🔒 **Tailscale VPN** (CT 202)
- **Purpose**: Secure mesh networking and remote access
- **IP**: 192.168.1.202
- **Integration**: Routes entire homelab subnet
- **Resources**: 512MB RAM, 2GB storage

### 📢 **Ntfy Notifications** (CT 203)
- **Purpose**: Self-hosted push notification service
- **IP**: 192.168.1.203:80
- **Integration**: Replaces public ntfy.sh for privacy
- **Resources**: 512MB RAM, 2GB storage

### 📁 **Samba File Share** (CT 204)
- **Purpose**: Network file sharing for media collection
- **IP**: 192.168.1.204
- **Integration**: Direct access to Docker media storage
- **Resources**: 1GB RAM, 8GB storage

### 🚫 **Pi-hole DNS** (CT 205)
- **Purpose**: Network-wide ad blocking and DNS
- **IP**: 192.168.1.205:80
- **Integration**: DNS for entire homelab network
- **Resources**: 512MB RAM, 2GB storage

### 🔐 **Vaultwarden** (CT 206)
- **Purpose**: Self-hosted password manager
- **IP**: 192.168.1.206:80
- **Integration**: Secure credential storage
- **Resources**: 512MB RAM, 2GB storage

## Directory Structure
```
lxc/
├── README.md                         # This file
├── nginx-proxy-manager/              # Reverse proxy & SSL management
│   ├── setup_npm_lxc.sh             # Automated setup script
│   └── README.md                     # NPM-specific documentation
├── tailscale/                        # Secure mesh networking
│   ├── setup_tailscale_lxc.sh       # Automated setup script
│   └── README.md                     # Tailscale-specific documentation
├── ntfy/                             # Ntfy notification server
│   ├── setup_ntfy_lxc.sh            # Automated setup script
│   ├── server.yml.example           # Configuration template
│   ├── configure_homelab.sh         # Homelab integration script
│   └── README.md                     # Ntfy-specific documentation
└── samba/                            # Media File Share server
    ├── setup_samba_lxc.sh           # Automated setup script
    ├── smb.conf.example         # Media File Share configuration template
    └── README.md                # Media File Share documentation

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
### VMID-to-IP Correlation Scheme
```bash
# Core Principle: IP = 192.168.1.XXX where XXX = VMID
# Benefits: Instant visual correlation, easy troubleshooting

# Current Infrastructure Services (200-219)
192.168.1.201    # VMID 201 - Nginx Proxy Manager
192.168.1.202    # VMID 202 - Tailscale VPN Router
192.168.1.203    # VMID 203 - Ntfy Notifications
192.168.1.204    # VMID 204 - Media File Share
192.168.1.205    # VMID 205 - Pi-hole DNS
192.168.1.206    # VMID 206 - Vaultwarden Password Manager

# Future Services (220+)
192.168.1.220+   # Additional infrastructure containers

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

- **Prometheus**: Metrics collection and alerting (Container 103)
- **Grafana**: Visualization and dashboards (Container 104)
- **Loki**: Log aggregation and analysis (Container 105)
- **Vault**: Secret management (Container 106)
- **Pi-hole**: DNS filtering and ad blocking (Container 107)
- **Backup Server**: Dedicated backup storage (Container 108)

## Documentation Links
- [Proxmox LXC Documentation](https://pve.proxmox.com/wiki/Linux_Container)
- [Container Best Practices](https://pve.proxmox.com/wiki/Linux_Container#_best_practices)
- [Homelab Main Documentation](../README.md)
