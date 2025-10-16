# 🔧 Manual Homelab Deployment Guide

## Why Manual Deployment?

After hours of automated attempts hitting kernel compatibility and Docker service issues, sometimes doing it step-by-step manually is actually **faster and more reliable**. You have full control and can troubleshoot each service individually.

## 📋 Manual Deployment Checklist

### Phase 1: Basic Infrastructure (5 minutes)
- [ ] **Step 1**: Create directories
- [ ] **Step 2**: Set up basic networking  
- [ ] **Step 3**: Create .env file with credentials

### Phase 2: Core Services (10 minutes each)
- [ ] **Step 4**: Deploy Jellyfin (media server)
- [ ] **Step 5**: Deploy Nginx Proxy Manager (reverse proxy)
- [ ] **Step 6**: Deploy Pi-hole (DNS blocking)

### Phase 3: Media Management (10 minutes each)  
- [ ] **Step 7**: Deploy Sonarr (TV shows)
- [ ] **Step 8**: Deploy Radarr (movies)
- [ ] **Step 9**: Deploy Prowlarr (indexers)

### Phase 4: Downloads & Tools (10 minutes each)
- [ ] **Step 10**: Deploy qBittorrent (torrents)
- [ ] **Step 11**: Deploy Vaultwarden (password manager)
- [ ] **Step 12**: Deploy NTFY (notifications)

### Phase 5: Monitoring (5 minutes)
- [ ] **Step 13**: Deploy Netdata (system monitoring)
- [ ] **Step 14**: Test all services

---

## 🚀 Step-by-Step Instructions

### Step 1: Create Directory Structure
```bash
mkdir -p /data/docker/{jellyfin,sonarr,radarr,prowlarr,qbittorrent,npm,pihole,vaultwarden,ntfy,netdata}
mkdir -p /data/media/{movies,tv,music}
mkdir -p /data/media/downloads/{complete,incomplete}
```

### Step 2: Create Docker Network
```bash
docker network create homelab --subnet=172.20.0.0/16
```

### Step 3: Create Environment File
```bash
cat > /data/docker/.env << 'EOF'
PUID=1000
PGID=1000
TZ=America/New_York
DOMAIN=homelab.local
EOF
```

### Step 4: Deploy Jellyfin (Media Server)
```bash
docker run -d \
  --name jellyfin \
  --network homelab \
  --ip 172.20.0.10 \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=America/New_York \
  -p 8096:8096 \
  -v /data/docker/jellyfin:/config \
  -v /data/media:/media:ro \
  --restart unless-stopped \
  lscr.io/linuxserver/jellyfin:latest
```
**Test**: Browse to `http://your-server-ip:8096`

### Step 5: Deploy Nginx Proxy Manager
```bash
docker run -d \
  --name npm \
  --network homelab \
  --ip 172.20.0.11 \
  -p 80:80 \
  -p 443:443 \
  -p 81:81 \
  -v /data/docker/npm/data:/data \
  -v /data/docker/npm/letsencrypt:/etc/letsencrypt \
  --restart unless-stopped \
  jc21/nginx-proxy-manager:latest
```
**Test**: Browse to `http://your-server-ip:81`  
**Login**: admin@example.com / changeme

### Step 6: Deploy Pi-hole (DNS Ad Blocker)
```bash
docker run -d \
  --name pihole \
  --network homelab \
  --ip 172.20.0.12 \
  -e TZ=America/New_York \
  -e WEBPASSWORD=admin123 \
  -e PIHOLE_DNS_1=1.1.1.1 \
  -e PIHOLE_DNS_2=1.0.0.1 \
  -p 53:53/tcp \
  -p 53:53/udp \
  -p 8053:80 \
  -v /data/docker/pihole/etc:/etc/pihole \
  -v /data/docker/pihole/dnsmasq:/etc/dnsmasq.d \
  --restart unless-stopped \
  pihole/pihole:latest
```
**Test**: Browse to `http://your-server-ip:8053`  
**Login**: admin123

### Step 7: Deploy Sonarr (TV Show Management)
```bash
docker run -d \
  --name sonarr \
  --network homelab \
  --ip 172.20.0.13 \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=America/New_York \
  -p 8989:8989 \
  -v /data/docker/sonarr:/config \
  -v /data/media/tv:/tv \
  -v /data/media/downloads:/downloads \
  --restart unless-stopped \
  lscr.io/linuxserver/sonarr:latest
```
**Test**: Browse to `http://your-server-ip:8989`

### Step 8: Deploy Radarr (Movie Management)
```bash
docker run -d \
  --name radarr \
  --network homelab \
  --ip 172.20.0.14 \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=America/New_York \
  -p 7878:7878 \
  -v /data/docker/radarr:/config \
  -v /data/media/movies:/movies \
  -v /data/media/downloads:/downloads \
  --restart unless-stopped \
  lscr.io/linuxserver/radarr:latest
```
**Test**: Browse to `http://your-server-ip:7878`

