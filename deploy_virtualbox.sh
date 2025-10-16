#!/bin/bash

# =====================================================
# 📦 VirtualBox Homelab Deployment
# =====================================================
# Deploys homelab using Docker on VirtualBox VM
# Includes VM creation, Docker setup, and service deployment
# Perfect for testing on Windows/Mac/Linux
# =====================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
VM_NAME="homelab-testing"
VM_MEMORY="4096"  # 4GB RAM
VM_DISK_SIZE="40960"  # 40GB disk
VM_CPUS="2"
UBUNTU_ISO_URL="https://releases.ubuntu.com/22.04/ubuntu-22.04.3-live-server-amd64.iso"
UBUNTU_ISO="ubuntu-22.04.3-live-server-amd64.iso"
HOMELAB_DIR="$(pwd)"

# Functions
log() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
success() { echo -e "${GREEN}[SUCCESS] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }
warn() { echo -e "${YELLOW}[WARNING] $1${NC}"; }
step() { echo -e "${PURPLE}[STEP] $1${NC}"; }

# Check VirtualBox installation
check_virtualbox() {
    step "Checking VirtualBox installation..."
    
    if ! command -v VBoxManage >/dev/null 2>&1; then
        error "VirtualBox is not installed"
        echo "Download and install VirtualBox from: https://www.virtualbox.org/wiki/Downloads"
        echo "Also install the Extension Pack for better performance"
        exit 1
    fi
    
    success "VirtualBox found: $(VBoxManage --version)"
}

# Download Ubuntu ISO if needed
download_ubuntu_iso() {
    step "Checking Ubuntu ISO..."
    
    if [[ ! -f "$UBUNTU_ISO" ]]; then
        log "Downloading Ubuntu Server ISO (this may take a while)..."
        if command -v wget >/dev/null 2>&1; then
            wget -O "$UBUNTU_ISO" "$UBUNTU_ISO_URL"
        elif command -v curl >/dev/null 2>&1; then
            curl -L -o "$UBUNTU_ISO" "$UBUNTU_ISO_URL"
        else
            error "Neither wget nor curl found. Please download Ubuntu ISO manually:"
            echo "URL: $UBUNTU_ISO_URL"
            echo "Save as: $UBUNTU_ISO"
            exit 1
        fi
    fi
    
    success "Ubuntu ISO ready: $UBUNTU_ISO"
}

# Create VirtualBox VM
create_vm() {
    step "Creating VirtualBox VM..."
    
    # Check if VM already exists
    if VBoxManage list vms | grep -q "\"$VM_NAME\""; then
        warn "VM '$VM_NAME' already exists"
        read -p "Remove existing VM? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            VBoxManage unregistervm "$VM_NAME" --delete 2>/dev/null || true
        else
            error "Cannot proceed with existing VM"
            exit 1
        fi
    fi
    
    # Create VM
    VBoxManage createvm --name "$VM_NAME" --ostype "Ubuntu_64" --register
    
    # Configure VM
    VBoxManage modifyvm "$VM_NAME" \
        --memory "$VM_MEMORY" \
        --cpus "$VM_CPUS" \
        --vram 128 \
        --graphicscontroller vmsvga \
        --boot1 dvd \
        --boot2 disk \
        --boot3 none \
        --boot4 none \
        --acpi on \
        --ioapic on \
        --rtcuseutc on \
        --accelerate3d on \
        --clipboard-mode bidirectional \
        --draganddrop bidirectional
    
    # Create and attach storage
    VBoxManage createmedium disk \
        --filename "$HOME/VirtualBox VMs/$VM_NAME/$VM_NAME.vdi" \
        --size "$VM_DISK_SIZE" \
        --format VDI
    
    VBoxManage storagectl "$VM_NAME" \
        --name "SATA Controller" \
        --add sata \
        --controller IntelAhci
    
    VBoxManage storageattach "$VM_NAME" \
        --storagectl "SATA Controller" \
        --port 0 \
        --device 0 \
        --type hdd \
        --medium "$HOME/VirtualBox VMs/$VM_NAME/$VM_NAME.vdi"
    
    VBoxManage storagectl "$VM_NAME" \
        --name "IDE Controller" \
        --add ide \
        --controller PIIX4
    
    VBoxManage storageattach "$VM_NAME" \
        --storagectl "IDE Controller" \
        --port 1 \
        --device 0 \
        --type dvddrive \
        --medium "$(realpath "$UBUNTU_ISO")"
    
    # Configure network
    VBoxManage modifyvm "$VM_NAME" \
        --nic1 nat \
        --nictype1 82540EM \
        --natpf1 "SSH,tcp,,2222,,22" \
        --natpf1 "Jellyfin,tcp,,8096,,8096" \
        --natpf1 "Sonarr,tcp,,8989,,8989" \
        --natpf1 "Radarr,tcp,,7878,,7878" \
        --natpf1 "Prowlarr,tcp,,9696,,9696" \
        --natpf1 "qBittorrent,tcp,,8080,,8080" \
        --natpf1 "NPM-Web,tcp,,81,,81" \
        --natpf1 "NPM-HTTP,tcp,,80,,80" \
        --natpf1 "NPM-HTTPS,tcp,,443,,443" \
        --natpf1 "Pihole,tcp,,8053,,80" \
        --natpf1 "Vaultwarden,tcp,,8200,,8200" \
        --natpf1 "NTFY,tcp,,8300,,8300" \
        --natpf1 "Netdata,tcp,,19999,,19999"
    
    success "VM '$VM_NAME' created successfully"
}

# Start VM and show instructions
start_vm() {
    step "Starting VM for Ubuntu installation..."
    
    VBoxManage startvm "$VM_NAME" --type gui
    
    echo
    success "VM started! Please complete Ubuntu installation manually."
    echo
    echo "📋 Installation Instructions:"
    echo "  1. Follow Ubuntu Server installation wizard"
    echo "  2. Create user: homelab (password: homelab123)"
    echo "  3. Enable SSH server when prompted"
    echo "  4. Install security updates"
    echo "  5. Wait for installation to complete and reboot"
    echo "  6. Remove ISO from VM (Machine > Settings > Storage)"
    echo "  7. Run this script again with 'setup' option"
    echo
    echo "💡 Tips:"
    echo "  • Use Tab to navigate installer"
    echo "  • Choose 'Ubuntu Server (minimized)' for faster installation"
    echo "  • Enable SSH for remote management"
    echo
    read -p "Press Enter after Ubuntu installation is complete..."
}

# Setup homelab on the VM
setup_homelab() {
    step "Setting up homelab on VM..."
    
    # Wait for VM to be accessible
    log "Waiting for VM to be accessible via SSH..."
    timeout=300
    while ! ssh -p 2222 -o StrictHostKeyChecking=no -o ConnectTimeout=5 homelab@localhost "echo 'Connected'" 2>/dev/null; do
        sleep 5
        timeout=$((timeout - 5))
        if [ $timeout -le 0 ]; then
            error "VM is not accessible via SSH. Check VM status and network configuration."
            exit 1
        fi
        echo -n "."
    done
    echo
    success "VM is accessible"
    
    # Create setup script
    cat > vm_setup.sh << 'EOF'
#!/bin/bash

# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo apt install -y docker-compose-plugin

# Create directories
mkdir -p ~/homelab/{media/{movies,tv,music},downloads/{complete,incomplete}}

# Download homelab configuration
curl -fsSL https://raw.githubusercontent.com/your-repo/homelab/main/docker-compose.yml -o ~/homelab/docker-compose.yml

echo "Setup completed! Please log out and back in for Docker permissions to take effect."
EOF
    
    # Transfer and execute setup script
    scp -P 2222 -o StrictHostKeyChecking=no vm_setup.sh homelab@localhost:~/
    ssh -p 2222 -o StrictHostKeyChecking=no homelab@localhost "chmod +x vm_setup.sh && ./vm_setup.sh"
    
    # Transfer homelab files
    log "Transferring homelab configuration..."
    scp -P 2222 -o StrictHostKeyChecking=no -r deployment/* homelab@localhost:~/homelab/
    
    success "Homelab setup completed on VM"
}

# Deploy services on VM
deploy_on_vm() {
    step "Deploying homelab services on VM..."
    
    # Start services
    ssh -p 2222 -o StrictHostKeyChecking=no homelab@localhost "cd ~/homelab && docker compose up -d"
    
    success "Services deployed on VM"
    show_vm_access_info
}

# Show VM access information
show_vm_access_info() {
    step "VM Access Information"
    echo
    echo "🖥️  VM Details:"
    echo "  • Name: $VM_NAME"
    echo "  • Memory: ${VM_MEMORY}MB"
    echo "  • CPUs: $VM_CPUS"
    echo "  • SSH: ssh -p 2222 homelab@localhost"
    echo
    echo "🌐 Service Access (from host machine):"
    echo "  • Jellyfin Media Server:     http://localhost:8096"
    echo "  • Sonarr (TV Shows):         http://localhost:8989"
    echo "  • Radarr (Movies):           http://localhost:7878"
    echo "  • Prowlarr (Indexers):       http://localhost:9696"
    echo "  • qBittorrent:               http://localhost:8080"
    echo "  • Nginx Proxy Manager:       http://localhost:81"
    echo "  • Pi-hole DNS:               http://localhost:8053"
    echo "  • Vaultwarden:               http://localhost:8200"
    echo "  • NTFY Notifications:        http://localhost:8300"
    echo "  • Netdata Monitoring:        http://localhost:19999"
    echo
    echo "🔧 VM Management:"
    echo "  • Start VM: VBoxManage startvm '$VM_NAME' --type headless"
    echo "  • Stop VM: VBoxManage controlvm '$VM_NAME' poweroff"
    echo "  • VM Console: VBoxManage startvm '$VM_NAME' --type gui"
    echo "  • SSH Access: ssh -p 2222 homelab@localhost"
    echo
    echo "💾 VM Storage:"
    echo "  • Location: $HOME/VirtualBox VMs/$VM_NAME/"
    echo "  • Disk: ${VM_DISK_SIZE}MB VDI file"
    echo "  • Snapshots: Available through VirtualBox GUI"
}

# Stop VM
stop_vm() {
    step "Stopping VM..."
    
    if VBoxManage list runningvms | grep -q "\"$VM_NAME\""; then
        VBoxManage controlvm "$VM_NAME" acpipowerbutton
        sleep 10
        
        # Force shutdown if still running
        if VBoxManage list runningvms | grep -q "\"$VM_NAME\""; then
            warn "VM not responding to ACPI shutdown, forcing power off..."
            VBoxManage controlvm "$VM_NAME" poweroff
        fi
        
        success "VM stopped"
    else
        log "VM is not running"
    fi
}

# Remove VM
remove_vm() {
    step "Removing VM and all data..."
    
    read -p "This will permanently delete the VM and all its data. Are you sure? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        stop_vm
        VBoxManage unregistervm "$VM_NAME" --delete 2>/dev/null || true
        success "VM removed"
    else
        log "VM removal cancelled"
    fi
}

# Main execution
main() {
    echo "================================================================"
    echo "📦 HOMELAB VIRTUALBOX DEPLOYMENT"
    echo "================================================================"
    echo "Platform: VirtualBox VM with Ubuntu Server"
    echo "VM Name: $VM_NAME"
    echo "Resources: ${VM_MEMORY}MB RAM, ${VM_CPUS} CPUs, ${VM_DISK_SIZE}MB disk"
    echo "Timestamp: $(date)"
    echo "================================================================"
    echo
    
    check_virtualbox
    download_ubuntu_iso
    create_vm
    start_vm
}

# Handle command line arguments
case "${1:-create}" in
    "create")
        main
        ;;
    "setup")
        setup_homelab
        ;;
    "deploy")
        deploy_on_vm
        ;;
    "start")
        VBoxManage startvm "$VM_NAME" --type headless
        success "VM started in background"
        ;;
    "stop")
        stop_vm
        ;;
    "gui")
        VBoxManage startvm "$VM_NAME" --type gui
        success "VM started with GUI"
        ;;
    "ssh")
        ssh -p 2222 homelab@localhost
        ;;
    "status")
        if VBoxManage list runningvms | grep -q "\"$VM_NAME\""; then
            success "VM is running"
            VBoxManage showvminfo "$VM_NAME" --machinereadable | grep -E "(name|memory|cpus|State)"
        else
            warn "VM is not running"
        fi
        ;;
    "info")
        show_vm_access_info
        ;;
    "remove")
        remove_vm
        ;;
    *)
        echo "Usage: $0 [create|setup|deploy|start|stop|gui|ssh|status|info|remove]"
        echo "  create - Create and start VM for Ubuntu installation"
        echo "  setup  - Setup Docker and homelab on existing VM"
        echo "  deploy - Deploy homelab services on VM"
        echo "  start  - Start VM in background"
        echo "  stop   - Stop VM gracefully"
        echo "  gui    - Start VM with GUI"
        echo "  ssh    - SSH into VM"
        echo "  status - Show VM status"
        echo "  info   - Show access information"
        echo "  remove - Remove VM and all data"
        echo
        echo "Typical workflow:"
        echo "  1. $0 create    # Create VM and install Ubuntu"
        echo "  2. $0 setup     # Setup Docker and homelab"
        echo "  3. $0 deploy    # Deploy services"
        exit 1
        ;;
esac