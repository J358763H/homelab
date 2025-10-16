# 🏠 Homelab - Complete Self-Hosted Stack# 🏠 Simple Homelab Setup



**A production-ready, self-hosted media and download stack optimized for Proxmox deployment.**Clean, organized Docker homelab with manual control over service groups.



## 🚀 Quick Start (Recommended)**Maintainer:** J35867U

**Last Updated:** 2025-10-16

**Deploy everything with one command on Proxmox:**

## Structure

```bash

wget -O deploy.sh https://raw.githubusercontent.com/J358763H/homelab/main/proxmox-deploy-homelab.sh && chmod +x deploy.sh && ./deploy.sh```

```homelab/

├── containers/

This automatically:│   ├── core/           # VPN & networking (Gluetun, FlareSolverr)

- ✅ Installs Docker and Docker Compose│   ├── downloads/      # Download clients (qBittorrent, NZBGet)

- ✅ Downloads the entire homelab repository│   └── media/          # Media management & streaming (Jellyfin, Servarr)

- ✅ Deploys all services in the correct order├── setup/              # Simple deployment scripts

- ✅ Provides access URLs when complete└── docs/               # Documentation

```

## 📦 What's Included

## Quick Start

### **Core Infrastructure**

- **Gluetun VPN** - Secure tunnel for download clients### 1. Setup Environment

- **FlareSolverr** - Cloudflare bypass service```bash

cd setup

### **Download Clients**./prepare.sh

- **qBittorrent** - Feature-rich BitTorrent client (`http://YOUR-IP:8080`)```

- **NZBGet** - Efficient Usenet downloader (`http://YOUR-IP:6789`)

### 2. Deploy Step by Step

### **Media Management** ```bash

- **Jellyfin** - Media server and streaming (`http://YOUR-IP:8096`)# Start core services first (VPN)

- **Prowlarr** - Indexer manager (`http://YOUR-IP:9696`)cd containers/core

- **Sonarr** - TV series management (`http://YOUR-IP:8989`)docker-compose up -d

- **Radarr** - Movie management (`http://YOUR-IP:7878`)

- **Bazarr** - Subtitle management (`http://YOUR-IP:6767`)# Then downloads (depends on VPN)

- **JellyStat** - Jellyfin statistics (`http://YOUR-IP:3001`)cd ../downloads

docker-compose up -d

### **Optional LXC Services**

- **Nginx Proxy Manager** - Reverse proxy with SSL# Finally media services

- **Pi-hole** - Network-wide ad blockingcd ../media

- **Tailscale** - Secure remote accessdocker-compose up -d

- **Vaultwarden** - Password manager```

- **Ntfy** - Push notifications

- **Samba** - Network file sharing### 3. Or Deploy Everything

```bash

## 🏗️ Architecturecd setup

./deploy-all.sh

``````

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐

│   Core Stack    │    │  Download Stack │    │   Media Stack   │## Service Access

│                 │    │                 │    │                 │

│  • Gluetun VPN │────┤  • qBittorrent  │────┤  • Jellyfin     │Once deployed, access your services at:

│  • FlareSolverr │    │  • NZBGet       │    │  • Sonarr       │

└─────────────────┘    └─────────────────┘    │  • Radarr       │### 🎬 **Media Services**

                                              │  • Prowlarr     │- **Jellyfin**: http://localhost:8096 - Media server

┌─────────────────┐                          │  • Bazarr       │- **Sonarr**: http://localhost:8989 - TV show automation

│ LXC Services    │                          │  • JellyStat    │- **Radarr**: http://localhost:7878 - Movie automation

│ (Optional)      │                          └─────────────────┘- **Bazarr**: http://localhost:6767 - Subtitles

│                 │- **Prowlarr**: http://localhost:9696 - Indexer management

│  • Nginx Proxy  │- **JellyStat**: http://localhost:3000 - Analytics

│  • Pi-hole      │

│  • Tailscale    │### 📥 **Download Services**

│  • Vaultwarden  │- **qBittorrent**: http://localhost:8080 - Torrent client

└─────────────────┘- **NZBGet**: http://localhost:6789 - Usenet client

