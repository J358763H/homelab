# 🏗️ Homelab Hardware Architecture

Comprehensive hardware specifications and architecture for the Homelab-SHV infrastructure.

**Last Updated:** October 12, 2025  
**Maintainer:** J35867U

## 📊 Infrastructure Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    HOMELAB-SHV INFRASTRUCTURE                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────┐ │
│  │   PRIMARY HOST  │    │   GAME SERVER   │    │ BACKUP NODE │ │
│  │   (i5-8400)     │────│   (i5-6500)     │────│  (Laptop)   │ │
│  │   Proxmox VE    │    │   Dedicated     │    │ Cold Backup │ │
│  │   24GB RAM      │    │   8GB RAM       │    │ External    │ │
│  └─────────────────┘    └─────────────────┘    └─────────────┘ │
│           │                       │                      │     │
│           ▼                       ▼                      ▼     │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────┐ │
│  │ Docker Stack    │    │ Game Streaming  │    │ Restic      │ │
│  │ LXC Services    │    │ Emulation       │    │ Archive     │ │
│  │ Media Server    │    │ Game Servers    │    │ Storage     │ │
│  └─────────────────┘    └─────────────────┘    └─────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 🖥️ Primary Homelab Server (homelab-SHV)

### **Hardware Specifications**
- **CPU**: Intel Core i5-8400 (6 cores, 6 threads, 2.8-4.0 GHz)
- **RAM**: 24GB DDR4 
- **Storage**:
  - **System**: 256GB NVMe SSD (Proxmox VE + VMs)
  - **Fast Storage**: 2x 512GB NVMe SSD (Docker volumes, databases)
  - **Archive**: 500GB HDD (temporary/staging)
  - **Media**: 2x 8TB HDD (media library, RAID1 or separate volumes)
- **Network**: 2.5Gb Ethernet port
- **GPU**: Intel UHD Graphics 630 (Hardware transcoding via Quick Sync)

### **Role & Services**
- **Primary Function**: Main homelab infrastructure host
- **Hypervisor**: Proxmox VE 8.x
- **Workloads**:
  - Docker media stack (Jellyfin, Sonarr, Radarr, etc.)
  - LXC infrastructure services (NPM, Tailscale, Pi-hole, etc.)
  - Storage management and file sharing
  - VPN routing and remote access

### **Performance Characteristics**
- **Transcoding**: 4-6 simultaneous 1080p → 720p streams via Intel Quick Sync
- **Storage I/O**: High-speed NVMe for databases and active data
- **Network**: 2.5Gb provides ample bandwidth for 4K streaming + backups
- **Virtualization**: Can handle 8-12 LXC containers + 2-3 VMs comfortably

### **Storage Architecture**
```
┌─────────────────────────────────────────────────────────────────┐
│                    STORAGE HIERARCHY                             │
├─────────────────────────────────────────────────────────────────┤
│  256GB NVMe SSD                                                 │
│  ├── Proxmox VE (root)                    ~50GB                 │
│  ├── Docker VM                            ~100GB                │
│  └── LXC containers                       ~100GB                │
├─────────────────────────────────────────────────────────────────┤
│  512GB NVMe SSD #1                                              │
│  ├── Docker volumes (databases)           ~200GB                │
│  ├── Application data                     ~200GB                │
│  └── Cache/temp processing                ~100GB                │
├─────────────────────────────────────────────────────────────────┤
│  512GB NVMe SSD #2                                              │
│  ├── VM storage pool                      ~300GB                │
│  └── Backup staging                       ~200GB                │
├─────────────────────────────────────────────────────────────────┤
│  500GB 2.5" SATA HDD (via USB/SATA)                            │
│  ├── Download staging (qBittorrent)       ~300GB                │
│  ├── Processing queue (Sonarr/Radarr)     ~150GB                │
│  └── Failed/incomplete downloads          ~50GB                 │
├─────────────────────────────────────────────────────────────────┤
│  2x 8TB HDDs - RECOMMENDED CONFIGURATION                       │
│  Option A: ZFS Mirror (8TB usable, full redundancy)            │
│  ├── Media library (movies/shows)         ~8TB                  │
│  └── Automatic redundancy + snapshots     (built-in)           │
│                                                                 │
│  Option B: Storage Pool (16TB usable, no redundancy)           │
│  ├── Media library (combined)             ~16TB                 │
│  └── Requires separate backup strategy    (manual)              │
└─────────────────────────────────────────────────────────────────┘
```

