#!/bin/bash
# =====================================================
# 🔄 Homelab — Reset Script
# =====================================================
# Maintainer: J35867U
# Email: mrnash404@protonmail.com
# Last Updated: 2025-10-11
# =====================================================

set -e

echo "Resetting Homelab environment..."

echo "--> Running teardown script..."
./teardown_homelab.sh

echo "--> Waiting 5 seconds for cleanup to complete..."
sleep 5

echo "--> Running deployment script..."
./deploy_homelab.sh

echo "✅ Reset complete."