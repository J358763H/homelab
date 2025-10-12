# 🧾 Changelog

All notable changes to the Homelab-SHV project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Web-based configuration management interface
- Container auto-updates with rollback capability
- Enhanced security hardening options
- Mobile app integration for remote management

## [1.5.0] - 2025-10-12

### Changed
- **Renamed Service**: "Samba File Share" → "Media File Share" for better clarity
- **Updated Documentation**: All references updated across scripts and documentation
- **Local DNS Records**: Changed samba.local → media.local for consistency

### Added
- **LXC Configuration Guide**: Comprehensive guide for customizing container deployments
- **Configuration Checklist**: Complete list of values requiring customization
- **Timezone Reference**: Common timezone values for global deployments
- **Security Recommendations**: Best practices for passwords and SMTP configuration

### Enhanced
- **Documentation Clarity**: Improved naming consistency across all homelab components
- **User Experience**: Clear identification of required vs optional configuration values
- **Setup Process**: Streamlined configuration workflow with detailed guidance

## [1.4.0] - 2025-10-12

### Added
- **Vaultwarden LXC Container**: Self-hosted Bitwarden-compatible password manager (192.168.1.206)
- **Enterprise Security**: End-to-end encrypted password management with zero-knowledge architecture
- **Multi-Platform Support**: Browser extensions, mobile apps, desktop applications, and CLI
- **Automated Backups**: Daily encrypted backups with disaster recovery procedures
- **SSL Integration**: HTTPS setup with Nginx Proxy Manager and Let's Encrypt support
- **Security Hardening**: Firewall configuration, rate limiting, and admin token management

### Enhanced
- **LXC Orchestration**: Added Vaultwarden to interactive deployment menu (option 6)
- **Complete Architecture**: Six-container LXC infrastructure for full homelab coverage
- **Pre-deployment Planning**: Updated checklist with Vaultwarden network allocation
- **Security Best Practices**: Comprehensive password management integration guide

## [1.3.0] - 2025-10-12

### Added
- **Pi-hole LXC Container**: Network-wide ad blocking and DNS management (192.168.1.205)
- **DNS Infrastructure**: Custom local domain resolution for homelab services
- **LXC Orchestration**: Enhanced homelab.sh with interactive LXC deployment menu
- **Ad Blocking Analytics**: Comprehensive Pi-hole monitoring and statistics dashboard
- **DNS Security**: Malware protection and tracker blocking for entire network

### Enhanced
- **Main Control Script**: Added `./homelab.sh lxc` for interactive container deployment
- **Pre-deployment Checklist**: Updated with LXC infrastructure planning section
- **Network Architecture**: Complete DNS hierarchy with Pi-hole integration
- **Service Discovery**: Local domain resolution (pihole.local, npm.local, etc.)

## [1.2.0] - 2025-10-11

### Added
- **Comprehensive Repository Analysis**: Deep quality assessment with REPOSITORY_ANALYSIS.md
- **Intel Quick Sync Optimization**: Hardware acceleration testing and validation
- **Pre-deployment Checklist**: PREDEPLOYMENT_CHECKLIST.txt for systematic validation
- **Testing Infrastructure**: Complete testing guide with VM setup and validation procedures
- **Configuration Validation**: Enhanced validate_config.sh with Intel GPU detection

### Improved
- **Documentation Quality**: Professional-grade organization and beginner-friendly guides
- **Code Consistency**: Repository-wide analysis confirms clean structure and naming
- **Error Handling**: Enhanced error checking across all deployment scripts
- **User Experience**: Multiple entry points and comprehensive troubleshooting guides

## [1.1.0] - 2025-10-11

### Added
- **LXC Architecture**: Nginx Proxy Manager and Tailscale in dedicated LXC containers
- **Automated Setup Scripts**: One-command LXC deployment for NPM and Tailscale
- **Environment Variable Infrastructure**: System configuration variables in .env files
- **Comprehensive Documentation**: Setup guides for LXC-based reverse proxy and VPN

### Removed
- **Docker-based NPM/Tailscale**: Moved to dedicated LXC containers for better isolation

### Changed
- **Network Architecture**: Tailscale now acts as subnet router for entire homelab (192.168.1.0/24)
- **Documentation Updates**: Reflect LXC-based approach throughout guides

## [1.0.0] - 2025-10-11

### Added
- **Initial Release**: Complete homelab-SHV repository structure
- **Core Infrastructure**: Docker Compose stack with 18+ services
- **Media Stack**: Jellyfin, Sonarr, Radarr, Bazarr, Prowlarr, Jellyseerr
- **Download Management**: qBittorrent + NZBGet with Gluetun VPN integration
- **Analytics & Requests**: Jellystat, Suggestarr, Tunarr for enhanced media management
- **YouTube Automation**: Complete YouTube content downloading and integration
- **Monitoring System**: Comprehensive health checks and alerting
- **Backup Solution**: Restic-based automated backup with encryption
- **Notification System**: Ntfy integration for real-time alerts and summaries

#### 🚀 Lifecycle Scripts
- `homelab.sh` - Master control script with deploy/teardown/reset/status commands
- `deploy_homelab.sh` - One-step deployment with dependency installation
- `teardown_homelab.sh` - Clean removal while preserving data
- `reset_homelab.sh` - Complete reset and redeployment
- `status_homelab.sh` - Comprehensive system health check

