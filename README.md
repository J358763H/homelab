# 🏠 Simple Homelab Setup# 🏠 Simple Homelab Setup# 🏠 Simple Homelab Setup# 🏠 Simple Homelab Setup



**Maintainer:** J35867U

**Last Updated:** 2025-10-16

**Maintainer:** J35867U

Clean, organized Docker homelab with manual control over service groups.

**Last Updated:** 2025-10-16

## 🚀 Quick Start

**Maintainer:** J35867U  **Maintainer:** J35867U

**Deploy everything with one command on Proxmox:**

Clean, organized Docker homelab with manual control over service groups.

```bash

wget -O deploy.sh https://raw.githubusercontent.com/J358763H/homelab/main/proxmox-deploy-homelab.sh && chmod +x deploy.sh && ./deploy.sh**Last Updated:** 2025-10-16

```

## 🚀 Quick Start (Recommended)

This automatically:

- ✅ Installs Docker and Docker Compose**Last Updated:** 2025-10-16

- ✅ Downloads the entire homelab repository

- ✅ Deploys all services in the correct order**Deploy everything with one command on Proxmox:**

- ✅ Provides access URLs when complete

Clean, organized Docker homelab with manual control over service groups.

## 📁 Structure

```bash

```

homelab/wget -O deploy.sh https://raw.githubusercontent.com/J358763H/homelab/main/proxmox-deploy-homelab.sh && chmod +x deploy.sh && ./deploy.sh**Deploy everything with one command on Proxmox:**

├── containers/

│   ├── core/           # VPN & networking (Gluetun, FlareSolverr)```

│   ├── downloads/      # Download clients (qBittorrent, NZBGet)

│   └── media/          # Media management & streaming (Jellyfin, Servarr)## 🚀 Quick Start (Recommended)

├── setup/              # Simple deployment scripts

├── lxc/                # LXC container servicesThis automatically:

└── docs/               # Documentation

```- ✅ Installs Docker and Docker Compose## Structure



## 📦 What's Included- ✅ Downloads the entire homelab repository



### Core Infrastructure- ✅ Deploys all services in the correct order**Deploy everything with one command on Proxmox:**

- **Gluetun VPN** - Secure tunnel for download clients

- **FlareSolverr** - Cloudflare bypass service- ✅ Provides access URLs when complete



### Download Clients```bash

- **qBittorrent** - Feature-rich BitTorrent client

- **NZBGet** - Efficient Usenet downloader## 📁 Structure



### Media Management```bash

- **Jellyfin** - Media server and streaming

- **Prowlarr** - Indexer manager```

- **Sonarr** - TV series management

- **Radarr** - Movie managementhomelab/wget -O deploy.sh https://raw.githubusercontent.com/J358763H/homelab/main/proxmox-deploy-homelab.sh && chmod +x deploy.sh && ./deploy.shwget -O deploy.sh https://raw.githubusercontent.com/J358763H/homelab/main/proxmox-deploy-homelab.sh && chmod +x deploy.sh && ./deploy.sh```

- **Bazarr** - Subtitle management

- **JellyStat** - Jellyfin statistics├── containers/



### Optional LXC Services (Proxmox)│   ├── core/           # VPN & networking (Gluetun, FlareSolverr)```

- **Nginx Proxy Manager** - Reverse proxy with SSL

- **Pi-hole** - Network-wide ad blocking│   ├── downloads/      # Download clients (qBittorrent, NZBGet)

- **Tailscale** - Secure remote access

- **Vaultwarden** - Password manager│   └── media/          # Media management & streaming (Jellyfin, Servarr)```homelab/

- **Ntfy** - Push notifications

- **Samba** - Network file sharing├── setup/              # Simple deployment scripts



## 🏗️ Architecture├── lxc/                # LXC container servicesThis automatically:



```└── docs/               # Documentation

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐

│   Core Stack    │    │  Download Stack │    │   Media Stack   │```- ✅ Installs Docker and Docker Compose├── containers/

│                 │    │                 │    │                 │

│  • Gluetun VPN │────▶│  • qBittorrent  │────▶│  • Jellyfin     │

