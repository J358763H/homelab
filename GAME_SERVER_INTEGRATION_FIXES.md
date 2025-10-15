# 🎮 Game Server Network Integration Fixes

## Current Inconsistencies

### **Game Server Repository (J35867U/game-server)**

**Hardcoded IP Issues:**
```bash
# Found in game-server repo setup.sh and documentation
- Expected IP: 192.168.1.106 
- New topology: 192.168.100.252 (gamelab subnet)
- VMID should be: 252 (not 106)
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

### **Game Server Repo Fixes** 
```bash
# These changes need to be made to J35867U/game-server:

1. setup.sh - Update IP expectations
2. README.md - Update VM creation examples  
3. scripts/monitoring/* - Update Ntfy server references
4. scripts/backup/* - Update backup target paths
5. All documentation - IP schema alignment
```

### **Integration Scripts**
Create cross-subnet integration scripts for:
- Backup sync from game server to homelab Samba
- Monitoring data relay to homelab monitoring stack
- Notifications routing through homelab Ntfy