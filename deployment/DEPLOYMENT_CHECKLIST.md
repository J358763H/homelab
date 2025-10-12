# ✅ Homelab-SHV Deployment Checklist

Complete this checklist before deploying your homelab to ensure a smooth setup.

## 📋 Pre-Deployment Checklist

### System Requirements
- [ ] Ubuntu/Debian-based system (20.04+ recommended)
- [ ] Minimum 4GB RAM, 8GB recommended
- [ ] Minimum 100GB storage, 500GB+ recommended  
- [ ] Internet connection for downloading container images
- [ ] SSH access configured (for remote management)

### Dependencies Installation
- [ ] Docker installed and running (`docker --version`)
- [ ] Docker Compose plugin installed (`docker compose version`)
- [ ] Git installed (`git --version`)
- [ ] Curl installed (`curl --version`)
- [ ] Rsync installed (`rsync --version`)

### Directory Structure
- [ ] `/data` directory created and owned by user 1000:1000
- [ ] `/data/docker` subdirectories created (servarr, jellyfin, etc.)
- [ ] `/data/media` subdirectories created (movies, shows, music, youtube)
- [ ] `/data/backups` directory created for backup storage

### Configuration Files
- [ ] `.env` file created from `.env.example`
- [ ] All `changeme` values replaced in `.env`
- [ ] VPN credentials configured in `.env`
- [ ] Database passwords set in `.env`
- [ ] API keys prepared (will be generated during first run)
- [ ] `wg0.conf` created from template with VPN details

### Reverse Proxy & Security Setup
- [ ] **NPM directories** created (`/data/docker/nginx-proxy-manager/`)
- [ ] **Tailscale account** created at tailscale.com
- [ ] **Auth key generated** from Tailscale admin console
- [ ] **Domain name** configured (optional, for SSL certificates)
- [ ] **Port 81** available for NPM admin interface

### Network Configuration
- [ ] Required ports available (8096, 8989, 7878, 9696, etc.)
- [ ] Firewall configured to allow necessary ports
- [ ] VPN service active and credentials valid
- [ ] `/dev/net/tun` device exists for VPN container

### Security Setup
- [ ] Strong passwords set for all services
- [ ] SSH keys configured (if using remote access)
- [ ] Firewall rules configured appropriately
- [ ] Regular update schedule planned

## 🔧 Configuration Validation

### Environment File Check
```bash
# Verify no placeholder values remain
grep -n "changeme\|your_.*_here\|replace_me" deployment/.env
# Should return no results
```

### VPN Configuration Check
```bash
# Verify WireGuard config exists and has required fields
grep -E "(PrivateKey|PublicKey|Endpoint)" deployment/wg0.conf
# Should show all three fields with actual values
```

### Docker Compose Validation
```bash
# Test Docker Compose configuration
docker compose -f deployment/docker-compose.yml config
# Should complete without errors
```

### Permissions Check
```bash
# Verify data directory permissions
ls -la /data/
# Should show owner as user 1000:1000
```

## 🚀 Deployment Validation

### Container Startup
- [ ] All containers start successfully (`docker compose ps`)
- [ ] No containers in "Exited" or "Restarting" state
- [ ] Gluetun VPN container passes health check
- [ ] Database containers are healthy

### Service Accessibility
- [ ] Jellyfin accessible at http://server-ip:8096
- [ ] Sonarr accessible at http://server-ip:8989
- [ ] Radarr accessible at http://server-ip:7878
- [ ] Prowlarr accessible at http://server-ip:9696
- [ ] qBittorrent accessible at http://server-ip:8080
- [ ] All services load without errors

### VPN Functionality
- [ ] VPN connection established in Gluetun
- [ ] External IP masked when using VPN services
- [ ] Download traffic routed through VPN
- [ ] DNS resolution working correctly

### Initial Configuration
- [ ] Jellyfin setup wizard completed
- [ ] Media libraries configured in Jellyfin
- [ ] Prowlarr indexers configured
- [ ] Sonarr/Radarr connected to Prowlarr
- [ ] Download clients configured in Sonarr/Radarr
- [ ] Quality profiles set up appropriately

## 📊 Post-Deployment Testing

### Functionality Tests
- [ ] Media scanning works in Jellyfin
- [ ] Can search for content in Sonarr/Radarr
- [ ] Indexers return results in Prowlarr
- [ ] Downloads initiate successfully
- [ ] Files appear in correct media directories

### Automation Tests
- [ ] Cron jobs scheduled and running
- [ ] Backup scripts execute without errors
- [ ] Health check scripts reporting correctly
- [ ] Log files being created properly

### Integration Tests
- [ ] Sonarr can communicate with Prowlarr
- [ ] Radarr can communicate with download clients
- [ ] Jellyfin can access and scan media files
- [ ] Jellystat can connect to Jellyfin

## 🛡️ Security Validation

### Access Control
- [ ] Default passwords changed on all services
- [ ] Admin accounts secured with strong passwords
- [ ] Unnecessary services disabled
- [ ] Regular security updates planned

### Network Security
- [ ] Only required ports exposed externally
- [ ] VPN properly configured and active
- [ ] Internal container communication secure
- [ ] SSL/TLS configured where appropriate

## 📈 Monitoring Setup

### Health Monitoring
- [ ] Container health checks configured
- [ ] System resource monitoring active
- [ ] Disk space monitoring configured
- [ ] Network connectivity monitoring

### Alerting
- [ ] Notification system configured (Ntfy)
- [ ] Alert thresholds set appropriately
- [ ] Test alerts sent successfully
- [ ] Critical failure notifications working

## 💾 Backup Verification

### Backup Configuration
- [ ] Backup destinations configured
- [ ] Backup schedules set up in cron
- [ ] Backup encryption configured
- [ ] Retention policies defined

### Backup Testing
- [ ] Test backup runs successfully
- [ ] Backup files created in expected locations
- [ ] Backup restoration process tested
- [ ] Critical data identified and backed up

## 🎯 Performance Optimization

### Resource Optimization
- [ ] Container resource limits set appropriately
- [ ] Storage allocation optimized
- [ ] Network bandwidth managed
- [ ] Transcoding settings configured

### System Tuning
- [ ] Disk I/O optimized for media serving
- [ ] Network buffers tuned for streaming
- [ ] CPU scheduling optimized
- [ ] Memory usage monitored and optimized

## 📚 Documentation

### Operational Documentation
- [ ] Network topology documented
- [ ] Service credentials recorded securely
- [ ] Backup and recovery procedures documented
- [ ] Troubleshooting runbook created

### User Documentation
- [ ] Service access instructions created
- [ ] User account management documented
- [ ] Media organization guidelines established
- [ ] Request process documented

## 🏁 Deployment Sign-off

### Final Verification
- [ ] All checklist items completed
- [ ] System stable for 24+ hours
- [ ] No critical errors in logs
- [ ] Performance meets requirements

### Handover
- [ ] Operational documentation provided
- [ ] Administrative access transferred
- [ ] Monitoring alerts configured
- [ ] Support procedures established

---

## 📝 Deployment Notes

**Deployment Date:** _______________

**Deployed By:** J35867U (mrnash404@protonmail.com)

**System Details:**
- OS Version: _______________
- Docker Version: _______________
- Server IP: _______________
- VPN Provider: _______________

**Additional Notes:**
_________________________________________________________________
_________________________________________________________________
_________________________________________________________________

**Sign-off:** _______________  **Date:** _______________