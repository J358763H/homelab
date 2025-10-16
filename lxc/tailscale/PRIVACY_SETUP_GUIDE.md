# 🔒 Privacy-Focused Tailscale Setup Guide
## 📋 Overview
This guide provides instructions for setting up Tailscale with maximum privacy considerations for your homelab environment.

---

## 🛡️ **Privacy-First Account Setup**
### **Step 1: Create Privacy-Focused Email Account**
#### **Recommended Privacy Email Providers:**

- **ProtonMail** (Best): https://proton.me/mail
- **Tutanota**: https://tutanota.com
- **TempMail** (Extreme): For throwaway accounts

#### **Suggested Email Format:**

```
homelab-tailscale-[year]@proton.me
Example: homelab-tailscale-2025@proton.me

```
### **Step 2: Create Tailscale Account**

1. Visit: https://login.tailscale.com/start
2. Choose **"Sign up with email"**
3. Use your privacy-focused email address
4. **Enable 2FA immediately** after account creation

---

## 🔑 **Generate Privacy-Focused Auth Key**
### **Access Auth Key Settings:**

1. Login to Tailscale admin console: https://login.tailscale.com/admin
2. Navigate to: **Settings → Keys**
3. Click **"Generate auth key"**

### **Recommended Auth Key Configuration:**

```
✅ Reusable: Yes
   - Use one key for all homelab devices
   - Reduces individual device tracking

✅ Preauthorized: Yes  
   - No manual approval required
   - Faster deployment

✅ Ephemeral: No
   - Devices persist after restart
   - Better for infrastructure

⏰ Expires in: 90 days
   - Balance between security and convenience
   - Set calendar reminder to regenerate

🏷️ Tags: homelab
   - Organize devices by purpose
   - Optional but helpful

📝 Description: "Homelab Infrastructure Key - Generated [DATE]"

```
### **Copy Your Auth Key:**

```bash
# Your auth key will look like this:
tskey-auth-xxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Save this securely - you'll need it for deployment

```
---

## 🔒 **Enhanced Privacy Configuration**
### **Privacy Flags Explanation:**
#### **`--accept-dns=false`**

- **Purpose**: Don't use Tailscale's DNS servers
- **Benefit**: Use your Pi-hole DNS instead (192.168.1.205)
- **Privacy**: Prevents Tailscale from seeing DNS queries

#### **`--accept-routes=false`**

- **Purpose**: Only accept routes you explicitly configure
- **Benefit**: Prevents unwanted network access
- **Privacy**: Limits network exposure

#### **`--shields-up`**

- **Purpose**: Extra firewall protection
- **Benefit**: Blocks incoming connections by default
- **Privacy**: Reduces attack surface

#### **`--netfilter-mode=on`**

- **Purpose**: Better firewall rule integration
- **Benefit**: Works with existing iptables rules
- **Privacy**: More granular network control

---

## 📊 **Privacy vs Functionality Trade-offs**
### **Maximum Privacy Settings:**

```bash
# Most private but potentially less convenient
tailscale up --authkey=$AUTH_KEY \
    --advertise-routes=$SUBNET_ROUTE \
    --accept-dns=false \
    --accept-routes=false \
    --shields-up \
    --netfilter-mode=on \
    --hostname=$HOSTNAME

```
### **Balanced Settings (Default in our script):**

```bash
# Good privacy with full functionality
tailscale up --authkey=$AUTH_KEY \
    --advertise-routes=$SUBNET_ROUTE \
    --ssh \
    --accept-dns=false \
    --accept-routes=false \
    --shields-up \
    --netfilter-mode=on \
    --hostname=$HOSTNAME

```
### **Convenience Settings (Less Private):**

```bash
# Maximum convenience but more data sharing
tailscale up --authkey=$AUTH_KEY \
    --advertise-routes=$SUBNET_ROUTE \
    --ssh \
    --accept-dns=true \
    --accept-routes=true \
    --hostname=$HOSTNAME

```
---

## 🎯 **Deployment Instructions**
### **Step 1: Update Environment Variables**

```bash
# Set your auth key (replace with your actual key)
export TAILSCALE_AUTHKEY="tskey-auth-your-key-here"

```
### **Step 2: Run Enhanced Setup Script**

