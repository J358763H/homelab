# 🕳️ Pi-hole LXC Container

## 📋 Overview

Pi-hole provides network-wide ad blocking and DNS management for your homelab. This LXC container setup integrates seamlessly with your existing Homelab-SHV infrastructure, providing DNS filtering, custom domain resolution, and comprehensive network analytics.

## 🎯 Features

### 🛡️ **Network Protection**
- **Network-wide ad blocking** - Blocks ads on all devices automatically
- **Malware protection** - Prevents access to known malicious domains
- **Tracker blocking** - Stops tracking scripts and analytics
- **Custom blacklists** - Add your own blocked domains
- **Whitelist management** - Override blocks for trusted sites

### 🌐 **DNS Management**
- **Custom local domains** - Resolve homelab services by name
- **Upstream DNS selection** - Choose your preferred DNS providers
- **DNS over HTTPS/TLS** - Encrypted DNS queries (configurable)
- **Conditional forwarding** - Route specific domains to local DNS
- **DHCP integration** - Assign IP addresses and hostnames

### 📊 **Monitoring & Analytics**
- **Real-time query logs** - See all DNS requests live
- **Detailed statistics** - Traffic patterns and blocking effectiveness
- **Top blocked domains** - Identify most common blocked requests
- **Client analytics** - Per-device blocking and query statistics
- **Historical data** - Long-term trend analysis

## 🏗️ Architecture Integration

### 📡 **Network Configuration**
```
Container IP: 192.168.1.205
Web Interface: http://192.168.1.205/admin
Local Domain: http://pihole.local/admin
DNS Port: 53 (TCP/UDP)
Web Port: 80 (HTTP)
```

### 🔗 **Homelab Integration**
- **192.168.1.201** - Nginx Proxy Manager (reverse proxy)
- **192.168.1.202** - Tailscale (VPN subnet router)
- **192.168.1.203** - Ntfy (notifications)
- **192.168.1.204** - Media File Share (media sharing)
- **192.168.1.205** - **Pi-hole (DNS/ad blocking)**

### 🌐 **DNS Resolution Chain**
```
Client Device → Pi-hole (192.168.1.205) → Upstream DNS (1.1.1.1/8.8.8.8)
                    ↓
               Local Services
               npm.local → 192.168.1.201
               ntfy.local → 192.168.1.203
               media.local → 192.168.1.204
```

## 🚀 Quick Start

### 📋 **Prerequisites**
- ✅ Proxmox VE host with LXC support
- ✅ Network: 192.168.1.0/24 configured
- ✅ Internet connectivity for downloads
- ✅ Root access to Proxmox host

### ⚡ **One-Command Setup**
```bash
# On your Proxmox host (as root)
cd /path/to/homelab-deployment
chmod +x lxc/pihole/setup_pihole_lxc.sh
./lxc/pihole/setup_pihole_lxc.sh
```

### 🎯 **What Gets Installed**
1. **Ubuntu 22.04 LTS** LXC container
2. **Pi-hole DNS server** with web interface
3. **Lighttpd web server** for admin panel
4. **Automatic blocklist updates** via cron
5. **Custom DNS records** for homelab services
6. **Firewall configuration** for security

## 📊 Configuration Details

### 🔧 **Default Settings**
| Setting | Value | Description |
|---------|-------|-------------|
| **Container ID** | 205 | LXC container identifier |
| **IP Address** | 192.168.1.205 | Static IP assignment |
| **Memory** | 1024MB | RAM allocation |
| **Storage** | 8GB | Disk space |
| **Admin Password** | admin123 | ⚠️ **Change this!** |
| **Upstream DNS** | 1.1.1.1, 8.8.8.8 | Cloudflare & Google |

### 🏠 **Local DNS Records**
Pre-configured homelab service resolution:
```dns
192.168.1.201  npm.local proxy.local
192.168.1.202  tailscale.local
192.168.1.203  ntfy.local
192.168.1.204  media.local
192.168.1.205  pihole.local dns.local
```

## 🛠️ Advanced Configuration

### 🔒 **Security Hardening**

#### **Change Default Password**
```bash
# Connect to container
pct exec 205 -- bash

# Change Pi-hole admin password
pihole -a -p your-secure-password-here

# Or use web interface
# Go to Settings → Change Password
```

