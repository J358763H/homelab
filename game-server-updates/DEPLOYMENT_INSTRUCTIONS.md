# 🚀 Game Server Repository Deployment Instructions

## 📋 **Overview**
This directory contains the updated files needed to make your game server repository deployment-ready for the dual-subnet architecture (192.168.100.x network).

## 📁 **Updated Files Included**

### **Core Documentation:**
- `README.md` - Updated with all IP references changed from 192.168.1.106 → 192.168.100.252
- `TROUBLESHOOTING.md` - Updated network testing examples and IP references

### **Key Changes Made:**
✅ **VMID**: Changed from 106 → 252  
✅ **IP Address**: Updated from 192.168.1.106 → 192.168.100.252  
✅ **VM Name**: Updated to `gamelab-moonlight-stream-252`  
✅ **Network Testing**: Updated all iperf3 and connectivity examples  
✅ **Client Setup**: Updated Moonlight connection instructions  
✅ **Web Interfaces**: Updated all URL references  

## 🎯 **Deployment Process**

### **Method 1: Replace Files Directly**
```bash
# 1. Navigate to your game server repository
cd /path/to/your/game-server/

# 2. Backup original files (optional)
cp README.md README.md.backup
cp TROUBLESHOOTING.md TROUBLESHOOTING.md.backup

# 3. Copy updated files
cp /path/to/homelab-deployment/game-server-updates/README.md .
cp /path/to/homelab-deployment/game-server-updates/TROUBLESHOOTING.md .

# 4. Commit changes
git add .
git commit -m "🌐 Update for dual-subnet deployment (192.168.100.252)"
git push
```

### **Method 2: Manual Updates**
If you prefer to update manually, here are the specific changes needed:

#### **README.md Updates:**
```bash
# Find and replace these specific text:
"192.168.1.106" → "192.168.100.252"
"VMID**: 106" → "VMID**: 252"
"qm create 106" → "qm create 252"
"--name \"game-server\"" → "--name \"gamelab-moonlight-stream-252\""
"Intel i5-8400" → "Intel i5-6500"
```

#### **TROUBLESHOOTING.md Updates:**
```bash
# Find and replace:
"192.168.1.106" → "192.168.100.252"
"telnet 192.168.1.106" → "telnet 192.168.100.252"
"iperf3 -c 192.168.1.106" → "iperf3 -c 192.168.100.252"
```

## 🖥️ **VM Creation Command**

**Updated Proxmox VM creation for PVE-Gamelab:**
```bash
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
```

## 🌐 **Network Configuration**

**During Ubuntu 22.04 installation, configure:**
- **IP Address**: 192.168.100.252/24
- **Gateway**: 192.168.100.1 (adjust for your network)
- **DNS**: 192.168.100.1 or 1.1.1.1
- **Hostname**: gamelab-moonlight-stream

## 🔗 **Service URLs**

**After deployment, services will be accessible at:**
- **CoinOps Web Interface**: http://192.168.100.252:8080
- **Moonlight GameStream**: 192.168.100.252:47984
- **Sunshine Config**: https://192.168.100.252:47990
- **SSH Access**: ssh username@192.168.100.252

## ✅ **Verification Steps**

### **1. Repository Status Check:**
```bash
# Verify all IP references updated
grep -r "192.168.1.106" .
# Should return no results

# Verify new IPs present
grep -r "192.168.100.252" .
# Should show multiple matches
```

### **2. Deployment Test:**
```bash
# SSH into VM and run setup
ssh username@192.168.100.252
wget -O setup.sh https://raw.githubusercontent.com/J35867U/game-server/main/setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

### **3. Service Verification:**
```bash
# Check services are running
./status.sh

# Test web interface
curl http://192.168.100.252:8080
```

## 🎮 **Client Setup**

**Update your Moonlight clients:**
1. Open Moonlight client application
2. **Remove old server**: 192.168.1.106 (if present)
3. **Add new server**: 192.168.100.252
4. **Pair with server** using PIN from web interface
5. **Start streaming** games!

## 📊 **Repository Status**

### **Before Updates:**
❌ Hardcoded for single subnet (192.168.1.x)  
❌ VMID 106 conflicts with homelab range  
❌ VM naming not consistent with dual-subnet approach  

### **After Updates:**
✅ **Configured for dual-subnet** (192.168.100.x)  
✅ **VMID 252** - proper game server range  
✅ **Consistent naming**: gamelab-moonlight-stream-252  
✅ **Documentation aligned** with network topology  
✅ **Deployment ready** for PVE-Gamelab  

## 🚀 **Final Notes**

- **setup.sh script** uses dynamic IP detection - no changes needed ✅
- **monitoring scripts** use hostname -I - automatically work ✅  
- **Only documentation** needed IP address updates
- **Repository independence** maintained - works standalone
- **Optional integration** with homelab Ntfy documented but not required

**Your game server repository will now be deployment-ready for the dual-subnet architecture!** 🎮