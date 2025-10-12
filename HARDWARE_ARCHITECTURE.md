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
│  └── Download staging                     ~100GB                │
├─────────────────────────────────────────────────────────────────┤
│  512GB NVMe SSD #2                                              │
│  ├── VM storage pool                      ~300GB                │
│  └── Backup staging                       ~200GB                │
├─────────────────────────────────────────────────────────────────┤
│  500GB HDD                                                      │
│  └── Temporary/archive storage            ~500GB                │
├─────────────────────────────────────────────────────────────────┤
│  8TB HDD #1                                                     │
│  └── Media library (movies/shows)         ~8TB                  │
├─────────────────────────────────────────────────────────────────┤
│  8TB HDD #2                                                     │
│  └── Media library (backup/redundancy)    ~8TB                  │
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