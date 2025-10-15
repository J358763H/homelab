# Game Server Troubleshooting Guide

## Quick Start Issues

### Installation Problems

#### Permission Denied During Setup
```bash
# Check if running with sudo
sudo ./setup.sh

# Fix ownership if needed
sudo chown -R gameserver:gameserver /opt/gameserver
sudo chown -R gameserver:gameserver /home/gameserver
```

#### Missing Dependencies
```bash
# Update package list
sudo apt update

# Install missing packages
sudo apt install curl wget git software-properties-common

# Check Docker installation
docker --version
docker-compose --version
```

#### Service Start Failures
```bash
# Check service status
sudo systemctl status sunshine
sudo systemctl status coinops

# View service logs
sudo journalctl -u sunshine -f
sudo journalctl -u coinops -f

# Restart services
sudo systemctl restart sunshine
sudo systemctl restart coinops
```

## Streaming Issues

### Moonlight/Sunshine Connection Problems

#### Cannot Connect to Server
1. **Check firewall:**
   ```bash
   sudo ufw status
   # Should show ports 47984-47990, 48010 as ALLOW
   ```

2. **Verify Sunshine is running:**
   ```bash
   curl -k https://localhost:47990
   # Should return Sunshine web interface
   ```

3. **Check network connectivity:**
   ```bash
   # From client machine
   telnet 192.168.100.252 47989
   ```

#### Poor Streaming Quality
1. **CPU encoding optimization:**
   ```bash
   # Check CPU usage during streaming
   htop
   
   # Monitor encoding performance
   cat /opt/gameserver/logs/sunshine.log | grep "encoding"
   ```

2. **Network bandwidth issues:**
   ```bash
   # Test bandwidth to client
   iperf3 -s  # On server
   iperf3 -c 192.168.100.252 -t 30  # On client
   ```

3. **Adjust streaming settings in Sunshine web UI:**
   - Lower bitrate (10-20 Mbps for 1080p)
   - Reduce FPS to 30
   - Enable hardware acceleration if available

#### Authentication Issues
```bash
# Reset Sunshine credentials
sudo rm -rf /var/lib/sunshine/sunshine.conf
sudo systemctl restart sunshine

# Check web interface access
curl -k https://localhost:47990/pin
```

## Game Server Issues

### Docker Container Problems

#### Containers Won't Start
```bash
# Check Docker daemon
sudo systemctl status docker

# View container logs
docker logs <container-name>

# Check resource usage
docker stats

# Restart container
docker restart <container-name>
```

#### Port Conflicts
```bash
# Check what's using ports
netstat -tulpn | grep :<port>

# Stop conflicting services
sudo systemctl stop <service-name>

# Modify port in docker-compose.yml
```

#### Memory/CPU Issues
```bash
# Check system resources
free -h
htop

# View container resource usage
docker stats

# Adjust resource limits in docker-compose.yml
```

### Game-Specific Issues

#### Minecraft Server
```bash
# Check logs
docker logs minecraft-server

# Common issues:
# - EULA not accepted: Set EULA=TRUE
# - Memory issues: Increase MEMORY value
# - World corruption: Restore from backup

# Access server console
docker exec -it minecraft-server rcon-cli
```

#### Valheim Server
```bash
# Check logs
docker logs valheim-server

# Common issues:
# - Steam login: Check PUID/PGID match system user
# - World not saving: Check volume permissions
# - Password issues: Ensure SERVER_PASS is set

# View server status
docker exec valheim-server supervisorctl status
```

#### Factorio Server
```bash
# Check logs
docker logs factorio-server

# Common issues:
# - Save file missing: Enable GENERATE_NEW_SAVE
# - Authentication: Set FACTORIO_USER_USERNAME/TOKEN
# - Memory issues: Increase container memory limit

# Access admin console
docker exec -it factorio-server factorio-rcon
```

## CoinOps Emulation Issues

### RetroArch Problems
```bash
# Check RetroArch installation
/home/gameserver/.local/share/coinops/retroarch/retroarch --version

# View logs
tail -f /home/gameserver/.config/retroarch/retroarch.log

# Reset configuration
rm /home/gameserver/.config/retroarch/retroarch.cfg
```

