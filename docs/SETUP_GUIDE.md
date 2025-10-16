# 📋 Simple Setup Guide

Step-by-step guide for setting up your homelab.

## Prerequisites

1. **Linux system** with Docker and Docker Compose installed
2. **Storage space** - at least 100GB for media
3. **VPN subscription** (recommended for downloads)

## Step 1: Environment Setup

```bash
# Run the preparation script
cd setup
./prepare.sh

# Edit your environment settings
nano ../.env
```

Configure these essentials in `.env`:
- `PUID` and `PGID` - your user/group IDs (`id $USER`)
- `TZ` - your timezone
- `DB_PASS` and `JWT_SECRET` - secure random passwords

## Step 2: VPN Configuration (Optional but Recommended)

1. Get a config file from your VPN provider (WireGuard format)
2. Save it as `containers/core/wg0.conf`
3. Update the Gluetun environment in `containers/core/docker-compose.yml`

## Step 3: Deploy Services

```bash
# Deploy everything at once
cd setup
./deploy-all.sh

# OR deploy step by step for more control
cd containers/core && docker-compose up -d    # VPN first
cd ../downloads && docker-compose up -d       # Downloads second
cd ../media && docker-compose up -d           # Media last
```

## Step 4: Initial Configuration

### 4.1 Jellyfin Setup
1. Go to http://localhost:8096
2. Run through setup wizard
3. Add media libraries:
   - Movies: `/data/media/movies`
   - TV Shows: `/data/media/shows`

### 4.2 Prowlarr Setup
1. Go to http://localhost:9696
2. Add indexers (torrent/usenet sites)
3. Add download clients:
   - qBittorrent: `http://gluetun:8080`
   - NZBGet: `http://gluetun:6789`

### 4.3 Sonarr/Radarr Setup
1. Go to http://localhost:8989 (Sonarr) and http://localhost:7878 (Radarr)
2. Add Prowlarr as indexer source
3. Add download clients (same as Prowlarr)
4. Configure root folders:
   - Sonarr: `/shows`
   - Radarr: `/movies`

## Step 5: Verify Everything Works

1. **Check VPN**: Download something in qBittorrent and verify IP
2. **Test automation**: Add a TV show/movie in Sonarr/Radarr
3. **Check media**: Verify content appears in Jellyfin

## Troubleshooting

### Downloads not working
```bash
# Check VPN connection
docker logs gluetun

# Test connection inside VPN container
docker exec -it gluetun curl ifconfig.me
```

### Media not appearing
- Check folder permissions: `ls -la /data/media`
- Verify paths in Jellyfin library settings
- Check container logs: `docker logs jellyfin`

### Services can't connect
- Verify all containers are on homelab network
- Check container names match in configs
- Restart services: `docker-compose restart`

## Management

```bash
# View all running containers
docker ps

# Check service logs
docker logs [container_name]

# Restart a service group
cd containers/[group] && docker-compose restart

# Stop everything
cd setup && ./stop-all.sh

# Update a service
cd containers/[group] && docker-compose pull && docker-compose up -d
```
