# 🎬 Complete Servarr + Jellyfin Directory Tree
## 📁 Full Directory Structure
```
/data/
├── docker/                           # Docker container configurations
│   ├── jellyfin/                     # Jellyfin media server config
│   │   ├── config/                   # Jellyfin settings & database
│   │   ├── cache/                    # Jellyfin cache files
│   │   └── log/                      # Jellyfin log files
│   ├── sonarr/                       # TV show management
│   │   ├── config.xml                # Sonarr configuration
│   │   ├── sonarr.db                 # Sonarr database
│   │   └── logs/                     # Sonarr logs
│   ├── radarr/                       # Movie management
│   │   ├── config.xml                # Radarr configuration
│   │   ├── radarr.db                 # Radarr database
│   │   └── logs/                     # Radarr logs
│   ├── bazarr/                       # Subtitle management
│   │   ├── config/                   # Bazarr configuration
│   │   ├── db/                       # Bazarr database
│   │   └── log/                      # Bazarr logs
│   ├── prowlarr/                     # Indexer management
│   │   ├── prowlarr.db               # Prowlarr database
│   │   ├── config.xml                # Prowlarr configuration
│   │   └── logs/                     # Prowlarr logs
│   ├── qbittorrent/                  # BitTorrent client
│   │   ├── qBittorrent.conf          # qBittorrent settings
│   │   ├── rss/                      # RSS configurations
│   │   └── logs/                     # qBittorrent logs
│   ├── flaresolverr/                 # Cloudflare bypass
│   │   └── config/                   # FlareSolverr configuration
│   ├── overseerr/                    # Request management
│   │   ├── db/                       # Overseerr database
│   │   ├── config/                   # Overseerr configuration
│   │   └── logs/                     # Overseerr logs
│   ├── tautulli/                     # Jellyfin analytics
│   │   ├── config.ini                # Tautulli configuration
│   │   ├── tautulli.db               # Tautulli database
│   │   └── logs/                     # Tautulli logs
│   ├── notifiarr/                    # Notification service
│   │   └── notifiarr.conf            # Notifiarr configuration
│   ├── recyclarr/                    # Quality profile management
│   │   ├── config.yml                # Recyclarr configuration
│   │   └── logs/                     # Recyclarr logs
│   └── suggestarr/                   # Content suggestions
│       ├── config/                   # Suggestarr configuration
│       └── logs/                     # Suggestarr logs
│
├── media/                            # MEDIA LIBRARY (Jellyfin reads from here)
│   ├── movies/                       # Movie collection
│   │   ├── Action/
│   │   │   ├── Movie Name (2023)/
│   │   │   │   ├── Movie Name (2023).mkv
│   │   │   │   ├── Movie Name (2023).srt    # Subtitles (Bazarr)
│   │   │   │   └── poster.jpg               # Metadata
│   │   │   └── Another Movie (2024)/
│   │   ├── Comedy/
│   │   ├── Drama/
│   │   └── Sci-Fi/
│   │
│   ├── shows/                        # TV show collection
│   │   ├── Show Name (2023)/
│   │   │   ├── Season 01/
│   │   │   │   ├── Show Name - S01E01 - Episode Title.mkv
│   │   │   │   ├── Show Name - S01E01 - Episode Title.srt
│   │   │   │   ├── Show Name - S01E02 - Episode Title.mkv
│   │   │   │   └── Show Name - S01E02 - Episode Title.srt
│   │   │   ├── Season 02/
│   │   │   └── tvshow.nfo              # Metadata
│   │   ├── Another Show (2024)/
│   │   └── Documentary Series (2023)/
│   │
│   ├── music/                        # Music collection (optional)
│   │   ├── Artist Name/
│   │   │   ├── Album Name (Year)/
│   │   │   │   ├── 01 - Track Name.flac
│   │   │   │   └── cover.jpg
│   │   │   └── Another Album/
│   │   └── Various Artists/
│   │
│   └── youtube/                      # YouTube downloads
│       ├── channels/
│       │   ├── TechnoTim/
│       │   ├── LinusTechTips/
│       │   └── NetworkChuck/
│       └── playlists/
│
└── downloads/                        # DOWNLOAD STAGING (qBittorrent writes here)
    ├── incomplete/                   # Active downloads
    │   ├── Movie.Name.2023.1080p.torrent
    │   └── TV.Show.S01E01.torrent
    │
    ├── movies/                       # Completed movie downloads
    │   ├── Movie.Name.2023.1080p.BluRay.x264/
    │   │   ├── Movie.Name.2023.1080p.BluRay.x264.mkv
    │   │   └── Movie.Name.2023.1080p.BluRay.x264.nfo
    │   └── Another.Movie.2024.2160p.WEB-DL/
    │
    ├── shows/                        # Completed TV downloads
    │   ├── Show.Name.S01E01.1080p.WEB-DL/
    │   │   └── Show.Name.S01E01.1080p.WEB-DL.mkv
    │   ├── Show.Name.S01E02.1080p.WEB-DL/
    │   └── Documentary.Series.S01/
    │
    └── music/                        # Music downloads (optional)
        ├── Artist.Name.Album.FLAC/
        └── Various.Artists.Compilation/

```
## 🔄 Workflow Process
### **Download → Processing → Library Flow**
1. **🔍 Search & Download**

   ```
   Overseerr Request → Sonarr/Radarr → Prowlarr → qBittorrent
   ```

