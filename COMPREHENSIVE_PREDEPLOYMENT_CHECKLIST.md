===============================================
🚀 UPDATED PRE-DEPLOYMENT CHECKLIST 
===============================================
Complete ALL items before deployment on BOTH machines
Last Updated: October 14, 2025

===============================================
🖥️ PROXMOX INFRASTRUCTURE SETUP
===============================================

PVE-Homelab (192.168.1.50):
□ Proxmox VE 8.x installed and accessible
□ Static IP configured: 192.168.1.50
□ SSH root access working
□ Storage configured (NVMe + HDDs per hardware spec)
□ Internet connectivity verified
□ NTP sync verified

PVE-Gamelab (192.168.100.50):
□ Proxmox VE 8.x installed and accessible  
□ Static IP configured: 192.168.100.50
□ SSH root access working
□ Storage configured for VMs
□ Internet connectivity verified
□ Hardware acceleration ready (if applicable)

===============================================
📦 HOMELAB DOCKER VM PREPARATION 
===============================================
On PVE-Homelab, create Docker VM (VMID 100):

# Create Docker host VM
qm create 100 \
  --name "docker-homelab-100" \
  --memory 16384 \
  --cores 8 \
  --net0 virtio,bridge=vmbr0 \
  --boot c --bootdisk scsi0 \
  --ostype l26 \
  --scsi0 local-lvm:100 \
  --ide2 local:iso/ubuntu-22.04-server-amd64.iso,media=cdrom \
  --agent enabled=1 \
  --cpu host

VM Configuration:
□ Ubuntu 22.04 LTS Server installed
□ Static IP: 192.168.1.100
□ SSH server enabled
□ User created and configured for sudo
□ Docker installed and working
□ Git installed

Required Directories:
□ /data/docker created
□ /data/media created  
□ /data/backups created
□ Proper permissions set (1000:1000)

===============================================
🎮 GAME SERVER VM PREPARATION
===============================================
On PVE-Gamelab, create Game Server VM (VMID 252):

# Create Windows gaming VM or Ubuntu for CoinOps
qm create 252 \
  --name "gamelab-moonlight-stream-252" \
  --memory 16384 \
  --cores 8 \
  --net0 virtio,bridge=vmbr0 \
  --boot c --bootdisk scsi0 \
  --ostype win11 \
  --scsi0 local-lvm:200 \
  --agent enabled=1 \
  --cpu host

Game Server Requirements:
□ OS installed (Windows 11 or Ubuntu 22.04)
□ Static IP: 192.168.100.252
□ Moonlight/Sunshine installed
□ Network ports configured (47984-47990)
□ Graphics drivers installed
□ Game libraries configured

===============================================
📋 CONFIGURATION FILES CHECKLIST
===============================================

Homelab Configuration:
□ deployment/.env file created from .env.example
□ deployment/wg0.conf created from wg0.conf.example  
□ VPN credentials configured in .env
□ All API keys and passwords set
□ Backup configuration completed
□ Ntfy notifications configured

Required .env Variables:
□ TZ (timezone)
□ PUID/PGID (1000/1000)
□ VPN_SERVICE_PROVIDER configured
□ WIREGUARD keys set
□ DB passwords set
□ NTFY_SERVER=http://192.168.1.203  
□ NTFY_TOPIC configured
□ RESTIC backup settings
□ JELLYFIN_PUBLISHED_SERVER_URL

===============================================
🌐 DUAL-SUBNET NETWORK VERIFICATION  
===============================================

**Network Topology (FINAL):**
□ **PVE-Homelab**: 192.168.1.50 (homelab infrastructure subnet)
□ **PVE-Gamelab**: 192.168.100.50 (game server infrastructure subnet)
□ Router/switch configured for dual-subnet topology
□ Each subnet operates independently (no cross-dependencies)
□ Internet connectivity verified on both subnets

LXC IP Assignments (Homelab):
□ 192.168.1.201 - homelab-nginx-proxy-201
□ 192.168.1.202 - homelab-tailscale-vpn-202  
□ 192.168.1.203 - homelab-ntfy-notify-203
□ 192.168.1.204 - homelab-media-share-204
□ 192.168.1.205 - homelab-pihole-dns-205
□ 192.168.1.206 - homelab-vaultwarden-pass-206

