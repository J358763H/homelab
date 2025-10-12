# 🌐 Homelab IP Addressing & Naming Convention

## 📋 **Overview**
This document defines the standardized IP addressing and naming scheme for the entire homelab infrastructure, where IP addresses correspond to VMIDs for easy organization.

---

## 🎯 **IP Addressing Strategy**

### **Core Principle:** `192.168.1.XXX = VMID XXX`
- **Benefit**: Instant visual correlation between IP and container/VM ID
- **Example**: Container 205 → IP 192.168.1.205
- **Range**: 192.168.1.100-254 for infrastructure

---

## 🏗️ **Infrastructure Layout**

### **🖥️ Physical Infrastructure (100-149)**
```bash
# Proxmox Nodes & Core Infrastructure
192.168.1.100    # VMID 100 - Docker Host VM (Primary)
192.168.1.101    # VMID 101 - Docker Host VM (Secondary/Backup)
192.168.1.102    # VMID 102 - TrueNAS/Storage VM
192.168.1.103    # VMID 103 - Home Assistant VM
192.168.1.104    # VMID 104 - OpenWRT/pfSense VM
192.168.1.105    # VMID 105 - Monitoring VM (Grafana/Prometheus)
192.168.1.110    # VMID 110 - Development VM
192.168.1.115    # VMID 115 - Testing/Staging VM
192.168.1.120    # VMID 120 - Backup/Archive VM
```

### **🏠 Core Services LXC (200-219)**
```bash
# Essential Infrastructure Services
192.168.1.201    # VMID 201 - Nginx Proxy Manager (Reverse Proxy & SSL)
192.168.1.202    # VMID 202 - Tailscale VPN Router (Secure Remote Access)
192.168.1.203    # VMID 203 - Ntfy Notifications (Alert System)
192.168.1.204    # VMID 204 - Media File Share (Samba/NFS)
192.168.1.205    # VMID 205 - Pi-hole DNS (Ad Blocking & Local DNS)
192.168.1.206    # VMID 206 - Vaultwarden (Password Manager)
```

### **🔧 Extended Services LXC (220-249)**
```bash
# Additional Infrastructure Services
192.168.1.220    # VMID 220 - Uptime Kuma (Service Monitoring)
192.168.1.221    # VMID 221 - Portainer (Container Management)
192.168.1.222    # VMID 222 - Authentik (Single Sign-On)
192.168.1.223    # VMID 223 - Netdata (System Monitoring)
192.168.1.224    # VMID 224 - Ansible Control Node (Automation)
192.168.1.225    # VMID 225 - GitLab/Gitea (Code Repository)
192.168.1.226    # VMID 226 - Jenkins/GitHub Actions Runner (CI/CD)
192.168.1.227    # VMID 227 - LDAP/FreeIPA (Directory Services)
192.168.1.228    # VMID 228 - Elastic Stack (Logging)
192.168.1.229    # VMID 229 - Zabbix/PRTG (Network Monitoring)
```

### **🎮 Application Services LXC (250-279)**
```bash
# Application-Specific Services
192.168.1.250    # VMID 250 - Minecraft Server
192.168.1.251    # VMID 251 - Nextcloud (Personal Cloud)
192.168.1.252    # VMID 252 - Bookstack (Documentation)
192.168.1.253    # VMID 253 - Calibre Web (E-book Library)
192.168.1.254    # VMID 254 - Photoprism (Photo Management)
```

---

## 🏷️ **Naming Convention**

### **🖥️ Virtual Machines**
```bash
# Format: [purpose]-[location]-[number]
docker-homelab-100          # Primary Docker host
storage-homelab-102         # TrueNAS storage
homeassistant-homelab-103   # Home automation
firewall-homelab-104        # Network security
monitor-homelab-105         # System monitoring
```

### **📦 LXC Containers**
```bash
# Format: [service]-[environment]-[vmid]
nginx-proxy-201             # Reverse proxy
tailscale-vpn-202          # VPN router
ntfy-notify-203            # Notification service
media-share-204            # File sharing
pihole-dns-205             # DNS & ad blocking
vaultwarden-pass-206       # Password manager
uptime-monitor-220         # Service monitoring
portainer-mgmt-221         # Container management
```

### **🌐 DNS Names (via Pi-hole)**
```bash
# Short names for easy access
npm.local           → 192.168.1.201
proxy.local         → 192.168.1.201
vpn.local           → 192.168.1.202
tailscale.local     → 192.168.1.202
notify.local        → 192.168.1.203
ntfy.local          → 192.168.1.203
files.local         → 192.168.1.204
media.local         → 192.168.1.204
dns.local           → 192.168.1.205
pihole.local        → 192.168.1.205
vault.local         → 192.168.1.206
passwords.local     → 192.168.1.206
```