#### 📊 Monitoring & Maintenance
- `restic_backup_with_alerts.sh` - Encrypted backup with repository integrity checks
- `daily_backup_summary.sh` - Daily operational summary and statistics
- `hdd_health_check.sh` - SMART disk health monitoring with temperature tracking
- `weekly_system_health.sh` - Comprehensive weekly health assessment
- `maintenance_dashboard.sh` - Automated daily maintenance orchestration
- `Homelab_Documentation_Archiver.sh` - Documentation backup and versioning

#### 🐳 Container Stack
- **VPN Gateway**: Gluetun with WireGuard support
- **Media Server**: Jellyfin with hardware acceleration
- **Media Management**: Complete Servarr stack (Sonarr, Radarr, Bazarr, Prowlarr)
- **Download Clients**: qBittorrent (VPN-protected) and NZBGet
- **Request Management**: Jellyseerr for user requests
- **Analytics**: Jellystat with PostgreSQL backend
- **Automation**: Recyclarr for quality profiles, YouTube integration
- **Utilities**: Flaresolverr for Cloudflare-protected sites

#### 🔧 Configuration Management
- **Environment Templates**: Comprehensive `.env.example` with all options
- **VPN Configuration**: WireGuard template with provider examples
- **Service Configuration**: Pre-configured container settings and networking
- **Documentation**: Complete setup guides and troubleshooting resources

#### 🤖 Automation Features
- **YouTube Integration**: Smart incremental downloading with quality profiles
- **Jellyfin Integration**: Automated library updates and metadata management
- **Cron Scheduling**: Automated daily/weekly maintenance tasks
- **Health Monitoring**: Proactive system monitoring with alerting

#### 📚 Documentation
- **Complete Documentation Suite**: Architecture, deployment, troubleshooting
- **Directory Structure**: Detailed filesystem layout and organization
- **Deployment Checklist**: Pre-deployment verification procedures
- **Troubleshooting Guide**: Common issues and resolution procedures
- **API References**: Service configuration and integration guides

#### 🛡️ Security Features
- **VPN-Protected Downloads**: All torrent traffic routed through VPN
- **Network Isolation**: Dedicated Docker network with static IP assignments
- **Secret Management**: Environment-based configuration for sensitive data
- **Container Security**: Non-root user execution and resource limits

#### 🔄 Backup & Recovery
- **Restic Integration**: Encrypted, incremental, cross-platform backups
- **Automated Scheduling**: Daily backups with weekly integrity checks
- **Retention Policies**: Configurable retention (daily/weekly/monthly/yearly)
- **Documentation Archiving**: Automated configuration and documentation backup
- **Disaster Recovery**: Complete system restoration procedures

#### 📈 Monitoring & Alerting
- **System Health**: CPU, memory, disk, and network monitoring
- **Service Health**: Container status and endpoint availability
- **Storage Monitoring**: Disk usage, SMART status, and ZFS integration
- **Notification System**: Real-time alerts via Ntfy with priority levels
- **Reporting**: Daily summaries and weekly comprehensive health reports

#### 🎛️ Management Features
- **Web Interfaces**: Access to all services via intuitive web UIs
- **Quality Management**: Automated quality profile synchronization
- **Content Organization**: Automated media library organization
- **User Management**: Multi-user support with request capabilities

### Technical Details

#### Network Architecture
- Custom Docker network (172.20.0.0/16) with static IP assignments
- VPN gateway routing for download clients
- Internal service communication via container names
- External access via mapped ports

#### Storage Layout
- `/data/docker/` - Container persistent configurations
- `/data/media/` - Organized media library (movies/shows/music/youtube)
- `/data/backups/` - Backup storage and archives
- `/data/logs/` - Application and system logs

#### Quality & Performance
- Hardware acceleration support for Jellyfin
- Configurable download quality profiles
- Resource-optimized container configurations
- Automated cleanup and maintenance

### Breaking Changes
- N/A (Initial release)

### Deprecated
- N/A (Initial release)

### Removed  
- N/A (Initial release)

### Fixed
- N/A (Initial release)

### Security
- VPN-mandatory download client configuration
- Encrypted backup repositories
- Container isolation and non-root execution
- Secret management via environment variables

---

## Version Numbering

This project uses [Semantic Versioning](https://semver.org/):
- **MAJOR** version for incompatible API changes
- **MINOR** version for backwards-compatible functionality additions
- **PATCH** version for backwards-compatible bug fixes

## Release Process

1. Update changelog with new version
2. Tag release in git: `git tag -a v1.0.0 -m "Release v1.0.0"`
3. Push tags: `git push origin --tags`
4. Create GitHub release with changelog excerpt

## Support Timeline

- **Current Version (1.x)**: Full support with regular updates
- **Previous Major**: Security updates for 6 months after new major release
- **End of Life**: Announced 3 months in advance

---

**Maintainer**: J35867U (mrnash404@protonmail.com)  
**Repository**: [homelab-SHV](https://github.com/J35867U/homelab-SHV)  
**Last Updated**: 2025-10-11