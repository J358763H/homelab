# 🌐 Dual-Subnet Deployment Guide
## Current Network Configuration
**Physical Setup:**
- **PVE-Homelab**: 192.168.1.50 (Main services & media)
- **PVE-Gamelab**: 192.168.100.50 (Gaming & emulation)

**Network Topology:**

```
Router
├── Port 1 → 192.168.1.x subnet
│   └── PVE-Homelab (192.168.1.50)
│       ├── Docker VM (192.168.1.100)
│       └── LXC Services (192.168.1.201+)
│
└── Port 2 → 192.168.100.x subnet
    └── PVE-Gamelab (192.168.100.50)
        └── Game Services (192.168.100.252+)

```
## Deployment Strategy
### Phase 1: Homelab Services (192.168.1.x)

Deploy on **PVE-Homelab** (192.168.1.50):

1. **Docker VM** (VMID 100, IP 192.168.1.100)
   - Jellyfin media server
   - Servarr stack (Sonarr, Radarr, etc.)
   - Download clients (qBittorrent)

2. **LXC Infrastructure Services:**
   - `homelab-nginx-proxy-201` (192.168.1.201)
   - `homelab-tailscale-vpn-202` (192.168.1.202) 
   - `homelab-ntfy-notify-203` (192.168.1.203)
   - `homelab-media-share-204` (192.168.1.204)
   - `homelab-pihole-dns-205` (192.168.1.205)
   - `homelab-vaultwarden-pass-206` (192.168.1.206)

### Phase 2: Game Server Services (192.168.100.x)

Deploy on **PVE-Gamelab** (192.168.100.50):

1. **Game Server VM** (VMID 252, IP 192.168.100.252)
   - Moonlight GameStream server
   - NVIDIA/AMD GPU passthrough
   - Windows VM for games

2. **Emulation LXC Services:**
   - `gamelab-coinops-emu-253` (192.168.100.253)
   - `gamelab-game-mgmt-254` (192.168.100.254)
   - `gamelab-monitoring-255` (192.168.100.255)

## Access URLs
### Homelab Services

```bash
# Proxmox Management
https://192.168.1.50:8006

# Media Services  
http://192.168.1.100:8096    # Jellyfin
http://192.168.1.100:8989    # Sonarr
http://192.168.1.100:7878    # Radarr

# Infrastructure Services
http://192.168.1.201:81      # Nginx Proxy Manager
http://192.168.1.203:80      # Ntfy
http://192.168.1.205/admin   # Pi-hole
http://192.168.1.206:80      # Vaultwarden

```
### Game Server Services

```bash
# Proxmox Management
https://192.168.100.50:8006

# Game Services
http://192.168.100.252:47989 # Moonlight Web UI
http://192.168.100.253:80    # CoinOps Web Interface
http://192.168.100.254:3000  # Game Management Dashboard
http://192.168.100.255:8080  # Game Server Monitoring

```
## Network Considerations
### Inter-Subnet Communication

- **Current**: Isolated subnets (good for security)
- **Future**: Gigabit switch can unify networks if needed

### Port Forwarding (if needed)

```bash
# For external access to Moonlight
Router → 47989 → 192.168.100.252:47989

# For external media access via Tailscale
Tailscale → 192.168.1.202 → homelab services

```
### DNS Configuration

- **Pi-hole** (192.168.1.205) can serve both subnets if router allows
- **Local DNS entries** for easy access:

  ```
  homelab.local     → 192.168.1.50
  gamelab.local     → 192.168.100.50
  jellyfin.local    → 192.168.1.100
  moonlight.local   → 192.168.100.252
  ```

## Deployment Commands
### Deploy Homelab Stack

```bash
# On PVE-Homelab (192.168.1.50)
cd /root
git clone https://github.com/J35867U/homelab-SHV.git
cd homelab-SHV
./deploy_homelab.sh

```
### Deploy Game Server Stack  

```bash
# On PVE-Gamelab (192.168.100.50)
cd /root
git clone https://github.com/J35867U/homelab-SHV.git
cd homelab-SHV/game-server-deployment
./scripts/standalone-deploy.sh

```
## Future Expansion
### Unified Network (with Gigabit Switch)

```
Gigabit Switch
├── PVE-Homelab    → 192.168.1.50
├── PVE-Gamelab    → 192.168.1.51  
├── Network Storage → 192.168.1.52
└── Other devices  → 192.168.1.x

```
### Clustering (optional)

```bash
# Create cluster on homelab
pvecm create homelab-cluster

# Join gamelab to cluster (if on same network)
pvecm add 192.168.1.50

```