#### **Enable HTTPS** (Optional)
```bash
# Install SSL certificate
pct exec 205 -- bash -c "
apt update && apt install -y certbot
certbot certonly --standalone -d pihole.yourdomain.com
"

# Configure lighttpd for HTTPS
pct exec 205 -- bash -c "
cat >> /etc/lighttpd/conf-available/10-ssl.conf << 'EOF'
\$HTTP[\"host\"] == \"pihole.yourdomain.com\" {
  \$SERVER[\"socket\"] == \":443\" {
    ssl.engine = \"enable\"
    ssl.pemfile = \"/etc/letsencrypt/live/pihole.yourdomain.com/fullchain.pem\"
    ssl.privkey = \"/etc/letsencrypt/live/pihole.yourdomain.com/privkey.pem\"
  }
}
EOF

# Enable SSL module
lighty-enable-mod ssl
systemctl reload lighttpd
"
```

### 📡 **DNS over HTTPS (DoH) Setup**
```bash
# Install cloudflared for DoH
pct exec 205 -- bash -c "
wget -O cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
dpkg -i cloudflared.deb

# Configure cloudflared
cat > /etc/default/cloudflared << 'EOF'
CLOUDFLARED_OPTS=--port 5053 --upstream https://1.1.1.1/dns-query --upstream https://1.0.0.1/dns-query
EOF

# Create systemd service
cat > /etc/systemd/system/cloudflared.service << 'EOF'
[Unit]
Description=cloudflared DNS over HTTPS proxy
After=syslog.target network-online.target

[Service]
Type=simple
User=cloudflared
EnvironmentFile=/etc/default/cloudflared
ExecStart=/usr/local/bin/cloudflared proxy-dns \$CLOUDFLARED_OPTS
Restart=on-failure
RestartSec=10
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF

# Create user and start service
useradd -s /usr/sbin/nologin -r -M cloudflared
systemctl enable cloudflared
systemctl start cloudflared
"

# Update Pi-hole to use DoH
# Web Interface: Settings → DNS → Custom 1: 127.0.0.1#5053
```

### 📊 **Monitoring Integration**

#### **Log Management**
```bash
# Configure log rotation
pct exec 205 -- bash -c "
cat > /etc/logrotate.d/pihole << 'EOF'
/var/log/pihole.log {
    daily
    missingok
    rotate 52
    compress
    notifempty
    create 644 pihole pihole
    postrotate
        systemctl restart pihole-FTL
    endscript
}
EOF
"
```

#### **Health Check Script**
```bash
# Create health monitoring script
pct exec 205 -- bash -c "
cat > /usr/local/bin/pihole-health-check.sh << 'EOF'
#!/bin/bash

# Pi-hole health check script
LOG_FILE=\"/var/log/pihole-health.log\"
TIMESTAMP=\$(date '+%Y-%m-%d %H:%M:%S')

# Check Pi-hole FTL service
if ! systemctl is-active --quiet pihole-FTL; then
    echo \"\$TIMESTAMP ERROR: Pi-hole FTL service is not running\" >> \$LOG_FILE
    systemctl restart pihole-FTL
fi

# Check web interface
if ! curl -s http://localhost/admin/api.php > /dev/null; then
    echo \"\$TIMESTAMP ERROR: Pi-hole web interface not responding\" >> \$LOG_FILE
    systemctl restart lighttpd
fi

# Check DNS resolution
if ! nslookup google.com localhost > /dev/null 2>&1; then
    echo \"\$TIMESTAMP ERROR: DNS resolution not working\" >> \$LOG_FILE
fi

# Log successful check
echo \"\$TIMESTAMP INFO: Pi-hole health check passed\" >> \$LOG_FILE
EOF

chmod +x /usr/local/bin/pihole-health-check.sh

# Add to crontab
echo '*/5 * * * * /usr/local/bin/pihole-health-check.sh' | crontab -
"
```

## 🔧 Management & Maintenance

### 📋 **Common Commands**
```bash
# Connect to Pi-hole container
pct exec 205 -- bash

# Check Pi-hole status
pihole status

# Update gravity (blocklists)
pihole -g

# Restart DNS service
pihole restartdns

# View real-time logs
tail -f /var/log/pihole.log

# Check service status
systemctl status pihole-FTL lighttpd

# Backup Pi-hole configuration
pihole -a teleporter
```

### 🔄 **Updates & Maintenance**
```bash
# Update Pi-hole
pihole -up

# Update system packages
apt update && apt upgrade -y

# Clean up old logs
logrotate -f /etc/logrotate.d/pihole

# Restart container (from Proxmox host)
pct restart 205
```