---

## 🔄 **Migration Plan**

### **Current → New IP Mapping**
Your current setup is already well-organized! Here's what needs updating:

#### **✅ Already Perfect (No Changes Needed):**
```bash
201 → 192.168.1.201 ✅ (Nginx Proxy Manager)
202 → 192.168.1.202 ✅ (Tailscale)  
203 → 192.168.1.203 ✅ (Ntfy)
205 → 192.168.1.205 ✅ (Pi-hole)
206 → 192.168.1.206 ✅ (Vaultwarden)
```

#### **🔧 Needs Update:**
```bash
# Media Share container
Current: Container 204 → IP 192.168.1.102
New:     Container 204 → IP 192.168.1.204

# This is the only change needed!
```

---

## ⚙️ **Implementation Steps**

### **Step 1: Update Media Share Container IP**
```bash
# Stop the container
pct stop 204

# Update network configuration
pct set 204 --net0 name=eth0,bridge=vmbr0,ip=192.168.1.204/24,gw=192.168.1.1

# Update Pi-hole DNS record
pct exec 205 -- bash -c "
sed -i 's/192.168.1.102 media.local/192.168.1.204 media.local/' /etc/pihole/custom.list
pihole restartdns
"

# Start container
pct start 204
```

### **Step 2: Update Documentation**
All setup scripts and documentation will be updated to reflect the new IP scheme.

### **Step 3: Future VM Allocation**
```bash
# When creating new VMs/containers, use:
VMID=220  # For new service
IP="192.168.1.220"  # Matching IP

# Example command:
pct create 220 template --net0 ip=192.168.1.220/24,gw=192.168.1.1
```

---

## 📋 **Benefits of This Scheme**

### **🎯 Immediate Benefits:**
- **Visual Correlation**: VMID 205 = IP .205 (instant recognition)
- **Easy Troubleshooting**: No IP lookup needed
- **Scalable**: Room for 154 VMs/containers (100-254)
- **Organized**: Clear separation by service type

### **🔧 Operational Benefits:**
- **Consistent Commands**: `pct exec 205` for container with IP .205
- **Easy DNS**: All local domains predictably resolve
- **Network Planning**: Clear IP ranges for different purposes
- **Documentation**: Self-documenting infrastructure

### **🚀 Future-Proof:**
- **Growth Ready**: Clear allocation for new services
- **Standardized**: New team members understand immediately
- **Maintainable**: Consistent patterns across all infrastructure

---

## 🎨 **Naming Scheme Options**

### **Option A: Service-Focused (Recommended)**
```bash
nginx-proxy-201         # Clear service identification
pihole-dns-205         # Function obvious from name
vaultwarden-pass-206   # Type and purpose clear
```

### **Option B: Short & Simple**
```bash
npm-201                # Abbreviated but recognizable
dns-205                # Simple and direct
vault-206              # Short but clear
```

### **Option C: Environment-Aware**
```bash
prod-nginx-201         # Environment prefix
homelab-pihole-205     # Location context
main-vault-206         # Instance identifier
```

---

## 🌐 **DNS Integration**

### **Pi-hole Custom Records** (Auto-configured)
```bash
# /etc/pihole/custom.list
192.168.1.201 npm.local proxy.local
192.168.1.202 vpn.local tailscale.local
192.168.1.203 notify.local ntfy.local
192.168.1.204 files.local media.local share.local
192.168.1.205 dns.local pihole.local
192.168.1.206 vault.local passwords.local
```

### **Reverse DNS** (Optional Enhancement)
```bash
# /etc/hosts or DNS server
201.1.168.192.in-addr.arpa. PTR nginx-proxy-201.homelab.local
202.1.168.192.in-addr.arpa. PTR tailscale-vpn-202.homelab.local
205.1.168.192.in-addr.arpa. PTR pihole-dns-205.homelab.local
```

---

## 🎊 **Ready to Implement!**

Your current setup is already 90% aligned with best practices! Only the Media Share container needs an IP update from .102 to .204 to achieve perfect VMID-to-IP correlation.

**Would you like me to:**
1. **Update the Media Share container IP** to match VMID 204?
2. **Create updated setup scripts** with the new IP scheme?
3. **Generate a network diagram** showing the complete layout?
4. **Implement the naming convention** across all containers?

This scheme will give you a perfectly organized, scalable infrastructure! 🚀