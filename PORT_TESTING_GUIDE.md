# 🌐 Port Testing & Network Diagnostics Guide

## 📋 Overview

This guide provides comprehensive methods to test if your homelab ports are properly exposed and accessible from the internet, including both internal and external testing approaches.

---

## 🔍 **Quick Port Testing Methods**

### **🌐 External Port Checkers (Easiest)**

#### **Online Port Testing Services:**
```bash
# Test specific ports from external perspective
https://www.yougetsignal.com/tools/open-ports/
https://canyouseeme.org/
https://portchecker.co/
https://www.portchecktool.com/

# Usage:
1. Enter your public IP address (whatismyipaddress.com)
2. Enter the port number you want to test
3. Click "Check Port" 
4. Should show "Open" if properly forwarded
```

#### **Command Line External Testing:**
```bash
# From an external machine/VPS (not your home network)
nmap -p [port] [your-public-ip]
telnet [your-public-ip] [port]
nc -zv [your-public-ip] [port]

# Example:
nmap -p 8096 203.0.113.1  # Test Jellyfin port
telnet 203.0.113.1 443    # Test HTTPS port
```

---

## 🏠 **Internal Network Testing**

### **🔧 Test Container Ports Locally**

#### **Test Individual Container Services:**
```bash
# Test from Proxmox host or any local machine
curl -I http://192.168.1.201:81      # Nginx Proxy Manager
curl -I http://192.168.1.203         # Ntfy notifications
curl -I http://192.168.1.205/admin   # Pi-hole admin panel
curl -I http://192.168.1.206         # Vaultwarden

# Expected response: HTTP/1.1 200 OK (or similar)
```

#### **Port Scanning Internal Network:**
```bash
# Scan all your homelab container ports
nmap -p 80,81,443,53,8080,8096 192.168.1.201-206

# Detailed scan with service detection
nmap -sV -p- 192.168.1.201  # Scan all ports on NPM

# Quick connectivity test
nc -zv 192.168.1.205 53     # Test Pi-hole DNS
nc -zv 192.168.1.201 81     # Test NPM admin
```

---

## 🎯 **Router Port Forwarding Examples**

### **Common Ports to Forward:**
```bash
# External Port → Internal IP:Port
80  → 192.168.1.201:80    # HTTP to Nginx Proxy Manager
443 → 192.168.1.201:443   # HTTPS to Nginx Proxy Manager  
81  → 192.168.1.201:81    # NPM Admin Panel (optional)
8096 → 192.168.1.100:8096 # Jellyfin (if using Docker host)

# Custom application ports as needed
5055 → 192.168.1.100:5055 # Jellyseerr
8989 → 192.168.1.100:8989 # Sonarr
7878 → 192.168.1.100:7878 # Radarr
```

### **Your Homelab Port Map:**
```bash
# LXC Container Ports (Internal Access)
192.168.1.201:81   # Nginx Proxy Manager Admin
192.168.1.202:22   # Tailscale (SSH access)
192.168.1.203:80   # Ntfy notifications
192.168.1.204:445  # Media File Share (SMB)
192.168.1.205:53   # Pi-hole DNS
192.168.1.205:80   # Pi-hole web admin
192.168.1.206:80   # Vaultwarden web interface
```

---

## 📱 **Mobile Testing Apps**

### **Android Apps:**
- **Network Analyzer** (WiFi network scanning)
- **Port Authority** (Port scanning)
- **Fing** (Network discovery)

### **iOS Apps:**  
- **Network Analyzer** (Network diagnostics)
- **iNet** (Network scanner)
- **Scany** (Port scanner)

---

## 🛠️ **Advanced Testing Commands**

### **Detailed Port Scanning:**
```bash
# Comprehensive homelab scan
nmap -sV -sC -p- 192.168.1.201-206

# Test specific service with headers
curl -v http://192.168.1.201:81

# Test HTTPS certificate
openssl s_client -connect yourdomain.com:443 -servername yourdomain.com

# Test DNS with different record types
dig @192.168.1.205 yourdomain.com A
dig @192.168.1.205 yourdomain.com MX
dig @192.168.1.205 yourdomain.com TXT
```

### **Network Performance Testing:**
```bash
# Bandwidth test between containers
iperf3 -s # On one container
iperf3 -c 192.168.1.201 # From another

# Latency testing
ping -c 10 192.168.1.205
traceroute 192.168.1.201

# DNS resolution speed
time dig @192.168.1.205 google.com
```

---

## 🛠️ **Automated Testing Script**

I've created a comprehensive testing script at `scripts/monitoring/homelab_network_test.sh` that will:

- ✅ **Auto-detect your public IP**
- ✅ **Test all internal service connectivity**
- ✅ **Check HTTP responses from web services**
- ✅ **Verify DNS functionality through Pi-hole**
- ✅ **Test external port accessibility**
- ✅ **Generate comprehensive summary report**

