# 🚀 Homelab Deployment Quick Start Guide
## 🎯 Your Setup Overview
**Primary Server:** i5-8400 at 192.168.1.50 (Proxmox VE)  
**Infrastructure:** ZFS Mirror + LXC Containers + Docker Stack  
**Network:** 192.168.1.x for LXC services, 172.20.0.x for Docker internal  

---

## ⚡ Quick Deployment Steps
### 1. 🗄️ Setup ZFS Mirror (Recommended for Aging Drives)
```bash
# SSH to your Proxmox server (192.168.1.50)
ssh root@192.168.1.50

# Download and run ZFS mirror setup
chmod +x scripts/setup_zfs_mirror.sh
./scripts/setup_zfs_mirror.sh

# Follow prompts to select your aging drives
# Script will create homelab-storage pool with redundancy

```
**What this does:**
- Creates mirrored ZFS pool for data protection
- Sets up automatic snapshots (daily at 2 AM)
- Configures Docker integration
- Implements health monitoring

### 2. 🏗️ Deploy Complete Infrastructure
```bash
# Run the master deployment script
chmod +x deploy_homelab_master.sh
./deploy_homelab_master.sh

# This will:
# - Deploy all LXC containers (201-206)
# - Create Docker host VM (100)
# - Deploy entire Docker stack
# - Configure networking

```
### 3. 🔍 Validate Deployment
```bash
# Run comprehensive validation
chmod +x scripts/validate_deployment.sh
./scripts/validate_deployment.sh

# Generates HTML report at /tmp/homelab_validation_*.html

```
---

## 🌐 Service Access URLs
Once deployed, access your services at:

| Service | URL | Default Credentials |
|---------|-----|-------------------|
| **Jellyfin Media Server** | <http://192.168.1.100:8096> | Setup wizard |
| **Sonarr (TV Shows)** | <http://192.168.1.100:8989> | No auth initially |
| **Radarr (Movies)** | <http://192.168.1.100:7878> | No auth initially |
| **Prowlarr (Indexers)** | <http://192.168.1.100:9696> | No auth initially |
| **qBittorrent** | <http://192.168.1.100:8080> | admin / adminadmin |
| **Nginx Proxy Manager** | <http://192.168.1.201:81> | admin@example.com / changeme |
| **Pi-hole Admin** | <http://192.168.1.205/admin> | Password: `X#zunVV!kDWdYUt0zAAg` |
| **Vaultwarden** | <http://192.168.1.206> | Create account |

---

## 🔧 Post-Deployment Configuration
### Priority 1: Secure Access

1. **Configure Nginx Proxy Manager:**
   - Add SSL certificates for each service
   - Set up custom domains (homelab-jellyfin.local, etc.)

2. **Setup Tailscale VPN:**
   - Configure auth key in LXC 202
   - Enable subnet routing for secure remote access

### Priority 2: Media Management

1. **Configure Prowlarr:**
   - Add indexers (trackers)
   - Generate API keys

2. **Setup Sonarr/Radarr:**
   - Connect to Prowlarr for indexers
   - Configure qBittorrent as download client
   - Set up Jellyfin library paths

3. **Configure Jellyfin:**
   - Add media libraries (/data/media/movies, /data/media/shows)
   - Enable hardware acceleration if supported
   - Configure user accounts

### Priority 3: Automation

1. **YouTube Automation:**
   - Configure creators in `/data/docker/jellyfin-youtube/config/`
   - Set up automated downloads

2. **Notifications:**
   - Configure ntfy topics for alerts
   - Test notification delivery

---

## 🚨 Troubleshooting Quick Fixes
### Network Issues

```bash
# Test all service connectivity
ping 192.168.1.201  # NPM
ping 192.168.1.205  # Pi-hole
ping 192.168.1.100  # Docker host

# Check Docker services
ssh root@192.168.1.100  # If LXC, use: pct enter 100
cd /opt/homelab
docker-compose ps

```
### Service Not Starting

```bash
# Check specific container logs
docker-compose logs [service_name]

# Restart specific service
docker-compose restart [service_name]

# Full stack restart
docker-compose down && docker-compose up -d

```
### Storage Issues (if using ZFS)

```bash
# Check ZFS pool health
zpool status homelab-storage

# Check disk usage
zfs list

# Create manual snapshot
zfs snapshot homelab-storage/docker@manual_$(date +%Y%m%d)

```
---

## 📊 Monitoring Your Homelab
### Daily Checks

- **Pi-hole:** Check blocked queries and top clients
- **Jellyfin:** Monitor transcoding and library updates  
- **qBittorrent:** Review active downloads and ratios

### Weekly Checks

- **ZFS Health:** `zpool status` (if configured)
- **Disk Space:** `df -h` across all systems
- **Container Health:** `docker-compose ps`
- **System Updates:** Update LXC containers and Docker images

### Monthly Maintenance

- **Backup Validation:** Test restore procedures
- **Security Updates:** Update Proxmox, containers, and services
- **Performance Review:** Check resource usage and optimization

---

## 🔗 Important File Locations
```
/opt/homelab/                    # Docker compose stack
/data/media/                     # Media libraries
/data/docker/                    # Docker persistent data
/mnt/homelab-storage/           # ZFS mount point (if configured)
/var/log/homelab_*.log          # Deployment logs

```
---

## 🆘 Support Resources
- **Main Documentation:** `README.md`
- **Network Guide:** `NETWORK_ADDRESSING_SCHEME.md`
- **Troubleshooting:** `deployment/TROUBLESHOOTING.md`
- **Validation Report:** Generated HTML reports in `/tmp/`

---

**🎉 Your homelab is now ready for production use!**

*Next step: Access the services, complete initial configuration, and enjoy your automated media management system.*