│  • FlareSolverr │    │  • NZBGet       │    │  • Sonarr       │

└─────────────────┘    └─────────────────┘    │  • Radarr       │## 📦 What's Included- ✅ Downloads the entire homelab repository

                                              │  • Prowlarr     │

┌─────────────────┐                          │  • Bazarr       │

│ LXC Services    │                          │  • JellyStat    │

│ (Optional)      │                          └─────────────────┘### **Core Infrastructure**- ✅ Deploys all services in the correct orderThis automatically:│   ├── core/           # VPN & networking (Gluetun, FlareSolverr)

│                 │

│  • Nginx Proxy  │- **Gluetun VPN** - Secure tunnel for download clients

│  • Pi-hole      │

│  • Tailscale    │- **FlareSolverr** - Cloudflare bypass service- ✅ Provides access URLs when complete

│  • Vaultwarden  │

└─────────────────┘

```

### **Download Clients**- ✅ Installs Docker and Docker Compose│   ├── downloads/      # Download clients (qBittorrent, NZBGet)

## 🌐 Service Access

- **qBittorrent** - Feature-rich BitTorrent client

### Media Services

- **Jellyfin**: http://localhost:8096 - Media server- **NZBGet** - Efficient Usenet downloader## 📁 Structure

- **Sonarr**: http://localhost:8989 - TV show automation

- **Radarr**: http://localhost:7878 - Movie automation

- **Bazarr**: http://localhost:6767 - Subtitles

- **Prowlarr**: http://localhost:9696 - Indexer management### **Media Management**- ✅ Downloads the entire homelab repository│   └── media/          # Media management & streaming (Jellyfin, Servarr)

- **JellyStat**: http://localhost:3000 - Analytics

- **Jellyfin** - Media server and streaming

### Download Services

- **qBittorrent**: http://localhost:8080 - Torrent client- **Prowlarr** - Indexer manager```

- **NZBGet**: http://localhost:6789 - Usenet client

- **Sonarr** - TV series management

### Optional LXC Infrastructure (Proxmox only)

- **Nginx Proxy Manager**: http://192.168.1.201:81 - Reverse proxy- **Radarr** - Movie managementhomelab/- ✅ Deploys all services in the correct order├── setup/              # Simple deployment scripts

- **Pi-hole**: http://192.168.1.204:80 - DNS & ad blocking

- **Ntfy**: http://192.168.1.203:80 - Push notifications- **Bazarr** - Subtitle management

- **Vaultwarden**: http://192.168.1.205:80 - Password manager

- **JellyStat** - Jellyfin statistics├── containers/

## 🛠️ Manual Deployment



### 1. Setup Environment

```bash### **Optional LXC Services** (Proxmox)│   ├── core/           # VPN & networking (Gluetun, FlareSolverr)- ✅ Provides access URLs when complete└── docs/               # Documentation

cd setup

./prepare.sh- **Nginx Proxy Manager** - Reverse proxy with SSL

```

- **Pi-hole** - Network-wide ad blocking│   ├── downloads/      # Download clients (qBittorrent, NZBGet)

### 2. Deploy Step by Step

```bash- **Tailscale** - Secure remote access

# Start core services first (VPN)

cd containers/core- **Vaultwarden** - Password manager│   └── media/          # Media management & streaming (Jellyfin, Servarr)```

docker-compose up -d

- **Ntfy** - Push notifications

# Then downloads (depends on VPN)

cd ../downloads- **Samba** - Network file sharing├── setup/              # Simple deployment scripts

docker-compose up -d



# Finally media services

cd ../media## 🏗️ Architecture├── lxc/                # LXC container services## 📦 What's Included

docker-compose up -d

```



### 3. Or Deploy Everything```└── docs/               # Documentation

```bash

cd setup┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐

./deploy-all.sh

```│   Core Stack    │    │  Download Stack │    │   Media Stack   │```## Quick Start



## 📊 Management│                 │    │                 │    │                 │



### Check Status│  • Gluetun VPN │────▶│  • qBittorrent  │────▶│  • Jellyfin     │

```bash

