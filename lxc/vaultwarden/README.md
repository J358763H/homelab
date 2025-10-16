# 🔐 Vaultwarden LXC Container
## 📋 Overview
Vaultwarden is a lightweight, self-hosted Bitwarden-compatible password manager written in Rust. This LXC container setup provides enterprise-grade password management with maximum security isolation, integrating seamlessly with your Homelab infrastructure.

## 🎯 Features
### 🛡️ **Security & Privacy**

- **Self-hosted** - Complete control over your password data
- **End-to-end encryption** - Passwords encrypted before leaving your device
- **Zero-knowledge architecture** - Server never sees your master password
- **Bitwarden compatibility** - Use official Bitwarden apps and extensions
- **Two-factor authentication** - TOTP, WebAuthn, YubiKey support
- **Secure password sharing** - Encrypted organization vaults

### 🌐 **Web Vault Features**

- **Modern web interface** - Full-featured password management
- **Real-time sync** - Instant updates across all devices
- **Password generator** - Strong, unique passwords for every account
- **Secure notes** - Encrypted storage for sensitive information
- **File attachments** - Store encrypted files and documents
- **Password health** - Identify weak, reused, or compromised passwords

### 📱 **Multi-Platform Support**

- **Browser extensions** - Chrome, Firefox, Safari, Edge
- **Mobile apps** - iOS and Android (official Bitwarden apps)
- **Desktop applications** - Windows, macOS, Linux
- **CLI tool** - Command-line interface for automation
- **API access** - REST API for custom integrations

## 🏗️ Architecture Integration
### 📡 **Network Configuration**

```
Container IP: 192.168.1.206
Web Interface: http://192.168.1.206
Local Domain: http://vault.local
Admin Panel: http://192.168.1.206/admin
HTTP Port: 80 (internal Nginx)
HTTPS Port: 443 (when SSL configured)
WebSocket Port: 3012 (for real-time notifications)

```
### 🔗 **Homelab Integration**

- **192.168.1.201** - Nginx Proxy Manager (SSL termination)
- **192.168.1.202** - Tailscale (secure remote access)
- **192.168.1.203** - Ntfy (backup notifications)
- **192.168.1.204** - Media File Share (backup storage)
- **192.168.1.205** - Pi-hole (local DNS resolution)
- **192.168.1.206** - **Vaultwarden (password management)** ✨

### 🔒 **Security Architecture**

```
Internet → Tailscale VPN → Nginx Proxy Manager → Vaultwarden LXC
    ↓           ↓                    ↓                 ↓
SSL Tunnel → Authentication → SSL Termination → Local HTTP

```
## 🚀 Quick Start
### 📋 **Prerequisites**

- ✅ Proxmox VE host with LXC support
- ✅ Network: 192.168.1.0/24 configured
- ✅ 2GB+ RAM available for container
- ✅ 20GB+ storage for container and data
- ✅ Root access to Proxmox host

### ⚡ **One-Command Setup**

```bash
# On your Proxmox host (as root)
cd /path/to/homelab-deployment
chmod +x lxc/vaultwarden/setup_vaultwarden_lxc.sh
./lxc/vaultwarden/setup_vaultwarden_lxc.sh

```
### 🎯 **What Gets Installed**

1. **Ubuntu 22.04 LTS** LXC container with security hardening
2. **Rust toolchain** for compiling Vaultwarden from source
3. **Vaultwarden server** with SQLite database
4. **Bitwarden web vault** for browser access
5. **Nginx reverse proxy** with SSL preparation
6. **Automated backups** and health monitoring
7. **Firewall configuration** for security
8. **Log rotation** and system monitoring

## 📊 Configuration Details
### 🔧 **Default Settings**

| Setting | Value | Description |
|---------|-------|-------------|
| **Container ID** | 206 | LXC container identifier |
| **IP Address** | 192.168.1.206 | Static IP assignment |
| **Memory** | 2048MB | RAM allocation |
| **Storage** | 20GB | Disk space for data |
| **Database** | SQLite | Local database file |
| **Signups** | Disabled | Enable temporarily for setup |
| **Web Vault** | Enabled | Browser interface |
| **WebSocket** | Enabled | Real-time notifications |

### 🏠 **Local DNS Integration**

Pre-configured with Pi-hole for easy access:

