# 📚 Homelab-SHV Documentation Master

Welcome to the comprehensive documentation for Homelab-SHV, your self-hosted media and automation platform.

## 📖 Documentation Index

### 🏗️ Architecture & Design
- **[System Architecture](System_Architecture.md)** - Overall system design and component relationships
- **[Network Plan](Network_Plan.md)** - Network topology, VLANs, and security zones  
- **[Storage Layout](Storage_Layout.md)** - Storage architecture and data organization
- **[Directory Tree](Directory_Tree_v1.0.txt)** - Complete filesystem layout

### 🚀 Deployment & Setup
- **[Deployment Guide](../deployment/README_START_HERE.md)** - Quick start deployment instructions
- **[Deployment Checklist](../deployment/DEPLOYMENT_CHECKLIST.md)** - Pre-deployment verification
- **[Troubleshooting](../deployment/TROUBLESHOOTING.md)** - Common issues and solutions

### 🐳 Container Stack
- **[Docker Compose Reference](Docker_Stack_Reference.md)** - Complete service definitions
- **[Service Configuration](Service_Configuration.md)** - Individual service setup guides
- **[Networking](Container_Networking.md)** - Internal container communication

### 📊 Monitoring & Maintenance
- **[Health Monitoring](Health_Monitoring.md)** - System health checks and alerting
- **[Backup Strategy](Backup_Strategy.md)** - Data protection and recovery procedures
- **[Maintenance Procedures](Maintenance_Procedures.md)** - Regular maintenance tasks

### 🤖 Automation
- **[Jellyfin YouTube Integration](YouTube_Automation.md)** - Automated YouTube content management
- **[Servarr Configuration](Servarr_Setup.md)** - Sonarr, Radarr, and Prowlarr setup
- **[Notification System](Notification_System.md)** - Ntfy alerts and monitoring

### 🔒 Security & Access
- **[Security Best Practices](Security_Guide.md)** - System hardening and security measures
- **[VPN Configuration](VPN_Setup.md)** - WireGuard and Gluetun setup
- **[User Management](User_Management.md)** - Account management and access control

### 🛠️ Operations
- **[Lifecycle Management](Lifecycle_Management.md)** - Deploy, update, and teardown procedures
- **[Log Management](Log_Management.md)** - Logging configuration and analysis
- **[Performance Tuning](Performance_Tuning.md)** - Optimization guidelines

## 🎯 Quick Reference

### Essential Commands
```bash
# Deploy the entire stack
./homelab.sh deploy

# Check system status  
./homelab.sh status

# Reset everything
./homelab.sh reset

# Teardown (preserves data)
./homelab.sh teardown
```

### Key URLs (replace `<server-ip>` with your server's IP)
- **Jellyfin**: `http://<server-ip>:8096`
- **Sonarr**: `http://<server-ip>:8989`
- **Radarr**: `http://<server-ip>:7878`
- **Prowlarr**: `http://<server-ip>:9696`
- **Jellyseerr**: `http://<server-ip>:5055`
- **qBittorrent**: `http://<server-ip>:8080`

### Important Directories
- `/data/docker/` - Container configurations
- `/data/media/` - Media libraries
- `/data/backups/` - Backup storage
- `/var/log/homelab-shv/` - Application logs

### Emergency Procedures
1. **Complete system failure**: See [Disaster Recovery](Disaster_Recovery.md)
2. **Container issues**: Check [Container Troubleshooting](../deployment/TROUBLESHOOTING.md#docker-container-issues)
3. **Network problems**: See [Network Troubleshooting](../deployment/TROUBLESHOOTING.md#vpn--network-issues)

## 📋 Maintenance Schedule

### Daily (Automated)
- System health checks
- Backup verification
- Log rotation
- Container health monitoring

### Weekly (Automated)
- Comprehensive system health report
- Repository integrity checks
- Security update notifications
- Performance analysis

### Monthly (Manual)
- Review and update configurations
- Security audit
- Capacity planning review
- Documentation updates

## 🆘 Support & Contact

- **Maintainer**: J35867U
- **Email**: mrnash404@protonmail.com
- **Repository**: [homelab-SHV](https://github.com/J35867U/homelab-SHV)
- **Issues**: Use GitHub Issues for bug reports and feature requests

## 📝 Documentation Standards

This documentation follows these principles:
- **Clarity**: Clear, concise explanations
- **Completeness**: Comprehensive coverage of all components
- **Currency**: Regular updates to reflect system changes
- **Accessibility**: Easy to navigate and understand

## 🔄 Version History

- **v1.0** (2025-10-11): Initial documentation structure
- Future versions will be tracked in [changelog.md](../changelog.md)

---

**Last Updated**: 2025-10-11  
**Documentation Version**: 1.0  
**System Version**: Homelab-SHV v1.0