#!/bin/bash
# =====================================================
# 🎮 Game Server Backup System
# =====================================================
# Automated backup for ROMs, saves, and configurations
# Maintainer: J35867U
# Email: mrnash404@protonmail.com
# Last Updated: 2025-10-14
# =====================================================

set -e

# Configuration
SERVER_NAME="game-server"
ADMIN_EMAIL="mrnash404@protonmail.com"
BACKUP_BASE_DIR="/data/backups/game-server"
LOGFILE="/var/log/game-server/backup.log"
DATE=$(date '+%Y-%m-%d_%H-%M-%S')
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# NTFY Configuration (separate from homelab)
NTFY_SERVER=${NTFY_SERVER:-"https://ntfy.sh"}
NTFY_TOPIC_GAMESERVER=${NTFY_TOPIC_GAMESERVER:-"game-server-standalone"}

# Retention policies (days)
RETAIN_DAILY=7
RETAIN_WEEKLY=4
RETAIN_MONTHLY=3

# GPG Configuration
GPG_RECIPIENT=${GPG_RECIPIENT:-"$ADMIN_EMAIL"}
ENCRYPT_BACKUPS=${ENCRYPT_BACKUPS:-"true"}

# Directories to backup
ROM_DIR="/opt/coinops/roms"
SAVES_DIR="/opt/coinops/saves"
CONFIG_DIR="/home/gameuser/.config"
SUNSHINE_CONFIG="/etc/sunshine"
WEB_CONFIG="/home/gameuser/coinops-web"

# Create directories
mkdir -p "$BACKUP_BASE_DIR"/{daily,weekly,monthly}
mkdir -p "$(dirname "$LOGFILE")"

# Function to log messages
log_message() {
    echo "[$TIMESTAMP] $1" | tee -a "$LOGFILE"
}

# Function to send NTFY notifications
send_ntfy() {
    local title="$1"
    local message="$2"
    local priority="${3:-default}"
    local tags="${4:-gaming,backup,storage}"
    
    if [ -n "$NTFY_SERVER" ] && [ -n "$NTFY_TOPIC_GAMESERVER" ]; then
        curl -s \
            -H "Title: [Game Server] $title" \
            -H "Priority: $priority" \
            -H "Tags: $tags" \
            -d "$message" \
            "$NTFY_SERVER/$NTFY_TOPIC_GAMESERVER" >/dev/null 2>&1 || true
    fi
}

# Function to calculate directory size
get_dir_size() {
    local dir="$1"
    if [ -d "$dir" ]; then
        du -sh "$dir" 2>/dev/null | cut -f1
    else
        echo "0B"
    fi
}

# Function to count files in directory
count_files() {
    local dir="$1"
    if [ -d "$dir" ]; then
        find "$dir" -type f 2>/dev/null | wc -l
    else
        echo "0"
    fi
}

