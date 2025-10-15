# 🎮 Game Server Single-Subnet Integration Guide

## Network Topology Confirmation

### **Single-Subnet Architecture (FINAL DECISION)**

**Unified Network - All Services:**
- Network: `192.168.1.x` 
- PVE-Homelab: `192.168.1.50` (homelab infrastructure)
- PVE-Gamelab: `192.168.1.51` (game server infrastructure)
- Repository: `J35867U/homelab` ✅ & `J35867U/gamelab` ✅

**Physical Setup:**
- Single unmanaged gigabit switch connected to router port 1
- Both Proxmox hosts on same subnet for simplified management
- Cost-effective solution without dual-subnet complexity

### **Game Server Repository Updates - COMPLETED ✅**

**Updated Configuration:**
```bash
# Game server repo now configured for single subnet
Game Server IP: 192.168.1.106 (updated from 192.168.100.252)
VMID: 106 (updated from 252) 
Network: 192.168.1.x/24
```

**Integration Benefits:**
```bash
# Single-subnet advantages achieved:
MOONLIGHT_PORT="47984"
COINOPS_PORT="8080"
GAME_SERVER_IP="192.168.1.106"  # Updated to single subnet

# Simplified network setup:
- No complex routing between subnets
- Single unmanaged switch deployment
- All services accessible on same network segment
- Cost-effective infrastructure

# Homelab integration on same network:
Ntfy Server: http://192.168.1.203      # Same subnet communication
Backup Target: 192.168.1.204           # Direct network access
Monitoring Hub: 192.168.1.201          # Simplified reverse proxy
```

## Deployment Sequence - Single Subnet

### **Phase 1: Homelab Infrastructure (PVE-Homelab: 192.168.1.50)**
```bash
# Deploy in this order on PVE-Homelab
1. Docker VM (192.168.1.100) 
2. NPM (192.168.1.201) 
3. Tailscale (192.168.1.202)
4. Ntfy (192.168.1.203)
5. Samba (192.168.1.204) 
6. Pi-hole (192.168.1.205)
7. Vaultwarden (192.168.1.206)
```

### **Phase 2: Game Server Infrastructure (PVE-Gamelab: 192.168.1.51)**  
```bash
# Deploy on PVE-Gamelab with single subnet IPs
1. Gaming VM (192.168.1.106) - gamelab-moonlight-stream-106
2. CoinOps LXC (192.168.1.107) - gamelab-coinops-emu-107
3. Game Management (192.168.1.108) - gamelab-game-mgmt-108
4. Game Monitoring (192.168.1.109) - gamelab-monitoring-109
```

## Network Integration - Simplified

### **Same-Subnet Communication**
```bash
# All services on 192.168.1.x network:
NTFY_SERVER=http://192.168.1.203      # Direct access
BACKUP_TARGET=192.168.1.204           # No routing needed
MONITORING_HUB=192.168.1.201          # Same subnet
GAME_SERVER=192.168.1.106             # Direct streaming access
```

## Repository Updates - COMPLETED ✅

### **Single-Subnet Conversion - DONE**

**Files Successfully Updated (192.168.100.252 → 192.168.1.106):**

#### **1. Core Files (IP & VMID Updates) - ✅ COMPLETED:**
- **README.md** - ✅ All references updated to 192.168.1.106, VMID 252→106
- **TROUBLESHOOTING.md** - ✅ Network testing examples updated
- **setup.sh** - ✅ Uses dynamic detection (no hardcoded IPs)
- **status.sh** - ✅ Uses dynamic IP detection

#### **2. Repository Status - ✅ UPDATED & PUSHED:**
```bash
# Changes committed to J35867U/gamelab repository:
✅ IP Address: 192.168.1.106 (single subnet)
✅ VMID: 106 (homelab consistency)
✅ VM Name: gamelab-moonlight-stream-106 
✅ All documentation references updated
✅ Pushed to GitHub main branch
```

#### **3. Network Configuration - Single Subnet:**
```bash
# Static IP configuration for Ubuntu installation:
Address: 192.168.1.106/24
Gateway: 192.168.1.1
DNS: 192.168.1.205 (Pi-hole) or 1.1.1.1
```

#### **4. Client Connection - Updated:**
```bash
# Moonlight client configuration:
Server IP: 192.168.1.106
Web Interface: http://192.168.1.106:8080
Sunshine Config: https://192.168.1.106:47990
```

