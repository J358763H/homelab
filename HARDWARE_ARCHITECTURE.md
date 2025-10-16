# 🏗️ Homelab Hardware Architecture

Comprehensive hardware specifications and architecture for the homelab infrastructure.

**Last Updated:** October 12, 2025  
**Maintainer:** J35867U

## 📊 Infrastructure Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    HOMELAB INFRASTRUCTURE                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐                        ┌─────────────────┐ │
│  │   PRIMARY HOST  │                        │   BACKUP NODE   │ │
│  │   (i5-8400)     │────────────────────────│   (Laptop)      │ │
│  │   Proxmox VE    │                        │   Cold Backup   │ │
│  │   24GB RAM      │                        │   External      │ │
│  └─────────────────┘                        └─────────────────┘ │
│           │                                            │        │
│           ▼                                            ▼        │
│  ┌─────────────────┐                        ┌─────────────────┐ │
│  │ Docker Stack    │                        │ Restic Archive  │ │
│  │ LXC Services    │                        │ Storage         │ │
│  │ Media Server    │                        │                 │ │
│  └─────────────────┘                        └─────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 🖥️ Primary Homelab Server (homelab)

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
│  ├── Media library (movies/shows)         ~6-7TB               │
│  ├── Photo library (with room to grow)    ~1-2TB               │
│  └── Automatic redundancy + snapshots     (built-in)           │
│                                                                 │
│  Option B: Storage Pool (16TB usable, no redundancy)           │
│  ├── Media library (combined)             ~14TB                │
│  ├── Photo library                        ~2TB                 │
│  └── Requires separate backup strategy    (manual)              │
└─────────────────────────────────────────────────────────────────┘
```





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
  ├── homelab (192.168.1.100) [2.5Gb]

    ├── Backup Node (WiFi/Ethernet as needed)
    └── Client Devices
```

### **IP Address Allocation**
```bash
# Primary Infrastructure
192.168.1.100    # Docker Host VM (Primary)

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

## 📸 Photo Library Considerations

### **Current Storage Capacity Analysis**

**Available for Photo Library:**
```bash
# With ZFS Mirror (8TB usable)
Current video media:        ~0-2TB (starting collection)
Photo library potential:    ~1-2TB (room for growth)
Future video growth:        ~4-6TB (as collection expands)
Emergency buffer:           ~1TB (recommended)

# Storage Timeline Projection
Year 1: ~500GB photos + 2TB video = 2.5TB used / 8TB
Year 2: ~750GB photos + 4TB video = 4.75TB used / 8TB  
Year 3: ~1TB photos + 6TB video = 7TB used / 8TB
```

### **Photo Library Setup Recommendation: START NOW**

**Why You Should Begin Photo Library:**

✅ **Sufficient Space**: 8TB ZFS mirror can handle both video and photos initially
✅ **Critical Protection**: Photos are even more irreplaceable than downloaded media
✅ **ZFS Benefits**: Automatic checksumming prevents photo corruption over time
✅ **Snapshots**: Easy recovery from accidental deletions
✅ **Growth Monitoring**: Can track usage and plan expansion before hitting limits

### **Optimal Photo Library Implementation**

**Recommended Software Stack:**
```bash
# Option 1: Immich (Modern, AI-powered)
immich:
  features:
    - Automatic face recognition and tagging
    - Mobile app auto-upload
    - Timeline view with smart search
    - Duplicate detection
    - RAW photo support
    - Video handling

# Option 2: PhotoPrism (Privacy-focused)
photoprism:
  features:
    - Advanced AI tagging and search
    - No cloud dependencies
    - RAW processing
    - Map integration
    - Facial recognition (optional)
```

**Storage Structure:**
```bash
/media/media-pool/photos/
├── originals/              # Master photo/video files
├── thumbnails/            # Generated previews (can regenerate)
├── sidecar/               # Metadata files
└── library/               # Organized structure

