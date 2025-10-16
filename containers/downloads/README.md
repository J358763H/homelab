# 📥 Download Clients

Torrent and Usenet download clients that route through VPN for privacy.

## Services Included
- **qBittorrent** - Torrent client (routes through VPN)
- **NZBGet** - Usenet client (routes through VPN)

## Prerequisites
⚠️ **IMPORTANT**: Core infrastructure must be running first (VPN)
```bash
cd ../core && docker-compose up -d
```

## Quick Deploy
```bash
cd containers/downloads
docker-compose up -d
```

## Individual Services
```bash
# Start qBittorrent only
docker-compose up -d qbittorrent

# Start NZBGet only
docker-compose up -d nzbget
```

## Access
- qBittorrent: http://localhost:8080
- NZBGet: http://localhost:6789

## Note
Both services use `network_mode: "service:gluetun"` which means they share the VPN container's network. This is why gluetun must be running first.