Game Server IPs:
□ 192.168.100.252 - gamelab-moonlight-stream-252
□ 192.168.100.253 - gamelab-coinops-emu-253  
□ 192.168.100.254 - gamelab-game-mgmt-254
□ 192.168.100.255 - gamelab-monitoring-255

===============================================
🔑 SECURITY & AUTHENTICATION
===============================================

SSH Configuration:
□ SSH keys configured for both Proxmox hosts
□ SSH keys configured for Docker VM
□ SSH keys configured for Game Server VM
□ Root login properly secured
□ Fail2ban configured (optional)

VPN & Remote Access:
□ Tailscale auth key obtained
□ Tailscale configured for subnet routing
□ VPN provider credentials ready
□ Wireguard configuration tested

Passwords & Keys:
□ Strong passwords generated for all services
□ Database passwords configured
□ API keys obtained (if using external services)
□ Backup encryption keys generated
□ Vaultwarden admin token ready

===============================================
📦 SOFTWARE INSTALLATION VERIFICATION
===============================================

On Docker VM (192.168.1.100):
□ Docker Engine installed and running
□ Docker Compose plugin installed
□ Git installed and configured
□ Required system packages installed:
  - curl, wget, htop, nano, rsync
  - lm-sensors, smartmontools
  - zfsutils-linux (if using ZFS)

On Proxmox Hosts:
□ Latest Proxmox updates applied
□ Container templates downloaded:
  - ubuntu-22.04-standard template
□ ISO images available:
  - Ubuntu 22.04 LTS Server
  - Windows 11 (if needed)

===============================================
🔄 BACKUP & STORAGE VERIFICATION  
===============================================

Storage Configuration:
□ ZFS pools configured (if applicable)
□ Backup destinations configured
□ Restic repository initialized
□ Backup retention policies set
□ Test backup/restore completed

Network Storage:
□ SMB/NFS shares accessible
□ Proper permissions configured
□ Media library structure created
□ Download directories configured

===============================================
🚀 DEPLOYMENT READINESS TEST
===============================================

Final Verification:
□ All IP addresses pinged successfully
□ SSH access verified to all systems
□ Internet connectivity on all systems
□ DNS resolution working
□ Time synchronization verified
□ Resource availability confirmed (CPU, RAM, Disk)

Pre-deployment Commands:
□ git clone repository successful
□ ./homelab.sh script executable
□ All LXC setup scripts executable
□ No syntax errors in configuration files

===============================================
✅ DEPLOYMENT ORDER  
===============================================

Phase 1 - Homelab Infrastructure:
1. Deploy Docker stack: ./deploy_homelab.sh
2. Deploy NPM: ./lxc/nginx-proxy-manager/setup_npm_lxc.sh
3. Deploy Tailscale: ./lxc/tailscale/setup_tailscale_lxc.sh  
4. Deploy Ntfy: ./lxc/ntfy/setup_ntfy_lxc.sh
5. Deploy Samba: ./lxc/samba/setup_samba_lxc.sh
6. Deploy Pi-hole: ./lxc/pihole/setup_pihole_lxc.sh
7. Deploy Vaultwarden: ./lxc/vaultwarden/setup_vaultwarden_lxc.sh

Phase 2 - Game Server (Separate Repository):
1. Update game-server repository IP addresses (192.168.1.x → 192.168.100.x)
2. Create gaming VM on PVE-Gamelab (VMID 252, IP 192.168.100.252)
3. Install Moonlight/Sunshine for game streaming
4. Deploy CoinOps emulation platform  
5. Configure independent monitoring and backup

Phase 3 - Independent Operation:
1. Verify homelab services (192.168.1.x) operate independently
2. Verify game server services (192.168.100.x) operate independently  
3. Test each subnet's functionality separately
4. Document access URLs for both networks

===============================================
🎯 SUCCESS CRITERIA
===============================================

Deployment Complete When:
□ All containers/VMs running successfully
□ Web interfaces accessible from management machine
□ Backup system operational
□ Monitoring alerts working
□ Game streaming functional (if applicable)
□ All services responding to health checks
□ Documentation updated with final configuration

===============================================