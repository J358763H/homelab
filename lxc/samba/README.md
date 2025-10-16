# =====================================================

# 📁 Media Share LXC Documentation

# =====================================================

# Maintainer: J35867U

# Email: mrnash404@protonmail.com

# Last Updated: 2025-10-11

# =====================================================
## Overview
This directory contains setup scripts and configuration for a dedicated Media Share file server LXC container. This provides network file sharing for your homelab media collection, integrating seamlessly with your Docker media stack.

**Based on**: [Proxmox Media Server Guide](https://youtu.be/qmSizZUbCOA?si=qWmb60b_BrFNtoLr)

## Files
- `setup_samba_lxc.sh` - Automated LXC container creation and Media Share setup
- `smb.conf.example` - Production Media Share configuration template
- `README.md` - This documentation file

## Architecture Integration
### **🏗️ Homelab Architecture**

```
Proxmox Host
├── Docker Stack (Container 101)          # Media apps (Jellyfin, Servarr)
├── Ntfy Server (Container 101)           # Notifications
└── Media Share (Container 102)           # File sharing & media access

```
### **📁 Directory Structure**

```
/media/                    # Main media directory
├── movies/               # Movie collection (Radarr → Jellyfin)
├── shows/                # TV shows (Sonarr → Jellyfin)
├── music/                # Music collection
├── youtube/              # YouTube downloads
└── downloads/            # Download staging area
    ├── movies/           # Movie downloads (qBittorrent)
    ├── shows/            # TV show downloads (qBittorrent)
    └── music/            # Music downloads

```
## Quick Start
### Prerequisites
- Proxmox VE host with LXC support
- Ubuntu 22.04 LXC template downloaded
- Existing storage mounts for media data
- Network configuration (adjust IP ranges in script)

### Installation
1. **Prepare Storage Mounts**

   ```bash
   # On Proxmox host, ensure your media storage is mounted
   # Example: /mnt/media (your actual media storage location)
   ```

2. **Review Configuration**

   ```bash
   # Edit the script to match your environment
   vi setup_samba_lxc.sh
   
   # Key variables to adjust:
   IP_ADDRESS="192.168.1.204/24"    # VMID-to-IP correlation: 204 → .204
   MEDIA_STORAGE_MOUNT="/mnt/media" # Your media storage path
   DOCKER_DATA_MOUNT="/mnt/docker"  # Your Docker data path
   CONTAINER_ID=204                 # Available container ID
   ```

3. **Run Setup Script**

   ```bash
   # On your Proxmox host
   chmod +x setup_samba_lxc.sh
   ./setup_samba_lxc.sh [container_id]
   
   # Example with custom container ID  
   ./setup_samba_lxc.sh 204
   ```

4. **Set User Passwords**

   During setup, you'll be prompted to set passwords for:

   - `mediauser` - Main media access user
   - `admin` - Administrative access user

## Container Specifications
- **OS**: Ubuntu 22.04 LTS
- **Memory**: 1GB RAM + 512MB Swap
- **Storage**: 8GB system disk + mounted media storage
- **CPU**: 2 cores
- **Network**: Static IP configuration
- **Type**: Privileged container (required for proper file permissions)
- **Features**: Nesting enabled for advanced functionality

## Network Shares
### **Available Media Shares**
| Share Name | Path | Purpose | Access |
|------------|------|---------|---------|
| `media` | `/media` | All media files | mediauser, admin |
| `movies` | `/media/movies` | Movie collection | mediauser, admin |
| `tv` | `/media/tv` | TV show collection | mediauser, admin |
| `music` | `/media/music` | Music collection | mediauser, admin |
| `youtube` | `/media/youtube` | YouTube downloads | mediauser, admin |
| `downloads` | `/media/downloads` | Download staging | mediauser, admin |
| `docker-admin` | `/docker-data` | Docker management | admin only |

### **Connection Examples**
**Windows:**

```
\\192.168.1.102\media
\\192.168.1.102\movies
\\192.168.1.102\downloads

```
**macOS:**

```
smb://192.168.1.102/media
smb://192.168.1.102/movies

```
**Linux:**

```bash
# Mount command
sudo mount -t cifs //192.168.1.102/media /mnt/media -o username=mediauser

# fstab entry
//192.168.1.102/media /mnt/media cifs username=mediauser,password=yourpassword,uid=1000,gid=1000,iocharset=utf8 0 0

```
## User Management
### **Default Users**
- **mediauser** (UID: 1500)
  - Primary media access account
  - Member of `mediagroup`
  - Read/write access to all media shares

- **admin** (UID: 1501)
  - Administrative account
  - Sudo privileges
  - Access to Docker data and system management

### **User Management Commands**
```bash
# List Media Share users
pct exec 102 -- manage-samba-users list

# Add new user
pct exec 102 -- manage-samba-users add newuser

# Remove user
pct exec 102 -- manage-samba-users remove olduser

# Change user password (Linux)
pct exec 102 -- passwd username

# Change user password (Media Share)
pct exec 102 -- smbpasswd username

```
## Performance Optimization
### **Media Share Configuration Features**
- **Modern SMB Protocol**: SMB 2.1 to SMB 3.11 support
- **Large File Optimization**: Configured for media file streaming
- **Memory Buffers**: Optimized read/write cache sizes
- **Multi-Channel Support**: Enhanced performance on modern networks
- **Sendfile**: Direct kernel-to-network file transfers

### **Network Performance**
The container is configured for optimal media streaming:

- Large socket buffers (524KB)
- Write cache enabled (256KB)
- Async I/O for large files
- Strict allocation for better disk performance

## Security Configuration
### **Firewall Rules**
UFW is configured to allow access only from your local network:

```bash
# Media Share ports (139, 445, 137, 138)
# SSH access (22)
# Restricted to 192.168.1.0/24 network

```
### **Access Control**
- **No guest access** - authentication required
- **User-based permissions** with group enforcement
- **Share-level access control**
- **Modern authentication methods**

### **Docker Integration**
### **Mount Point Mapping**
The Media Share container shares the same storage as your Docker media stack:

```yaml
# Docker compose volume mapping
volumes:
  - /mnt/media/movies:/data/movies      # Shared with Media Share /media/movies
  - /mnt/media/tv:/data/tv             # Shared with Media Share /media/tv
  - /mnt/media/downloads:/data/downloads # Shared with Media Share /media/downloads

```
### **File Permission Compatibility**
- **UID/GID alignment** with Docker containers
- **Proper ownership** for media files
- **Write permissions** for download clients
- **Read permissions** for media servers

## Maintenance
### **Backup Configuration**
```bash
# Backup Media Share configuration
pct exec 102 -- backup-samba-config

# Manual backup
pct exec 102 -- cp /etc/samba/smb.conf /root/smb.conf.backup

```
### **Monitor Services**
```bash
# Check Media Share status
pct exec 102 -- systemctl status smbd nmbd

# View Media Share logs
pct exec 102 -- tail -f /var/log/samba/log.smbd

# Check connected users
pct exec 102 -- smbstatus

```
### **Performance Monitoring**
```bash
# Check container resources
pct exec 102 -- htop

# Network connections
pct exec 102 -- netstat -tulpn | grep -E ':(139|445)'

# Disk usage
pct exec 102 -- df -h

```
## Troubleshooting
### **Common Issues**
1. **Cannot connect to shares**

   ```bash
   # Check if services are running
   pct exec 102 -- systemctl status smbd nmbd
   
   # Test Media Share configuration
   pct exec 102 -- testparm
   
   # Check firewall
   pct exec 102 -- ufw status
   ```

2. **Permission denied errors**

   ```bash
   # Check file permissions
   pct exec 102 -- ls -la /media/
   
   # Fix permissions if needed
   pct exec 102 -- chown -R mediauser:mediagroup /media/
   pct exec 102 -- chmod -R 775 /media/
   ```

3. **Slow transfer speeds**

   ```bash
   # Check network configuration
   pct exec 102 -- ethtool eth0
   
   # Monitor network usage
   pct exec 102 -- iftop
   ```

### **Log Locations**
- **Samba logs**: `/var/log/samba/`
- **System logs**: `journalctl -u smbd -u nmbd`
- **Container logs**: `pct enter 102` then check logs

## Advanced Configuration
### **Custom Shares**
To add additional shares, edit the Samba configuration:

```bash
pct exec 102 -- nano /etc/samba/smb.conf

# Add new share section
[newshare]
   comment = Custom Share
   path = /path/to/share
   browseable = yes
   writable = yes
   valid users = mediauser

# Restart Media Share
pct exec 102 -- systemctl restart smbd

```
### **Active Directory Integration**
For domain environments, the container can be joined to AD:

```bash
# Install additional packages
pct exec 102 -- apt install krb5-user

# Configure for AD integration
# (Requires additional configuration based on your AD setup)

```
## Integration with Homelab Services
### **Media Server Integration**
- **Jellyfin**: Reads directly from shared media directories
- **Plex**: Can access shares via SMB or direct mount
- **Emby**: Compatible with shared folder structure

### **Download Client Integration**
- **qBittorrent**: Downloads to `/media/downloads` shared folder
- **Transmission**: Can be configured to use shared downloads
- **Usenet clients**: SABnzbd, NZBGet compatible

### **Backup Integration**
The Media Share folders can be included in your Homelab backup strategy:

```bash
# Include in Restic backups
BACKUP_PATHS="/data/docker /media/movies /media/tv /media/music"

```
## Documentation Links
- [Samba/SMB Documentation](https://www.samba.org/samba/docs/)
- [Proxmox LXC Documentation](https://pve.proxmox.com/wiki/Linux_Container)
- [Original Guide Video](https://youtu.be/qmSizZUbCOA?si=qWmb60b_BrFNtoLr)
- [Homelab Main Documentation](../../README.md)

