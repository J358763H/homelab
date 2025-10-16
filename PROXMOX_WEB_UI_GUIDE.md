# 🌐 Proxmox Web UI Homelab Deployment Guide

## 🚀 **One-Command Homelab Deployment**

Perfect for deploying your homelab directly from the Proxmox web interface shell!

### **🎯 Quick Deploy (Copy & Paste into Proxmox Web UI Shell):**

```bash
wget -O deploy.sh https://raw.githubusercontent.com/J358763H/homelab/main/proxmox-deploy-homelab.sh && chmod +x deploy.sh && ./deploy.sh
```

**That's it!** This single command will:
- ✅ Download the deployment script
- ✅ Install Docker and dependencies
- ✅ Clone your homelab repository
- ✅ Deploy all services automatically
- ✅ Show status and access information

---

## 📋 **Deployment Options**

### **Full Deployment (Recommended)**
```bash
wget -O deploy.sh https://raw.githubusercontent.com/J358763H/homelab/main/proxmox-deploy-homelab.sh && chmod +x deploy.sh && ./deploy.sh
```

### **Download Repository Only**
```bash
./deploy.sh --download-only
```

### **Deploy Existing Repository**
```bash
./deploy.sh --deploy-only
```

### **Skip Dependency Installation**
```bash
./deploy.sh --no-deps
```

---

## 🏠 **Post-Deployment Access**

After successful deployment, access your services via:

### **Core Services**
- **Gluetun VPN**: Provides secure tunnel for download clients
- **FlareSolverr**: Cloudflare bypass service

### **Download Services**
- **qBittorrent**: `http://PROXMOX-IP:8080`
- **NZBGet**: `http://PROXMOX-IP:6789`

### **Media Services**
- **Jellyfin**: `http://PROXMOX-IP:8096`
- **Prowlarr**: `http://PROXMOX-IP:9696`
- **Sonarr**: `http://PROXMOX-IP:8989`
- **Radarr**: `http://PROXMOX-IP:7878`
- **Bazarr**: `http://PROXMOX-IP:6767`
- **JellyStat**: `http://PROXMOX-IP:3001`

### **Optional LXC Services** (if deployed)
- **Nginx Proxy Manager**: `http://PROXMOX-IP:81`
- **Pi-hole**: `http://PROXMOX-IP/admin`
- **Vaultwarden**: `http://PROXMOX-IP:8080`
- **Ntfy**: `http://PROXMOX-IP:8080`

---

## 🔧 **Management Commands**

### **Check Status**
```bash
cd /opt/homelab && ./setup/status.sh
```

### **View Container Logs**
```bash
docker logs <container-name>
```

### **Restart Services**
```bash
cd /opt/homelab/containers/core && docker-compose restart
cd /opt/homelab/containers/downloads && docker-compose restart
cd /opt/homelab/containers/media && docker-compose restart
```

### **Stop All Services**
```bash
cd /opt/homelab/containers/core && docker-compose down
cd /opt/homelab/containers/downloads && docker-compose down
cd /opt/homelab/containers/media && docker-compose down
```

### **Update Homelab**
```bash
cd /opt/homelab && git pull origin main
```

---

## 🌐 **Proxmox Web UI Advantages**

✅ **Direct Host Access** - Deploy directly on Proxmox host
✅ **No SSH Required** - Use built-in web shell
✅ **Real-time Output** - See deployment progress instantly
✅ **Easy Copy/Paste** - Simple command execution
✅ **Persistent Sessions** - Web UI maintains connection
✅ **Full Control** - Complete access to Proxmox host

---

## 🚨 **Troubleshooting**

### **If deployment fails:**
1. Check Docker status: `systemctl status docker`
2. Check network connectivity: `ping google.com`
3. Check disk space: `df -h`
4. View deployment logs: `journalctl -xe`

### **Common fixes:**
```bash
# Restart Docker
systemctl restart docker

# Fix permissions
chmod +x /opt/homelab/setup/*.sh

# Rerun deployment
cd /opt/homelab && ./setup/deploy-all.sh
```

---

## 🎯 **Perfect for Proxmox Web UI!**

This deployment method is specifically optimized for the Proxmox web interface shell, providing:

- **Single command deployment**
- **No external tools required**
- **Automatic dependency installation**
- **Clean error handling**
- **Status reporting**

**Your homelab is now ready to deploy with just one command in the Proxmox web UI!** 🚀