2. **📥 Download Staging**

   ```
   qBittorrent downloads to: /data/downloads/[movies|shows]/
   ```

3. **🎯 Automated Processing**

   ```
   Sonarr/Radarr monitors downloads → Renames & organizes → Moves to /data/media/
   ```

4. **📚 Library Integration**

   ```
   Jellyfin scans /data/media/ → Bazarr adds subtitles → Ready for streaming
   ```

## 🎛️ Service Integration
### **Core Stack**

- **Jellyfin** (`172.20.0.10`): Media server & streaming
- **Sonarr** (`172.20.0.5`): TV show automation
- **Radarr** (`172.20.0.6`): Movie automation
- **Bazarr** (`172.20.0.7`): Subtitle management
- **Prowlarr** (`172.20.0.8`): Indexer management
- **qBittorrent** (via Gluetun): Download client

### **Enhancement Stack**

- **Overseerr** (`172.20.0.11`): Request management
- **Tautulli** (`172.20.0.12`): Analytics & monitoring
- **Recyclarr** (`172.20.0.15`): Quality profile sync
- **Notifiarr** (`172.20.0.16`): Notification hub
- **Suggestarr** (`172.20.0.18`): Content suggestions

### **Utility Stack**

- **Gluetun** (`172.20.0.2`): VPN gateway
- **FlareSolverr** (`172.20.0.9`): Cloudflare bypass

## 📊 Volume Mappings
### **Jellyfin Media Access**

```yaml
volumes:
  - /data/docker/jellyfin:/config          # Configuration
  - /data/media:/data/media                # Full media library
  - /dev/shm:/data/transcode              # RAM transcoding

```
### **Sonarr TV Management**

```yaml
volumes:
  - /data/docker/sonarr:/config           # Configuration
  - /data/media:/data/media               # Full media access
  - /data/downloads:/downloads            # Download monitoring
  - /data/media/shows:/shows              # Direct TV access

```
### **Radarr Movie Management**

```yaml
volumes:
  - /data/docker/radarr:/config           # Configuration
  - /data/media:/data/media               # Full media access
  - /data/downloads:/downloads            # Download monitoring
  - /data/media/movies:/movies            # Direct movie access

```
### **qBittorrent Downloads**

```yaml
volumes:
  - /data/docker/qbittorrent:/config      # Configuration
  - /data/downloads:/downloads            # Download destination

```
## 🔧 Permissions & Ownership
All media files should have consistent permissions:

```bash
# User/Group IDs (set in .env)
PUID=1000    # media user
PGID=1000    # media group

# File permissions
Files: 644 (rw-r--r--)
Directories: 755 (rwxr-xr-x)

```
## 🎯 Key Benefits
1. **Separation of Concerns**: Downloads and media library are separate
2. **Automated Workflow**: Minimal manual intervention required
3. **Quality Control**: Recyclarr maintains consistent quality profiles
4. **Family Friendly**: Clear directory names (`shows` vs `tv`)
5. **Scalable**: Easy to add new content types or services
6. **Backup Ready**: Clear separation for backup strategies

---
*Generated on: $(date)*
*Configuration: TechnoTim-aligned Servarr + Jellyfin Stack*