## 🎮 Game Server (Dedicated)

### **Hardware Specifications**
- **CPU**: Intel Core i5-6500 (4 cores, 4 threads, 3.2-3.6 GHz)
- **RAM**: 4GB → **Upgrading to 8GB**
- **Storage**: 512GB NVMe SSD (**More storage planned**)
- **Network**: Standard Gigabit Ethernet
- **GPU**: Intel HD Graphics 530 (Basic encoding capability)

### **Role & Services**
- **Primary Function**: Dedicated gaming and emulation server
- **OS**: Ubuntu 22.04 LTS (bare metal)
- **Workloads**:
  - Moonlight/Sunshine game streaming server
  - CoinOps retro gaming emulation platform
  - Docker game servers (Minecraft, Valheim, Factorio)
  - CPU-optimized encoding (no dedicated GPU)

### **Performance Characteristics**
- **Game Streaming**: 1080p @ 30-60fps via CPU encoding
- **Emulation**: PSX, N64, GameBoy, SNES, NES, Arcade systems
- **Game Servers**: 2-3 concurrent lightweight game servers
- **Encoding**: Intel HD 530 provides basic hardware acceleration

### **Planned Upgrades**
- **RAM**: 4GB → 8GB (immediate priority)
- **Storage**: Additional storage for game libraries and save data
- **Network**: Potential 2.5Gb upgrade for better streaming quality

## 💾 Cold Backup Node (Laptop)

### **Hardware Specifications**
- **Type**: Laptop (portable backup solution)
- **Role**: Cold storage and disaster recovery
- **Connection**: **External storage enclosure planned**
- **Network**: WiFi/Ethernet as available

### **Role & Services**
- **Primary Function**: Offline backup and disaster recovery
- **Backup Software**: Restic with encryption
- **Storage**: External enclosure for easy backup management
- **Frequency**: Weekly/monthly cold backups
- **Recovery**: Full system restore capability

## 🌐 Network Architecture

### **Network Topology**
```
Internet
    │
Router/Modem
    │
Switch (Gigabit/2.5Gb)
    ├── homelab-SHV (192.168.1.100) [2.5Gb]
    ├── Game Server (192.168.1.106) [1Gb]
    ├── Backup Node (WiFi/Ethernet as needed)
    └── Client Devices
```

### **IP Address Allocation**
```bash
# Primary Infrastructure
192.168.1.100    # Docker Host VM (Primary)
192.168.1.106    # Game Server (Dedicated)

# LXC Infrastructure Services (200-219)
192.168.1.201    # Nginx Proxy Manager
192.168.1.202    # Tailscale VPN Router  
192.168.1.203    # Ntfy Notifications
192.168.1.204    # Media File Share (Samba)
192.168.1.205    # Pi-hole DNS
192.168.1.206    # Vaultwarden Password Manager
```

## 💾 Storage Strategy Deep Dive

### **500GB 2.5" SATA HDD Usage**

**Recommended Role: Download Staging Drive**

**Why This Makes Sense:**
- **Perfect Size**: Large enough for multiple simultaneous downloads, small enough to stay fast
- **USB/SATA Connection**: Easy to connect via USB-to-SATA adapter or dock
- **Wear Leveling**: Protects your NVMe drives from constant download writes
- **Easy Replacement**: If it fails, minimal impact vs. losing media library