```

### 🔧 **Optional: LXC Infrastructure** (Proxmox only)

## 🛠️ Manual Deployment- **Nginx Proxy Manager**: http://192.168.1.201:81 - Reverse proxy

- **Pi-hole**: http://192.168.1.205:80 - DNS & ad blocking

If you prefer step-by-step deployment:- **Ntfy**: http://192.168.1.203:80 - Push notifications

- **Vaultwarden**: http://192.168.1.206:80 - Password manager

### **1. Prerequisites**

```bash## Management

# Install Docker and Docker Compose

curl -fsSL https://get.docker.com -o get-docker.sh```bash

sh get-docker.sh# Check status

```docker ps



### **2. Clone Repository**# View logs

```bashdocker logs [container_name]

git clone https://github.com/J358763H/homelab.git

cd homelab# Restart service group

```cd containers/[group]

docker-compose restart

### **3. Deploy Services**

```bash# Deploy LXC services (Proxmox)

cd setupcd setup

./deploy-all.sh./deploy-lxc.sh

```

# Stop everything

## 📊 Managementcd setup

./stop-all.sh

### **Check Status**```

```bash

cd /opt/homelab && ./setup/status.sh- **Jellyfin** (Media Server): `http://your-server-ip:8096`

```- **Sonarr** (TV Shows): `http://your-server-ip:8989`

- **Radarr** (Movies): `http://your-server-ip:7878`

### **View Logs**- **Prowlarr** (Indexers): `http://your-server-ip:9696`

```bash- **Jellyseerr** (Requests): `http://your-server-ip:5055`

docker logs <container-name>- **qBittorrent** (Downloads): `http://your-server-ip:8080`

```

## 🔄 Lifecycle Management

### **Restart Services**- **`./homelab.sh deploy`** → Build and schedule everything

```bash- **`./homelab.sh teardown`** → Stop containers, remove cron jobs, preserve data

docker-compose restart- **`./homelab.sh reset`** → Teardown and redeploy in one go

```- **`./homelab.sh status`** → Check containers, cron jobs, services, and system health



### **Update Stack**## 🏗️ What's Included

```bash### 🎬 Media Stack

git pull origin main

docker-compose pull- **Jellyfin** - Media server and streaming platform

docker-compose up -d- **Sonarr** - TV show collection manager

```- **Radarr** - Movie collection manager

- **Bazarr** - Subtitle manager

## 🌐 Proxmox Integration- **Prowlarr** - Indexer manager for torrents and usenet

- **Jellyseerr** - Request management for users

This homelab is specifically optimized for Proxmox VE:

### 📥 Download Clients

- **LXC Services** - Infrastructure services in lightweight containers

- **Docker Stack** - Application services in Docker- **qBittorrent** - Torrent client (VPN-protected)

- **Web UI Deployment** - Deploy directly from Proxmox web interface- **NZBGet** - Usenet client

- **Nuclear Cleanup** - Complete reset script for fresh starts- **Gluetun** - VPN container for secure downloading



### **Fresh Proxmox Setup**### 🤖 Automation & Analytics

For a completely clean start:

```bash- **Jellystat** - Jellyfin usage analytics

wget https://raw.githubusercontent.com/J358763H/homelab/main/proxmox-nuclear-cleanup.sh- **YouTube Integration** - Automated YouTube content downloading

chmod +x proxmox-nuclear-cleanup.sh- **Recyclarr** - Quality profile management

./proxmox-nuclear-cleanup.sh- **Tunarr** - Custom channel creation

```

### 📊 Monitoring & Maintenance

## 📁 Directory Structure

- **Daily backup summaries** with Restic

```- **Weekly system health reports**

homelab/- **HDD health monitoring** with SMART

├── containers/           # Docker Compose services- **Automated maintenance tasks**

│   ├── core/            # VPN and networking- **Ntfy notifications** for alerts and summaries

│   ├── downloads/       # Download clients

│   └── media/           # Media management## 🛡️ Security Features

├── lxc/                 # LXC container services- **VPN Integration** - All download traffic routed through VPN

├── setup/               # Deployment scripts- **Network Isolation** - Containers on dedicated Docker network

├── docs/                # Documentation- **Secret Management** - Environment variables for sensitive data

