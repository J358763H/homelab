# 🔧 LXC Container Configuration Guide

## 📋 Overview

This guide identifies all configuration values that need to be customized before deploying your LXC containers. Each container has specific settings that should be personalized for your environment.

---

## 🔗 **Nginx Proxy Manager (192.168.1.201)**

### 📄 File: `lxc/nginx-proxy-manager/setup_npm_lxc.sh`
**Status: ✅ Ready to deploy - No customization required**

### 🔧 Post-Deployment Configuration Required:
- **Default Login**: `admin@example.com` / `changeme`
- **⚠️ CRITICAL**: Change these credentials immediately after first login
- **Access**: http://192.168.1.201:81

---

## 🔒 **Tailscale VPN Router (192.168.1.202)**

### 📄 File: `lxc/tailscale/setup_tailscale_lxc.sh`
**Status: 🔑 Requires Tailscale Auth Key**

### 🔧 Pre-Deployment Configuration Required:
```bash
# The script will prompt for this during deployment:
Enter your Tailscale auth key: [REQUIRED]
```

### 📝 How to Get Privacy-Focused Auth Key:

#### **Step 1: Create Privacy-Focused Account**
- **Email**: Use ProtonMail or dedicated privacy email
- **Example**: `homelab-tailscale-2025@proton.me`
- **2FA**: Enable immediately after signup

#### **Step 2: Generate Auth Key**
1. Visit https://login.tailscale.com/admin/settings/keys
2. Generate a new auth key with these **privacy-focused** settings:
   ```
   ✅ Reusable: Yes (one key for all homelab devices)
   ✅ Preauthorized: Yes (no manual approvals)
   ✅ Ephemeral: No (devices persist after restart)
   ⏰ Expires in: 90 days (balance security/convenience)
   🏷️ Tags: homelab (optional organization)
   ```
3. Copy the key: `tskey-auth-xxxxxxxxxxxxxxxxxxxxx`

### 🛡️ **Enhanced Privacy Features:**
Our setup includes privacy-focused configurations:
- **DNS Privacy**: Uses Pi-hole (192.168.1.205) instead of Tailscale DNS
- **Network Isolation**: `--shields-up` for extra firewall protection  
- **Minimal Routes**: Only accepts explicitly configured routes
- **No Telemetry**: Reduces data sharing with Tailscale servers

> 📋 **Full Privacy Guide**: See `lxc/tailscale/PRIVACY_SETUP_GUIDE.md` for complete privacy setup instructions.

---

## 📢 **Ntfy Notifications (192.168.1.203)**

### 📄 File: `lxc/ntfy/setup_ntfy_lxc.sh`
**Status: ✅ Ready to deploy - No customization required**

### 🔧 Optional Configuration:
- Server runs with default settings
- Web interface: http://192.168.1.203
- Topics can be created dynamically

---

## 📁 **Media File Share (192.168.1.204)**

### 📄 File: `lxc/samba/setup_samba_lxc.sh`
**Status: ✅ Ready to deploy - No customization required**

### 🔧 Post-Deployment Configuration:
- Default shares created automatically
- User management via included scripts
- Access via \\\\192.168.1.204 or \\\\media.local

---

## 🕳️ **Pi-hole DNS/Ad Blocker (192.168.1.205)**

### 📄 File: `lxc/pihole/setup_pihole_lxc.sh`
**Status: ⚠️ Customization Recommended**

### 🔧 Values to Customize:

#### **1. Web Admin Password**
```bash
# Line 26 - Current setting:
WEBPASSWORD="X#zunVV!kDWdYUt0zAAg"  # Secure password configured

# Change if desired:
WEBPASSWORD="YourOwnSecurePassword123!"
```

#### **2. Timezone**
```bash
# Line 27 - Current setting:
TIMEZONE="America/Phoenix"  # Change to your timezone

# Common alternatives:
TIMEZONE="America/Los_Angeles"    # Pacific Time
TIMEZONE="America/Chicago"        # Central Time
TIMEZONE="America/Denver"         # Mountain Time
TIMEZONE="Europe/London"          # GMT
TIMEZONE="Europe/Paris"           # Central European Time
TIMEZONE="Asia/Tokyo"             # Japan Time
TIMEZONE="Australia/Sydney"       # Australian Eastern Time
```

#### **3. Optional DNS Servers**
```bash
# Lines 28-29 - Current settings (good defaults):
DNS_UPSTREAM_1="1.1.1.1"     # Cloudflare (fast, privacy-focused)
DNS_UPSTREAM_2="8.8.8.8"     # Google (reliable)

# Alternative options:
# DNS_UPSTREAM_1="9.9.9.9"   # Quad9 (security-focused)
# DNS_UPSTREAM_2="208.67.222.222"  # OpenDNS
```

---

## 🔐 **Vaultwarden Password Manager (192.168.1.206)**

### 📄 File: `lxc/vaultwarden/setup_vaultwarden_lxc.sh`
**Status: ⚠️ Customization Required**

### 🔧 Values to Customize:

#### **1. Domain Name**
```bash
# Line 25 - Current setting:
DOMAIN_NAME="homelab-vault.local"  # Configured domain name

# Alternative options:
DOMAIN_NAME="vault.yourdomain.com"    # If you have a domain
DOMAIN_NAME="vaultwarden.local"       # Alternative local name
DOMAIN_NAME="passwords.local"         # Descriptive local name
```