### 📊 **Performance Monitoring**
```bash
# Check resource usage
pct exec 205 -- bash -c "
echo 'CPU Usage:'; top -bn1 | grep 'Cpu(s)'
echo 'Memory Usage:'; free -h
echo 'Disk Usage:'; df -h /
echo 'DNS Queries Today:'; pihole -c -j | jq '.dns_queries_today'
"
```

## 🌐 Network Integration

### 🏠 **Router Configuration**
To enable network-wide ad blocking:

1. **Access your router's admin panel**
2. **Navigate to DHCP/DNS settings**
3. **Set primary DNS server**: `192.168.1.205`
4. **Set secondary DNS server**: `1.1.1.1` (backup)
5. **Save and restart router**

### 📱 **Device-Specific Setup**
For devices that don't use router DNS:

#### **Windows**
```cmd
# Set DNS via PowerShell (as Administrator)
netsh interface ip set dns "Wi-Fi" static 192.168.1.205
netsh interface ip add dns "Wi-Fi" 1.1.1.1 index=2
```

#### **Linux/macOS**
```bash
# Edit resolv.conf
sudo nano /etc/resolv.conf

# Add these lines:
nameserver 192.168.1.205
nameserver 1.1.1.1
```

#### **Mobile Devices**
- **iOS**: Settings → Wi-Fi → [Network] → Configure DNS → Manual
- **Android**: Settings → Wi-Fi → [Network] → Advanced → DNS

## 🎭 Customization

### 🚫 **Custom Blocklists**
Popular additional blocklists:

```url
# Malware & Security
https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts

# Social Media Blocking
https://someonewhocares.org/hosts/zero/hosts

# Cryptocurrency Mining
https://zerodot1.gitlab.io/CoinBlockerLists/hosts_browser

# Add via: Settings → Blocklists → Add Custom List
```

### ✅ **Whitelist Management**
```bash
# Whitelist specific domains
pihole -w google-analytics.com
pihole -w facebook.com
pihole -w youtube.com

# Whitelist entire domain and subdomains
pihole -w -wild amazon.com
```

### 🏠 **Local Domain Resolution**
```bash
# Add custom local records
pct exec 205 -- bash -c "
echo '192.168.1.100 homeassistant.local' >> /etc/pihole/custom.list
echo '192.168.1.150 plex.local' >> /etc/pihole/custom.list
pihole restartdns
"
```

## 🔍 Troubleshooting

### ❌ **Common Issues**

#### **Pi-hole Web Interface Not Loading**
```bash
# Check lighttpd service
pct exec 205 -- systemctl status lighttpd

# Restart web server
pct exec 205 -- systemctl restart lighttpd

# Check port binding
pct exec 205 -- netstat -tlnp | grep :80
```

#### **DNS Not Resolving**
```bash
# Check Pi-hole FTL service
pct exec 205 -- systemctl status pihole-FTL

# Test DNS resolution
pct exec 205 -- nslookup google.com localhost

# Check upstream DNS
pct exec 205 -- pihole -q google.com
```

#### **High Memory Usage**
```bash
# Check memory usage
pct exec 205 -- free -h

# Restart Pi-hole service
pct exec 205 -- systemctl restart pihole-FTL

# Increase container memory if needed (from Proxmox host)
pct set 205 --memory 2048
pct restart 205
```

### 📞 **Support Resources**
- **Pi-hole Documentation**: https://docs.pi-hole.net/
- **Community Forum**: https://discourse.pi-hole.net/
- **GitHub Issues**: https://github.com/pi-hole/pi-hole/issues
- **Homelab Integration**: See main repository documentation

## 📈 Performance & Analytics

### 📊 **Key Metrics to Monitor**
- **Queries blocked percentage** (target: 15-25%)
- **Response time** (should be < 50ms)
- **Memory usage** (should stay under 80%)
- **Disk usage** (logs can grow large)

### 🎯 **Optimization Tips**
1. **Regular updates** - Keep blocklists current
2. **Log rotation** - Prevent disk space issues  
3. **Memory monitoring** - Increase if needed
4. **Network placement** - Minimize DNS latency
5. **Backup configuration** - Export settings regularly

---

## 🎊 **Ready to Block Ads!**

Your Pi-hole LXC container is now ready to provide network-wide ad blocking and DNS management for your entire homelab. Access the web interface at **http://192.168.1.205/admin** to start customizing your filtering preferences!

**Next Steps:**
1. 🔧 Configure your router to use Pi-hole as primary DNS
2. 📊 Monitor the admin dashboard for blocking statistics
3. 🛡️ Customize blocklists and whitelists as needed
4. 🔗 Integrate with your reverse proxy for HTTPS access