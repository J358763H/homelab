# 🛠️ Homelab-SHV Troubleshooting Guide

## 🚨 Common Issues & Solutions

### Docker Container Issues

**Problem: Containers won't start**
```bash
# Check container status
docker compose ps

# View container logs
docker logs <container-name>

# Check Docker Compose configuration
docker compose config

# Restart a specific service
docker compose restart <service-name>
```

**Problem: Permission denied errors**
```bash
# Fix ownership of /data directory
sudo chown -R 1000:1000 /data

# Check current permissions
ls -la /data/
```

### VPN & Network Issues

**Problem: VPN not connecting (Gluetun)**
1. Check your `.env` file has correct VPN credentials
2. Verify `wg0.conf` has valid WireGuard configuration
3. Check Gluetun logs:
   ```bash
   docker logs gluetun
   ```
4. Ensure `/dev/net/tun` exists:
   ```bash
   ls -la /dev/net/tun
   # If missing: sudo mkdir /dev/net && sudo mknod /dev/net/tun c 10 200
   ```

**Problem: Can't access web interfaces**
1. Check if containers are running: `docker ps`
2. Verify port mappings in `docker-compose.yml`
3. Check firewall settings:
   ```bash
   sudo ufw status
   # Allow ports if needed: sudo ufw allow 8096
   ```

### Servarr Stack Issues

**Problem: Sonarr/Radarr can't connect to download clients**
1. Verify qBittorrent is accessible through Gluetun network
2. Use container names (not localhost) for internal connections
3. Check API keys in `.env` file
4. Test connectivity:
   ```bash
   docker exec sonarr curl -I http://gluetun:8080
   ```

**Problem: Indexers not working in Prowlarr**
1. Check if Flaresolverr is running for Cloudflare-protected sites
2. Verify indexer credentials and URLs
3. Check Prowlarr logs: `docker logs prowlarr`

### Media Server Issues

**Problem: Jellyfin can't see media files**
1. Check volume mounts in docker-compose.yml
2. Verify file permissions:
   ```bash
   docker exec jellyfin ls -la /data/media/
   ```
3. Scan library in Jellyfin admin panel

**Problem: Jellyfin transcoding issues**
1. Ensure hardware acceleration is configured
2. Check `/dev/dri` device availability:
   ```bash
   ls -la /dev/dri/
   ```
3. Monitor transcode directory: `/dev/shm`

### Database Issues

**Problem: Jellystat database connection failed**
1. Check if jellystat-db container is running
2. Verify database credentials in `.env`
3. Check database logs:
   ```bash
   docker logs jellystat-db
   ```

### Storage & Backup Issues

**Problem: Disk space issues**
1. Check disk usage: `df -h`
2. Clean up Docker: `docker system prune -a`
3. Check backup storage: `ls -la /data/backups/`

**Problem: Backup scripts failing**
1. Check script logs in `/var/log/homelab-shv/`
2. Verify Restic configuration in `.env`
3. Test backup manually:
   ```bash
   /usr/local/bin/restic_backup_with_alerts.sh
   ```

## 🔄 Reset Procedures

### Soft Reset (Restart containers)
```bash
docker compose down
docker compose up -d
```

### Hard Reset (Remove containers and volumes)
```bash
docker compose down
docker volume prune -f
docker compose up -d
```

### Complete Reset (Nuclear option)
```bash
# ⚠️ WARNING: This will delete ALL data
sudo rm -rf /data
docker system prune -a --volumes -f
./deploy_homelab.sh
```

## 📊 Health Checks

### Container Health Status
```bash
# Check all containers
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Check specific service health
docker exec gluetun curl -f http://localhost:8000/health
```

### System Health
```bash
# Run status script
./status_homelab.sh

# Check cron jobs
sudo crontab -l | grep homelab-shv

# Check system resources
htop
df -h
free -h
```

### Network Connectivity
```bash
# Test external connectivity through VPN
docker exec gluetun curl ifconfig.me

# Test internal container communication
docker exec sonarr curl -I http://prowlarr:9696
```

## 🆘 Emergency Recovery

### Service Down Recovery
1. Check container status: `docker ps -a`
2. Review logs: `docker logs <container>`
3. Restart service: `docker compose restart <service>`
4. If persistent, check configurations and redeploy

### Data Recovery
1. Backups are stored in `/data/backups/`
2. Restic repository configured in `.env`
3. Restore from backup:
   ```bash
   restic -r $RESTIC_REPOSITORY restore latest --target /data/restore/
   ```

### Configuration Recovery
1. Git history contains all configuration versions
2. Reset to known good state:
   ```bash
   git checkout <commit-hash>
   ./homelab.sh reset
   ```

## 📞 Getting Help

1. Check this troubleshooting guide first
2. Review container logs for specific error messages
3. Search the project documentation in `/docs`
4. Check GitHub issues for similar problems
5. Create detailed issue reports with:
   - Error messages
   - Container logs
   - System information
   - Steps to reproduce

## 🔍 Useful Commands

```bash
# View all container logs in real-time
docker compose logs -f

# Check container resource usage  
docker stats

# Access container shell
docker exec -it <container-name> /bin/bash

# Backup current configuration
tar -czf homelab-backup-$(date +%Y%m%d).tar.gz /data/docker/

# Monitor system in real-time
watch -n 5 'docker ps --format "table {{.Names}}\t{{.Status}}"'
```