### **✅ DEPLOYMENT STATUS - BOTH REPOSITORIES READY**

**Repository Status:**
- **homelab**: ✅ **DEPLOYMENT READY** (192.168.1.x subnet)
- **gamelab**: ✅ **DEPLOYMENT READY** (192.168.1.x subnet) - **UPDATED**

**Changes Applied to Game Server Repository:**
- ✅ All IP addresses updated (192.168.100.252 → 192.168.1.106)
- ✅ VMID updated (252 → 106)
- ✅ VM naming updated (gamelab-moonlight-stream-252)
- ✅ Documentation aligned with dual-subnet architecture
- ✅ Network testing examples corrected
- ✅ Client setup instructions updated

**Repository Independence:**
- **No cross-subnet dependencies** - each repo runs independently
- **No shared services** - each manages its own infrastructure  
- **Optional integration only** - document for future reference but not required

### **Step-by-Step Update Process**

#### **Phase 1: Update README.md**
```bash
# Find and replace these specific lines:
Line 40: "192.168.1.106" → "192.168.100.252"
Line 99-126: VM creation commands (VMID 106→252, IP change)
Line 137: "Add server: 192.168.1.106" → "Add server: 192.168.100.252"
Line 151: "http://192.168.1.106:8080" → "http://192.168.100.252:8080"
Line 151: "https://192.168.1.106:47990" → "https://192.168.100.252:47990"
Line 169: Architecture diagram IP update
Line 196: Tailscale integration IP update
Line 240+: Troubleshooting iperf3 command IP update
```

#### **Phase 2: Proxmox VM Creation**
```bash
# New VM creation command for PVE-Gamelab:
qm create 252 \
  --name "gamelab-moonlight-stream-252" \
  --memory 16384 \
  --cores 8 \
  --net0 virtio,bridge=vmbr0 \
  --boot c --bootdisk scsi0 \
  --ostype l26 \
  --scsi0 local-lvm:100 \
  --ide2 local:iso/ubuntu-22.04-server-amd64.iso,media=cdrom \
  --agent enabled=1 \
  --cpu host

# During Ubuntu installation, configure:
# Static IP: 192.168.100.252/24
# Gateway: 192.168.100.1 (adjust for your network)
```

#### **Phase 3: Deploy Game Server**
```bash
# SSH into the VM and run setup:
ssh username@192.168.100.252
wget -O setup.sh https://raw.githubusercontent.com/J35867U/gamelab/main/setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

#### **Phase 4: Update Documentation References**
```bash
# Update any remaining documentation that references old IP:
# - Architecture diagrams
# - Client setup instructions  
# - Network configuration examples
# - Integration documentation
```

### **Optional Integration Updates**

#### **Use Homelab Ntfy Server (Optional):**
```bash
# Update monitoring scripts to use homelab Ntfy:
# In scripts/monitoring/weekly_health.sh:
NTFY_SERVER="http://192.168.1.203"  # Your homelab Ntfy
NTFY_TOPIC="gamelab-alerts"

# In scripts/backup/daily_backup.sh:
NTFY_SERVER="http://192.168.1.203"
NTFY_TOPIC_ALERTS="gamelab-backup-alerts"
```

#### **Cross-Subnet Backup (Optional):**
```bash
# Enable backup to homelab Samba share:
BACKUP_TARGET="//192.168.1.204/gamelab-backups"
# Requires SMB mount configuration
```
---

## 🎯 Final Status - Single Subnet Conversion Complete ✅

### **✅ DEPLOYMENT READY - Both Repositories Updated****Repository Status:**
- **homelab**: ✅ Ready (192.168.1.x subnet)
- **gamelab**: ✅ Updated & Pushed (192.168.1.x subnet)

**Network Architecture - Single Subnet:**
```bash
# Unified 192.168.1.x network:
PVE-Homelab:    192.168.1.50
PVE-Gamelab:    192.168.1.51  
Game Server VM: 192.168.1.106 (VMID 106)
All Services:   192.168.1.100-254
```

**Benefits Achieved:**
- ✅ Cost-effective single switch deployment
- ✅ Simplified network management
- ✅ Direct service communication (no routing)
- ✅ Consistent IP/VMID mapping across infrastructure

**Ready for Fresh Proxmox Installation with Single Switch Setup**
