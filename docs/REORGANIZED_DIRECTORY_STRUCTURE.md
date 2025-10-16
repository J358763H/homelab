# 🏗️ Homelab Directory Structure - TechHut Methodology
# =====================================================
# Based on TechHut's Proxmox Homelab Series
# Optimized for Servarr Stack + Jellyfin Media Server
# =====================================================

## 📁 Recommended Directory Structure on Proxmox LXC Container:

```
/data/
├── docker/                           # Docker container configurations
│   ├── bazarr/                      # Bazarr config files
│   ├── gluetun/                     # VPN configuration
│   ├── jellyfin/                    # Jellyfin server config
│   ├── jellyseerr/                  # Request management config
│   ├── jellystat/                   # Analytics config
│   │   └── backup-data/             # Analytics backups
│   ├── jellystat-db/               # PostgreSQL database
│   ├── nzbget/                      # Usenet client config
│   ├── prowlarr/                    # Indexer management config
│   ├── qbittorrent/                 # Torrent client config
│   ├── radarr/                      # Movie management config
│   ├── recyclarr/                   # Quality profile management
│   ├── sonarr/                      # TV show management config
│   ├── tunarr/                      # Channel management config
│   ├── wizarr/                      # User invitation config
│   └── ytdl-sub/                    # YouTube downloader config
│
├── media/                           # Media library (main storage)
│   ├── downloads/                   # Download staging area
│   │   ├── complete/                # Completed downloads
│   │   ├── incomplete/              # In-progress downloads
│   │   ├── movies/                  # Movie downloads
│   │   ├── shows/                   # TV show downloads
│   │   └── usenet/                  # Usenet downloads
│   │
│   ├── movies/                      # Final movie library
│   │   ├── Action/
│   │   ├── Comedy/
│   │   ├── Drama/
│   │   └── [Other Genres]/
│   │
│   ├── shows/                       # Final TV show library
│   │   ├── Show Name (Year)/
│   │   │   ├── Season 01/
│   │   │   ├── Season 02/
│   │   │   └── extras/
│   │   └── [Other Shows]/
│   │
│   ├── youtube/                     # YouTube content
│   │   ├── admin/                   # Admin/parent content
│   │   ├── family/                  # Family-safe content
│   │   ├── kids/                    # Children's content
│   │   ├── music/                   # Music content
│   │   └── teen/                    # Teen content
│   │
│   └── music/                       # Music library (future expansion)
│       ├── Albums/
│       ├── Artists/
│       └── Playlists/
│
├── backups/                         # System and data backups
│   ├── daily/                       # Daily incremental backups
│   ├── weekly/                      # Weekly full backups
│   └── configs/                     # Configuration backups
│
└── logs/                           # Application and system logs
    ├── docker/                      # Docker container logs
    └── system/                      # System-level logs
```

## 🔗 Service Communication Flow:

```
Internet
    ↓
[VPN Gateway - Gluetun]
    ↓
[Download Clients] ← [Indexers via Prowlarr]
 qBittorrent            ↑
 NZBGet            [FlareSolverr]
    ↓
[Download Processing]
    ↓
[Media Management - Servarr Stack]
 Sonarr (TV) ←→ Bazarr (Subtitles)
 Radarr (Movies) ←→ Recyclarr (Quality)
    ↓
[Media Library]
    ↓
[Media Server - Jellyfin] ←→ [Analytics - JellyStat]
    ↓
[User Management]
 Jellyseerr (Requests) ←→ Wizarr (Invites)
    ↓
[Enhancement Services]
 YouTube Automation ←→ Tunarr (Channels)
```

## 🌐 Network Layout (TechHut Style):

```
Proxmox Host: 192.168.1.50
├── Docker LXC: 192.168.1.100
│   └── Docker Network: 172.20.0.0/16
│       ├── Gluetun VPN: 172.20.0.5
│       ├── FlareSolverr: 172.20.0.9
│       ├── Prowlarr: 172.20.0.10
│       ├── Sonarr: 172.20.0.11
│       ├── Radarr: 172.20.0.12
│       ├── Bazarr: 172.20.0.13
│       ├── Recyclarr: 172.20.0.14
│       ├── Jellyfin: 172.20.0.20
│       ├── JellyStat DB: 172.20.0.25
│       ├── JellyStat: 172.20.0.26
│       ├── Jellyseerr: 172.20.0.30
│       ├── Wizarr: 172.20.0.31
│       ├── YT-DL-Sub: 172.20.0.35
│       ├── YT Automation: 172.20.0.36
│       └── Tunarr: 172.20.0.37
│
├── NPM (Reverse Proxy): 192.168.1.201
├── Tailscale VPN: 192.168.1.202
├── Ntfy Notifications: 192.168.1.203
├── Samba File Share: 192.168.1.204
├── Pi-hole DNS: 192.168.1.205
└── Vaultwarden: 192.168.1.206
```

## 🔧 Key Improvements in Reorganized Structure:

### 1. **Logical Service Grouping**
- **VPN & Networking Layer**: Foundation services
- **Download Clients Layer**: All download traffic isolated
- **Media Management Layer**: Servarr stack in logical order
- **Media Server Layer**: Jellyfin and related services
- **Analytics & Monitoring**: JellyStat and metrics
- **User Management**: Request and invitation systems
- **Automation**: YouTube and enhancement services

### 2. **Improved IP Addressing**
- **5-9**: Networking & VPN services
- **10-19**: Media management (Servarr)
- **20-24**: Media servers
- **25-29**: Analytics & monitoring
- **30-34**: User management
- **35-39**: Automation services
- **40+**: Optional/future services

### 3. **Better Dependencies**
- Clear service dependencies defined
- Logical startup order
- Health checks for critical services

### 4. **Enhanced Documentation**
- Clear comments explaining each layer
- Hardware acceleration notes for Intel GPU
- Network routing explanations

## 🚀 Migration Instructions:

1. **Backup current setup**: `docker-compose down`
2. **Review new structure**: Compare with current setup
3. **Update environment variables**: Ensure all vars are defined
4. **Test new compose**: `docker-compose -f docker-compose.reorganized.yml config`
5. **Deploy gradually**: Start with core services first
6. **Verify connectivity**: Test each layer before proceeding

This structure follows TechHut's proven methodology for a reliable, scalable homelab media server setup! 🎬