#!/bin/bash
# =====================================================
# 📚 Homelab Documentation Archiver
# =====================================================
# Archives documentation with encryption and backup
# Maintainer: J35867U
# Email: mrnash404@protonmail.com
# Last Updated: 2025-10-11
# =====================================================

set -e

# Source environment variables
if [ -f "/usr/local/etc/homelab/config.env" ]; then
    source /usr/local/etc/homelab/config.env
elif [ -f "$HOME/homelab-deployment/deployment/.env" ]; then
    source $HOME/homelab-deployment/deployment/.env
fi

# Default values
SERVER_NAME=${SERVER_NAME:-"homelab"}
ADMIN_EMAIL=${ADMIN_EMAIL:-"mrnash404@protonmail.com"}
ARCHIVE_DIR="/data/backups/docs"
SOURCE_DIR="$HOME/homelab-deployment"
LOGFILE="/var/log/homelab/docs_archive.log"
DATE=$(date '+%Y-%m-%d_%H-%M-%S')
ARCHIVE_NAME="homelab-docs-${DATE}"

# Create directories
mkdir -p "$ARCHIVE_DIR"
mkdir -p "$(dirname "$LOGFILE")"

# Function to log messages
log_message() {
    echo "[$DATE] $1" | tee -a "$LOGFILE"
}

log_message "📚 Starting documentation archive for $SERVER_NAME"

# Create temporary directory for archive
TEMP_DIR=$(mktemp -d)
ARCHIVE_PATH="$TEMP_DIR/$ARCHIVE_NAME"

log_message "📁 Creating archive directory at $ARCHIVE_PATH"
mkdir -p "$ARCHIVE_PATH"

# Copy documentation files
log_message "📄 Copying documentation files..."

# Copy main documentation
if [ -d "$SOURCE_DIR/docs" ]; then
    cp -r "$SOURCE_DIR/docs" "$ARCHIVE_PATH/"
    log_message "✅ Copied docs directory"
fi

# Copy deployment configurations (sanitized)
if [ -d "$SOURCE_DIR/deployment" ]; then
    mkdir -p "$ARCHIVE_PATH/deployment"
    
    # Copy safe files
    for file in docker-compose.yml .env.example wg0.conf.example README_START_HERE.md TROUBLESHOOTING.md DEPLOYMENT_CHECKLIST.md; do
        if [ -f "$SOURCE_DIR/deployment/$file" ]; then
            cp "$SOURCE_DIR/deployment/$file" "$ARCHIVE_PATH/deployment/"
            log_message "✅ Copied deployment/$file"
        fi
    done
fi

# Copy scripts
if [ -d "$SOURCE_DIR/scripts" ]; then
    cp -r "$SOURCE_DIR/scripts" "$ARCHIVE_PATH/"
    log_message "✅ Copied scripts directory"
fi

# Copy root-level files
for file in README.md changelog.md homelab.sh deploy_homelab.sh teardown_homelab.sh reset_homelab.sh status_homelab.sh; do
    if [ -f "$SOURCE_DIR/$file" ]; then
        cp "$SOURCE_DIR/$file" "$ARCHIVE_PATH/"
        log_message "✅ Copied $file"
    fi
done

# Create archive manifest
log_message "📋 Creating archive manifest..."
MANIFEST_FILE="$ARCHIVE_PATH/ARCHIVE_MANIFEST.txt"

cat > "$MANIFEST_FILE" << EOF
# Homelab Documentation Archive
# Generated: $(date)
# Server: $SERVER_NAME
# Maintainer: $ADMIN_EMAIL

## Archive Contents
$(find "$ARCHIVE_PATH" -type f | sed "s|$ARCHIVE_PATH/||" | sort)

## System Information
- Hostname: $(hostname)
- OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")
- Kernel: $(uname -r)
- Docker Version: $(docker --version 2>/dev/null || echo "Not available")
- Archive Date: $(date)
- Archive Size: $(du -sh "$ARCHIVE_PATH" | cut -f1)

## Git Information (if available)
$(cd "$SOURCE_DIR" && git log --oneline -5 2>/dev/null || echo "No git history available")

## Container Status at Archive Time
$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null || echo "Docker not available")
EOF

log_message "✅ Archive manifest created"

