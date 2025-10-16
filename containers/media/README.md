# 🎬 Media Management & Streaming

Complete Servarr stack for automated media management plus Jellyfin for streaming.

## Services Included
- **Jellyfin** - Media server and streaming
- **Prowlarr** - Indexer management hub
- **Sonarr** - TV show automation
- **Radarr** - Movie automation
- **Bazarr** - Subtitle automation
- **Recyclarr** - Quality profile management
- **JellyStat** - Jellyfin analytics

## Quick Deploy
```bash
cd containers/media
docker-compose up -d
```

## Service Groups
```bash
# Start just Jellyfin
docker-compose up -d jellyfin

# Start Servarr stack only
docker-compose up -d prowlarr sonarr radarr bazarr

# Start analytics
docker-compose up -d jellystat-db jellystat
```

## Access Points
- Jellyfin: http://localhost:8096
- Prowlarr: http://localhost:9696
- Sonarr: http://localhost:8989
- Radarr: http://localhost:7878
- Bazarr: http://localhost:6767
- JellyStat: http://localhost:3000

## Setup Order
1. Start Jellyfin first
2. Configure Prowlarr with indexers
3. Add download clients to Prowlarr
4. Configure Sonarr/Radarr with Prowlarr
5. Setup Bazarr for subtitles