**Optimal Configuration:**
```bash
# Mount as download staging
/media/staging/
├── downloads/          # qBittorrent download directory
├── processing/         # Sonarr/Radarr processing queue  
├── completed/          # Temporary storage before move to media drives
└── failed/             # Failed/incomplete downloads for review
```

**Workflow Benefits:**
1. **Download** → 500GB HDD (fast, disposable, protects other drives)
2. **Process** → NVMe SSD (Sonarr/Radarr processing) 
3. **Store** → 8TB ZFS mirror (permanent, protected media library)
4. **Protect** → NVMe drives from download wear, media from download failures

**500GB Drive Implementation:**
```bash
# USB-to-SATA adapter connection (recommended)
# - Easy hot-swapping if drive fails
# - No internal SATA port usage
# - Can be moved between systems
# - Cheap to replace ($20-30 vs $200+ media drives)

# Mount configuration in Proxmox
/media/downloads/
├── incomplete/     # Active qBittorrent downloads
├── completed/      # Finished downloads awaiting processing  
├── processing/     # Sonarr/Radarr import queue
└── failed/         # Failed downloads for manual review

# Docker volume mapping
qbittorrent:
  volumes:
    - /media/downloads:/downloads
    
sonarr/radarr:
  volumes:
    - /media/downloads/completed:/downloads
    - /media/media-pool/shows:/tv
    - /media/media-pool/movies:/movies
```

**Why This Setup Works for Aging Drives:**
- **500GB failure**: Minimal impact, just re-download current items
- **8TB failure in mirror**: Automatic rebuild, no data loss
- **8TB failure in pool**: Catastrophic - lose entire library

### **8TB HDD Configuration Analysis**

#### **Option A: ZFS Mirror (ESSENTIAL for 5+ Year Old Drives)**
```bash
# ZFS mirror configuration for aging hardware
Storage: 8TB usable (50% efficiency)
Redundancy: Full - can lose 1 drive safely
Performance: Good read speeds, decent write
Protection: Built-in checksumming, snapshots, scrubbing
Recovery: Automatic healing, hot replacement
Monitoring: Proactive failure detection

Pros:
✅ Complete data protection (crucial for aging drives)
✅ Automatic error correction and healing
✅ Detects silent corruption (common in old drives)
✅ Easy snapshots and backups
✅ No manual intervention during drive failure
✅ ZFS scrubs detect issues before catastrophic failure
✅ Can replace failing drives without downtime

Cons:
❌ 50% storage efficiency (acceptable trade-off for reliability)
❌ More complex setup (worth it for data protection)
```

#### **Option B: Simple Pool (DANGEROUS with Aging Drives)**
```bash
# Simple storage pool with aging drives
Storage: 16TB usable (100% efficiency) 
Redundancy: None - lose everything if 1 drive fails
Performance: Good write speeds
Protection: Manual backups only (high risk with old drives)
Recovery: Complete rebuild from backups (if they exist)

Pros:
✅ Maximum storage space
✅ Simple configuration initially

Cons:
❌ EXTREMELY HIGH RISK with 5+ year old used drives
❌ Complete data loss when (not if) drive fails
❌ No protection against silent bit rot (common in aging drives)
❌ No early warning system for drive degradation
❌ Manual backup burden (often neglected)
❌ Catastrophic failure mode with aging hardware
❌ 16TB loss vs 0TB loss with mirror
```

### **Storage Recommendation: ZFS Mirror (CRITICAL for Aging Drives)**

**With 5+ year old drives, ZFS Mirror becomes ESSENTIAL:**

1. **Aging Hardware Protection**: Older drives have higher failure probability
2. **Used Drive Risk**: Unknown previous usage patterns and stress
3. **SMART is Lagging Indicator**: Drives can fail suddenly even with good SMART
4. **Irreplaceable Data**: Your media collection represents years of curation
5. **Cost of Failure**: Losing 16TB of media vs. "only" 8TB in mirror

