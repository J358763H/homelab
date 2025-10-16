#!/bin/bash

# =====================================================
# 🔧 VS Code Markdown Linting Fix Script
# =====================================================
# Fixes common Markdown linting issues across all files
# Addresses MD022, MD032, MD047, MD034, MD031 errors
# =====================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date +'%H:%M:%S')] $1${NC}"; }
success() { echo -e "${GREEN}[SUCCESS] $1${NC}"; }
warn() { echo -e "${YELLOW}[WARNING] $1${NC}"; }

# Function to fix markdown files
fix_markdown_file() {
    local file="$1"
    local temp_file="${file}.tmp"

    log "Fixing: $(basename "$file")"

    # Create a backup
    cp "$file" "${file}.backup"

    # Fix the file using sed and awk
    {
        # Add blank lines around headings (MD022)
        # Add blank lines around lists (MD032)
        # Fix bare URLs (MD034) - wrap in angle brackets
        # Add final newline (MD047)
        awk '
        BEGIN { prev_line = ""; in_list = 0; in_code = 0 }

        # Track code blocks
        /^```/ {
            in_code = !in_code
            if (prev_line != "" && prev_line !~ /^$/) print ""
            print $0
            if (!in_code && NF > 0) print ""
            prev_line = $0
            next
        }

        # Skip processing inside code blocks
        in_code {
            print $0
            prev_line = $0
            next
        }

        # Handle headings (MD022)
        /^#/ {
            if (prev_line != "" && prev_line !~ /^$/) print ""
            print $0
            print ""
            prev_line = ""
            in_list = 0
            next
        }

        # Handle list items (MD032)
        /^[ ]*[-*+]/ || /^[ ]*[0-9]+\./ {
            if (!in_list && prev_line != "" && prev_line !~ /^$/) print ""
            print $0
            in_list = 1
            prev_line = $0
            next
        }

        # End of list
        !/^[ ]*[-*+]/ && !/^[ ]*[0-9]+\./ && !/^$/ && in_list {
            if (prev_line !~ /^$/) print ""
            print $0
            in_list = 0
            prev_line = $0
            next
        }

        # Fix bare URLs (MD034) - basic fix for http/https
        {
            gsub(/http:\/\/[^ )]+/, "<&>")
            gsub(/https:\/\/[^ )]+/, "<&>")
        }

        # Regular lines
        {
            print $0
            prev_line = $0
        }

        END {
            # Ensure file ends with single newline (MD047)
            if (prev_line != "") print ""
        }
        ' "$file" > "$temp_file"
    } 2>/dev/null || {
        warn "Failed to process $file with awk, trying simpler approach"

        # Fallback: simpler fixes
        sed -e '/^#/i\\' \
            -e '/^#/a\\' \
            -e '/^[ ]*[-*+]/i\\' \
            -e '/^[ ]*[0-9]*\./i\\' \
            -e 's|http://[^ )]*|<&>|g' \
            -e 's|https://[^ )]*|<&>|g' \
            "$file" > "$temp_file"

        # Ensure final newline
        echo "" >> "$temp_file"
    }

    # Remove multiple consecutive blank lines (keep max 2)
    sed '/^$/N;/^\n$/d' "$temp_file" > "${temp_file}.clean"
    mv "${temp_file}.clean" "$temp_file"

    # Replace original with fixed version
    mv "$temp_file" "$file"

    success "Fixed: $(basename "$file")"
}

# Main execution
main() {
    log "Starting Markdown linting fixes..."

    # Find all markdown files
    local md_files
    mapfile -t md_files < <(find . -name "*.md" -type f | grep -v node_modules | grep -v .git)

    if [ ${#md_files[@]} -eq 0 ]; then
        warn "No markdown files found"
        exit 0
    fi

    log "Found ${#md_files[@]} markdown files to fix"

    # Fix each file
    for file in "${md_files[@]}"; do
        if [ -f "$file" ]; then
            fix_markdown_file "$file"
        fi
    done

    success "All markdown files processed!"
    log "Backup files created with .backup extension"
    log "You can remove backups with: find . -name '*.backup' -delete"
}

# Handle arguments
case "${1:-fix}" in
    "fix")
        main
        ;;
    "clean-backups")
        log "Removing backup files..."
        find . -name "*.backup" -delete
        success "Backup files removed"
        ;;
    "restore")
        log "Restoring from backups..."
        find . -name "*.backup" -exec bash -c 'mv "$1" "${1%.backup}"' _ {} \;
        success "Files restored from backups"
        ;;
    *)
        echo "Usage: $0 [fix|clean-backups|restore]"
        echo "  fix           - Fix markdown linting issues (default)"
        echo "  clean-backups - Remove .backup files"
        echo "  restore       - Restore files from .backup versions"
        exit 1
        ;;
esac
