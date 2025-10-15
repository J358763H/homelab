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

### **Complete Game Server Repository Update Plan**

**Files that need IP address updates (192.168.1.106 → 192.168.100.252):**

#### **1. Core Files (IP & VMID Updates):**
- **README.md** - Multiple references in setup guide, client instructions, management URLs
- **setup.sh** - Main installation script (no IP hardcoding found - uses dynamic detection ✅)
- **status.sh** - Status monitoring script (uses dynamic IP detection ✅)

#### **2. Documentation Files:**
- **README.md Lines 40, 99-126, 137-169** - Architecture diagram, VM setup guide, client setup
- **TROUBLESHOOTING.md Line 240+** - Network testing examples
- **CHANGELOG.md** - No IP updates needed ✅

#### **3. Scripts Directory:**
**✅ Monitoring Scripts** (use dynamic IP detection - no hardcoded IPs):
- `scripts/monitoring/weekly_health.sh` - Uses hostname -I (dynamic)
- `scripts/backup/daily_backup.sh` - No IP references
- `scripts/maintenance/cleanup.sh` - No IP references

**⚠️  NTFY Integration** - Optional update needed:
```bash
# In weekly_health.sh and backup scripts:
NTFY_SERVER="https://ntfy.sh"  # Currently uses public server
# Option to change to homelab:
NTFY_SERVER="http://192.168.1.203"  # Your homelab Ntfy
```

#### **4. VM Creation Commands:**
```bash
# Update Proxmox VM creation:
qm create 106 → qm create 252
--name "game-server" → --name "gamelab-moonlight-stream-252"
IP: 192.168.1.106 → 192.168.100.252
```

#### **5. Network Configuration Updates:**
```bash
# Static IP configuration during Ubuntu installation:
Address: 192.168.100.252/24
Gateway: 192.168.100.1 (or your game server subnet gateway)
DNS: 192.168.100.1 or 1.1.1.1
```

#### **6. Client Connection Updates:**
```bash
# Moonlight client configuration:
Server IP: 192.168.100.252
Web Interface: http://192.168.100.252:8080
Sunshine Config: https://192.168.100.252:47990
```

### **Repository Independence**

**Keep Repositories Completely Separate:**
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
wget -O setup.sh https://raw.githubusercontent.com/J35867U/game-server/main/setup.sh
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