**Critical Implementation for Aging Drives:**
```bash
# Create ZFS mirror with aggressive monitoring
zpool create media-pool mirror /dev/sdb /dev/sdc
zfs create media-pool/movies
zfs create media-pool/shows  
zfs create media-pool/music

# Enable compression and frequent snapshots
zfs set compression=lz4 media-pool
zfs set snapdir=visible media-pool

# Set up automatic scrubbing (weekly for aging drives)
echo "0 2 * * 0 root zpool scrub media-pool" >> /etc/crontab

# Enable email alerts for any ZFS issues
echo "ZED_EMAIL_ADDR=your@email.com" >> /etc/zfs/zed.d/zed.rc
```

**Additional Monitoring for Aging Drives:**
```bash
# Daily SMART checks
smartctl -a /dev/sdb | grep -E "(Temperature|Reallocated|Current_Pending)"
smartctl -a /dev/sdc | grep -E "(Temperature|Reallocated|Current_Pending)"

# Monitor ZFS pool health
zpool status media-pool
zpool iostat media-pool 1 5  # Check for unusual I/O patterns
```

### **Aging Drive Risk Assessment**

**Your Hardware Profile: HIGH RISK**
- **Primary Risk**: Multiple 5+ year old drives
- **Secondary Risk**: Used 8TB drives (unknown wear history)
- **Failure Window**: Higher probability in next 1-2 years
- **Impact**: Complete media library loss without redundancy

**Risk Mitigation Strategy:**
```bash
# Monitor drive health weekly
#!/bin/bash
# Add to weekly health check script
for drive in /dev/sdb /dev/sdc; do
    echo "=== SMART Status for $drive ==="
    smartctl -H $drive
    smartctl -A $drive | grep -E "(Reallocated_Sector_Ct|Current_Pending_Sector|Offline_Uncorrectable)"
    echo "Temperature: $(smartctl -A $drive | grep Temperature_Celsius | awk '{print $10}')°C"
done
```

**Drive Replacement Planning:**
1. **Budget**: Set aside funds for replacement drives
2. **Monitoring**: Watch for SMART attribute changes
3. **Proactive Replacement**: Replace drives showing degradation before failure
4. **Hot Spares**: Consider keeping spare drive if budget allows

### **Future Expansion Strategy**

**Phase 1 (Current)**: 500GB staging + 8TB ZFS mirror (essential with aging drives)
**Phase 2 (3-6 months)**: Monitor drive health, replace any showing degradation
**Phase 3 (6-12 months)**: Add second 8TB mirror pair → 16TB total
**Phase 4 (1-2 years)**: Proactive replacement of original aging drives

**Why ZFS Mirror is Critical for Your Setup:**
- **Aging drives fail more frequently**: Redundancy is insurance
- **Used drives have unknown stress**: Previous heavy usage patterns unknown
- **SMART lag time**: Drives can fail suddenly even with good recent SMART data
- **5+ years is critical age**: Many drives fail in years 5-8 of operation
- **Media is irreplaceable**: Your time investment in curation
- **Download bandwidth**: Re-downloading 8TB+ takes weeks even with fast internet

## ⚡ Performance Optimization

### **Intel Quick Sync (i5-8400)**
- **Hardware Transcoding**: Enabled for Jellyfin
- **Codec Support**: H.264, H.265 (HEVC), VP9
- **Device Access**: `/dev/dri/renderD128` passed to containers
- **Performance**: ~10x more efficient than CPU-only transcoding

### **Storage Optimization**
- **NVMe SSDs**: Database storage, Docker volumes, active VMs
- **HDDs**: Media library with redundancy (RAID1 or backup strategy)
- **Staging Area**: Fast NVMe for download processing before archival