# Create compressed archive
log_message "🗜️ Creating compressed archive..."
cd "$TEMP_DIR"
ARCHIVE_FILE="$ARCHIVE_DIR/${ARCHIVE_NAME}.tar.gz"

if tar -czf "$ARCHIVE_FILE" "$ARCHIVE_NAME"; then
    log_message "✅ Compressed archive created: $ARCHIVE_FILE"
    ARCHIVE_SIZE=$(du -sh "$ARCHIVE_FILE" | cut -f1)
    log_message "📊 Archive size: $ARCHIVE_SIZE"
else
    log_message "❌ Failed to create compressed archive"
    exit 1
fi

# Encrypt archive if GPG is available
if command -v gpg >/dev/null 2>&1; then
    log_message "🔒 Encrypting archive with GPG..."
    
    # Use admin email as recipient if GPG key exists
    if gpg --list-keys "$ADMIN_EMAIL" >/dev/null 2>&1; then
        ENCRYPTED_FILE="${ARCHIVE_FILE}.gpg"
        if gpg --trust-model always --encrypt --recipient "$ADMIN_EMAIL" --output "$ENCRYPTED_FILE" "$ARCHIVE_FILE"; then
            log_message "✅ Archive encrypted: $ENCRYPTED_FILE"
            # Keep both encrypted and unencrypted for local use
        else
            log_message "⚠️ Encryption failed, keeping unencrypted archive"
        fi
    else
        log_message "⚠️ No GPG key found for $ADMIN_EMAIL, skipping encryption"
    fi
else
    log_message "ℹ️ GPG not available, archive not encrypted"
fi

# Cleanup old archives (keep last 30 days)
log_message "🧹 Cleaning up old archives..."
OLD_ARCHIVES=$(find "$ARCHIVE_DIR" -name "homelab-docs-*.tar.gz*" -mtime +30 2>/dev/null || true)
if [ -n "$OLD_ARCHIVES" ]; then
    echo "$OLD_ARCHIVES" | xargs rm -f
    OLD_COUNT=$(echo "$OLD_ARCHIVES" | wc -l)
    log_message "🗑️ Removed $OLD_COUNT old archives"
else
    log_message "ℹ️ No old archives to remove"
fi

# Create symlink to latest
log_message "🔗 Creating symlink to latest archive..."
cd "$ARCHIVE_DIR"
ln -sf "$(basename "$ARCHIVE_FILE")" "homelab-docs-latest.tar.gz"

if [ -f "${ARCHIVE_FILE}.gpg" ]; then
    ln -sf "$(basename "${ARCHIVE_FILE}.gpg")" "homelab-docs-latest.tar.gz.gpg"
fi

# Generate archive summary
TOTAL_FILES=$(find "$ARCHIVE_PATH" -type f | wc -l)
TOTAL_DIRS=$(find "$ARCHIVE_PATH" -type d | wc -l)

# Cleanup temporary directory
rm -rf "$TEMP_DIR"

log_message "📊 Archive summary:"
log_message "   - Files archived: $TOTAL_FILES"
log_message "   - Directories: $TOTAL_DIRS"
log_message "   - Archive size: $ARCHIVE_SIZE"
log_message "   - Location: $ARCHIVE_FILE"

# Send notification if configured
if [ -n "$NTFY_SERVER" ] && [ -n "$NTFY_TOPIC_SUMMARY" ]; then
    NOTIFICATION="📚 Documentation Archive Complete

✅ Successfully archived Homelab documentation

📊 Archive Details:
• Files: $TOTAL_FILES
• Size: $ARCHIVE_SIZE
• Location: $ARCHIVE_DIR
• Encrypted: $([ -f "${ARCHIVE_FILE}.gpg" ] && echo "Yes" || echo "No")

🗓️ Archive Date: $(date +'%Y-%m-%d %H:%M')
📅 Next Archive: $(date -d '+1 day' +'%Y-%m-%d')"

    curl -s \
        -H "Title: [$SERVER_NAME] Documentation Archived" \
        -H "Priority: default" \
        -H "Tags: books,backup" \
        -d "$NOTIFICATION" \
        "$NTFY_SERVER/$NTFY_TOPIC_SUMMARY" || true
fi

log_message "✅ Documentation archive completed successfully"
echo "Documentation archive completed: $ARCHIVE_FILE"