### ROM/BIOS Issues
```bash
# Check ROM directories
ls -la /home/gameserver/coinops/roms/
ls -la /home/gameserver/coinops/bios/

# Fix permissions
sudo chown -R gameserver:gameserver /home/gameserver/coinops/
```

### Performance Issues
```bash
# Enable performance mode
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Check CPU temperature
sensors

# Monitor system during emulation
htop
```

## Network Issues

### Firewall Problems
```bash
# Check UFW status
sudo ufw status verbose

# Reset to default rules
sudo ufw --force reset
sudo ufw enable

# Re-add game server rules
sudo ufw allow 47984:47990/tcp
sudo ufw allow 47998:48010/udp
```

### Port Forwarding
```bash
# Check if ports are externally accessible
# From external machine:
nmap -p 25565 <external-ip>  # Minecraft
nmap -p 2456-2458 <external-ip>  # Valheim

# Configure router port forwarding for remote access
```

## Performance Optimization

### System Tuning
```bash
# CPU governor for performance
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Increase file descriptor limits
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# Network optimization
echo 'net.core.rmem_max = 134217728' | sudo tee -a /etc/sysctl.conf
echo 'net.core.wmem_max = 134217728' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### Docker Optimization
```bash
# Enable Docker logging limits
cat > /etc/docker/daemon.json << EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

sudo systemctl restart docker
```

## Monitoring and Logs

### System Monitoring
```bash
# Check system health
./status.sh

# Monitor in real-time
watch -n 5 ./status.sh

# View system logs
sudo journalctl -f
```

### Application Logs
```bash
# Sunshine logs
tail -f /opt/gameserver/logs/sunshine.log

# CoinOps logs
tail -f /home/gameserver/coinops/logs/coinops.log

# Docker container logs
docker logs -f <container-name>
```

### Network Monitoring
```bash
# Monitor network traffic
sudo nethogs

# Check connections
netstat -tuln

# Monitor specific ports
sudo tcpdump -i any port 47989
```

## Recovery Procedures

### Service Recovery
```bash
# Stop all services
sudo systemctl stop sunshine coinops
docker stop $(docker ps -q)

# Clear temporary files
sudo rm -rf /tmp/gameserver/*

# Restart everything
sudo systemctl start sunshine coinops
./scripts/maintenance/restart_servers.sh
```

### Data Recovery
```bash
# Restore from backup
./scripts/backup/restore_backup.sh <backup-date>

# Manual file recovery
rsync -av /opt/gameserver/backups/latest/ /home/gameserver/
sudo chown -R gameserver:gameserver /home/gameserver/
```

### Reset to Defaults
```bash
# Nuclear option - complete reset
sudo ./teardown.sh
sudo ./setup.sh
```

## Getting Help

### Log Collection
```bash
# Collect all relevant logs
mkdir -p /tmp/gameserver-debug
cp /opt/gameserver/logs/* /tmp/gameserver-debug/
docker logs sunshine > /tmp/gameserver-debug/docker-sunshine.log
docker logs coinops > /tmp/gameserver-debug/docker-coinops.log
journalctl -u sunshine --no-pager > /tmp/gameserver-debug/systemd-sunshine.log

# Create tarball
tar -czf gameserver-debug.tar.gz /tmp/gameserver-debug/
```

### System Information
```bash
# Hardware info
lscpu
lsmem
lsblk
lspci | grep -i vga

# Software versions
uname -a
docker --version
cat /etc/os-release

# Network configuration
ip addr show
ip route show
```

### Support Checklist
Before asking for help, please provide:
1. Error messages from logs
2. System information output
3. Steps to reproduce the issue
4. When the issue started occurring
5. Any recent changes made to the system

## Common Error Messages

### "Permission denied"
- Run with sudo or fix file ownership
- Check SELinux/AppArmor policies if enabled

### "Port already in use"
- Another service is using the port
- Use `netstat -tulpn | grep <port>` to identify
- Stop conflicting service or change port

### "No space left on device"
- Check disk usage with `df -h`
- Clean up Docker images: `docker system prune -a`
- Run maintenance script: `./scripts/maintenance/cleanup.sh`

### "Connection refused"
- Service not running or firewall blocking
- Check service status and firewall rules
- Verify correct IP address and port

### "Container exited with code 1"
- Check container logs: `docker logs <container>`
- Usually configuration or permission issue
- Review docker-compose.yml settings