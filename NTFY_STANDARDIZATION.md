# 📡 Ntfy Topic Standardization

Standard Ntfy topic naming scheme for homelab infrastructure.

## 🏷️ Topic Naming Convention

### **Primary Infrastructure (homelab-SHV)**
- `homelab-shv-alerts` - Critical alerts and backup failures
- `homelab-shv-summary` - Weekly summaries and health reports
- `homelab-shv-maintenance` - Maintenance notifications

### **Game Server Infrastructure**
- `homelab-game-server-alerts` - Game server alerts and backup failures
- `homelab-game-server-summary` - Game server health reports
- `homelab-game-server-maintenance` - Game server maintenance

### **Backup Node Infrastructure**  
- `homelab-backup-alerts` - Backup node alerts and failures
- `homelab-backup-summary` - Backup completion reports

## 🔧 Configuration

Update your `.env` files to use these standardized topics:

### homelab-SHV
```bash
NTFY_SERVER="https://ntfy.sh"
NTFY_TOPIC_ALERTS="homelab-shv-alerts"
NTFY_TOPIC_SUMMARY="homelab-shv-summary" 
NTFY_TOPIC_MAINTENANCE="homelab-shv-maintenance"
```

### game-server
```bash
NTFY_SERVER="https://ntfy.sh"
NTFY_TOPIC_ALERTS="homelab-game-server-alerts"
NTFY_TOPIC_SUMMARY="homelab-game-server-summary"
NTFY_TOPIC_MAINTENANCE="homelab-game-server-maintenance"
```

This ensures consistent monitoring across all homelab infrastructure.