cd setup│  • FlareSolverr │    │  • NZBGet       │    │  • Sonarr       │

./status.sh

```└─────────────────┘    └─────────────────┘    │  • Radarr       │## 📦 What's Included### **Core Infrastructure**



### View Logs                                              │  • Prowlarr     │

```bash

docker logs [container_name]┌─────────────────┐                          │  • Bazarr       │

```

│ LXC Services    │                          │  • JellyStat    │

### Restart Services

```bash│ (Optional)      │                          └─────────────────┘### **Core Infrastructure**- **Gluetun VPN** - Secure tunnel for download clients### 1. Setup Environment

docker-compose restart

```│                 │



### Update Stack│  • Nginx Proxy  │- **Gluetun VPN** - Secure tunnel for download clients

```bash

git pull origin main│  • Pi-hole      │

docker-compose pull

docker-compose up -d│  • Tailscale    │- **FlareSolverr** - Cloudflare bypass service- **FlareSolverr** - Cloudflare bypass service```bash

```

│  • Vaultwarden  │

## 🌐 Proxmox Integration

└─────────────────┘

This homelab is specifically optimized for Proxmox VE:

```

- **LXC Services** - Infrastructure services in lightweight containers

- **Docker Stack** - Application services in Docker### **Download Clients**cd setup

- **Web UI Deployment** - Deploy directly from Proxmox web interface

- **Nuclear Cleanup** - Complete reset script for fresh starts## 🌐 Service Access



### Fresh Proxmox Setup- **qBittorrent** - Feature-rich BitTorrent client

```bash

wget https://raw.githubusercontent.com/J358763H/homelab/main/proxmox-nuclear-cleanup.shOnce deployed, access your services at:

chmod +x proxmox-nuclear-cleanup.sh

./proxmox-nuclear-cleanup.sh- **NZBGet** - Efficient Usenet downloader### **Download Clients**./prepare.sh

```

### Media Services

## 📦 System Requirements

- **Jellyfin**: http://localhost:8096 - Media server

- **OS**: Ubuntu/Debian-based system (20.04+ recommended)

- **RAM**: Minimum 4GB, 8GB+ recommended- **Sonarr**: http://localhost:8989 - TV show automation

- **Storage**: 100GB minimum, 500GB+ recommended for media

- **Network**: Reliable internet connection- **Radarr**: http://localhost:7878 - Movie automation### **Media Management**- **qBittorrent** - Feature-rich BitTorrent client (`http://YOUR-IP:8080`)```

- **Dependencies**: Docker, Docker Compose, Git

- **Bazarr**: http://localhost:6767 - Subtitles

## 🔧 Configuration

- **Prowlarr**: http://localhost:9696 - Indexer management- **Jellyfin** - Media server and streaming

### Environment Variables

```bash- **JellyStat**: http://localhost:3000 - Analytics

cp env.example .env

```- **Prowlarr** - Indexer manager- **NZBGet** - Efficient Usenet downloader (`http://YOUR-IP:6789`)

Edit `.env` with your settings for PUID/PGID, timezone, VPN credentials, and API keys.

### Download Services

### VPN Setup

Configure `containers/core/wg0.conf` with your VPN provider's WireGuard settings.- **qBittorrent**: http://localhost:8080 - Torrent client- **Sonarr** - TV series management



### Media Organization- **NZBGet**: http://localhost:6789 - Usenet client

```

/data/media/- **Radarr** - Movie management### 2. Deploy Step by Step

├── movies/     # Movie files

├── shows/      # TV show files### Optional LXC Infrastructure (Proxmox only)

├── music/      # Music library

└── downloads/  # Download staging- **Nginx Proxy Manager**: http://192.168.1.201:81 - Reverse proxy- **Bazarr** - Subtitle management

```

- **Pi-hole**: http://192.168.1.204:80 - DNS & ad blocking

## 🚨 Troubleshooting

- **Ntfy**: http://192.168.1.203:80 - Push notifications- **JellyStat** - Jellyfin statistics### **Media Management** ```bash

