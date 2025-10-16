# 🔑 Tailscale Auth Key Quick Setup
## 📋 **Before Deployment - Get Your Auth Key**
### **1. Privacy-First Account Creation**

```bash
# Recommended privacy email providers:
ProtonMail: https://proton.me/mail
Tutanota:   https://tutanota.com

# Suggested email format:
homelab-tailscale-2025@proton.me

```
### **2. Generate Privacy-Focused Auth Key**

```bash
# Visit: https://login.tailscale.com/admin/settings/keys
# Click: "Generate auth key"

# PRIVACY-FOCUSED SETTINGS:
✅ Reusable: Yes          # One key for all homelab devices
✅ Preauthorized: Yes     # No manual device approval needed  
✅ Ephemeral: No          # Devices survive container restarts
⏰ Expires in: 90 days    # Reasonable security rotation
🏷️ Tags: homelab         # Optional: organize your devices
📝 Description: "Homelab Infrastructure - Generated [DATE]"

```
### **3. Save Your Auth Key**

```bash
# Your key will look like this:
tskey-auth-k123456789abcdefghijklmnopqrstuvwxyz

# SECURELY SAVE THIS KEY - You'll need it for deployment!

```
---

## 🚀 **Ready for Deployment**
Once you have your auth key:

```bash
# Run the Tailscale LXC setup
./lxc/tailscale/setup_tailscale_lxc.sh

# When prompted, paste your auth key:
Enter your Tailscale auth key: tskey-auth-k123456789abcdefghijklmnopqrstuvwxyz

```
## 🔒 **Privacy Features Included**
Your setup automatically includes:

- ✅ **DNS Privacy**: Uses Pi-hole instead of Tailscale DNS
- ✅ **Network Isolation**: Shields-up firewall protection
- ✅ **Minimal Data**: Only necessary networking information shared
- ✅ **Local Control**: Route management through your infrastructure

---

## 📞 **Need Help?**
- 📚 **Full Guide**: See `PRIVACY_SETUP_GUIDE.md` for complete instructions
- 🔧 **Configuration**: See `../LXC_CONFIGURATION_GUIDE.md` for all containers
- 🏠 **Integration**: Your Pi-hole DNS will handle local domain resolution

**Your privacy-focused VPN is ready to deploy!** 🔒🚀