```dns
192.168.1.206  vault.local vaultwarden.local

```
## 🛠️ Initial Setup
### 🎯 **First-Time Configuration**
#### **1. Access Admin Panel**

```bash
# Open in browser
http://192.168.1.206/admin

# Use generated admin token (displayed after setup)
# Example: Admin token will be shown in setup output

```
#### **2. Enable Signups Temporarily**

```bash
# Connect to container
pct exec 206 -- bash

# Edit configuration
nano /opt/vaultwarden/.env

# Change this line:
SIGNUPS_ALLOWED=true

# Restart service
systemctl restart vaultwarden

```
#### **3. Create Your First User**

```bash
# Open web vault
http://192.168.1.206

# Click "Create Account"
# Use a strong master password
# Save your master password securely!

```
#### **4. Disable Signups (Security)**

```bash
# Edit configuration again
nano /opt/vaultwarden/.env

# Change back to:
SIGNUPS_ALLOWED=false

# Restart service
systemctl restart vaultwarden

```
### 📧 **SMTP Configuration**

For email notifications and password resets:

```bash
# Edit configuration
pct exec 206 -- nano /opt/vaultwarden/.env

# Uncomment and configure SMTP settings:
SMTP_HOST=smtp.gmail.com
SMTP_FROM=vaultwarden@yourdomain.com
SMTP_PORT=587
SMTP_SECURITY=starttls
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-app-password

# Restart to apply changes
pct exec 206 -- systemctl restart vaultwarden

```
## 🔒 Security Hardening
### 🛡️ **SSL/HTTPS Setup**
#### **Option 1: Via Nginx Proxy Manager (Recommended)**

```bash
# Add new proxy host in NPM (192.168.1.201)
Domain: vault.yourdomain.com
Forward Hostname: 192.168.1.206
Forward Port: 80

# Enable SSL with Let's Encrypt
# Force SSL: ON
# HTTP/2 Support: ON
# HSTS: ON

```
#### **Option 2: Local SSL Certificate**

```bash
# Connect to container
pct exec 206 -- bash

# Generate SSL certificate with Certbot
certbot certonly --standalone -d vault.yourdomain.com

# Update Nginx configuration
nano /etc/nginx/sites-available/vaultwarden

# Uncomment HTTPS server block and update paths
# Restart Nginx
systemctl restart nginx

```
### 🔐 **Additional Security Measures**
#### **Admin Token Security**

```bash
# Rotate admin token periodically
pct exec 206 -- bash

# Generate new token
NEW_TOKEN=$(openssl rand -base64 48 | tr -d "=+/" | cut -c1-64)

# Update configuration
sed -i "s/ADMIN_TOKEN=.*/ADMIN_TOKEN=$NEW_TOKEN/" /opt/vaultwarden/.env

# Restart service
systemctl restart vaultwarden

echo "New admin token: $NEW_TOKEN"

```
#### **Firewall Rules**

```bash
# Additional security rules
pct exec 206 -- bash

# Allow only from specific networks
ufw delete allow 80/tcp
ufw delete allow 443/tcp

# Allow only from homelab network
ufw allow from 192.168.1.0/24 to any port 80
ufw allow from 192.168.1.0/24 to any port 443

# Allow from Tailscale network (adjust subnet as needed)
ufw allow from 100.64.0.0/10 to any port 80
ufw allow from 100.64.0.0/10 to any port 443

```
#### **Rate Limiting**

```bash
# Add rate limiting to Nginx
pct exec 206 -- bash

# Edit Nginx configuration
nano /etc/nginx/sites-available/vaultwarden

# Add to server block:
# limit_req_zone $binary_remote_addr zone=login:10m rate=1r/s;
# 
# location /api/accounts/prelogin {
#     limit_req zone=login burst=5 nodelay;
#     proxy_pass http://127.0.0.1:8080;
# }

```
## 💾 Backup & Recovery
### 🔄 **Automated Backups**

Backups run daily at 2 AM automatically:

```bash
# Manual backup
pct exec 206 -- /usr/local/bin/vaultwarden-backup.sh

# List backups
pct exec 206 -- ls -la /opt/vaultwarden/backups/

# Backup contains:
# - SQLite database
# - Configuration files
# - User attachments
# - Log files

```
### 🏥 **Disaster Recovery**
#### **Container Backup (Proxmox)**

