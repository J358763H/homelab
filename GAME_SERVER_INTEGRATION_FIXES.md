# 🎮 Game Server Dual-Subnet Integration Guide

## Network Topology Confirmation

### **Dual-Subnet Architecture (FINAL)**

**Homelab Network (PVE-Homelab):**
- Proxmox Host: `192.168.1.50`
- Services: `192.168.1.100-254`
- Repository: `J35867U/homelab-SHV` ✅

**Game Server Network (PVE-Gamelab):**
- Proxmox Host: `192.168.100.50` 
- Services: `192.168.100.50-254`
- Repository: `J35867U/game-server` (needs IP updates)

### **Game Server Repository Updates Required**

**Current State:**
```bash
# Game server repo currently expects single subnet
Expected IP: 192.168.1.106 (old assumption)
Target IP: 192.168.100.252 (dual-subnet correct)
VMID: 252 (gamelab naming convention)
```

**Integration Fixes Needed:**
```bash
# 1. Update game-server/setup.sh 
MOONLIGHT_PORT="47984"
COINOPS_PORT="8080"
EXPECTED_IP="192.168.100.252"  # Update from 192.168.1.106

# 2. Update game-server documentation
VM Setup Guide needs IP change:
- Old: qm create 106 --name "game-server" 
- New: qm create 252 --name "gamelab-moonlight-stream-252"

# 3. Update homelab integration references
Ntfy Server: http://192.168.1.203  # homelab-ntfy-notify-203
Backup Integration: Use 192.168.1.x for homelab services
```

## Deployment Sequence Updates

### **Phase 1: Homelab Infrastructure (192.168.1.50)**
```bash
# Deploy in this order on PVE-Homelab
1. Docker VM (192.168.1.100) 
2. NPM (192.168.1.201) 
3. Tailscale (192.168.1.202)
4. Ntfy (192.168.1.203) - FIXED IP
5. Samba (192.168.1.204) - FIXED naming
6. Pi-hole (192.168.1.205)
7. Vaultwarden (192.168.1.206)
```

### **Phase 2: Game Server (192.168.100.50)**  
```bash
# Deploy on PVE-Gamelab with corrected IP schema
1. Windows Gaming VM (192.168.100.252) - Moonlight host
2. CoinOps LXC (192.168.100.253) 
3. Game Management (192.168.100.254)
4. Game Monitoring (192.168.100.255)
```

## Network Integration

### **Cross-Subnet Communication**
```bash
# Homelab services that game server needs to access:
NTFY_SERVER=http://192.168.1.203      # Notifications  
BACKUP_TARGET=192.168.1.204           # Samba share for backups
MONITORING_HUB=192.168.1.201          # NPM for reverse proxy
```

## Required Repository Updates

### **Required Changes for Game Server Repository**

**Update these files in `J35867U/game-server` when deploying:**

1. **IP Address Updates:**
```bash
# Find and replace in all files:
192.168.1.106 → 192.168.100.252
192.168.1.xxx → 192.168.100.xxx (any homelab references)
```

2. **VM Creation Scripts:**
```bash
# Update VM creation command:
qm create 106 → qm create 252
--name "game-server" → --name "gamelab-moonlight-stream-252"
```

3. **Network Configuration:**
```bash
# Update network interfaces and gateway:
IP_ADDRESS="192.168.100.252/24"
GATEWAY="192.168.100.1"
BRIDGE="vmbr0"
```

4. **Service Ports & Firewall:**
```bash
# Update firewall rules for 192.168.100.x subnet
# Ensure game streaming ports accessible from both subnets
```

### **Repository Independence**

**Keep Repositories Completely Separate:**
- **No cross-subnet dependencies** - each repo runs independently
- **No shared services** - each manages its own infrastructure  
- **Optional integration only** - document for future reference but not required

### **Deployment Strategy**
```bash
# Phase 1: Deploy homelab-SHV (192.168.1.x subnet)
cd /homelab-SHV && ./deploy_homelab.sh

# Phase 2: Update & deploy game-server (192.168.100.x subnet) 
cd /game-server && ./setup.sh  # After IP updates
```