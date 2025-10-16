# =====================================================
# 🌩️ Cloud Homelab Deployment (AWS/GCP/Azure/DigitalOcean)
# =====================================================
# Deploy homelab to cloud providers for testing
# Includes Terraform configurations and deployment scripts
# Perfect for realistic testing environments
# =====================================================

# AWS Deployment
$ErrorActionPreference = "Stop"

# Colors for PowerShell
function Write-Color {
    param(
        [string]$Text,
        [string]$Color = "White"
    )
    Write-Host $Text -ForegroundColor $Color
}

function Write-Step { Write-Color "[STEP] $args" "Magenta" }
function Write-Success { Write-Color "[SUCCESS] $args" "Green" }
function Write-Error { Write-Color "[ERROR] $args" "Red" }
function Write-Warn { Write-Color "[WARNING] $args" "Yellow" }
function Write-Log { Write-Color "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $args" "Blue" }

# Configuration
$VM_NAME = "homelab-testing"
$INSTANCE_TYPE = "t3.medium"  # 2 vCPU, 4GB RAM
$REGION = "us-east-1"
$KEY_NAME = "homelab-testing-key"

function Test-Requirements {
    Write-Step "Checking requirements..."
    
    # Check AWS CLI
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        Write-Error "AWS CLI not found. Install from: https://aws.amazon.com/cli/"
        Write-Host "After installation, run: aws configure"
        exit 1
    }
    
    # Check Terraform
    if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
        Write-Error "Terraform not found. Install from: https://terraform.io/downloads"
        exit 1
    }
    
    # Check SSH key
    if (-not (Test-Path "~/.ssh/id_rsa.pub")) {
        Write-Warn "SSH key not found. Generating new key pair..."
        ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/id_rsa" -N ""
    }
    
    Write-Success "Requirements check passed"
}

function New-TerraformConfig {
    Write-Step "Creating Terraform configuration..."
    
    New-Item -ItemType Directory -Path terraform -Force | Out-Null
    
    # Main Terraform configuration
    @"
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "$REGION"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "$INSTANCE_TYPE"
}

variable "key_name" {
  description = "AWS key pair name"
  type        = string
  default     = "$KEY_NAME"
}

# Get latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Create VPC
resource "aws_vpc" "homelab" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "homelab-vpc"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "homelab" {
  vpc_id = aws_vpc.homelab.id

  tags = {
    Name = "homelab-igw"
  }
}

# Create subnet
resource "aws_subnet" "homelab" {
  vpc_id                  = aws_vpc.homelab.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "homelab-subnet"
  }
}

# Get availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Create route table
resource "aws_route_table" "homelab" {
  vpc_id = aws_vpc.homelab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.homelab.id
  }

  tags = {
    Name = "homelab-rt"
  }
}

# Associate route table
resource "aws_route_table_association" "homelab" {
  subnet_id      = aws_subnet.homelab.id
  route_table_id = aws_route_table.homelab.id
}

# Security group for homelab services
resource "aws_security_group" "homelab" {
  name_prefix = "homelab-"
  vpc_id      = aws_vpc.homelab.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP/HTTPS
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Homelab services
  ingress {
    from_port   = 8000
    to_port     = 9999
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 19999
    to_port     = 19999
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "homelab-sg"
  }
}

# Create key pair
resource "aws_key_pair" "homelab" {
  key_name   = var.key_name
  public_key = file("~/.ssh/id_rsa.pub")
}

# Create EC2 instance
resource "aws_instance" "homelab" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name              = aws_key_pair.homelab.key_name
  vpc_security_group_ids = [aws_security_group.homelab.id]
  subnet_id             = aws_subnet.homelab.id

  root_block_device {
    volume_type = "gp3"
    volume_size = 40
    encrypted   = true
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y docker.io docker-compose-plugin
              systemctl start docker
              systemctl enable docker
              usermod -aG docker ubuntu
              
              # Create directories
              mkdir -p /home/ubuntu/homelab/{media/{movies,tv,music},downloads/{complete,incomplete}}
              chown -R ubuntu:ubuntu /home/ubuntu/homelab
              
              # Download homelab configuration
              su - ubuntu -c "curl -fsSL https://raw.githubusercontent.com/linuxserver/docker-jellyfin/master/README.md > /dev/null"
              EOF

  tags = {
    Name = "homelab-testing"
  }
}

# Outputs
output "instance_ip" {
  description = "Public IP of the homelab instance"
  value       = aws_instance.homelab.public_ip
}