```bash
# Create container snapshot
vzdump 206 --mode snapshot --storage local-lvm

# Restore from snapshot
qmrestore /path/to/backup.tar.gz 206

```
#### **Data Recovery**

```bash
# Stop Vaultwarden service
pct exec 206 -- systemctl stop vaultwarden

# Restore from backup
pct exec 206 -- bash -c "
cd /opt/vaultwarden
tar -xzf backups/vaultwarden_backup_YYYYMMDD_HHMMSS.tar.gz
chown -R vaultwarden:vaultwarden data .env
"

# Start service
pct exec 206 -- systemctl start vaultwarden

```
### 📤 **External Backup Strategy**

```bash
# Copy backups to external storage
pct exec 206 -- bash -c "
# Mount external storage (Media share)
mkdir -p /mnt/backup
mount -t cifs //192.168.1.204/backups /mnt/backup -o username=backup,password=your-password

# Copy latest backup
cp /opt/vaultwarden/backups/vaultwarden_backup_*.tar.gz /mnt/backup/

# Unmount
umount /mnt/backup
"

```
## 🔧 Management & Maintenance
### 📋 **Common Commands**

```bash
# Connect to Vaultwarden container
pct exec 206 -- bash

# Check service status
systemctl status vaultwarden nginx

# View Vaultwarden logs
tail -f /opt/vaultwarden/data/vaultwarden.log

# View Nginx logs
tail -f /var/log/nginx/access.log

# Restart services
systemctl restart vaultwarden nginx

# Check database size
du -sh /opt/vaultwarden/data/

# View active connections
ss -tlnp | grep -E ':80|:443|:8080|:3012'

```
### 🔄 **Updates & Maintenance**
#### **Update Vaultwarden**

```bash
# Connect to container
pct exec 206 -- bash

# Switch to vaultwarden user
sudo -u vaultwarden bash
cd /home/vaultwarden/vaultwarden

# Pull latest changes
git pull

# Update Rust toolchain
source ~/.cargo/env
rustup update stable

# Rebuild Vaultwarden
cargo build --features sqlite,web-vault --release

# Stop service (as root)
exit
systemctl stop vaultwarden

# Update binary
cp /home/vaultwarden/vaultwarden/target/release/vaultwarden /opt/vaultwarden/bin/

# Update web vault
cd /tmp
VAULT_VERSION=$(curl -s https://api.github.com/repos/dani-garcia/bw_web_builds/releases/latest | grep 'tag_name' | cut -d'"' -f4)
wget https://github.com/dani-garcia/bw_web_builds/releases/download/$VAULT_VERSION/bw_web_$VAULT_VERSION.tar.gz
rm -rf /opt/vaultwarden/web-vault/*
tar -xzf bw_web_$VAULT_VERSION.tar.gz -C /opt/vaultwarden/web-vault --strip-components=1
chown -R vaultwarden:vaultwarden /opt/vaultwarden/web-vault

# Start service
systemctl start vaultwarden

```
#### **System Updates**

```bash
# Update container OS
pct exec 206 -- bash -c "
apt update && apt upgrade -y
apt autoremove -y
"

# Restart container (from Proxmox host)
pct restart 206

```
### 📊 **Performance Monitoring**

```bash
# Check resource usage
pct exec 206 -- bash -c "
echo 'CPU Usage:'; top -bn1 | grep 'Cpu(s)'
echo 'Memory Usage:'; free -h
echo 'Disk Usage:'; df -h /opt/vaultwarden/data
echo 'Active Users:'; sqlite3 /opt/vaultwarden/data/db.sqlite3 'SELECT COUNT(*) FROM users;'
echo 'Total Items:'; sqlite3 /opt/vaultwarden/data/db.sqlite3 'SELECT COUNT(*) FROM ciphers;'
"

```
## 📱 Client Setup
### 🌐 **Browser Extensions**

1. **Install Bitwarden extension** in your browser
2. **Configure server URL**: `http://192.168.1.206` or `https://vault.yourdomain.com`
3. **Login** with your account credentials
4. **Enable auto-fill** and auto-save features

### 📱 **Mobile Apps**

1. **Download official Bitwarden app** (iOS/Android)
2. **Tap gear icon** → Settings
3. **Server URL**: Enter your Vaultwarden URL
4. **Login** with your credentials
5. **Enable biometric unlock** for convenience

