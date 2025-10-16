# =====================================================

# 📦 Ntfy LXC Configuration Files

# =====================================================

# Maintainer: J35867U

# Email: mrnash404@protonmail.com

# Last Updated: 2025-10-11

# =====================================================
## Overview
This directory contains scripts and configuration files for setting up Ntfy (notification service) in a dedicated LXC container. This provides a self-hosted, private notification system for your homelab.

## Files
- `setup_ntfy_lxc.sh` - Automated LXC container creation and Ntfy installation script
- `server.yml.example` - Example Ntfy server configuration
- `README.md` - This file

## Quick Start
### Prerequisites
- Proxmox VE host with LXC support
- Ubuntu 22.04 LXC template downloaded
- Network configuration (adjust IP ranges in script)

### Installation
1. **Review Configuration**

   ```bash
   # Edit the script to match your network
   vi setup_ntfy_lxc.sh
   
   # Key variables to adjust:
   IP_ADDRESS="192.168.1.200/24"  # Your desired IP
   GATEWAY="192.168.1.1"          # Your gateway
   CONTAINER_ID=200               # Available container ID
   ```

2. **Run Setup Script**

   ```bash
   # On your Proxmox host
   chmod +x setup_ntfy_lxc.sh
   ./setup_ntfy_lxc.sh [container_id]
   
   # Example with custom container ID
   ./setup_ntfy_lxc.sh 201
   ```

3. **Create Admin User**

   ```bash
   # After setup completes
   pct exec 200 -- ntfy user add --role=admin admin
   ```

4. **Update Homelab Configuration**

   ```bash
   # In your homelab .env file, change:
   NTFY_SERVER=<http://192.168.1.200>  # Your LXC IP
   ```

## Container Specifications
- **OS**: Ubuntu 22.04 LTS
- **Memory**: 512MB RAM + 512MB Swap
- **Storage**: 2GB disk space
- **CPU**: 1 core
- **Network**: Static IP configuration
- **Services**: Ntfy server on port 80

## Security Considerations
- **Default Access**: Deny-all (authentication required)
- **Admin User**: Must be created manually for security
- **Rate Limiting**: Configured to prevent abuse
- **Internal Network**: Recommended to keep on internal VLAN

## Usage Examples
### Send Test Notification

```bash
# Simple message
curl -d "Test message from homelab" http://192.168.1.200/test-topic

# With title and priority
curl -H "title: System Alert" \
     -H "priority: high" \
     -d "Server backup completed successfully" \
     http://192.168.1.200/homelab-alerts

```
### Integration with Homelab Scripts
Your existing monitoring and backup scripts will automatically use the new server once you update the `NTFY_SERVER` environment variable.

## Management Commands
```bash
# Container management
pct start 200                    # Start container
pct stop 200                     # Stop container
pct enter 200                    # Enter container shell

# Service management (inside container)
systemctl status ntfy            # Check service status
systemctl restart ntfy           # Restart service
journalctl -u ntfy -f            # View logs

# User management (inside container)
ntfy user list                   # List users
ntfy user add username           # Add user
ntfy user del username           # Delete user
ntfy user change-pass username   # Change password

```
## Troubleshooting
### Container Won't Start

```bash
# Check container status
pct status 200

# View container logs
pct enter 200
journalctl -u ntfy -n 50

```
### Network Issues

```bash
# Test connectivity from homelab
ping 192.168.1.200

# Test Ntfy service
curl -I http://192.168.1.200

```
### Service Issues

```bash
# Inside container
systemctl status ntfy
cat /etc/ntfy/server.yml
ntfy serve --config /etc/ntfy/server.yml --log-level DEBUG

```
## Advanced Configuration
### HTTPS Setup (Optional)
For HTTPS support, you can:

1. Set up a reverse proxy (nginx/Caddy) in the container
2. Use your existing reverse proxy to forward to the Ntfy container
3. Configure Let's Encrypt certificates

### High Availability
For production setups:

- Set up multiple Ntfy containers with load balancing
- Use shared storage for the database
- Configure container backups

## Backup Recommendations
```bash
# Backup container
vzdump 200 --storage backup-storage --compress gzip

# Backup Ntfy data specifically
pct exec 200 -- tar -czf /tmp/ntfy-backup.tar.gz /var/lib/ntfy /etc/ntfy
pct pull 200 /tmp/ntfy-backup.tar.gz ./ntfy-backup-$(date +%Y%m%d).tar.gz

```
## Documentation Links
- [Ntfy Documentation](https://docs.ntfy.sh/)
- [Proxmox LXC Documentation](https://pve.proxmox.com/wiki/Linux_Container)
- [Homelab Main Documentation](../../README.md)

