# 🚀 Single-Subnet Homelab Deployment Guide

## 🎯 Overview

This guide provides complete deployment instructions for both PVE-Homelab and PVE-Gamelab using a unified single-subnet architecture. This approach simplifies network management and reduces hardware costs by using a single unmanaged switch.

---

## 🌐 Network Architecture

### **Single-Subnet Design**
```
Router (192.168.1.1) 
└── Port 1 → Unmanaged Gigabit Switch
    ├── PVE-Homelab (192.168.1.50)
    │   ├── Docker VM (192.168.1.100)
    │   └── LXC Services (192.168.1.201-206)
    │
    └── PVE-Gamelab (192.168.1.51)  
        └── Game Server VM (192.168.1.106)
```

### **IP Allocation Strategy**
- **Core Infrastructure**: 192.168.1.50-99
- **Virtual Machines**: 192.168.1.100-199
- **LXC Services**: 192.168.1.200-254

---

## 🛠️ Hardware Requirements

### **PVE-Homelab (i5-8400)**
- **CPU**: Intel i5-8400 (6 cores)
- **RAM**: 32GB+ recommended
- **Storage**: 2x drives for ZFS mirror
- **Network**: Gigabit Ethernet

### **PVE-Gamelab (i5-6500)**  
- **CPU**: Intel i5-6500 (4 cores)
- **RAM**: 16GB+ recommended
- **Storage**: Single SSD (100GB+)
- **Network**: Gigabit Ethernet

### **Network Equipment**
- **Switch**: Unmanaged 8-port Gigabit switch
- **Router**: Calix GigaSpire BLAST U4 (configured for 192.168.1.x)

---

## 📋 Pre-Installation Checklist

### **Physical Setup**
- [ ] Both machines assembled with adequate cooling
- [ ] Proxmox VE 8.x ISO downloaded and prepared
- [ ] Ethernet cables ready (Cat6 recommended)
- [ ] Unmanaged switch positioned and powered

### **Network Planning**
- [ ] Router configured for 192.168.1.x subnet
- [ ] Static IP reservations planned:
  - [ ] PVE-Homelab: 192.168.1.50
  - [ ] PVE-Gamelab: 192.168.1.51
  - [ ] Game Server VM: 192.168.1.106

### **Repository Access**
- [ ] GitHub access confirmed for both repositories:
  - [ ] `J35867U/homelab` (homelab infrastructure)
  - [ ] `J35867U/gamelab` (game server deployment)

---

## 🖥️ Proxmox Installation

### **Step 1: Install PVE-Homelab (192.168.1.50)**

#### **Boot and Install**
1. Boot from Proxmox VE ISO
2. Follow installation wizard:
   ```
   Hostname: pve-homelab
   IP Address: 192.168.1.50/24
   Gateway: 192.168.1.1
   DNS: 192.168.1.1
   ```

#### **Post-Installation Setup**
```bash
# Update system
apt update && apt upgrade -y

# Remove subscription notice (optional)
sed -Ezi.bak "s/(Ext.Msg.show\(\{\s+title: gettext\('No valid sub)/void\(\{ \/\/\1/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js

# Restart web service
systemctl restart pveproxy
```

### **Step 2: Install PVE-Gamelab (192.168.1.51)**

#### **Boot and Install**
1. Boot from Proxmox VE ISO
2. Follow installation wizard:
   ```
   Hostname: pve-gamelab  
   IP Address: 192.168.1.51/24
   Gateway: 192.168.1.1
   DNS: 192.168.1.1
   ```

#### **Post-Installation Setup**
```bash
# Same updates as PVE-Homelab
apt update && apt upgrade -y
sed -Ezi.bak "s/(Ext.Msg.show\(\{\s+title: gettext\('No valid sub)/void\(\{ \/\/\1/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
systemctl restart pveproxy
```

---

## 🏗️ Infrastructure Deployment

### **Phase 1: Homelab Services (PVE-Homelab)**

#### **Access Homelab Repository**
```bash
# Clone or download the homelab deployment
wget -O deploy_homelab.sh https://raw.githubusercontent.com/J35867U/homelab/main/deploy_homelab.sh
chmod +x deploy_homelab.sh
```

#### **Deploy Core Services**
```bash
# Run the main deployment script
sudo ./deploy_homelab.sh

# Services will be created with these IPs:
# Docker VM:           192.168.1.100
# NPM (Reverse Proxy): 192.168.1.201  
# Tailscale VPN:       192.168.1.202
# Ntfy Notifications:  192.168.1.203
# Samba File Share:    192.168.1.204
# Pi-hole DNS:         192.168.1.205
# Vaultwarden:         192.168.1.206
```

### **Phase 2: Game Server (PVE-Gamelab)**

#### **Create Game Server VM**
```bash
# SSH into PVE-Gamelab
ssh root@192.168.1.51

# Create Ubuntu VM for game server
qm create 106 \
  --name "gamelab-moonlight-stream-106" \
  --memory 16384 \
  --cores 8 \
  --net0 virtio,bridge=vmbr0 \
  --boot c --bootdisk scsi0 \
  --ostype l26 \
  --scsi0 local-lvm:100 \
  --ide2 local:iso/ubuntu-22.04-server-amd64.iso,media=cdrom \
  --agent enabled=1 \
  --cpu host

# Start VM and complete Ubuntu installation
qm start 106
```