# Function to create backup archive
create_backup() {
    local backup_type="$1"
    local backup_name="$2"
    local temp_dir=$(mktemp -d)
    local backup_dir="$temp_dir/$backup_name"
    local final_path="$BACKUP_BASE_DIR/$backup_type/${backup_name}.tar.gz"
    
    log_message "🎮 Creating $backup_type backup: $backup_name"
    
    mkdir -p "$backup_dir"
    
    # Create backup manifest
    cat > "$backup_dir/BACKUP_MANIFEST.txt" << EOF
# Game Server Backup Manifest
# Generated: $(date)
# Backup Type: $backup_type
# Server: $SERVER_NAME
# Maintainer: $ADMIN_EMAIL

## Backup Information
Backup Name: $backup_name
Backup Date: $(date)
Server Hostname: $(hostname)
Server OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")
Kernel Version: $(uname -r)

## System Status at Backup Time
Uptime: $(uptime -p)
Load Average: $(uptime | awk -F'load average:' '{print $2}')
Memory Usage: $(free -h | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100}')
Disk Usage: $(df / | tail -1 | awk '{print $5}')

## Services Status
EOF
    
    # Add service status to manifest
    for service in sunshine coinops-web x11-server openbox; do
        if systemctl list-units --all | grep -q "$service"; then
            STATUS=$(systemctl is-active "$service" 2>/dev/null || echo "unknown")
            echo "$service: $STATUS" >> "$backup_dir/BACKUP_MANIFEST.txt"
        fi
    done
    
    echo "" >> "$backup_dir/BACKUP_MANIFEST.txt"
    echo "## Backup Contents" >> "$backup_dir/BACKUP_MANIFEST.txt"
    
    # Backup ROM files
    if [ -d "$ROM_DIR" ]; then
        log_message "📦 Backing up ROM collection..."
        ROM_SIZE=$(get_dir_size "$ROM_DIR")
        ROM_COUNT=$(count_files "$ROM_DIR")
        
        mkdir -p "$backup_dir/roms"
        if tar -czf "$backup_dir/roms/roms_collection.tar.gz" -C "$(dirname "$ROM_DIR")" "$(basename "$ROM_DIR")" 2>/dev/null; then
            log_message "✅ ROM backup completed: $ROM_SIZE ($ROM_COUNT files)"
            echo "ROMs: $ROM_SIZE ($ROM_COUNT files) - ✅ Included" >> "$backup_dir/BACKUP_MANIFEST.txt"
        else
            log_message "⚠️ ROM backup failed"
            echo "ROMs: Backup failed" >> "$backup_dir/BACKUP_MANIFEST.txt"
        fi
    else
        log_message "⚠️ ROM directory not found: $ROM_DIR"
        echo "ROMs: Directory not found" >> "$backup_dir/BACKUP_MANIFEST.txt"
    fi
    
    # Backup save games
    if [ -d "$SAVES_DIR" ]; then
        log_message "💾 Backing up save games..."
        SAVES_SIZE=$(get_dir_size "$SAVES_DIR")
        SAVES_COUNT=$(count_files "$SAVES_DIR")
        
        mkdir -p "$backup_dir/saves"
        if tar -czf "$backup_dir/saves/save_games.tar.gz" -C "$(dirname "$SAVES_DIR")" "$(basename "$SAVES_DIR")" 2>/dev/null; then
            log_message "✅ Save games backup completed: $SAVES_SIZE ($SAVES_COUNT files)"
            echo "Save Games: $SAVES_SIZE ($SAVES_COUNT files) - ✅ Included" >> "$backup_dir/BACKUP_MANIFEST.txt"
        else
            log_message "⚠️ Save games backup failed"
            echo "Save Games: Backup failed" >> "$backup_dir/BACKUP_MANIFEST.txt"
        fi
    else
        log_message "⚠️ Saves directory not found: $SAVES_DIR"
        echo "Save Games: Directory not found" >> "$backup_dir/BACKUP_MANIFEST.txt"
    fi
    
    # Backup user configurations
    if [ -d "$CONFIG_DIR" ]; then
        log_message "⚙️ Backing up user configurations..."
        CONFIG_SIZE=$(get_dir_size "$CONFIG_DIR")
        CONFIG_COUNT=$(count_files "$CONFIG_DIR")
        
        mkdir -p "$backup_dir/configs"
        if tar -czf "$backup_dir/configs/user_configs.tar.gz" -C "$(dirname "$CONFIG_DIR")" "$(basename "$CONFIG_DIR")" 2>/dev/null; then
            log_message "✅ User configs backup completed: $CONFIG_SIZE ($CONFIG_COUNT files)"
            echo "User Configs: $CONFIG_SIZE ($CONFIG_COUNT files) - ✅ Included" >> "$backup_dir/BACKUP_MANIFEST.txt"
        else
            log_message "⚠️ User configs backup failed"
            echo "User Configs: Backup failed" >> "$backup_dir/BACKUP_MANIFEST.txt"
        fi
    else
        log_message "ℹ️ User config directory not found: $CONFIG_DIR"
        echo "User Configs: Directory not found" >> "$backup_dir/BACKUP_MANIFEST.txt"
    fi
    
    # Backup Sunshine configuration
    if [ -d "$SUNSHINE_CONFIG" ]; then
        log_message "☀️ Backing up Sunshine configuration..."
        mkdir -p "$backup_dir/sunshine"
        if tar -czf "$backup_dir/sunshine/sunshine_config.tar.gz" -C "$(dirname "$SUNSHINE_CONFIG")" "$(basename "$SUNSHINE_CONFIG")" 2>/dev/null; then
            log_message "✅ Sunshine config backup completed"
            echo "Sunshine Config: ✅ Included" >> "$backup_dir/BACKUP_MANIFEST.txt"
        else
            log_message "⚠️ Sunshine config backup failed"
            echo "Sunshine Config: Backup failed" >> "$backup_dir/BACKUP_MANIFEST.txt"
        fi
    else
        log_message "ℹ️ Sunshine config directory not found: $SUNSHINE_CONFIG"
        echo "Sunshine Config: Directory not found" >> "$backup_dir/BACKUP_MANIFEST.txt"
    fi
    
    # Backup web interface configuration
    if [ -d "$WEB_CONFIG" ]; then
        log_message "🌐 Backing up web interface configuration..."
        mkdir -p "$backup_dir/web-interface"
        if tar -czf "$backup_dir/web-interface/web_config.tar.gz" -C "$(dirname "$WEB_CONFIG")" "$(basename "$WEB_CONFIG")" 2>/dev/null; then
            log_message "✅ Web interface backup completed"
            echo "Web Interface: ✅ Included" >> "$backup_dir/BACKUP_MANIFEST.txt"
        else
            log_message "⚠️ Web interface backup failed"
            echo "Web Interface: Backup failed" >> "$backup_dir/BACKUP_MANIFEST.txt"
        fi
    else
        log_message "ℹ️ Web interface directory not found: $WEB_CONFIG"
        echo "Web Interface: Directory not found" >> "$backup_dir/BACKUP_MANIFEST.txt"
    fi
    
    # Backup system information
    log_message "🖥️ Collecting system information..."
    mkdir -p "$backup_dir/system-info"
    
    # Hardware info
    lscpu > "$backup_dir/system-info/cpu_info.txt" 2>/dev/null || true
    free -h > "$backup_dir/system-info/memory_info.txt" 2>/dev/null || true
    df -h > "$backup_dir/system-info/disk_usage.txt" 2>/dev/null || true
    lspci > "$backup_dir/system-info/pci_devices.txt" 2>/dev/null || true
    
    # Graphics info
    lspci | grep -i "vga\|display\|graphics" > "$backup_dir/system-info/graphics_info.txt" 2>/dev/null || true
    vainfo > "$backup_dir/system-info/vaapi_info.txt" 2>/dev/null || echo "VAAPI not available" > "$backup_dir/system-info/vaapi_info.txt"
    nvidia-smi > "$backup_dir/system-info/nvidia_info.txt" 2>/dev/null || echo "NVIDIA not available" > "$backup_dir/system-info/nvidia_info.txt"
    
    # Service information
    systemctl list-units --type=service > "$backup_dir/system-info/services.txt" 2>/dev/null || true
    ss -tulpn > "$backup_dir/system-info/network_ports.txt" 2>/dev/null || true
    
    # Log files (last 1000 lines of important logs)
    mkdir -p "$backup_dir/logs"
    journalctl -u sunshine --lines=1000 > "$backup_dir/logs/sunshine.log" 2>/dev/null || true
    journalctl -u coinops-web --lines=1000 > "$backup_dir/logs/coinops-web.log" 2>/dev/null || true
    
    echo "System Information: ✅ Included" >> "$backup_dir/BACKUP_MANIFEST.txt"
    
    # Create final compressed archive
    log_message "🗜️ Creating compressed archive..."
    cd "$temp_dir"
    
    if tar -czf "$final_path" "$backup_name"; then
        BACKUP_SIZE=$(du -sh "$final_path" | cut -f1)
        log_message "✅ Backup archive created: $final_path ($BACKUP_SIZE)"
        
        # Verify archive integrity
        if tar -tzf "$final_path" >/dev/null 2>&1; then
            log_message "✅ Archive integrity verified"
        else
            log_message "❌ Archive integrity check failed"
            rm -f "$final_path"
            cleanup_temp "$temp_dir"
            return 1
        fi
        
        # Encrypt backup if GPG is configured
        if [ "$ENCRYPT_BACKUPS" = "true" ] && command -v gpg >/dev/null 2>&1; then
            if gpg --list-keys "$GPG_RECIPIENT" >/dev/null 2>&1; then
                log_message "🔒 Encrypting backup with GPG..."
                ENCRYPTED_PATH="${final_path}.gpg"
                
                if gpg --trust-model always --encrypt --recipient "$GPG_RECIPIENT" --output "$ENCRYPTED_PATH" "$final_path"; then
                    log_message "✅ Backup encrypted: $ENCRYPTED_PATH"
                    rm -f "$final_path"
                    final_path="$ENCRYPTED_PATH"
                else
                    log_message "⚠️ Encryption failed, keeping unencrypted backup"
                fi
            else
                log_message "⚠️ GPG key for $GPG_RECIPIENT not found, skipping encryption"
            fi
        fi
        
        # Update manifest with final information
        echo "" >> "$backup_dir/BACKUP_MANIFEST.txt"
        echo "## Final Archive Information" >> "$backup_dir/BACKUP_MANIFEST.txt"
        echo "Archive Size: $BACKUP_SIZE" >> "$backup_dir/BACKUP_MANIFEST.txt"
        echo "Archive Path: $final_path" >> "$backup_dir/BACKUP_MANIFEST.txt"
        echo "Encrypted: $([ "${final_path##*.}" = "gpg" ] && echo "Yes" || echo "No")" >> "$backup_dir/BACKUP_MANIFEST.txt"
        echo "Verification: Passed" >> "$backup_dir/BACKUP_MANIFEST.txt"
        
        # Create symlink to latest backup
        cd "$BACKUP_BASE_DIR/$backup_type"
        ln -sf "$(basename "$final_path")" "latest-${backup_type}.tar.gz$([ "${final_path##*.}" = "gpg" ] && echo ".gpg")"
        
        cleanup_temp "$temp_dir"
        echo "$final_path"  # Return path for caller
        return 0
    else
        log_message "❌ Failed to create backup archive"
        cleanup_temp "$temp_dir"
        return 1
    fi
}

# Function to cleanup temporary directory
cleanup_temp() {
    local temp_dir="$1"
    rm -rf "$temp_dir" 2>/dev/null || true
}

# Function to cleanup old backups
cleanup_old_backups() {
    local backup_type="$1"
    local retain_days="$2"
    local backup_dir="$BACKUP_BASE_DIR/$backup_type"
    
    if [ -d "$backup_dir" ]; then
        log_message "🧹 Cleaning up old $backup_type backups (keeping $retain_days days)..."
        
        OLD_BACKUPS=$(find "$backup_dir" -name "*.tar.gz*" -type f -mtime +$retain_days 2>/dev/null || true)
        if [ -n "$OLD_BACKUPS" ]; then
            OLD_COUNT=$(echo "$OLD_BACKUPS" | wc -l)
            echo "$OLD_BACKUPS" | xargs rm -f
            log_message "🗑️ Removed $OLD_COUNT old $backup_type backups"
        else
            log_message "ℹ️ No old $backup_type backups to remove"
        fi
    fi
}

# Function to perform daily backup
backup_daily() {
    local backup_name="game-server-daily-$DATE"
    log_message "📅 Starting daily backup: $backup_name"
    
    if BACKUP_PATH=$(create_backup "daily" "$backup_name"); then
        cleanup_old_backups "daily" "$RETAIN_DAILY"
        
        BACKUP_SIZE=$(du -sh "$BACKUP_PATH" | cut -f1)
        SUCCESS_MESSAGE="✅ Daily game server backup completed successfully!

📦 Backup Details:
• Name: $backup_name
• Size: $BACKUP_SIZE  
• Location: $BACKUP_PATH
• Encrypted: $([ "${BACKUP_PATH##*.}" = "gpg" ] && echo "Yes" || echo "No")

📊 Backup Contents:
• ROM collection and save games
• User configurations and settings
• Sunshine GameStream configuration
• Web interface settings
• System information and logs

🕐 Backup Time: $(date +'%H:%M')
📧 Maintainer: $ADMIN_EMAIL"

        send_ntfy "Daily Backup Complete" "$SUCCESS_MESSAGE"
        log_message "✅ Daily backup completed successfully: $BACKUP_PATH"
        return 0
    else
        ERROR_MESSAGE="❌ Daily game server backup failed!

⚠️ Backup Issues:
• Failed to create backup archive
• Check system logs for details
• Manual intervention may be required

🕐 Failed Time: $(date +'%H:%M')
📧 Contact: $ADMIN_EMAIL"

        send_ntfy "Backup Failed" "$ERROR_MESSAGE" "high" "gaming,backup,error"
        log_message "❌ Daily backup failed"
        return 1
    fi
}

# Function to perform weekly backup
backup_weekly() {
    local backup_name="game-server-weekly-$(date +'%Y-W%U')"
    log_message "📅 Starting weekly backup: $backup_name"
    
    if BACKUP_PATH=$(create_backup "weekly" "$backup_name"); then
        cleanup_old_backups "weekly" $((RETAIN_WEEKLY * 7))
        
        BACKUP_SIZE=$(du -sh "$BACKUP_PATH" | cut -f1)
        log_message "✅ Weekly backup completed successfully: $BACKUP_PATH"
        
        # Send summary notification
        WEEKLY_MESSAGE="📅 Weekly game server backup completed

✅ Backup successful: $BACKUP_SIZE
📁 Retention: Keeping $RETAIN_WEEKLY weekly backups
🔄 Next weekly backup: $(date -d '+7 days' +'%Y-%m-%d')

📊 Current backup storage:
$(du -sh "$BACKUP_BASE_DIR"/{daily,weekly,monthly} 2>/dev/null | awk '{print "• " $2 ": " $1}' || echo "• Storage info unavailable")"

        send_ntfy "Weekly Backup Complete" "$WEEKLY_MESSAGE" "low" "gaming,backup,weekly"
        return 0
    else
        log_message "❌ Weekly backup failed"
        return 1
    fi
}

# Function to perform monthly backup
backup_monthly() {
    local backup_name="game-server-monthly-$(date +'%Y-%m')"
    log_message "📅 Starting monthly backup: $backup_name"
    
    if BACKUP_PATH=$(create_backup "monthly" "$backup_name"); then
        cleanup_old_backups "monthly" $((RETAIN_MONTHLY * 30))
        
        BACKUP_SIZE=$(du -sh "$BACKUP_PATH" | cut -f1)
        log_message "✅ Monthly backup completed successfully: $BACKUP_PATH"
        
        # Send detailed monthly summary
        TOTAL_STORAGE=$(du -sh "$BACKUP_BASE_DIR" | cut -f1)
        MONTHLY_MESSAGE="📅 Monthly game server backup completed

✅ Archive Created: $BACKUP_SIZE
💾 Total Backup Storage: $TOTAL_STORAGE
📁 Retention Policy: $RETAIN_MONTHLY monthly backups

📊 Backup Breakdown:
$(du -sh "$BACKUP_BASE_DIR"/{daily,weekly,monthly} 2>/dev/null | awk '{print "• " $2 ": " $1}' || echo "• Storage breakdown unavailable")

🗓️ Next monthly backup: $(date -d '+1 month' +'%Y-%m-%d')
📧 Questions: $ADMIN_EMAIL"

        send_ntfy "Monthly Backup Complete" "$MONTHLY_MESSAGE" "low" "gaming,backup,monthly"
        return 0
    else
        log_message "❌ Monthly backup failed"
        return 1
    fi
}

# Function to show backup status
show_status() {
    echo "🎮 Game Server Backup Status"
    echo "══════════════════════════════════════════════════════"
    echo "Server: $SERVER_NAME"
    echo "Time: $(date)"
    echo ""
    
    for backup_type in daily weekly monthly; do
        echo "📁 $backup_type Backups:"
        backup_dir="$BACKUP_BASE_DIR/$backup_type"
        
        if [ -d "$backup_dir" ]; then
            backup_count=$(find "$backup_dir" -name "*.tar.gz*" -type f | wc -l)
            backup_size=$(du -sh "$backup_dir" 2>/dev/null | cut -f1 || echo "0B")
            
            if [ "$backup_count" -gt 0 ]; then
                latest_backup=$(find "$backup_dir" -name "*.tar.gz*" -type f -printf '%T+ %p\n' | sort -r | head -1 | cut -d' ' -f2-)
                latest_time=$(stat -c %Y "$latest_backup" 2>/dev/null || echo "0")
                current_time=$(date +%s)
                age_hours=$(( (current_time - latest_time) / 3600 ))
                
                echo "   Count: $backup_count backups"
                echo "   Size: $backup_size"
                echo "   Latest: $(basename "$latest_backup") ($age_hours hours ago)"
            else
                echo "   No backups found"
            fi
        else
            echo "   Directory not found"
        fi
        echo ""
    done
    
    # Show storage usage
    echo "💾 Storage Usage:"
    df -h "$BACKUP_BASE_DIR" 2>/dev/null | tail -1 | awk '{print "   Available: " $4 " (" $5 " used)"}' || echo "   Storage info unavailable"
    
    # Show next scheduled backups
    echo ""
    echo "🗓️ Scheduled Backups:"
    echo "   Daily: Every day at 02:00"
    echo "   Weekly: Sundays at 03:00"
    echo "   Monthly: 1st of month at 04:00"
}

# Main execution
main() {
    local backup_type="${1:-daily}"
    
    log_message "Starting game server backup system - type: $backup_type"
    
    case "$backup_type" in
        "daily")
            backup_daily
            ;;
        "weekly")
            backup_weekly
            ;;
        "monthly")
            backup_monthly
            ;;
        "status")
            show_status
            ;;
        "cleanup")
            log_message "Running cleanup for all backup types"
            cleanup_old_backups "daily" "$RETAIN_DAILY"
            cleanup_old_backups "weekly" $((RETAIN_WEEKLY * 7))
            cleanup_old_backups "monthly" $((RETAIN_MONTHLY * 30))
            ;;
        "help"|"-h"|"--help")
            echo "Game Server Backup System"
            echo ""
            echo "Usage: $0 [BACKUP_TYPE]"
            echo ""
            echo "Backup Types:"
            echo "  daily     Create daily backup (default)"
            echo "  weekly    Create weekly backup"
            echo "  monthly   Create monthly backup"
            echo "  status    Show backup status and information"
            echo "  cleanup   Clean up old backups according to retention policy"
            echo "  help      Show this help message"
            echo ""
            echo "Configuration:"
            echo "  Backup Directory: $BACKUP_BASE_DIR"
            echo "  Retention: Daily ($RETAIN_DAILY days), Weekly ($RETAIN_WEEKLY weeks), Monthly ($RETAIN_MONTHLY months)"
            echo "  Encryption: $ENCRYPT_BACKUPS (GPG recipient: $GPG_RECIPIENT)"
            echo "  Notifications: $([ -n "$NTFY_TOPIC_GAMESERVER" ] && echo "Enabled ($NTFY_TOPIC_GAMESERVER)" || echo "Disabled")"
            ;;
        *)
            echo "❌ Unknown backup type: $backup_type"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"