└── archive/             # Legacy files (preserved)- **Regular Updates** - Automated security update notifications

```

## 📦 System Requirements

## 🔧 Configuration- **OS**: Ubuntu/Debian-based system (20.04+ recommended)

- **RAM**: Minimum 4GB, 8GB+ recommended

### **Environment Variables**- **Storage**: 100GB minimum, 500GB+ recommended for media

Copy and customize the environment file:- **Network**: Reliable internet connection

```bash- **Dependencies**: Docker, Docker Compose, Git

cp env.example .env

# Edit .env with your settings📋 **For detailed hardware specifications and architecture planning, see [Hardware Architecture Guide](HARDWARE_ARCHITECTURE.md)**

```

## 🔧 Configuration

### **Key Settings**### Environment Variables

- `PUID/PGID` - User/group permissions

- `TZ` - TimezoneEdit `deployment/.env` with your settings:

- `DATA_ROOT` - Data storage location

- VPN credentials (WireGuard)

## 🚨 Troubleshooting- Database passwords

- API keys

### **Common Issues**- Notification settings

1. **Port conflicts** - Check if ports are already in use- Backup configuration

2. **Permission errors** - Verify PUID/PGID settings

3. **VPN connectivity** - Check Gluetun logs for VPN status### VPN Setup

4. **Storage issues** - Ensure sufficient disk space

Configure `deployment/wg0.conf` with your VPN provider's WireGuard settings.

### **Logs and Debugging**

```bash### Media Organization

# View all container logs

docker-compose logsThe system organizes media in `/data/media/`:



# Check specific service```

docker logs gluetun/data/media/

├── movies/     # Movie files

# Monitor real-time logs├── shows/      # TV show files

docker-compose logs -f├── music/      # Music library

```└── youtube/    # YouTube downloads



## 📄 License```

## 📚 Documentation

This project is licensed under the MIT License - see the LICENSE file for details.Comprehensive documentation is available in the `/docs` directory:



## 🤝 Contributing- **[Getting Started](docs/Documentation_Master.md)** - Complete documentation index

- **[Directory Structure](docs/Directory_Tree_v1.0.txt)** - File organization

1. Fork the repository- **[Troubleshooting](deployment/TROUBLESHOOTING.md)** - Common issues and solutions

2. Create a feature branch- **[Deployment Checklist](deployment/DEPLOYMENT_CHECKLIST.md)** - Pre-deployment verification

3. Make your changes

4. Submit a pull request## 🔄 Backup & Recovery

### Automated Backups

## 🆘 Support

- **Restic** - Encrypted, incremental backups

- **Documentation**: Check the `docs/` directory- **Daily summaries** - Backup status reports

- **Issues**: Open a GitHub issue- **Documentation archiving** - Config and documentation backups

- **Discussions**: Use GitHub Discussions for questions

### Disaster Recovery

---

1. **Fresh Installation**: Clone repo on new system

**Ready to deploy your homelab?** Start with the one-command deployment above! 🚀2. **Configuration**: Copy backed-up `.env` and `wg0.conf`
3. **Deployment**: Run `./homelab.sh deploy`
4. **Data Restoration**: Restore from Restic backup

## 📈 Monitoring & Alerts
### Health Checks

- Container status monitoring
- System resource tracking
- Disk health (SMART) monitoring
- Network connectivity verification

### Notifications

Integrated with **Ntfy** for real-time alerts:

- Backup completion/failure
- System health summaries
- Critical service failures
- Weekly health reports

## 🤝 Contributing
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📝 Changelog
See [changelog.md](changelog.md) for detailed version history.

## 📞 Support
- **Issues**: Use GitHub Issues for bug reports and feature requests
- **Discussions**: GitHub Discussions for questions and community support
- **Maintainer**: J35867U (<mrnash404@protonmail.com>)

## ⚖️ License
This project is open source. See individual components for their respective licenses.

## 🙏 Acknowledgments
Built with and inspired by:

- **Linuxserver.io** containers
- **Servarr** applications
- **Jellyfin** media server
- **Gluetun** VPN client
- **Restic** backup tool

---

**⭐ Star this repository if you find it helpful!**

Made with ❤️ for the self-hosting community.