### **Usage:**
```bash
# Make executable and run
chmod +x scripts/monitoring/homelab_network_test.sh
./scripts/monitoring/homelab_network_test.sh

# Expected output:
# 🔍 Homelab Network Connectivity Test
# [INFO] Detecting public IP address...
# [✓] Public IP detected: XXX.XXX.XXX.XXX
# [INFO] Testing nginx-proxy-manager (192.168.1.201:81)...
# [✓] nginx-proxy-manager is accessible
# ... (detailed test results)
```

---

## 🚨 **Troubleshooting Common Issues**

### **Port Not Accessible Externally:**
```bash
# Check if service is running
systemctl status nginx  # Or service-specific command
docker ps | grep container-name

# Check if port is listening
netstat -tlnp | grep :80
ss -tlnp | grep :443

# Check firewall rules
ufw status verbose
iptables -L -n

# Test from internal network first
curl -I http://192.168.1.201:81
```

### **Router/Firewall Issues:**
```bash
# Check if ISP blocks ports
telnet portquiz.net 80   # Should connect if port 80 is not blocked
telnet portquiz.net 443  # Test HTTPS
telnet portquiz.net 22   # Test SSH

# Common blocked ports by ISPs:
# 25 (SMTP), 80 (HTTP), 135, 139, 445 (SMB), 1900 (UPnP)
```

### **DNS Issues:**
```bash
# Test if Pi-hole is resolving
dig @192.168.1.205 google.com

# Test local domain resolution
dig @192.168.1.205 pihole.local
dig @192.168.1.205 vault.local

# Check Pi-hole status
pct exec 205 -- pihole status
```

---

## 🎯 **Quick Testing Workflow**

### **1. Internal Testing First:**
```bash
# Run the automated script
./scripts/monitoring/homelab_network_test.sh

# Or manual quick tests:
curl -I http://192.168.1.201:81  # NPM admin
curl -I http://192.168.1.205/admin  # Pi-hole
curl -I http://192.168.1.206  # Vaultwarden
```

### **2. External Testing:**
```bash
# Get your public IP
curl https://ifconfig.me

# Test with online tools:
# https://www.yougetsignal.com/tools/open-ports/
# Enter your public IP and port numbers

# Or from external machine:
nmap -p 80,443,8096 YOUR_PUBLIC_IP
```

### **3. DNS Testing:**
```bash
# Test local DNS resolution
dig @192.168.1.205 pihole.local
dig @192.168.1.205 vault.local
dig @192.168.1.205 media.local

# Test external DNS
dig @192.168.1.205 google.com
dig @192.168.1.205 github.com
```

---

## 📊 **Monitoring Integration**

### **Uptime Monitoring:**
```bash
# Add to cron for regular testing
0 */6 * * * /path/to/homelab_network_test.sh >> /var/log/network_test.log

# Integrate with Ntfy for alerts
curl -d "Port test failed" http://192.168.1.203/homelab-alerts
```

### **Grafana Dashboard Metrics:**
- Port response times
- Service availability percentages  
- External accessibility status
- DNS resolution performance

---

## 🔐 **Security Considerations**

### **Port Exposure Best Practices:**
```bash
# Only expose necessary ports
# Use non-standard ports when possible
# Always use HTTPS for web services
# Implement proper authentication
# Use VPN (Tailscale) for sensitive services
```

### **Recommended External Exposure:**
```bash
# Safe to expose:
80/443 → Nginx Proxy Manager (with proper SSL)

# Use VPN for:
- Container admin panels (NPM admin, Pi-hole admin)
- Internal file shares (SMB)
- Database services
- Monitoring dashboards
```

---

## 🎉 **Ready to Test Your Ports!**

### **Quick Start Checklist:**
- [ ] **Run automated script**: `./scripts/monitoring/homelab_network_test.sh`
- [ ] **Test externally**: Use https://www.yougetsignal.com/tools/open-ports/
- [ ] **Configure port forwarding**: Set up router rules for external access
- [ ] **Verify DNS**: Test Pi-hole local domain resolution
- [ ] **Monitor continuously**: Set up automated testing and alerts

### **Common Test Results:**
- ✅ **Internal services accessible**: All containers responding properly
- ✅ **DNS working**: Pi-hole resolving internal and external domains  
- ⚠️ **External ports closed**: Normal if port forwarding not configured
- ❌ **Service not responding**: Check container status and firewall

Your homelab network testing toolkit is ready! Use the automated script for comprehensive testing, and online tools for external verification. 🚀

---

## 📞 **Need Help?**

- 🔧 **Script Issues**: Check dependencies with `apt install netcat-openbsd curl dnsutils`
- 🌐 **External Access**: Verify router port forwarding configuration  
- 🕳️ **DNS Problems**: Check Pi-hole status with `pct exec 205 -- pihole status`
- 🔒 **Security Questions**: Use Tailscale VPN for secure remote access

**Happy port testing!** 🎯