### Common Issues

1. **Port conflicts** - Check if ports are already in use- **Vaultwarden**: http://192.168.1.205:80 - Password manager

2. **Permission errors** - Verify PUID/PGID settings

3. **VPN connectivity** - Check Gluetun logs for VPN status

4. **Storage issues** - Ensure sufficient disk space

## 🛠️ Manual Deployment

### Debugging

```bash### **Optional LXC Services** (Proxmox)- **Jellyfin** - Media server and streaming (`http://YOUR-IP:8096`)# Start core services first (VPN)

# View all container logs

docker-compose logsIf you prefer step-by-step deployment:



# Check specific service- **Nginx Proxy Manager** - Reverse proxy with SSL

docker logs gluetun

### 1. Setup Environment

# Monitor real-time logs

docker-compose logs -f```bash- **Pi-hole** - Network-wide ad blocking- **Prowlarr** - Indexer manager (`http://YOUR-IP:9696`)cd containers/core

```

cd setup

## 📚 Documentation

./prepare.sh- **Tailscale** - Secure remote access

- **[Getting Started](docs/Documentation_Master.md)** - Complete documentation index

- **[Directory Structure](docs/Directory_Tree_v1.0.txt)** - File organization```



## 🔄 Backup & Recovery- **Vaultwarden** - Password manager- **Sonarr** - TV series management (`http://YOUR-IP:8989`)docker-compose up -d



### Automated Backups### 2. Deploy Step by Step

- **Restic** - Encrypted, incremental backups

- **Daily summaries** - Backup status reports```bash- **Ntfy** - Push notifications

- **Documentation archiving** - Config and documentation backups

# Start core services first (VPN)

### Disaster Recovery

1. **Fresh Installation**: Clone repo on new systemcd containers/core- **Samba** - Network file sharing- **Radarr** - Movie management (`http://YOUR-IP:7878`)

2. **Configuration**: Copy backed-up `.env` and `wg0.conf`

3. **Deployment**: Run `./setup/deploy-all.sh`docker-compose up -d

4. **Data Restoration**: Restore from Restic backup



## 📈 Monitoring & Alerts

# Then downloads (depends on VPN)

### Health Checks

- Container status monitoringcd ../downloads## 🏗️ Architecture- **Bazarr** - Subtitle management (`http://YOUR-IP:6767`)# Then downloads (depends on VPN)

- System resource tracking

- Disk health (SMART) monitoringdocker-compose up -d

- Network connectivity verification



### Notifications

Integrated with **Ntfy** for real-time alerts:# Finally media services

- Backup completion/failure

- System health summariescd ../media```- **JellyStat** - Jellyfin statistics (`http://YOUR-IP:3001`)cd ../downloads

- Critical service failures

- Weekly health reportsdocker-compose up -d



## 🤝 Contributing```┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐



1. Fork the repository

2. Create a feature branch

3. Make your changes### 3. Or Deploy Everything│   Core Stack    │    │  Download Stack │    │   Media Stack   │docker-compose up -d

4. Test thoroughly

5. Submit a pull request```bash



## 📞 Supportcd setup│                 │    │                 │    │                 │



- **Issues**: Use GitHub Issues for bug reports and feature requests./deploy-all.sh

- **Discussions**: GitHub Discussions for questions and community support

- **Maintainer**: J35867U (<mrnash404@protonmail.com>)```│  • Gluetun VPN │────▶│  • qBittorrent  │────▶│  • Jellyfin     │### **Optional LXC Services**



## ⚖️ License



This project is open source. See individual components for their respective licenses.## 📊 Management│  • FlareSolverr │    │  • NZBGet       │    │  • Sonarr       │



## 🙏 Acknowledgments



Built with and inspired by:### Check Status└─────────────────┘    └─────────────────┘    │  • Radarr       │- **Nginx Proxy Manager** - Reverse proxy with SSL# Finally media services



- **Linuxserver.io** containers```bash

- **Servarr** applications

- **Jellyfin** media servercd setup                                              │  • Prowlarr     │

- **Gluetun** VPN client

- **Restic** backup tool./status.sh



---```┌─────────────────┐                          │  • Bazarr       │- **Pi-hole** - Network-wide ad blockingcd ../media



