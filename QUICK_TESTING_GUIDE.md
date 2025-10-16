# 🚀 Quick Testing Platform Guide

## Summary of Available Testing Options

### 🐳 Docker Desktop (Fastest - 5 minutes)
**Best for: Quick testing, development**
```bash
# Windows PowerShell
./deploy_docker_testing.sh

# Or manual Docker Compose
docker-compose -f docker-compose.testing.yml up -d
```
- **Time to deploy**: 5-10 minutes
- **Cost**: Free
- **Resources**: Uses host system resources
- **Access**: All services on localhost ports

### 📦 VirtualBox (Local VM - 30 minutes)
**Best for: Isolated testing, learning virtualization**
```bash
# Create and setup VM
./deploy_virtualbox.sh create   # Install Ubuntu manually
./deploy_virtualbox.sh setup    # Configure Docker
./deploy_virtualbox.sh deploy   # Start services
```
- **Time to deploy**: 30-45 minutes (includes Ubuntu install)
- **Cost**: Free
- **Resources**: 4GB RAM, 2 CPUs, 40GB disk
- **Access**: Port forwarding to localhost

### 🌩️ Cloud Deployment (Most Realistic - 15 minutes)
**Best for: Production-like testing, remote access**
```powershell
# AWS/GCP/Azure deployment
.\deploy_cloud.ps1 deploy      # Deploy infrastructure
.\deploy_cloud.ps1 destroy     # Clean up (important!)
```
- **Time to deploy**: 10-15 minutes
- **Cost**: ~$0.04/hour (AWS t3.medium)
- **Resources**: 2 vCPU, 4GB RAM, 40GB SSD
- **Access**: Public IP with all services

## 🎯 Recommended Testing Sequence

1. **Start with Docker** - Quick validation of services
2. **Move to VirtualBox** - Test full deployment process
3. **Deploy to Cloud** - Production-like environment testing
4. **Return to Proxmox** - Apply learnings to original platform

## 🔧 Service Comparison Across Platforms

| Service | Docker Port | VM Port | Cloud URL |
|---------|-------------|---------|-----------|
| Jellyfin | :8096 | :8096 | http://IP:8096 |
| Sonarr | :8989 | :8989 | http://IP:8989 |
| Radarr | :7878 | :7878 | http://IP:7878 |
| Prowlarr | :9696 | :9696 | http://IP:9696 |
| qBittorrent | :8080 | :8080 | http://IP:8080 |
| NPM | :81 | :81 | http://IP:81 |
| Pi-hole | :8053 | :8053 | http://IP:8053 |
| Vaultwarden | :8200 | :8200 | http://IP:8200 |
| NTFY | :8300 | :8300 | http://IP:8300 |
| Netdata | :19999 | :19999 | http://IP:19999 |

## 🛠️ Platform-Specific Commands

### Docker Commands
```bash
# Deploy
./deploy_docker_testing.sh deploy

# Check status
./deploy_docker_testing.sh status

# View logs
./deploy_docker_testing.sh logs jellyfin

# Stop all
./deploy_docker_testing.sh stop

# Clean up
./deploy_docker_testing.sh cleanup
```

### VirtualBox Commands
```bash
# VM lifecycle
./deploy_virtualbox.sh create    # Create VM
./deploy_virtualbox.sh start     # Start VM
./deploy_virtualbox.sh ssh       # SSH into VM
./deploy_virtualbox.sh stop      # Stop VM
./deploy_virtualbox.sh remove    # Delete VM

# Service management (run inside VM)
cd ~/homelab
docker compose ps                # Check status
docker compose logs jellyfin     # View logs
docker compose restart sonarr    # Restart service
```

### Cloud Commands
```powershell
# Infrastructure
.\deploy_cloud.ps1 deploy        # Deploy everything
.\deploy_cloud.ps1 status        # Check status
.\deploy_cloud.ps1 info          # Show access info
.\deploy_cloud.ps1 destroy       # ⚠️ IMPORTANT: Clean up

# Service management (SSH to instance)
ssh -i ~/.ssh/id_rsa ubuntu@[IP]
cd homelab
docker compose ps                # Check services
docker compose logs              # View all logs
```

## 💡 Troubleshooting Tips

### Docker Issues
- **Port conflicts**: Change ports in docker-compose.yml
- **Permission issues**: Run `docker system prune -f`
- **Slow performance**: Increase Docker resources in settings

### VirtualBox Issues
- **VM won't start**: Enable virtualization in BIOS
- **Network issues**: Check port forwarding rules
- **Performance**: Increase VM memory/CPU allocation

### Cloud Issues
- **Access denied**: Check security group rules
- **High costs**: Don't forget to run `destroy`!
- **Connection timeout**: Check instance status in AWS console

## 🎯 Which Platform Should You Choose?

**Choose Docker if:**
- You want the fastest setup
- You're familiar with containers
- You need quick iteration testing

**Choose VirtualBox if:**
- You want to learn virtualization
- You need isolated testing
- You have plenty of local resources

**Choose Cloud if:**
- You need production-like testing
- You want to test remote access
- You need to share access with others

**Return to Proxmox when:**
- You've validated the configuration works
- You've identified platform-specific issues
- You're ready for the production deployment