#### **Ubuntu Configuration**
During Ubuntu installation, configure network as:
```
IP Address: 192.168.1.106/24  
Gateway: 192.168.1.1
DNS: 192.168.1.205 (Pi-hole) or 192.168.1.1
```

#### **Deploy Game Server Software**
```bash
# SSH into the game server VM
ssh username@192.168.1.106

# Download and run setup script
wget -O setup.sh https://raw.githubusercontent.com/J35867U/gamelab/main/setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

---

## 🔧 Service Configuration

### **Essential Service URLs**
```bash
# Proxmox Management
PVE-Homelab:  https://192.168.1.50:8006
PVE-Gamelab:  https://192.168.1.51:8006

# Core Services  
NPM (Reverse Proxy):    http://192.168.1.201:81
Pi-hole (DNS):          http://192.168.1.205/admin
Ntfy (Notifications):   http://192.168.1.203
Vaultwarden (Passwords): http://192.168.1.206

# Game Services
Game Server Config:     https://192.168.1.106:47990
CoinOps Web Interface:  http://192.168.1.106:8080
```

### **Network Integration Benefits**
- **Same-subnet communication**: All services can directly communicate
- **Simplified firewall rules**: No complex inter-subnet routing  
- **Cost-effective**: Single unmanaged switch handles all traffic
- **Easy troubleshooting**: All devices on same network segment

---

## 📊 Verification & Testing

### **Network Connectivity Tests**
```bash
# Test connectivity from any device:
ping 192.168.1.50  # PVE-Homelab
ping 192.168.1.51  # PVE-Gamelab  
ping 192.168.1.106 # Game Server

# Test service availability:
curl -I http://192.168.1.201:81  # NPM
curl -I http://192.168.1.205     # Pi-hole
curl -I http://192.168.1.106:8080 # CoinOps
```

### **Service Status Checks**
```bash
# On PVE-Homelab, check LXC status:
pct list

# On PVE-Gamelab, check VM status:  
qm list

# Check game server services:
ssh username@192.168.1.106 'sudo systemctl status sunshine'
```

---

## 🔒 Security Configuration

### **Firewall Rules (Optional)**
```bash
# Basic iptables rules for game server:
# Allow Moonlight ports
iptables -A INPUT -p tcp --dport 47984:47989 -j ACCEPT
iptables -A INPUT -p udp --dport 47998:48010 -j ACCEPT

# Allow CoinOps web interface  
iptables -A INPUT -p tcp --dport 8080 -j ACCEPT

# Allow SSH (change default port recommended)
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
```

### **Access Control**
- Use Pi-hole for DNS-based ad blocking
- Configure Vaultwarden for centralized password management  
- Set up Tailscale for secure remote access
- Implement strong passwords for all service accounts

---

## 🚀 Quick Start Deployment

### **Automated Single-Command Deployment**
```bash
# For experienced users - complete deployment:

# 1. Deploy homelab (run on PVE-Homelab):
wget -qO- https://raw.githubusercontent.com/J35867U/homelab/main/deploy_homelab.sh | sudo bash

# 2. Deploy game server (run on game server VM):  
wget -qO- https://raw.githubusercontent.com/J35867U/gamelab/main/setup.sh | sudo bash
```

---

## 📋 Maintenance & Monitoring

### **Health Checks**
```bash
# Weekly system health (can be automated):
./scripts/monitoring/weekly_system_health.sh

# Check game server status:
ssh username@192.168.1.106 './status.sh'

# Monitor storage usage:
df -h  # Check disk space on both hosts
```

### **Backup Strategy**
- **Homelab**: Automated via restic to external storage
- **Game Server**: Optional backup to homelab Samba share (192.168.1.204)
- **Proxmox**: Regular VM/LXC snapshots before updates

### **Update Schedule**
- **Monthly**: Update Proxmox hosts and containers
- **Quarterly**: Review and update game server software
- **As-needed**: Security updates and service configurations

---

## 🎯 Success Criteria

✅ **Deployment Complete When:**
- [ ] Both Proxmox hosts accessible and updated
- [ ] All homelab LXC containers running and configured
- [ ] Game server VM deployed with Moonlight + CoinOps
- [ ] Pi-hole providing DNS resolution across network  
- [ ] Tailscale VPN configured for remote access
- [ ] All service web interfaces accessible
- [ ] Network connectivity verified between all nodes
- [ ] Basic security hardening applied

🎮 **Ready for Gaming When:**
- [ ] Moonlight clients can discover and connect to 192.168.1.106
- [ ] CoinOps web interface accessible at http://192.168.1.106:8080
- [ ] Game streaming performance acceptable (test with simple games first)

🏠 **Homelab Production Ready When:**
- [ ] Jellyfin media server deployed and accessible
- [ ] File sharing operational via Samba
- [ ] Monitoring and alerting functional  
- [ ] Backup systems tested and verified
- [ ] All services documented and configured

**You now have a complete, single-subnet homelab with game server capabilities!** 🎉