**⭐ Star this repository if you find it helpful!**



Made with ❤️ for the self-hosting community.### View Logs│ LXC Services    │                          │  • JellyStat    │

```bash

docker logs [container_name]│ (Optional)      │                          └─────────────────┘- **Tailscale** - Secure remote accessdocker-compose up -d

```

│                 │

### Restart Services

```bash│  • Nginx Proxy  │- **Vaultwarden** - Password manager```

docker-compose restart

```│  • Pi-hole      │



### Update Stack│  • Tailscale    │- **Ntfy** - Push notifications

```bash

git pull origin main│  • Vaultwarden  │

docker-compose pull

docker-compose up -d└─────────────────┘- **Samba** - Network file sharing### 3. Or Deploy Everything

```

```

## 🌐 Proxmox Integration

```bash

This homelab is specifically optimized for Proxmox VE:

## 🌐 Service Access

- **LXC Services** - Infrastructure services in lightweight containers

- **Docker Stack** - Application services in Docker## 🏗️ Architecturecd setup

- **Web UI Deployment** - Deploy directly from Proxmox web interface

- **Nuclear Cleanup** - Complete reset script for fresh startsOnce deployed, access your services at:



### Fresh Proxmox Setup./deploy-all.sh

For a completely clean start:

```bash### 🎬 **Media Services**

wget https://raw.githubusercontent.com/J358763H/homelab/main/proxmox-nuclear-cleanup.sh

chmod +x proxmox-nuclear-cleanup.sh- **Jellyfin**: http://localhost:8096 - Media server``````

./proxmox-nuclear-cleanup.sh

```- **Sonarr**: http://localhost:8989 - TV show automation



## 📦 System Requirements- **Radarr**: http://localhost:7878 - Movie automation┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐



- **OS**: Ubuntu/Debian-based system (20.04+ recommended)- **Bazarr**: http://localhost:6767 - Subtitles

- **RAM**: Minimum 4GB, 8GB+ recommended

- **Storage**: 100GB minimum, 500GB+ recommended for media- **Prowlarr**: http://localhost:9696 - Indexer management│   Core Stack    │    │  Download Stack │    │   Media Stack   │## Service Access

- **Network**: Reliable internet connection

- **Dependencies**: Docker, Docker Compose, Git- **JellyStat**: http://localhost:3000 - Analytics



## 🔧 Configuration│                 │    │                 │    │                 │



### Environment Variables### 📥 **Download Services**

Copy and customize the environment file:

```bash- **qBittorrent**: http://localhost:8080 - Torrent client```

cp env.example .env

```- **NZBGet**: http://localhost:6789 - Usenet client│  • Gluetun VPN │────┤  • qBittorrent  │────┤  • Jellyfin     │

Edit `.env` with your settings for PUID/PGID, timezone, VPN credentials, and API keys.

│  • FlareSolverr │    │  • NZBGet       │    │  • Sonarr       │

### VPN Setup

Configure `containers/core/wg0.conf` with your VPN provider's WireGuard settings.### 🔧 **Optional: LXC Infrastructure** (Proxmox only)└─────────────────┘    └─────────────────┘    │  • Radarr       │



### Media Organization- **Nginx Proxy Manager**: http://192.168.1.201:81 - Reverse proxy                                              │  • Prowlarr     │

The system organizes media in `/data/media/`:

```- **Pi-hole**: http://192.168.1.204:80 - DNS & ad blocking┌─────────────────┐                          │  • Bazarr       │

/data/media/

├── movies/     # Movie files- **Ntfy**: http://192.168.1.203:80 - Push notifications│ LXC Services    │                          │  • JellyStat    │

├── shows/      # TV show files

├── music/      # Music library- **Vaultwarden**: http://192.168.1.205:80 - Password manager│ (Optional)      │                          └─────────────────┘

└── downloads/  # Download staging