output "instance_dns" {
  description = "Public DNS of the homelab instance"
  value       = aws_instance.homelab.public_dns
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@`${aws_instance.homelab.public_ip}"
}
"@ | Out-File -FilePath terraform/main.tf -Encoding UTF8

    Write-Success "Terraform configuration created"
}

function Deploy-Infrastructure {
    Write-Step "Deploying AWS infrastructure..."
    
    Push-Location terraform
    try {
        # Initialize Terraform
        Write-Log "Initializing Terraform..."
        terraform init
        
        # Plan deployment
        Write-Log "Planning deployment..."
        terraform plan
        
        # Apply deployment
        Write-Log "Creating infrastructure (this may take a few minutes)..."
        terraform apply -auto-approve
        
        # Get outputs
        $public_ip = terraform output -raw instance_ip
        $public_dns = terraform output -raw instance_dns
        
        Write-Success "Infrastructure deployed successfully!"
        Write-Host "Public IP: $public_ip" -ForegroundColor Green
        Write-Host "Public DNS: $public_dns" -ForegroundColor Green
        
        # Wait for instance to be ready
        Write-Log "Waiting for instance to be ready..."
        do {
            Start-Sleep 10
            $status = aws ec2 describe-instance-status --instance-ids (terraform output -raw instance_id) --query 'InstanceStatuses[0].InstanceStatus.Status' --output text 2>$null
            Write-Host "." -NoNewline
        } while ($status -ne "ok")
        Write-Host ""
        
        Write-Success "Instance is ready!"
        return $public_ip
        
    } finally {
        Pop-Location
    }
}

function Deploy-Homelab {
    param([string]$PublicIP)
    
    Write-Step "Deploying homelab services..."
    
    # Create deployment script
    $deployScript = @"
#!/bin/bash
cd /home/ubuntu/homelab

# Create Docker Compose file
cat > docker-compose.yml << 'COMPOSE_EOF'
version: '3.8'

services:
  jellyfin:
    image: lscr.io/linuxserver/jellyfin:latest
    container_name: jellyfin
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - ./config/jellyfin:/config
      - ./media:/media:ro
    ports:
      - "8096:8096"
    restart: unless-stopped

  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - ./config/sonarr:/config
      - ./media/tv:/tv
      - ./downloads:/downloads
    ports:
      - "8989:8989"
    restart: unless-stopped

  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - ./config/radarr:/config
      - ./media/movies:/movies
      - ./downloads:/downloads
    ports:
      - "7878:7878"
    restart: unless-stopped

  nginx-proxy-manager:
    image: jc21/nginx-proxy-manager:latest
    container_name: npm
    ports:
      - "80:80"
      - "443:443"
      - "81:81"
    volumes:
      - ./config/npm/data:/data
      - ./config/npm/letsencrypt:/etc/letsencrypt
    restart: unless-stopped

  netdata:
    image: netdata/netdata:latest
    container_name: netdata
    hostname: homelab-cloud
    ports:
      - "19999:19999"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    cap_add:
      - SYS_PTRACE
    security_opt:
      - apparmor:unconfined
    restart: unless-stopped
COMPOSE_EOF

# Create sample content
mkdir -p media/movies media/tv downloads
echo "Sample movie content" > media/movies/sample.txt
echo "Sample TV content" > media/tv/sample.txt

# Start services
docker compose up -d

echo "Homelab deployed successfully!"
echo "Services starting up - please wait a few minutes"
"@

    # Transfer and execute script
    $deployScript | ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$PublicIP "cat > deploy.sh && chmod +x deploy.sh && ./deploy.sh"
    
    Write-Success "Homelab services deployed!"
}

function Show-AccessInfo {
    param([string]$PublicIP)
    
    Write-Step "Cloud Homelab Access Information"
    Write-Host ""
    Write-Host "🌩️ Cloud Instance Details:" -ForegroundColor Cyan
    Write-Host "  • Provider: AWS EC2" -ForegroundColor White
    Write-Host "  • Instance Type: $INSTANCE_TYPE" -ForegroundColor White
    Write-Host "  • Region: $REGION" -ForegroundColor White
    Write-Host "  • Public IP: $PublicIP" -ForegroundColor Green
    Write-Host ""
    Write-Host "🌐 Service Access URLs:" -ForegroundColor Cyan
    Write-Host "  • Jellyfin Media Server:     http://$PublicIP`:8096" -ForegroundColor White
    Write-Host "  • Sonarr (TV Shows):         http://$PublicIP`:8989" -ForegroundColor White
    Write-Host "  • Radarr (Movies):           http://$PublicIP`:7878" -ForegroundColor White
    Write-Host "  • Nginx Proxy Manager:       http://$PublicIP`:81" -ForegroundColor White
    Write-Host "  • Netdata Monitoring:        http://$PublicIP`:19999" -ForegroundColor White
    Write-Host ""
    Write-Host "🔧 Management Commands:" -ForegroundColor Cyan
    Write-Host "  • SSH Access: ssh -i ~/.ssh/id_rsa ubuntu@$PublicIP" -ForegroundColor White
    Write-Host "  • View Logs: ssh ubuntu@$PublicIP 'cd homelab && docker compose logs'" -ForegroundColor White
    Write-Host "  • Restart Services: ssh ubuntu@$PublicIP 'cd homelab && docker compose restart'" -ForegroundColor White
    Write-Host ""
    Write-Host "💰 Cost Information:" -ForegroundColor Cyan
    Write-Host "  • EC2 t3.medium: approximately `$0.04/hour" -ForegroundColor Yellow
    Write-Host "  • Storage (40GB): approximately `$4/month" -ForegroundColor Yellow
    Write-Host "  • Data transfer: `$0.09/GB outbound (first 1GB free)" -ForegroundColor Yellow
    Write-Host "  • REMEMBER TO DESTROY RESOURCES WHEN DONE TESTING!" -ForegroundColor Red
}

