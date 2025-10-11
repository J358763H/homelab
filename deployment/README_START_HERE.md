# 📦 Homelab-SHV Deployment — Start Here

Welcome to Homelab-SHV! This directory contains everything you need to deploy your self-hosted media and automation stack.

## 🚀 Quick Start

1. **Copy configuration templates:**
   ```bash
   cp .env.example .env
   cp wg0.conf.example wg0.conf
   ```

2. **Edit your secrets:**
   ```bash
   nano .env          # Add your API keys, passwords, VPN settings
   nano wg0.conf      # Add your WireGuard VPN configuration
   ```

3. **Run bootstrap:**
   ```bash
   chmod +x bootstrap.sh
   ./bootstrap.sh
   ```

4. **Deploy the stack:**
   ```bash
   docker compose up -d
   ```

## 🌐 Service Access

Once deployed, access your services at:

- **Jellyfin** (Media Server): `http://your-server-ip:8096`
- **Sonarr** (TV Shows): `http://your-server-ip:8989`
- **Radarr** (Movies): `http://your-server-ip:7878`
- **Prowlarr** (Indexers): `http://your-server-ip:9696`
- **Jellyseerr** (Requests): `http://your-server-ip:5055`
- **Jellystat** (Analytics): `http://your-server-ip:3000`
- **qBittorrent** (Downloads): `http://your-server-ip:8080`

## 📁 Key Files

- `docker-compose.yml` - Complete service stack definition
- `.env.example` - Configuration template (copy to `.env`)
- `wg0.conf.example` - VPN configuration template  
- `bootstrap.sh` - System preparation script
- `TROUBLESHOOTING.md` - Common issues and solutions
- `DEPLOYMENT_CHECKLIST.md` - Pre-deployment verification

## 🔧 Configuration Notes

### VPN Setup
The stack uses Gluetun for VPN connectivity. Your download traffic (qBittorrent) will be routed through the VPN automatically. Make sure to configure your WireGuard details in `wg0.conf`.

### Storage Layout
```
/data/
├── docker/          # Container configurations
├── media/           # Media files
│   ├── movies/      # Movie library
│   ├── shows/       # TV show library  
│   ├── music/       # Music library
│   └── youtube/     # YouTube content
├── backups/         # Backup storage
└── logs/            # Application logs
```

### Environment Variables
All sensitive configuration is stored in `.env`. Never commit this file to version control! The provided `.env.example` shows all required variables.

## 🛟 Support

- **Troubleshooting**: See `TROUBLESHOOTING.md`
- **Documentation**: Check the `/docs` directory
- **Issues**: Check container logs with `docker logs <container-name>`

## ⚠️ Security Notes

1. Change all default passwords in `.env`
2. Keep your VPN configuration secure
3. Regularly update container images
4. Monitor your system with the included health check scripts

Happy hosting! 🏠