```│                 │



## 🚨 Troubleshooting## 🛠️ Manual Deployment│  • Nginx Proxy  │



### Common Issues│  • Pi-hole      │

1. **Port conflicts** - Check if ports are already in use

2. **Permission errors** - Verify PUID/PGID settingsIf you prefer step-by-step deployment:│  • Tailscale    │

3. **VPN connectivity** - Check Gluetun logs for VPN status

4. **Storage issues** - Ensure sufficient disk space│  • Vaultwarden  │



### Logs and Debugging### 1. Setup Environment└─────────────────┘

```bash

# View all container logs```bash```

docker-compose logs

cd setup

# Check specific service

docker logs gluetun./prepare.shOnce deployed, access your services at:



# Monitor real-time logs```

docker-compose logs -f

```### 🎬 **Media Services**



## 📚 Documentation### 2. Deploy Step by Step- **Jellyfin**: http://localhost:8096 - Media server



Comprehensive documentation is available in the `/docs` directory:```bash- **Sonarr**: http://localhost:8989 - TV show automation



- **[Getting Started](docs/Documentation_Master.md)** - Complete documentation index# Start core services first (VPN)- **Radarr**: http://localhost:7878 - Movie automation

- **[Directory Structure](docs/Directory_Tree_v1.0.txt)** - File organization

cd containers/core

## 🔄 Backup & Recovery

docker-compose up -d│ (Optional)      │                          └─────────────────┘- **Bazarr**: http://localhost:6767 - Subtitles

### Automated Backups

- **Restic** - Encrypted, incremental backups

- **Daily summaries** - Backup status reports

- **Documentation archiving** - Config and documentation backups# Then downloads (depends on VPN)│                 │- **Prowlarr**: http://localhost:9696 - Indexer management



### Disaster Recoverycd ../downloads

1. **Fresh Installation**: Clone repo on new system

2. **Configuration**: Copy backed-up `.env` and `wg0.conf`docker-compose up -d│  • Nginx Proxy  │- **JellyStat**: http://localhost:3000 - Analytics

3. **Deployment**: Run `./setup/deploy-all.sh`

4. **Data Restoration**: Restore from Restic backup



## 📈 Monitoring & Alerts# Finally media services│  • Pi-hole      │



### Health Checkscd ../media

- Container status monitoring

- System resource trackingdocker-compose up -d│  • Tailscale    │### 📥 **Download Services**

- Disk health (SMART) monitoring

- Network connectivity verification```



### Notifications│  • Vaultwarden  │- **qBittorrent**: http://localhost:8080 - Torrent client

Integrated with **Ntfy** for real-time alerts:

- Backup completion/failure### 3. Or Deploy Everything

- System health summaries

- Critical service failures```bash└─────────────────┘- **NZBGet**: http://localhost:6789 - Usenet client

- Weekly health reports

cd setup

## 🤝 Contributing

./deploy-all.sh```

1. Fork the repository

2. Create a feature branch```

3. Make your changes

4. Test thoroughly### 🔧 **Optional: LXC Infrastructure** (Proxmox only)

5. Submit a pull request

## 📊 Management

## 📞 Support

## 🛠️ Manual Deployment- **Nginx Proxy Manager**: http://192.168.1.201:81 - Reverse proxy

- **Issues**: Use GitHub Issues for bug reports and feature requests

- **Discussions**: GitHub Discussions for questions and community support### Check Status

- **Maintainer**: J35867U (<mrnash404@protonmail.com>)

```bash- **Pi-hole**: http://192.168.1.205:80 - DNS & ad blocking

## ⚖️ License

cd setup

This project is open source. See individual components for their respective licenses.

./status.shIf you prefer step-by-step deployment:- **Ntfy**: http://192.168.1.203:80 - Push notifications

## 🙏 Acknowledgments

```

Built with and inspired by:

- **Vaultwarden**: http://192.168.1.206:80 - Password manager

- **Linuxserver.io** containers

- **Servarr** applications### View Logs

- **Jellyfin** media server

- **Gluetun** VPN client```bash### **1. Prerequisites**

- **Restic** backup tool

docker logs [container_name]

---

``````bash## Management

**⭐ Star this repository if you find it helpful!**



Made with ❤️ for the self-hosting community.
### Restart Services# Install Docker and Docker Compose

```bash

