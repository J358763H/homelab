# 🌐 Nginx Proxy Manager + Tailscale Setup Guide (Docker-Based - Legacy)
⚠️ **DEPRECATED**: This guide is for Docker-based NPM+Tailscale setup. 

**RECOMMENDED**: Use the LXC-based approach in `/lxc/nginx-proxy-manager/` and `/lxc/tailscale/` instead.

This guide will help you set up secure remote access to your homelab using Nginx Proxy Manager (NPM) for reverse proxy functionality and Tailscale for secure networking running in Docker containers.

## 🎯 What This Setup Provides
- **Reverse Proxy**: Clean URLs with SSL certificates for all services
- **Secure Remote Access**: VPN-like access without opening firewall ports
- **SSL Certificates**: Automatic Let's Encrypt certificates (optional)
- **Centralized Management**: Single interface for all proxy configurations

## 🔧 Prerequisites
1. **Tailscale Account**: Sign up at [tailscale.com](https://tailscale.com)
2. **Domain (Optional)**: For SSL certificates and clean URLs
3. **Docker Environment**: Homelab stack already deployed

## 📋 Setup Steps
### 1. Configure Tailscale Authentication
1. **Generate Auth Key:**

   ```bash
   # Visit Tailscale admin console
   open <https://login.tailscale.com/admin/settings/keys>
   ```

2. **Create Reusable Key:**
   - Check "Reusable" 
   - Set expiration (90 days recommended)
   - Tag with "homelab" or similar
   - Copy the generated key

3. **Update Environment:**

   ```bash
   # Edit your .env file
   nano .env
   
   # Add your Tailscale auth key
   TAILSCALE_AUTH_KEY=tskey-auth-your-key-here
   ```

### 2. Deploy NPM + Tailscale
```bash
# Deploy the updated stack
docker compose up -d nginx-proxy-manager tailscale

# Check container status
docker compose ps

```
### 3. Configure Nginx Proxy Manager
1. **Access NPM Web UI:**

   ```
   <http://your-server-ip:81>
   ```

2. **Default Login:**
   - Email: `admin@example.com`
   - Password: `changeme`
   - **⚠️ Change these immediately!**

3. **Add Proxy Hosts:**

   

   **Example: Jellyfin Proxy**

   ```
   Domain Names: jellyfin.tail2bd275.ts.net
   Scheme: http
   Forward Hostname/IP: 172.20.0.10
   Forward Port: 8096
   
   ✅ Cache Assets
   ✅ Block Common Exploits
   ✅ Websockets Support
   ```

   **Example: Jellyseerr Proxy**

   ```
   Domain Names: requests.tail2bd275.ts.net
   Scheme: http  
   Forward Hostname/IP: 172.20.0.11
   Forward Port: 5055
   ```

### 4. Verify Tailscale Integration
1. **Check Tailscale Status:**

   ```bash
   docker exec tailscale tailscale status
   ```

2. **Verify Route Advertisement:**

   ```bash
   docker exec tailscale tailscale status | grep "172.20.0.0/16"
   ```

3. **Test Access:**
   - Install Tailscale on your device
   - Access: `http://homelab-shv-docker:81` (NPM)
   - Access: `http://homelab-shv-docker:8096` (Jellyfin direct)

## 🔒 Security Configuration
### NPM Security Headers

Add these custom headers in NPM for better security:

```nginx
# In NPM Advanced tab for each proxy host
X-Frame-Options: SAMEORIGIN
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
Referrer-Policy: strict-origin-when-cross-origin

```
### Tailscale ACLs (Optional)

Control access with Tailscale ACLs:

```json
{
  "groups": {
    "group:homelab-users": ["you@example.com"]
  },
  "acls": [
    {
      "action": "accept",
      "src": ["group:homelab-users"],
      "dst": ["tag:homelab:*"]
    }
  ],
  "tagOwners": {
    "tag:homelab": ["you@example.com"]
  }
}

```
## 🌐 Service URLs (Post-Setup)
### Via Tailscale Direct Access:

- Nginx Proxy Manager: `http://homelab-shv-docker:81`
- Jellyfin: `http://homelab-shv-docker:8096`
- Sonarr: `http://homelab-shv-docker:8989`
- Radarr: `http://homelab-shv-docker:7878`
- Jellyseerr: `http://homelab-shv-docker:5055`

### Via NPM Proxy (Configure as needed):

- Jellyfin: `http://jellyfin.tail2bd275.ts.net`
- Requests: `http://requests.tail2bd275.ts.net`
- Movies: `http://movies.tail2bd275.ts.net`
- Shows: `http://shows.tail2bd275.ts.net`

## 🛠️ Troubleshooting
### Tailscale Not Connecting

```bash
# Check container logs
docker logs tailscale

# Verify auth key
echo $TAILSCALE_AUTH_KEY

# Restart container
docker compose restart tailscale

```
### NPM Can't Reach Services

```bash
# Test connectivity from NPM container
docker exec nginx-proxy-manager curl http://172.20.0.10:8096

# Check network connectivity
docker network inspect homelab-deployment_homelab

```
### SSL Certificate Issues

1. Ensure domain points to your external IP
2. Check firewall allows ports 80/443
3. Verify Let's Encrypt rate limits
4. Use Tailscale + internal certificates for private access

## 📊 Network Architecture
```
Internet
    ↓
[Tailscale Mesh Network]
    ↓
[Your Device] → [Tailscale] → [Homelab Server]
                                    ↓
                              [NPM] → [Services]
                              :81     :8096, :8989, etc.

```
## 🎉 Next Steps
1. **Configure All Services**: Add proxy hosts for each service
2. **Set Up Monitoring**: Use NPM logs and Tailscale admin console
3. **Mobile Access**: Install Tailscale on mobile devices
4. **Share Access**: Invite family/friends to your Tailnet
5. **Backup Configs**: Export NPM settings regularly

---

**⚠️ Security Reminder**: 
- Keep Tailscale keys secure
- Regularly rotate auth keys
- Monitor access logs
- Use strong NPM admin credentials