function Remove-Infrastructure {
    Write-Step "Destroying AWS infrastructure..."
    
    Write-Warn "This will permanently delete all cloud resources and data."
    $confirm = Read-Host "Are you sure? Type 'yes' to confirm"
    
    if ($confirm -eq "yes") {
        Push-Location terraform
        try {
            terraform destroy -auto-approve
            Write-Success "Infrastructure destroyed"
        } finally {
            Pop-Location
        }
    } else {
        Write-Log "Destruction cancelled"
    }
}

function Show-Status {
    Push-Location terraform
    try {
        $public_ip = terraform output -raw instance_ip 2>$null
        if ($public_ip) {
            Write-Success "Infrastructure is deployed"
            Write-Host "Public IP: $public_ip" -ForegroundColor Green
            
            # Check if services are running
            try {
                $response = Invoke-WebRequest -Uri "http://$public_ip`:19999" -TimeoutSec 5 -UseBasicParsing
                Write-Success "Services are running"
            } catch {
                Write-Warn "Services may still be starting up"
            }
        } else {
            Write-Warn "No infrastructure found"
        }
    } catch {
        Write-Warn "No infrastructure found or Terraform not initialized"
    } finally {
        Pop-Location
    }
}

# Main function
function Main {
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "🌩️ HOMELAB CLOUD DEPLOYMENT (AWS)" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "Platform: AWS EC2 with Ubuntu + Docker" -ForegroundColor White
    Write-Host "Instance: $INSTANCE_TYPE in $REGION" -ForegroundColor White
    Write-Host "Timestamp: $(Get-Date)" -ForegroundColor White
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    Test-Requirements
    New-TerraformConfig
    $public_ip = Deploy-Infrastructure
    Deploy-Homelab -PublicIP $public_ip
    Show-AccessInfo -PublicIP $public_ip
    
    Write-Success "Cloud homelab deployment completed!"
    Write-Host ""
    Write-Host "🎉 Your homelab is now running in the cloud!" -ForegroundColor Green
    Write-Host "💡 Don't forget to destroy resources when done testing to avoid charges!" -ForegroundColor Yellow
}

# Handle command line arguments
switch ($args[0]) {
    "deploy" { Main }
    "destroy" { Remove-Infrastructure }
    "status" { Show-Status }
    "info" { 
        Push-Location terraform
        try {
            $public_ip = terraform output -raw instance_ip 2>$null
            if ($public_ip) { Show-AccessInfo -PublicIP $public_ip }
            else { Write-Warn "No infrastructure found" }
        } finally { Pop-Location }
    }
    default {
        Write-Host "Usage: .\deploy_cloud.ps1 [deploy|destroy|status|info]" -ForegroundColor Yellow
        Write-Host "  deploy  - Deploy infrastructure and homelab services" -ForegroundColor White
        Write-Host "  destroy - Destroy all cloud resources" -ForegroundColor White
        Write-Host "  status  - Check deployment status" -ForegroundColor White
        Write-Host "  info    - Show access information" -ForegroundColor White
        Write-Host ""
        Write-Host "Prerequisites:" -ForegroundColor Cyan
        Write-Host "  • AWS CLI installed and configured (aws configure)" -ForegroundColor White
        Write-Host "  • Terraform installed" -ForegroundColor White
        Write-Host "  • SSH key pair in ~/.ssh/id_rsa" -ForegroundColor White
        exit 1
    }
}