### Step 9: Deploy Prowlarr (Indexer Management)
```bash
docker run -d \
  --name prowlarr \
  --network homelab \
  --ip 172.20.0.15 \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=America/New_York \
  -p 9696:9696 \
  -v /data/docker/prowlarr:/config \
  --restart unless-stopped \
  lscr.io/linuxserver/prowlarr:latest
```
**Test**: Browse to `http://your-server-ip:9696`

### Step 10: Deploy qBittorrent (Torrent Client)
```bash
docker run -d \
  --name qbittorrent \
  --network homelab \
  --ip 172.20.0.16 \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=America/New_York \
  -e WEBUI_PORT=8080 \
  -p 8080:8080 \
  -p 6881:6881 \
  -p 6881:6881/udp \
  -v /data/docker/qbittorrent:/config \
  -v /data/media/downloads:/downloads \
  --restart unless-stopped \
  lscr.io/linuxserver/qbittorrent:latest
```
**Test**: Browse to `http://your-server-ip:8080`  
**Login**: admin / adminpass (change immediately)

### Step 11: Deploy Vaultwarden (Password Manager)
```bash
docker run -d \
  --name vaultwarden \
  --network homelab \
  --ip 172.20.0.17 \
  -e WEBSOCKET_ENABLED=true \
  -e SIGNUPS_ALLOWED=false \
  -e ADMIN_TOKEN=your-secure-admin-token-here \
  -p 8200:80 \
  -v /data/docker/vaultwarden:/data \
  --restart unless-stopped \
  vaultwarden/server:latest
```
**Test**: Browse to `http://your-server-ip:8200`

### Step 12: Deploy NTFY (Notifications)
```bash
docker run -d \
  --name ntfy \
  --network homelab \
  --ip 172.20.0.18 \
  -e NTFY_BASE_URL=http://your-server-ip:8300 \
  -p 8300:80 \
  -v /data/docker/ntfy/cache:/var/cache/ntfy \
  -v /data/docker/ntfy/etc:/etc/ntfy \
  --restart unless-stopped \
  binwiederhier/ntfy:latest
```
**Test**: Browse to `http://your-server-ip:8300`

### Step 13: Deploy Netdata (System Monitoring)
```bash
docker run -d \
  --name netdata \
  --network homelab \
  --ip 172.20.0.19 \
  -p 19999:19999 \
  -v /data/docker/netdata/lib:/var/lib/netdata \
  -v /data/docker/netdata/cache:/var/cache/netdata \
  -v /etc/passwd:/host/etc/passwd:ro \
  -v /etc/group:/host/etc/group:ro \
  -v /proc:/host/proc:ro \
  -v /sys:/host/sys:ro \
  -v /etc/os-release:/host/etc/os-release:ro \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  --cap-add SYS_PTRACE \
  --security-opt apparmor:unconfined \
  --restart unless-stopped \
  netdata/netdata:latest
```
**Test**: Browse to `http://your-server-ip:19999`

### Step 14: Verify All Services
```bash
# Check all containers are running
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Check network connectivity
docker network inspect homelab
```

---

## 🎯 Service URLs Summary

| Service | URL | Default Login |
|---------|-----|---------------|
| Jellyfin | http://IP:8096 | Setup wizard |
| Nginx Proxy Manager | http://IP:81 | admin@example.com / changeme |
| Pi-hole | http://IP:8053 | admin123 |
| Sonarr | http://IP:8989 | No login required |
| Radarr | http://IP:7878 | No login required |
| Prowlarr | http://IP:9696 | No login required |
| qBittorrent | http://IP:8080 | admin / adminpass |
| Vaultwarden | http://IP:8200 | Create account |
| NTFY | http://IP:8300 | No login required |
| Netdata | http://IP:19999 | No login required |

---

## 💡 Manual Deployment Benefits

✅ **Full Control**: You see exactly what's happening at each step  
✅ **Easy Troubleshooting**: If one service fails, others keep working  
✅ **No Complex Scripts**: Simple Docker commands that always work  
✅ **Individual Testing**: Test each service as you deploy it  
✅ **No Dependencies**: Each service is independent  

## 🚨 If Something Goes Wrong

**Container won't start?**
```bash
docker logs [container-name]
```

**Port conflict?**
```bash
# Change the first port number (host port)
-p 8097:8096  # Instead of 8096:8096
```

**Permission issues?**
```bash
sudo chown -R 1000:1000 /data/docker/[service-name]
```

**Remove and retry:**
```bash
docker stop [container-name]
docker rm [container-name]
# Then run the deployment command again
```

---

## ⏱️ Expected Timeline

- **Infrastructure Setup**: 5 minutes
- **Each Core Service**: 5-10 minutes  
- **Total Time**: 60-90 minutes (but you can test as you go!)

**The beauty of manual deployment**: If something breaks, you fix just that one service instead of debugging a complex automation script!