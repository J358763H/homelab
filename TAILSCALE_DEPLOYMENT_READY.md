# 🔑 Tailscale Deployment Ready
## Auth Key Generated

**Date**: October 12, 2025  
**Authentication**: GitHub OAuth  
**Key Format**: tskey-auth-k4dvv2MnLB11CNTRL-dERsvVZ3zC3ZwXP6NsZED3Acg7X1r278U

## Key Settings Used

- ✅ **Reusable**: Yes (one key for all homelab devices)
- ✅ **Preauthorized**: Yes (automatic device approval)
- ❌ **Ephemeral**: No (devices persist after restart)
- ⏰ **Expires**: 90 days (regenerate ~January 10, 2026)
- 🏷️ **Tags**: homelab
- 📝 **Description**: Homelab Infrastructure - GitHub Auth

## Privacy Features Enabled

Your deployment will automatically include:

- 🛡️ **DNS Privacy**: Uses Pi-hole (192.168.1.205) instead of Tailscale DNS
- 🔒 **Network Isolation**: --accept-routes=false for selective routing
- 🛡️ **Firewall Protection**: --shields-up for extra security
- ⚙️ **Enhanced Filtering**: --netfilter-mode=on for better integration

## Deployment Command

```bash
# Deploy Tailscale LXC container with privacy settings
./lxc/tailscale/setup_tailscale_lxc.sh

# When prompted, use this auth key:
# tskey-auth-k4dvv2MnLB11CNTRL-dERsvVZ3zC3ZwXP6NsZED3Acg7X1r278U

```
## Next Steps After Deployment

1. ✅ Approve subnet routes in Tailscale admin console
2. 🔧 Install Tailscale on your client devices
3. 📱 Access homelab services remotely via 192.168.1.x addresses
4. 🌐 Verify Pi-hole DNS is working (should block ads automatically)

## Key Renewal Reminder

📅 **Set Calendar Reminder**: January 10, 2026  
📝 **Action**: Generate new auth key before expiration  
🔄 **Process**: Follow same privacy settings for renewal

---
**Auth key ready for secure, privacy-focused homelab VPN deployment!** 🚀🔒