```bash
# Deploy Tailscale with privacy settings
cd /path/to/homelab-deployment
./lxc/tailscale/setup_tailscale_lxc.sh

# When prompted, enter your auth key

```
### **Step 3: Verify Privacy Settings**

```bash
# Check that privacy settings are applied
pct exec 202 -- tailscale status

# Verify DNS is disabled (should show "false")
pct exec 202 -- tailscale status --json | grep -i dns

# Check shields-up status
pct exec 202 -- tailscale status --json | grep -i shield

```
---

## 🔍 **Post-Deployment Privacy Verification**
### **1. Verify DNS Configuration**

```bash
# Should use Pi-hole (192.168.1.205), not Tailscale DNS
pct exec 202 -- nslookup google.com
# Expected: Server should be 192.168.1.205

```
### **2. Check Network Routes**

```bash
# Verify only your subnet is advertised
pct exec 202 -- tailscale status --json | grep -i route
# Should only show 192.168.1.0/24

```
### **3. Confirm Firewall Status**

```bash
# Shields should be up
pct exec 202 -- tailscale status
# Look for "shields-up: true" in output

```
---

## 🛠️ **Managing Privacy Settings**
### **Runtime Privacy Commands:**

```bash
# Disable DNS acceptance (if enabled)
pct exec 202 -- tailscale set --accept-dns=false

# Enable shields-up
pct exec 202 -- tailscale set --shields-up=true

# Disable route acceptance
pct exec 202 -- tailscale set --accept-routes=false

# Check current settings
pct exec 202 -- tailscale status --json | jq '.Self.HostInfo'

```
### **Re-authenticate with New Settings:**

```bash
# If you want to change connection settings
pct exec 202 -- tailscale down
pct exec 202 -- tailscale up --authkey=$NEW_AUTH_KEY [your-privacy-flags]

```
---

## 📋 **Privacy Checklist**
### **Account Privacy:**

- [ ] Used privacy-focused email provider
- [ ] Enabled 2FA on Tailscale account
- [ ] Generated reusable, tagged auth key
- [ ] Set reasonable expiration date

### **Network Privacy:**

- [ ] Disabled Tailscale DNS (`--accept-dns=false`)
- [ ] Using Pi-hole for DNS resolution
- [ ] Disabled automatic route acceptance
- [ ] Enabled shields-up protection

### **Operational Privacy:**

- [ ] Using auth keys instead of personal logins
- [ ] Minimized device naming information
- [ ] Regular auth key rotation schedule
- [ ] Monitoring network traffic patterns

---

## 🔄 **Regular Privacy Maintenance**
### **Monthly Tasks:**

- [ ] Review connected devices in admin console
- [ ] Remove unused/old devices
- [ ] Check for Tailscale software updates

### **Quarterly Tasks:**

- [ ] Rotate auth keys
- [ ] Review access logs
- [ ] Update privacy settings if needed

### **Annual Tasks:**

- [ ] Consider switching to Headscale (self-hosted)
- [ ] Review overall privacy posture
- [ ] Update documentation

---

## 🆚 **Alternative: Self-Hosted Headscale**
If maximum privacy is required, consider migrating to Headscale:

### **Headscale Benefits:**

- ✅ **Complete self-hosting** - No external dependencies
- ✅ **Zero data sharing** - Everything stays in your network
- ✅ **Full control** - Customize all aspects
- ✅ **No user limits** - Scale as needed

### **Migration Path:**

1. **Deploy Headscale server** (can use Container 207)
2. **Migrate devices** to point to your Headscale instance
3. **Decommission Tailscale account** after migration

### **When to Consider Migration:**

- Maximum privacy is essential
- Want complete control over coordination server
- Need to avoid any cloud dependencies
- Have technical expertise to maintain server

---

## 🎊 **Privacy-First Tailscale Ready!**
Your Tailscale setup now includes:

✅ **Privacy-focused authentication** with reusable auth keys
✅ **DNS privacy** by using Pi-hole instead of Tailscale DNS  
✅ **Network isolation** with shields-up and selective routing
✅ **Minimal data sharing** with optimized connection flags
✅ **Documentation** for ongoing privacy maintenance

**Access your homelab securely from anywhere while maintaining maximum privacy!** 🔒🚀