### 💻 **Desktop Applications**

1. **Download Bitwarden desktop app**
2. **Settings** → Server URL
3. **Enter your server**: `https://vault.yourdomain.com`
4. **Login** and sync your vault

## 🔍 Troubleshooting
### ❌ **Common Issues**
#### **Web Interface Not Loading**

```bash
# Check Nginx service
pct exec 206 -- systemctl status nginx

# Check Vaultwarden service
pct exec 206 -- systemctl status vaultwarden

# Check port binding
pct exec 206 -- ss -tlnp | grep -E ':80|:8080'

# Restart services
pct exec 206 -- systemctl restart nginx vaultwarden

```
#### **Admin Panel Access Denied**

```bash
# Check admin token
pct exec 206 -- grep ADMIN_TOKEN /opt/vaultwarden/.env

# Generate new token if needed
pct exec 206 -- bash -c "
NEW_TOKEN=\$(openssl rand -base64 48 | tr -d '=+/' | cut -c1-64)
sed -i \"s/ADMIN_TOKEN=.*/ADMIN_TOKEN=\$NEW_TOKEN/\" /opt/vaultwarden/.env
systemctl restart vaultwarden
echo \"New admin token: \$NEW_TOKEN\"
"

```
#### **Client Sync Issues**

```bash
# Check WebSocket service
pct exec 206 -- ss -tlnp | grep :3012

# Check database integrity
pct exec 206 -- sqlite3 /opt/vaultwarden/data/db.sqlite3 "PRAGMA integrity_check;"

# Check logs for errors
pct exec 206 -- tail -n 50 /opt/vaultwarden/data/vaultwarden.log

```
#### **SSL Certificate Issues**

```bash
# Test SSL certificate
pct exec 206 -- openssl s_client -connect vault.yourdomain.com:443

# Renew Let's Encrypt certificate
pct exec 206 -- certbot renew --dry-run

# Check certificate expiration
pct exec 206 -- certbot certificates

```
### 📞 **Support Resources**

- **Vaultwarden Wiki**: https://github.com/dani-garcia/vaultwarden/wiki
- **GitHub Issues**: https://github.com/dani-garcia/vaultwarden/issues
- **Bitwarden Help**: https://bitwarden.com/help/
- **Community Forum**: https://community.bitwarden.com/

## 📈 Performance & Optimization
### 📊 **Key Metrics to Monitor**

- **Response time** (should be < 200ms)
- **Memory usage** (typically 50-200MB)
- **Database size** (grows with users and items)
- **Backup success rate** (should be 100%)
- **SSL certificate expiration**

### 🎯 **Optimization Tips**

1. **Regular backups** - Automate and test recovery
2. **Monitor logs** - Check for unusual activity
3. **Update regularly** - Keep Vaultwarden current
4. **SSL health** - Monitor certificate expiration
5. **Database maintenance** - Periodic integrity checks
6. **Resource monitoring** - Ensure adequate resources

## 🔐 Best Practices
### 🛡️ **Security Best Practices**

1. **Strong master password** - Use a unique, complex password
2. **Enable 2FA** - Add extra security layer
3. **Regular backups** - Test backup/restore procedures
4. **Monitor access logs** - Watch for suspicious activity
5. **Keep updated** - Apply security updates promptly
6. **Network segmentation** - Use VPN for remote access
7. **Admin token rotation** - Change periodically

### 📱 **Usage Best Practices**

1. **Unique passwords** - Generate for every account
2. **Regular audits** - Check for weak/reused passwords
3. **Secure sharing** - Use organization vaults for teams
4. **Emergency access** - Configure trusted contacts
5. **Regular syncing** - Keep all devices synchronized

---

## 🎊 **Ready for Secure Password Management!**
Your Vaultwarden LXC container is now ready to provide enterprise-grade password management for your entire homelab and beyond. Access the web interface at **<http://192.168.1.206**> to start securing your digital life!

**Next Steps:**
1. 🔧 Access admin panel and configure SMTP
2. 👤 Create your first user account
3. 🔒 Disable signups for security
4. 🌐 Set up SSL via Nginx Proxy Manager
5. 📱 Install Bitwarden apps on all your devices
6. 🛡️ Enable two-factor authentication