# Typical storage requirements
Personal collection (10 years):     ~200-500GB
Family collection (20+ years):      ~500GB-2TB
Professional/RAW workflow:          ~1-5TB
```

### **Photo Library Growth Management**

**Monitoring Strategy:**
```bash
# Add to weekly monitoring script
echo "=== Photo Library Storage Usage ==="
df -h /media/media-pool
zfs list media-pool/photos
du -sh /media/media-pool/photos/*

# Alert thresholds
# Warning: 75% full (6TB used / 8TB)
# Critical: 85% full (6.8TB used / 8TB)
```

**Expansion Planning:**
- **Phase 1**: Start photo library now (plenty of room)
- **Phase 2**: Monitor growth quarterly  
- **Phase 3**: When approaching 6TB total usage, add second mirror pair
- **Phase 4**: Continue monitoring and expanding as needed

### **Photo Library vs Video Priority**

**Storage Priority Assessment:**
1. **Photos**: Highest priority (irreplaceable family memories)
2. **Downloaded Video**: Medium priority (replaceable but time-consuming)
3. **Temp/Processing**: Lowest priority (fully replaceable)

**Risk Assessment:**
- **Photo Loss**: Catastrophic - decades of memories
- **Video Loss**: Significant but recoverable
- **Both Protected**: ZFS mirror protects everything equally

## ☁️ Cloud Backup Strategy

### **Multi-Tier Cloud Backup Architecture**

Your homelab needs offsite protection against catastrophic events (fire, theft, natural disasters). Here's a comprehensive cloud backup strategy for all three systems:

```
┌─────────────────────────────────────────────────────────────────┐
│                    CLOUD BACKUP HIERARCHY                       │
├─────────────────────────────────────────────────────────────────┤
│  Tier 1: Critical Data (Photos, Configs, Databases)            │
│  ├── Target: Multiple cloud providers                           │
│  ├── Frequency: Daily incremental                              │
│  ├── Retention: 30 daily, 12 monthly, 7 yearly               │
│  └── Encryption: Client-side (zero knowledge)                  │
├─────────────────────────────────────────────────────────────────┤
│  Tier 2: Important Data (Documents, Game Saves)               │
│  ├── Target: Primary cloud provider                           │
│  ├── Frequency: Weekly full, daily incremental               │
│  ├── Retention: 4 weekly, 12 monthly                         │
│  └── Encryption: Client-side                                 │
├─────────────────────────────────────────────────────────────────┤
│  Tier 3: Replaceable Data (Media Library)                     │
│  ├── Target: Cold storage (optional)                          │
│  ├── Frequency: Monthly or manual                             │
│  ├── Retention: Latest version only                           │
│  └── Priority: Low (can re-download if needed)               │
└─────────────────────────────────────────────────────────────────┘
```

### **🏆 Recommended Solution: Hybrid Approach**

**Primary Recommendation: Backblaze B2 + Restic**
- **Cost**: ~$6/TB/month (most cost-effective)
- **Performance**: Good upload speeds, excellent for Restic
- **Reliability**: 99.9% durability, proven track record
- **Integration**: Native Restic support, easy automation

**Why This Combination:**
✅ **Cost Effective**: Cheapest per-TB among major providers
✅ **Zero Knowledge**: Client-side encryption (your keys only)
✅ **Deduplication**: Restic eliminates duplicate data
✅ **Cross-Platform**: Works on all your systems
✅ **Incremental**: Only uploads changes after initial backup
✅ **Battle Tested**: Widely used in homelab community

### **Cloud Provider Comparison**

#### **Tier 1: Backblaze B2 (RECOMMENDED)**
```bash
Cost: $6/TB/month storage + $10/TB egress
Pros:
✅ Cheapest storage cost
✅ Excellent Restic integration  
✅ No API fees
✅ S3-compatible API
✅ Good performance
✅ Homelab-friendly

Cons:
❌ Egress fees (rarely needed)
❌ Newer company vs AWS/Google
```

#### **Tier 2: Wasabi Cloud Storage**
```bash
Cost: $7/TB/month (no egress fees)
Pros:
✅ No egress charges
✅ S3-compatible
✅ Good for frequent access
✅ Predictable pricing

Cons:
❌ Slightly more expensive
❌ Minimum storage requirements
```

#### **Tier 3: Amazon S3 Glacier Deep Archive**
```bash
Cost: $1/TB/month storage + high retrieval costs
Pros:
✅ Extremely cheap storage
✅ AWS reliability
✅ Good for long-term archive

Cons:
❌ Very expensive retrieval ($0.10/GB)
❌ 12+ hour retrieval time
❌ Complex pricing structure
```

### **Implementation Strategy by System**

#### **Primary Homelab Server (i5-8400)**
```bash
# Critical data backup (daily)
/backup-scripts/critical-backup.sh:
- Docker volumes (/data/docker)
- ZFS snapshots of photo library
- Configuration files
- Database exports
- System configurations

# Target: Backblaze B2
Repository: b2:homelab-critical-backup
Estimated size: 500GB-2TB
Monthly cost: $3-12
```



#### **Backup Node (Laptop)**
```bash
# Backup coordination and monitoring
/backup-scripts/orchestrate-backups.sh:
- Coordinates cloud backups from all systems
- Monitors backup health across infrastructure
- Maintains backup logs and alerts
- Emergency restore capabilities

# Also backs up its own coordination data
Repository: b2:homelab-backup-node
Estimated size: 10-50GB
Monthly cost: $0.06-0.30
```

### **Restic Configuration Example**

#### **Installation and Setup**
```bash
# Install Restic on all systems
curl -L https://github.com/restic/restic/releases/latest/download/restic_linux_amd64.bz2 | bunzip2 > /usr/local/bin/restic
chmod +x /usr/local/bin/restic

# Initialize Backblaze B2 repository
export B2_ACCOUNT_ID="your-account-id"
export B2_ACCOUNT_KEY="your-application-key"
export RESTIC_REPOSITORY="b2:your-bucket-name:/"
export RESTIC_PASSWORD="your-strong-encryption-password"

restic init
```

#### **Automated Backup Scripts**
```bash
#!/bin/bash
# /usr/local/bin/homelab-cloud-backup.sh

# Source credentials
source /etc/restic/credentials

# Backup critical data
restic backup \
  /data/docker \
  /media/media-pool/photos \
  /etc/docker \
  /home/user/.config \
  --exclude-file=/etc/restic/excludes.txt \
  --tag="homelab-$(date +%Y%m%d)"

# Cleanup old snapshots
restic forget --tag="homelab-*" \
  --keep-daily=30 \
  --keep-monthly=12 \
  --keep-yearly=7 \
  --prune

# Send notification
curl -d "Homelab backup completed: $(date)" ntfy.sh/homelab-alerts
```

### **Cost Analysis (Your Estimated Usage)**

#### **Monthly Cloud Backup Costs**
```bash
# Tier 1: Critical Data (Photos, Configs, Databases)
Photos: 1TB × $6 = $6/month
Configs/DBs: 100GB × $6 = $0.60/month
Subtotal: $6.60/month


Game saves/configs: 50GB × $6 = $0.30/month
Subtotal: $0.30/month

# Total Monthly Cost: ~$7-10/month
# Annual Cost: ~$84-120/year

# Compare to risk: Losing 10+ years of photos = PRICELESS
# ROI: First prevented data loss pays for decades of backup
```

### **Alternative: Self-Hosted Offsite Backup**

#### **Option: Remote VPS Backup**
```bash
# Rent cheap VPS with large storage
Provider: Hetzner Storage Box (1TB = €3.81/month)
Setup: rsync + encryption to remote server
Cost: ~$4/month for 1TB

Pros:
✅ Very cheap per TB
✅ Full control
✅ No vendor lock-in
✅ European data protection

Cons:
❌ Manual setup and maintenance
❌ VPS reliability responsibility
❌ Network transfer limits
❌ More complex restoration
```

#### **Option: Family/Friend Backup Exchange**
```bash
# Reciprocal backup with trusted family/friends
Setup: Both parties host each other's encrypted backups
Cost: Hardware/bandwidth only
Security: Strong encryption essential

Pros:
✅ Nearly free ongoing cost
✅ Mutual benefit
✅ Personal relationship trust

Cons:
❌ Depends on others' reliability  
❌ Bandwidth limitations
❌ Geographic risk concentration
❌ Relationship complications if issues arise
```

### **🎯 Final Recommendation**

**For your setup, I strongly recommend Backblaze B2 + Restic:**

1. **Start Small**: Begin with critical data only (photos, configs)
2. **Automate Everything**: Set up daily automated backups with notifications
3. **Monitor Costs**: Track usage, adjust retention as needed
4. **Test Restoration**: Quarterly restore tests to verify backup integrity
5. **Expand Gradually**: Add more data types as you see value

**Initial Setup Priority:**
1. **Week 1**: Photos and personal documents (highest value)
2. **Week 2**: Docker configurations and databases
3. **Week 3**: System configuration backups
4. **Week 4**: Automated monitoring and alerting

**Budget**: Start with $10/month budget, should cover all critical data with room to grow.

The peace of mind knowing your irreplaceable photos and configurations are safely stored offsite is worth every penny! 🌟

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


├── Ubuntu OS                     ~1GB
├── Game streaming services       ~2GB

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
1. **Primary Storage**: Evaluate additional storage needs
2. **Memory**: Consider additional RAM for containerized workloads
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

- [ ] External storage enclosure for backup node


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

- **Backup Speed**: Limited by network speed to laptop
- **Transcoding**: Single stream limited by Quick Sync capabilities

---

*This document reflects the actual hardware deployment as of October 2025. Update as hardware changes or upgrades are implemented.*