docker-compose restartcurl -fsSL https://get.docker.com -o get-docker.sh```bash

```

sh get-docker.sh# Check status

### Update Stack

```bash```docker ps

git pull origin main

docker-compose pull

docker-compose up -d

```### **2. Clone Repository**# View logs



## 🌐 Proxmox Integration```bashdocker logs [container_name]



This homelab is specifically optimized for Proxmox VE:git clone https://github.com/J358763H/homelab.git



- **LXC Services** - Infrastructure services in lightweight containerscd homelab# Restart service group

- **Docker Stack** - Application services in Docker

- **Web UI Deployment** - Deploy directly from Proxmox web interface```cd containers/[group]

- **Nuclear Cleanup** - Complete reset script for fresh starts

docker-compose restart

### Fresh Proxmox Setup

For a completely clean start:### **3. Deploy Services**

```bash

wget https://raw.githubusercontent.com/J358763H/homelab/main/proxmox-nuclear-cleanup.sh```bash# Deploy LXC services (Proxmox)

chmod +x proxmox-nuclear-cleanup.sh

./proxmox-nuclear-cleanup.shcd setupcd setup

```

./deploy-all.sh

## 📦 System Requirements

# Deploy LXC services (Proxmox)

- **OS**: Ubuntu/Debian-based system (20.04+ recommended)cd setup

- **RAM**: Minimum 4GB, 8GB+ recommended./deploy-lxc.sh

- **Storage**: 100GB minimum, 500GB+ recommended for media

- **Network**: Reliable internet connection# Stop everything

- **Dependencies**: Docker, Docker Compose, Gitcd setup

./stop-all.sh

## 🔧 Configuration```



### Environment Variables## 📊 Management

Copy and customize the environment file:

```bash### **Check Status**```

cp env.example .env

# Edit .env with your settings```bash

```

cd /opt/homelab && ./setup/status.sh- **Jellyfin** (Media Server): `http://your-server-ip:8096`

### Key Settings

- `PUID/PGID` - User/group permissions```- **Sonarr** (TV Shows): `http://your-server-ip:8989`

- `TZ` - Timezone

- VPN credentials (WireGuard)- **Radarr** (Movies): `http://your-server-ip:7878`

- Database passwords

- API keys### **View Logs**- **Prowlarr** (Indexers): `http://your-server-ip:9696`



### VPN Setup```bash- **Jellyseerr** (Requests): `http://your-server-ip:5055`

Configure `containers/core/wg0.conf` with your VPN provider's WireGuard settings.

docker logs <container-name>- **qBittorrent** (Downloads): `http://your-server-ip:8080`

### Media Organization

The system organizes media in `/data/media/`:```

```

/data/media/## 🔄 Lifecycle Management

├── movies/     # Movie files

├── shows/      # TV show files### **Restart Services**- **`./homelab.sh deploy`** → Build and schedule everything

├── music/      # Music library

└── downloads/  # Download staging```bash- **`./homelab.sh teardown`** → Stop containers, remove cron jobs, preserve data

```

docker-compose restart- **`./homelab.sh reset`** → Teardown and redeploy in one go

## 🚨 Troubleshooting

```- **`./homelab.sh status`** → Check containers, cron jobs, services, and system health

### Common Issues

1. **Port conflicts** - Check if ports are already in use

2. **Permission errors** - Verify PUID/PGID settings

3. **VPN connectivity** - Check Gluetun logs for VPN status### **Update Stack**## 🏗️ What's Included

4. **Storage issues** - Ensure sufficient disk space

```bash### 🎬 Media Stack

### Logs and Debugging

```bashgit pull origin main

# View all container logs

docker-compose logsdocker-compose pull- **Jellyfin** - Media server and streaming platform



# Check specific servicedocker-compose up -d- **Sonarr** - TV show collection manager

docker logs gluetun

```- **Radarr** - Movie collection manager

# Monitor real-time logs

docker-compose logs -f- **Bazarr** - Subtitle manager

```

