#!/bin/bash

# Script to move legacy files to archive directory
echo "🗂️ Moving legacy files to archive..."

# Legacy documentation files
LEGACY_DOCS=(
    "COMPREHENSIVE_PREDEPLOYMENT_CHECKLIST.md"
    "CONTAINER_CLEANUP_SUMMARY.md" 
    "CREDENTIALS_CONFIGURED.md"
    "DEPLOYMENT_FILES_EXPORT.md"
    "DEPLOYMENT_ISSUES_AND_FIXES.md"
    "DEPLOYMENT_READY.md"
    "DEPLOYMENT_READINESS_REPORT.md"
    "DEPLOYMENT_VALIDATION_REPORT.md"
    "DUAL_SUBNET_DEPLOYMENT.md"
    "FINAL_DEPLOYMENT_ASSESSMENT.md"
    "FINAL_STATUS.md"
    "HARDWARE_ARCHITECTURE.md"
    "HOMELAB_ANALYSIS_RESPONSE.md"
    "HOMELAB_QUICK_EXPORT.md"
    "HOMELAB_REPOSITORY_EXPORT.md"
    "LXC_CONFIGURATION_GUIDE.md"
    "MANUAL_DEPLOYMENT_GUIDE.md"
    "NETWORK_ADDRESSING_SCHEME.md"
    "NTFY_STANDARDIZATION.md"
    "PORT_TESTING_GUIDE.md"
    "PROXMOX_DEPLOYMENT_GUIDE.md"
    "PROXMOX_DEPLOYMENT_STATUS.md"
    "PROXMOX_LXC_DEPLOYMENT_FIXES.md"
    "QUICK_DEPLOYMENT_GUIDE.md"
    "QUICK_TESTING_GUIDE.md"
    "REPOSITORY_ANALYSIS.md"
    "REPOSITORY_ENHANCEMENT_SUMMARY.md"
    "SECURE_DEPLOYMENT_READY.md"
    "STAGED_DEPLOYMENT_GUIDE.md"
    "TAILSCALE_DEPLOYMENT_READY.md"
    "TESTING_ENVIRONMENTS.md"
    "TESTING_GUIDE.md"
    "VSCODE_ISSUES_FIXED.md"
)

# Legacy script files
LEGACY_SCRIPTS=(
    "cleanup_homelab_complete.sh"
    "deploy_cloud.ps1"
    "deploy_docker_testing.sh"
    "deploy_lxc_stage1_core.sh"
    "deploy_lxc_stage1_no_pihole.sh"
    "deploy_lxc_stage2_support.sh"
    "deploy_secure.sh"
    "deploy_stage1_core.sh"
    "deploy_stage2_servarr.sh"
    "deploy_stage3_frontend.sh"
    "deploy_virtualbox.sh"
    "enhance_docker_compose.sh"
    "fix_critical_deployment.sh"
    "fix_deployment_conflicts.sh"
    "fix_docker_service.sh"
    "fix_kernel_compatibility.sh"
    "fix_lxc_automation.sh"
    "fix_markdown_linting.sh"
    "final_deployment_assessment.sh"
    "optimize_proxmox_single_node.sh"
    "proxmox_deployment_preflight.sh"
    "proxmox_quick_check.sh"
    "validate_config.sh"
    "validate_deployment_readiness.sh"
    "validate_env.sh"
)

# Move legacy documentation
echo "Moving legacy documentation files..."
for file in "${LEGACY_DOCS[@]}"; do
    if [ -f "$file" ]; then
        mv "$file" "archive/legacy-docs/"
        echo "✅ Moved $file"
    fi
done

# Move legacy scripts  
echo "Moving legacy script files..."
for file in "${LEGACY_SCRIPTS[@]}"; do
    if [ -f "$file" ]; then
        mv "$file" "archive/legacy-scripts/"
        echo "✅ Moved $file"
    fi
done

# Create archive README
cat > archive/README.md << 'EOF'
# Archive Directory

This directory contains legacy files that were part of the previous homelab structure but are no longer needed for the current simplified approach.

## Contents

- `legacy-docs/` - Outdated documentation files from previous iterations
- `legacy-scripts/` - Old deployment and utility scripts superseded by the new `setup/` directory

## Why These Files Were Archived

The homelab repository was reorganized on October 16, 2025 to provide a simpler, more maintainable structure focused on:

- Manual control over service deployment
- Clear separation of service groups (core, downloads, media)
- Simple deployment scripts
- Streamlined documentation

These archived files represented an overly complex automation approach that was difficult to maintain and understand.

## If You Need These Files

These files are preserved in case any specific functionality is needed. However, the new structure in `containers/` and `setup/` is recommended for all deployments.
EOF

echo "✅ Archive setup complete!"
echo "📁 Legacy files moved to archive/ directory"