#### **2. Timezone**
```bash
# Line 26 - Current setting:
TIMEZONE="America/Phoenix"  # Change to your timezone

# Use same timezone as Pi-hole (see above for options)
```

#### **3. SMTP Email Configuration (Optional but Recommended)**
```bash
# Lines 315-317 - Currently commented out:
# SMTP_HOST=smtp.gmail.com
# SMTP_USERNAME=your-email@gmail.com
# SMTP_PASSWORD=your-app-password

# For Gmail setup:
SMTP_HOST=smtp.gmail.com
SMTP_FROM=vaultwarden@yourdomain.com
SMTP_PORT=587
SMTP_SECURITY=starttls
SMTP_USERNAME=your-gmail@gmail.com
SMTP_PASSWORD=your-gmail-app-password  # Generate from Google Account settings
```

---

## 🎯 **Quick Configuration Checklist**

### ✅ **Before Deployment**

#### **Required (Must Configure):**
- [ ] **Tailscale Auth Key** - Generate from Tailscale admin panel
- [ ] **Your Timezone** - Update Pi-hole and Vaultwarden scripts

#### **Recommended (Should Configure):**
- [ ] **Pi-hole Admin Password** - Change from default "admin123"
- [ ] **Vaultwarden Domain** - Set to your preferred domain/subdomain
- [ ] **SMTP Settings** - Configure email for Vaultwarden notifications

#### **Optional (Can Configure Later):**
- [ ] **DNS Upstream Servers** - Pi-hole DNS providers
- [ ] **Custom Domain Names** - All containers support custom domains

### ✅ **After Deployment**

#### **Nginx Proxy Manager:**
- [ ] Change admin credentials from admin@example.com/changeme
- [ ] Add SSL certificates for your domains
- [ ] Configure reverse proxy rules

#### **Vaultwarden:**
- [ ] Access admin panel with generated token
- [ ] Enable signups temporarily to create first user
- [ ] Create your master account
- [ ] Disable signups for security
- [ ] Test SMTP email functionality

#### **Pi-hole:**
- [ ] Configure router to use Pi-hole as DNS (192.168.1.205)
- [ ] Customize blocklists in admin panel
- [ ] Add whitelist entries as needed

---

## 🔧 **How to Customize Before Deployment**

### **Method 1: Edit Scripts Directly**
```bash
# Edit the setup script before running
nano lxc/pihole/setup_pihole_lxc.sh
# Make your changes to timezone, password, etc.
# Then run the script
./lxc/pihole/setup_pihole_lxc.sh
```

### **Method 2: Environment Variables**
```bash
# Set environment variables before running
export PIHOLE_PASSWORD="YourSecurePassword"
export TIMEZONE="Your/Timezone"
./lxc/pihole/setup_pihole_lxc.sh
```

### **Method 3: Interactive Prompts**
Some scripts (like Tailscale) will prompt for required values during deployment.

---

## 🌍 **Common Timezone Values**

```bash
# North America
TIMEZONE="America/New_York"        # Eastern Time
TIMEZONE="America/Chicago"         # Central Time  
TIMEZONE="America/Denver"          # Mountain Time
TIMEZONE="America/Los_Angeles"     # Pacific Time
TIMEZONE="America/Toronto"         # Eastern (Canada)
TIMEZONE="America/Vancouver"       # Pacific (Canada)

# Europe
TIMEZONE="Europe/London"           # GMT/BST
TIMEZONE="Europe/Paris"            # Central European
TIMEZONE="Europe/Berlin"           # Central European
TIMEZONE="Europe/Rome"             # Central European
TIMEZONE="Europe/Madrid"           # Central European
TIMEZONE="Europe/Amsterdam"        # Central European

# Asia Pacific
TIMEZONE="Asia/Tokyo"              # Japan
TIMEZONE="Asia/Shanghai"           # China
TIMEZONE="Asia/Seoul"              # South Korea
TIMEZONE="Asia/Singapore"          # Singapore
TIMEZONE="Australia/Sydney"        # Australian Eastern
TIMEZONE="Australia/Melbourne"     # Australian Eastern
TIMEZONE="Australia/Perth"         # Australian Western
```

Find your timezone: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones

---

## 🔒 **Security Recommendations**

### **Strong Passwords:**
- **Pi-hole**: Use 16+ character password with mix of letters, numbers, symbols
- **NPM**: Change immediately after first login
- **Vaultwarden**: Master password should be memorizable but very strong

### **Email Security:**
- **Gmail**: Use App Passwords, not your regular password
- **Other Providers**: Use dedicated SMTP credentials when possible

### **Domain Security:**
- **Local Domains**: Use .local suffix for internal-only access
- **Public Domains**: Ensure proper SSL certificates are configured

---

## 🎊 **Ready to Deploy!**

Once you've customized the required values:

```bash
# Deploy all containers with customizations
./homelab.sh lxc

# Or deploy individually
./lxc/pihole/setup_pihole_lxc.sh        # With your customizations
./lxc/vaultwarden/setup_vaultwarden_lxc.sh  # With your customizations
```

Your personalized homelab infrastructure will be ready in minutes! 🚀