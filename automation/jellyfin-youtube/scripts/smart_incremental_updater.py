#!/usr/bin/env python3
"""
Smart Incremental YouTube Updater
Intelligently downloads new content from subscribed channels
"""

import os
import sys
import time
import yaml
import json
import logging
import requests
from datetime import datetime, timedelta
from pathlib import Path
import subprocess

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/homelab-shv/jellyfin-youtube.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class YouTubeUpdater:
    def __init__(self, config_path='/app/config'):
        self.config_path = Path(config_path)
        self.load_config()
        self.setup_directories()
        
    def load_config(self):
        """Load configuration from YAML files"""
        try:
            # Load main config
            with open(self.config_path / 'config.yml', 'r') as f:
                self.config = yaml.safe_load(f)
                
            # Load creators config
            with open(self.config_path / 'creators.yaml', 'r') as f:
                self.creators = yaml.safe_load(f)
                
            # Load Jellyfin config
            with open(self.config_path / 'jellyfin_youtube.yaml', 'r') as f:
                self.jellyfin_config = yaml.safe_load(f)
                
            logger.info("Configuration loaded successfully")
            
        except Exception as e:
            logger.error(f"Failed to load configuration: {e}")
            sys.exit(1)
            
    def setup_directories(self):
        """Create necessary directories"""
        base_dir = Path(self.jellyfin_config['jellyfin']['library_path'])
        
        directories = [
            base_dir / 'channels',
            base_dir / 'music', 
            base_dir / 'playlists',
            base_dir / 'temp',
            Path('/var/log/homelab-shv')
        ]
        
        for directory in directories:
            directory.mkdir(parents=True, exist_ok=True)
            
    def send_notification(self, title, message, priority='default'):
        """Send notification via ntfy"""
        try:
            ntfy_config = self.jellyfin_config.get('notifications', {}).get('ntfy', {})
            server = os.environ.get('NTFY_SERVER', ntfy_config.get('server'))
            topic = os.environ.get('NTFY_TOPIC_SUMMARY', ntfy_config.get('topic'))
            
            if server and topic:
                requests.post(
                    f"{server}/{topic}",
                    headers={
                        'Title': f"[YouTube] {title}",
                        'Priority': priority,
                        'Tags': 'youtube,automation'
                    },
                    data=message,
                    timeout=10
                )
        except Exception as e:
            logger.warning(f"Failed to send notification: {e}")
            
    def download_channel_content(self, creator):
        """Download content from a specific creator"""
        name = creator['name']
        url = creator['url']
        category = creator.get('category', 'General')
        days_back = creator.get('download_recent', 30)
        quality = creator.get('quality', '1080p')
        
        logger.info(f"Processing channel: {name}")
        
        # Calculate date filter
        cutoff_date = datetime.now() - timedelta(days=days_back)
        date_filter = cutoff_date.strftime('%Y%m%d')
        
        # Setup output directory
        output_dir = Path(self.jellyfin_config['jellyfin']['library_path']) / 'channels' / name
        output_dir.mkdir(parents=True, exist_ok=True)
        
        # Build yt-dlp command
        cmd = [
            'yt-dlp',
            url,
            '--dateafter', date_filter,
            '--output', str(output_dir / '%(upload_date)s - %(title)s.%(ext)s'),
            '--write-thumbnail',
            '--write-description',
            '--write-info-json',
            '--embed-metadata',
            '--add-metadata'
        ]
        
        # Add quality settings
        quality_profiles = self.creators.get('quality_profiles', {})
        if quality in quality_profiles:
            cmd.extend(['--format', quality_profiles[quality]['format']])
        else:
            cmd.extend(['--format', 'best[height<=1080]'])
            
        # Add subtitle options
        if creator.get('quality') != 'audio_only':
            cmd.extend([
                '--write-subs',
                '--write-auto-subs',
                '--sub-langs', 'en,en-US'
            ])
            
        try:
            # Run download
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=3600)
            
            if result.returncode == 0:
                # Count downloaded files
                downloaded_count = len([f for f in output_dir.glob('*') if f.is_file() and f.suffix in ['.mp4', '.mkv', '.webm']])
                logger.info(f"Successfully processed {name} - {downloaded_count} files")
                return True, downloaded_count
            else:
                logger.error(f"Failed to download from {name}: {result.stderr}")
                return False, 0
                
        except subprocess.TimeoutExpired:
            logger.error(f"Download timeout for {name}")
            return False, 0
        except Exception as e:
            logger.error(f"Download error for {name}: {e}")
            return False, 0
            
    def download_playlists(self):
        """Download configured playlists"""
        playlists = self.creators.get('playlists', [])
        results = []
        
        for playlist in playlists:
            name = playlist['name']
            url = playlist['url']
            max_videos = playlist.get('max_videos', 50)
            
            logger.info(f"Processing playlist: {name}")
            
            output_dir = Path(self.jellyfin_config['jellyfin']['library_path']) / 'playlists' / name
            output_dir.mkdir(parents=True, exist_ok=True)
            
            cmd = [
                'yt-dlp',
                url,
                '--playlist-end', str(max_videos),
                '--output', str(output_dir / '%(playlist_index)03d - %(title)s.%(ext)s'),
                '--write-thumbnail',
                '--write-description',
                '--write-info-json',
                '--format', 'best[height<=1080]'
            ]
            
            try:
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=7200)
                
                if result.returncode == 0:
                    downloaded_count = len([f for f in output_dir.glob('*') if f.is_file() and f.suffix in ['.mp4', '.mkv', '.webm']])
                    logger.info(f"Successfully processed playlist {name} - {downloaded_count} files")
                    results.append((name, True, downloaded_count))
                else:
                    logger.error(f"Failed to download playlist {name}: {result.stderr}")
                    results.append((name, False, 0))
                    
            except Exception as e:
                logger.error(f"Playlist download error for {name}: {e}")
                results.append((name, False, 0))
                
        return results
        
    def update_jellyfin_library(self):
        """Trigger Jellyfin library scan"""
        try:
            jellyfin_url = self.jellyfin_config['jellyfin']['server_url']
            api_key = os.environ.get('JELLYFIN_API_KEY')
            
            if not api_key:
                logger.warning("No Jellyfin API key configured - skipping library update")
                return False
                
            # Trigger library scan
            scan_url = f"{jellyfin_url}/Library/Refresh"
            headers = {'X-Emby-Token': api_key}
            
            response = requests.post(scan_url, headers=headers, timeout=30)
            
            if response.status_code == 204:
                logger.info("Jellyfin library scan triggered successfully")
                return True
            else:
                logger.warning(f"Failed to trigger library scan: {response.status_code}")
                return False
                
        except Exception as e:
            logger.error(f"Failed to update Jellyfin library: {e}")
            return False
            
    def cleanup_old_files(self):
        """Clean up old files based on retention policy"""
        try:
            cleanup_config = self.jellyfin_config.get('cleanup', {})
            if not cleanup_config.get('old_files', {}).get('enabled', False):
                return
                
            retention_days = cleanup_config['old_files'].get('retention_days', 180)
            cutoff_date = datetime.now() - timedelta(days=retention_days)
            
            base_dir = Path(self.jellyfin_config['jellyfin']['library_path'])
            cleanup_count = 0
            
            for file_path in base_dir.rglob('*'):
                if file_path.is_file():
                    file_time = datetime.fromtimestamp(file_path.stat().st_mtime)
                    if file_time < cutoff_date:
                        file_path.unlink()
                        cleanup_count += 1
                        
            if cleanup_count > 0:
                logger.info(f"Cleaned up {cleanup_count} old files")
                
        except Exception as e:
            logger.error(f"Cleanup error: {e}")
            
    def run_update_cycle(self):
        """Run a complete update cycle"""
        start_time = datetime.now()
        logger.info("Starting YouTube update cycle")
        
        total_downloads = 0
        successful_channels = 0
        failed_channels = 0
        
        # Process creators
        creators = self.creators.get('creators', [])
        for creator in creators:
            try:
                success, count = self.download_channel_content(creator)
                if success:
                    successful_channels += 1
                    total_downloads += count
                else:
                    failed_channels += 1
                    
                # Small delay between channels
                time.sleep(5)
                
            except Exception as e:
                logger.error(f"Error processing creator {creator.get('name', 'Unknown')}: {e}")
                failed_channels += 1
                
        # Process playlists
        playlist_results = self.download_playlists()
        
        # Update Jellyfin library
        library_updated = self.update_jellyfin_library()
        
        # Cleanup old files
        self.cleanup_old_files()
        
        # Calculate duration
        duration = datetime.now() - start_time
        
        # Send summary notification
        summary = f"""🎬 YouTube Update Complete

📊 Summary:
• Channels processed: {successful_channels + failed_channels}
• Successful: {successful_channels}
• Failed: {failed_channels}
• Total downloads: {total_downloads}
• Playlists: {len(playlist_results)}
• Duration: {str(duration).split('.')[0]}

📚 Library Updated: {'✅' if library_updated else '❌'}

🗓️ Next update: {(datetime.now() + timedelta(hours=1)).strftime('%H:%M')}"""

        priority = 'default' if failed_channels == 0 else 'high'
        self.send_notification("Update Complete", summary, priority)
        
        logger.info(f"Update cycle completed - {successful_channels} successful, {failed_channels} failed")
        
if __name__ == "__main__":
    updater = YouTubeUpdater()
    
    # Run continuously with hourly updates
    while True:
        try:
            updater.run_update_cycle()
            
            # Wait 1 hour before next update
            logger.info("Waiting 1 hour for next update cycle...")
            time.sleep(3600)
            
        except KeyboardInterrupt:
            logger.info("Shutting down YouTube updater")
            break
        except Exception as e:
            logger.error(f"Unexpected error in main loop: {e}")
            # Wait 5 minutes on error then retry
            time.sleep(300)