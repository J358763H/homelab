# 🐳 Docker Installation Guide for Windows

## Quick Setup Options

### Option 1: Docker Desktop (Recommended)
**Best for: Easy setup with GUI**

1. **Download Docker Desktop**:
   - Visit: https://www.docker.com/products/docker-desktop/
   - Download "Docker Desktop for Windows"

2. **Install Requirements**:
   - Windows 10/11 Pro, Enterprise, or Education
   - WSL 2 (Windows Subsystem for Linux)
   - Hyper-V enabled

3. **Installation Steps**:
   ```powershell
   # Enable WSL 2 (run as Administrator)
   wsl --install
   
   # Restart computer when prompted
   # Then install Docker Desktop and restart again
   ```

4. **Verify Installation**:
   ```powershell
   docker --version
   docker compose version
   ```

### Option 2: Docker in WSL 2 (Advanced)
**Best for: Command-line users, better performance**

1. **Install WSL 2 Ubuntu**:
   ```powershell
   # Run as Administrator
   wsl --install -d Ubuntu
   # Restart computer
   ```

2. **Install Docker in WSL**:
   ```bash
   # In WSL Ubuntu terminal
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   sudo usermod -aG docker $USER
   # Logout and login to WSL again
   ```

3. **Start Docker**:
   ```bash
   sudo service docker start
   # Or enable auto-start
   echo 'sudo service docker start' >> ~/.bashrc
   ```

### Option 3: Cloud Testing (No Local Docker)
**Best for: Immediate testing without local setup**

Use our cloud deployment script:
```powershell
.\deploy_cloud.ps1 deploy
```

## 🚀 After Docker Installation

Once Docker is installed, come back and run:
```bash
./deploy_docker_testing.sh
```

This will:
- ✅ Create all homelab services (Jellyfin, Sonarr, Radarr, etc.)
- ✅ Set up networking and volumes
- ✅ Start everything on localhost ports
- ✅ Create sample media content for testing

## 🌐 Expected Service URLs

After deployment, you'll access:
- **Jellyfin**: http://localhost:8096
- **Sonarr**: http://localhost:8989  
- **Radarr**: http://localhost:7878
- **Prowlarr**: http://localhost:9696
- **qBittorrent**: http://localhost:8080
- **Nginx Proxy Manager**: http://localhost:81
- **Pi-hole**: http://localhost:8053
- **Vaultwarden**: http://localhost:8200
- **NTFY**: http://localhost:8300
- **Netdata**: http://localhost:19999

## 💡 Quick Alternative

If you want to test immediately without installing Docker locally, try the cloud option:
```powershell
# Requires: AWS CLI configured, Terraform installed
.\deploy_cloud.ps1 deploy
```

This creates a cloud VM with everything pre-installed and gives you public URLs to test all services.

## ❓ Which Option Should You Choose?

- **New to Docker?** → Docker Desktop
- **Comfortable with Linux?** → WSL 2 + Docker
- **Want immediate testing?** → Cloud deployment
- **Don't want to install anything?** → Cloud deployment

Let me know which option you prefer and I can guide you through the specific steps!