## 🌐 Proxmox Integration- **Prowlarr** - Indexer manager for torrents and usenet

## 📚 Documentation

- **Jellyseerr** - Request management for users

Comprehensive documentation is available in the `/docs` directory:

This homelab is specifically optimized for Proxmox VE:

- **[Getting Started](docs/Documentation_Master.md)** - Complete documentation index

- **[Directory Structure](docs/Directory_Tree_v1.0.txt)** - File organization### 📥 Download Clients



## 🔄 Backup & Recovery- **LXC Services** - Infrastructure services in lightweight containers



### Automated Backups- **Docker Stack** - Application services in Docker- **qBittorrent** - Torrent client (VPN-protected)

- **Restic** - Encrypted, incremental backups

- **Daily summaries** - Backup status reports- **Web UI Deployment** - Deploy directly from Proxmox web interface- **NZBGet** - Usenet client

- **Documentation archiving** - Config and documentation backups

- **Nuclear Cleanup** - Complete reset script for fresh starts- **Gluetun** - VPN container for secure downloading

### Disaster Recovery

1. **Fresh Installation**: Clone repo on new system

2. **Configuration**: Copy backed-up `.env` and `wg0.conf`

3. **Deployment**: Run `./setup/deploy-all.sh`### **Fresh Proxmox Setup**### 🤖 Automation & Analytics

4. **Data Restoration**: Restore from Restic backup

For a completely clean start:

## 📈 Monitoring & Alerts

```bash- **Jellystat** - Jellyfin usage analytics

### Health Checks

- Container status monitoringwget https://raw.githubusercontent.com/J358763H/homelab/main/proxmox-nuclear-cleanup.sh- **YouTube Integration** - Automated YouTube content downloading

- System resource tracking

- Disk health (SMART) monitoringchmod +x proxmox-nuclear-cleanup.sh- **Recyclarr** - Quality profile management

- Network connectivity verification

./proxmox-nuclear-cleanup.sh- **Tunarr** - Custom channel creation

### Notifications

Integrated with **Ntfy** for real-time alerts:```

- Backup completion/failure

- System health summaries### 📊 Monitoring & Maintenance

- Critical service failures

- Weekly health reports## 📁 Directory Structure



## 🤝 Contributing- **Daily backup summaries** with Restic



1. Fork the repository```- **Weekly system health reports**

2. Create a feature branch

3. Make your changeshomelab/- **HDD health monitoring** with SMART

4. Test thoroughly

5. Submit a pull request├── containers/           # Docker Compose services- **Automated maintenance tasks**



## 📞 Support│   ├── core/            # VPN and networking- **Ntfy notifications** for alerts and summaries



- **Issues**: Use GitHub Issues for bug reports and feature requests│   ├── downloads/       # Download clients

- **Discussions**: GitHub Discussions for questions and community support

- **Maintainer**: J35867U (<mrnash404@protonmail.com>)│   └── media/           # Media management## 🛡️ Security Features



## ⚖️ License├── lxc/                 # LXC container services- **VPN Integration** - All download traffic routed through VPN



This project is open source. See individual components for their respective licenses.├── setup/               # Deployment scripts- **Network Isolation** - Containers on dedicated Docker network



## 🙏 Acknowledgments├── docs/                # Documentation- **Secret Management** - Environment variables for sensitive data



Built with and inspired by:└── archive/             # Legacy files (preserved)- **Regular Updates** - Automated security update notifications



- **Linuxserver.io** containers```

- **Servarr** applications

- **Jellyfin** media server## 📦 System Requirements

- **Gluetun** VPN client

- **Restic** backup tool## 🔧 Configuration- **OS**: Ubuntu/Debian-based system (20.04+ recommended)



---- **RAM**: Minimum 4GB, 8GB+ recommended



**⭐ Star this repository if you find it helpful!**### **Environment Variables**- **Storage**: 100GB minimum, 500GB+ recommended for media



Made with ❤️ for the self-hosting community.Copy and customize the environment file:- **Network**: Reliable internet connection

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