### **Memory Allocation**
```bash
# Proxmox Host (24GB total)
├── Proxmox VE overhead           ~2GB
├── Docker VM                     ~12GB
├── LXC containers                ~6GB
└── Host cache/buffer             ~4GB

# Game Server (8GB planned)
├── Ubuntu OS                     ~1GB
├── Game streaming services       ~2GB
├── Game servers                  ~3GB
└── System cache                  ~2GB
```

## 🔧 Hardware Requirements by Service

### **Minimum Requirements (Per Service)**
```yaml
Jellyfin (with transcoding):
  CPU: i5-8400 (Quick Sync essential)
  RAM: 4GB allocated
  Storage: NVMe for metadata, HDD for media

Sonarr/Radarr/Prowlarr:
  CPU: 2 cores allocated
  RAM: 1GB each
  Storage: Fast SSD for databases

Game Streaming Server:
  CPU: i5-6500 minimum (4 cores)
  RAM: 6GB for encoding + games
  Network: 100Mbps minimum, 1Gb recommended

LXC Services (each):
  CPU: 1-2 cores
  RAM: 512MB - 2GB depending on service
  Storage: 2-8GB system disk
```

### **Scaling Recommendations**

#### **Current Capacity**
- **Simultaneous Users**: 8-10 (media streaming)
- **Game Streams**: 1-2 concurrent
- **Docker Services**: 15+ containers
- **LXC Containers**: 6+ infrastructure services

#### **Upgrade Priorities**
1. **Game Server RAM**: 4GB → 8GB (immediate)
2. **Game Server Storage**: Add 1-2TB for game libraries
3. **Backup Storage**: External enclosure for laptop backup node
4. **Network**: Consider 2.5Gb switch for full bandwidth utilization

## 🔒 Hardware Security Considerations

### **Physical Security**
- **Server Location**: Secure, temperature-controlled environment
- **Power**: UPS recommended for graceful shutdowns
- **Cooling**: Adequate ventilation for 24/7 operation

### **Data Protection**
- **RAID**: Consider RAID1 for 8TB drives (media redundancy)
- **Backups**: Multiple backup strategies (local + cold storage)
- **Encryption**: Full disk encryption on sensitive systems

## 📈 Monitoring & Hardware Health

### **System Monitoring**
- **Temperature**: CPU, storage drive temperatures
- **Storage Health**: S.M.A.R.T. monitoring for all drives
- **Memory**: Usage patterns and potential upgrades
- **Network**: Bandwidth utilization and bottlenecks

### **Maintenance Schedule**
- **Monthly**: Check drive health, clean dust filters
- **Quarterly**: Verify backup integrity, test disaster recovery
- **Annually**: Consider hardware upgrades, replace aging components

## 🚀 Future Expansion Plans

### **Short Term (6 months)**
- [ ] Game server RAM upgrade (4GB → 8GB)
- [ ] External storage enclosure for backup node
- [ ] Additional game server storage (1-2TB)

### **Medium Term (1 year)**
- [ ] Network upgrade to 2.5Gb throughout
- [ ] Consider additional NVMe storage for cache
- [ ] Evaluate backup server upgrade

### **Long Term (2+ years)**
- [ ] Primary server CPU/motherboard upgrade
- [ ] Move to enterprise-grade storage
- [ ] Consider dedicated network attached storage (NAS)

---

## 📋 Hardware Compatibility Notes

### **Tested Configurations**
- **Intel Quick Sync**: Confirmed working on i5-8400
- **Docker Performance**: 24GB RAM handles current workload comfortably  
- **Network Throughput**: 2.5Gb adequate for 4K + backup traffic
- **Storage Performance**: NVMe provides excellent I/O for databases

### **Known Limitations**
- **Game Server**: Limited by 4GB RAM (upgrade planned)
- **Backup Speed**: Limited by network speed to laptop
- **Transcoding**: Single stream limited by Quick Sync capabilities

---

*This document reflects the actual hardware deployment as of October 2025. Update as hardware changes or upgrades are implemented.*