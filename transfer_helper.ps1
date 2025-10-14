# =====================================================
# 🚀 PowerShell Transfer Script for Proxmox Setup
# =====================================================
# Run this in PowerShell to transfer the setup script

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "🚀 HOMELAB PROXMOX TRANSFER UTILITY" -ForegroundColor Cyan  
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$ProxmoxIP = "192.168.1.50"
$SetupScript = "proxmox_auto_setup.sh"

Write-Host "📋 TRANSFER OPTIONS:" -ForegroundColor Yellow
Write-Host ""
Write-Host "OPTION 1 - Copy and Paste Method (Recommended):" -ForegroundColor Green
Write-Host "1. Open the file: $SetupScript"
Write-Host "2. Copy all contents (Ctrl+A, Ctrl+C)"
Write-Host "3. SSH to Proxmox: ssh root@$ProxmoxIP"
Write-Host "4. Create file: nano /root/proxmox_auto_setup.sh"
Write-Host "5. Paste contents and save (Ctrl+X, Y, Enter)"
Write-Host "6. Make executable: chmod +x /root/proxmox_auto_setup.sh"
Write-Host "7. Run setup: /root/proxmox_auto_setup.sh"
Write-Host ""

Write-Host "OPTION 2 - SCP Transfer (if available):" -ForegroundColor Green
Write-Host "scp $SetupScript root@${ProxmoxIP}:/root/proxmox_auto_setup.sh"
Write-Host ""

Write-Host "OPTION 3 - WinSCP/FileZilla GUI:" -ForegroundColor Green
Write-Host "1. Open WinSCP or FileZilla"
Write-Host "2. Connect to: $ProxmoxIP (username: root)"
Write-Host "3. Upload: $SetupScript to /root/"
Write-Host "4. SSH and make executable: chmod +x /root/proxmox_auto_setup.sh"
Write-Host ""

Write-Host "=========================================="
Write-Host "📄 File to transfer: $SetupScript" -ForegroundColor Cyan
Write-Host "🎯 Target server: $ProxmoxIP" -ForegroundColor Cyan  
Write-Host "📁 Target location: /root/" -ForegroundColor Cyan
Write-Host "=========================================="
Write-Host ""

# Test connectivity
Write-Host "🔍 Testing connectivity to Proxmox server..." -ForegroundColor Blue
try {
    $pingResult = Test-Connection -ComputerName $ProxmoxIP -Count 1 -Quiet
    if ($pingResult) {
        Write-Host "✅ Proxmox server is reachable" -ForegroundColor Green
    } else {
        Write-Host "❌ Cannot reach Proxmox server" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Network test failed" -ForegroundColor Red
}

Write-Host ""
Write-Host "🎯 AFTER TRANSFER, RUN ON PROXMOX:" -ForegroundColor Yellow
Write-Host "ssh root@$ProxmoxIP" -ForegroundColor White
Write-Host "chmod +x /root/proxmox_auto_setup.sh" -ForegroundColor White  
Write-Host "/root/proxmox_auto_setup.sh" -ForegroundColor White
Write-Host ""

Write-Host "📖 The auto-setup script will:" -ForegroundColor Cyan
Write-Host "  • Create all deployment scripts" -ForegroundColor White
Write-Host "  • Set up ZFS mirror (optional)" -ForegroundColor White
Write-Host "  • Deploy LXC containers" -ForegroundColor White
Write-Host "  • Install Docker stack" -ForegroundColor White  
Write-Host "  • Validate deployment" -ForegroundColor White
Write-Host ""

# Check if file exists
if (Test-Path $SetupScript) {
    Write-Host "✅ Setup script ready: $SetupScript" -ForegroundColor Green
    Write-Host "📝 File size: $((Get-Item $SetupScript).Length) bytes" -ForegroundColor Gray
} else {
    Write-Host "❌ Setup script not found: $SetupScript" -ForegroundColor Red
    Write-Host "Please ensure the file exists in the current directory." -ForegroundColor Red
}

Write-Host ""
Write-Host "=========================================="