#!/usr/bin/env node
/**
 * =====================================================
 * 🎮 Game Server Enhanced Web Interface
 * =====================================================
 * Enhanced Node.js web interface with Prometheus metrics
 * Maintainer: J35867U
 * Email: mrnash404@protonmail.com
 * Last Updated: 2025-10-14
 * =====================================================
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const url = require('url');
const { exec } = require('child_process');
const { promisify } = require('util');

const execAsync = promisify(exec);

// Configuration
const CONFIG = {
    port: process.env.COINOPS_PORT || 8080,
    host: process.env.COINOPS_HOST || '0.0.0.0',
    moonlightPort: process.env.MOONLIGHT_PORT || 47984,
    romsPath: process.env.ROMS_PATH || '/opt/coinops/roms',
    savesPath: process.env.SAVES_PATH || '/opt/coinops/saves',
    configPath: process.env.CONFIG_PATH || '/home/gameuser/.config',
    serverName: process.env.SERVER_NAME || 'game-server',
    adminEmail: process.env.ADMIN_EMAIL || 'mrnash404@protonmail.com',
    ntfyServer: process.env.NTFY_SERVER || 'https://ntfy.sh',
    ntfyTopic: process.env.NTFY_TOPIC_GAMESERVER || 'game-server-standalone'
};

// Metrics storage
const metrics = {
    httpRequests: 0,
    httpErrors: 0,
    systemStatus: 'unknown',
    servicesStatus: {},
    lastUpdate: new Date(),
    startTime: new Date(),
    romCount: 0,
    saveCount: 0,
    systemResources: {
        cpu: 0,
        memory: 0,
        disk: 0,
        load: 0
    }
};

// Utility functions
const formatBytes = (bytes) => {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
};

const formatUptime = (seconds) => {
    const days = Math.floor(seconds / 86400);
    const hours = Math.floor((seconds % 86400) / 3600);
    const mins = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    
    let result = '';
    if (days > 0) result += `${days}d `;
    if (hours > 0) result += `${hours}h `;
    if (mins > 0) result += `${mins}m `;
    result += `${secs}s`;
    
    return result.trim();
};

const sendNotification = async (title, message, priority = 'default') => {
    if (!CONFIG.ntfyServer || !CONFIG.ntfyTopic) return;
    
    try {
        const { exec } = require('child_process');
        exec(`curl -s -H "Title: [Game Server] ${title}" -H "Priority: ${priority}" -H "Tags: gaming,web,interface" -d "${message}" "${CONFIG.ntfyServer}/${CONFIG.ntfyTopic}"`, 
            (error) => {
                if (error) console.error('NTFY notification failed:', error.message);
            });
    } catch (error) {
        console.error('NTFY notification error:', error);
    }
};

// System monitoring functions
const updateSystemMetrics = async () => {
    try {
        // CPU Usage
        const cpuResult = await execAsync("top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1");
        metrics.systemResources.cpu = parseFloat(cpuResult.stdout.trim()) || 0;

        // Memory Usage
        const memResult = await execAsync("free | grep Mem | awk '{printf \"%.1f\", $3/$2 * 100.0}'");
        metrics.systemResources.memory = parseFloat(memResult.stdout.trim()) || 0;

        // Disk Usage
        const diskResult = await execAsync("df / | tail -1 | awk '{print $5}' | cut -d'%' -f1");
        metrics.systemResources.disk = parseInt(diskResult.stdout.trim()) || 0;

        // Load Average
        const loadResult = await execAsync("uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ','");
        metrics.systemResources.load = parseFloat(loadResult.stdout.trim()) || 0;

        // ROM and Save Counts
        try {
            const romResult = await execAsync(`find "${CONFIG.romsPath}" -type f \\( -name "*.zip" -o -name "*.7z" -o -name "*.iso" \\) 2>/dev/null | wc -l`);
            metrics.romCount = parseInt(romResult.stdout.trim()) || 0;
        } catch (error) {
            metrics.romCount = 0;
        }

        try {
            const saveResult = await execAsync(`find "${CONFIG.savesPath}" -type f 2>/dev/null | wc -l`);
            metrics.saveCount = parseInt(saveResult.stdout.trim()) || 0;
        } catch (error) {
            metrics.saveCount = 0;
        }

        // Service Status
        const services = ['sunshine', 'coinops-web', 'x11-server', 'openbox'];
        for (const service of services) {
            try {
                const statusResult = await execAsync(`systemctl is-active ${service} 2>/dev/null || echo "inactive"`);
                metrics.servicesStatus[service] = statusResult.stdout.trim();
            } catch (error) {
                metrics.servicesStatus[service] = 'unknown';
            }
        }

        // Overall system status
        const criticalServices = ['sunshine'];
        const allCriticalActive = criticalServices.every(service => 
            metrics.servicesStatus[service] === 'active'
        );

        if (allCriticalActive && metrics.systemResources.cpu < 90 && metrics.systemResources.memory < 90) {
            metrics.systemStatus = 'healthy';
        } else if (metrics.systemResources.cpu > 95 || metrics.systemResources.memory > 95) {
            metrics.systemStatus = 'critical';
        } else {
            metrics.systemStatus = 'warning';
        }

        metrics.lastUpdate = new Date();
    } catch (error) {
        console.error('Error updating system metrics:', error);
        metrics.systemStatus = 'error';
    }
};

// Generate Prometheus metrics
const generateMetrics = () => {
    const uptime = Math.floor((Date.now() - metrics.startTime) / 1000);
    
    return `# HELP gameserver_http_requests_total Total HTTP requests received
# TYPE gameserver_http_requests_total counter
gameserver_http_requests_total ${metrics.httpRequests}

# HELP gameserver_http_errors_total Total HTTP errors
# TYPE gameserver_http_errors_total counter
gameserver_http_errors_total ${metrics.httpErrors}

# HELP gameserver_uptime_seconds Server uptime in seconds
# TYPE gameserver_uptime_seconds gauge
gameserver_uptime_seconds ${uptime}

# HELP gameserver_system_cpu_percent CPU usage percentage
# TYPE gameserver_system_cpu_percent gauge
gameserver_system_cpu_percent ${metrics.systemResources.cpu}

# HELP gameserver_system_memory_percent Memory usage percentage
# TYPE gameserver_system_memory_percent gauge
gameserver_system_memory_percent ${metrics.systemResources.memory}

# HELP gameserver_system_disk_percent Disk usage percentage
# TYPE gameserver_system_disk_percent gauge
gameserver_system_disk_percent ${metrics.systemResources.disk}

# HELP gameserver_system_load Load average
# TYPE gameserver_system_load gauge
gameserver_system_load ${metrics.systemResources.load}

# HELP gameserver_rom_count Number of ROM files
# TYPE gameserver_rom_count gauge
gameserver_rom_count ${metrics.romCount}

# HELP gameserver_save_count Number of save files
# TYPE gameserver_save_count gauge
gameserver_save_count ${metrics.saveCount}

# HELP gameserver_service_status Service status (1=active, 0=inactive)
# TYPE gameserver_service_status gauge
${Object.entries(metrics.servicesStatus).map(([service, status]) => 
    `gameserver_service_status{service="${service}"} ${status === 'active' ? 1 : 0}`
).join('\n')}

# HELP gameserver_system_health Overall system health (2=healthy, 1=warning, 0=critical)
# TYPE gameserver_system_health gauge
gameserver_system_health ${metrics.systemStatus === 'healthy' ? 2 : metrics.systemStatus === 'warning' ? 1 : 0}
`;
};

// Generate dashboard HTML
const generateDashboard = () => {
    const uptime = Math.floor((Date.now() - metrics.startTime) / 1000);
    const systemHealth = metrics.systemStatus;
    const healthColor = systemHealth === 'healthy' ? '#28a745' : systemHealth === 'warning' ? '#ffc107' : '#dc3545';
    
    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🎮 ${CONFIG.serverName} - Game Server Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: #333;
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: rgba(255, 255, 255, 0.95);
            border-radius: 15px;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(135deg, #2c3e50 0%, #34495e 100%);
            color: white;
            padding: 30px;
            text-align: center;
            position: relative;
        }
        
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        
        .header .subtitle {
            font-size: 1.1em;
            opacity: 0.9;
        }
        
        .system-status {
            position: absolute;
            top: 20px;
            right: 30px;
            padding: 10px 20px;
            border-radius: 25px;
            background: ${healthColor};
            color: white;
            font-weight: bold;
            text-transform: uppercase;
            font-size: 0.9em;
        }
        
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            padding: 30px;
        }
        
        .card {
            background: white;
            border-radius: 10px;
            padding: 25px;
            box-shadow: 0 5px 15px rgba(0, 0, 0, 0.1);
            border-left: 5px solid #3498db;
            transition: transform 0.3s ease, box-shadow 0.3s ease;
        }
        
        .card:hover {
            transform: translateY(-5px);
            box-shadow: 0 10px 25px rgba(0, 0, 0, 0.15);
        }
        
        .card h3 {
            color: #2c3e50;
            margin-bottom: 20px;
            display: flex;
            align-items: center;
            font-size: 1.2em;
        }
        
        .card h3::before {
            content: '';
            width: 20px;
            height: 20px;
            margin-right: 10px;
            border-radius: 50%;
            background: #3498db;
        }
        
        .metric {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 12px 0;
            border-bottom: 1px solid #eee;
        }
        
        .metric:last-child {
            border-bottom: none;
        }
        
        .metric-label {
            font-weight: 600;
            color: #555;
        }
        
        .metric-value {
            font-weight: bold;
            padding: 5px 10px;
            border-radius: 5px;
            background: #f8f9fa;
        }
        
        .status-active {
            background: #d4edda !important;
            color: #155724;
        }
        
        .status-inactive {
            background: #f8d7da !important;
            color: #721c24;
        }
        
        .status-warning {
            background: #fff3cd !important;
            color: #856404;
        }
        
        .progress-bar {
            width: 100%;
            height: 8px;
            background: #e9ecef;
            border-radius: 4px;
            overflow: hidden;
            margin-top: 5px;
        }
        
        .progress-fill {
            height: 100%;
            transition: width 0.3s ease;
            border-radius: 4px;
        }
        
        .progress-low { background: #28a745; }
        .progress-medium { background: #ffc107; }
        .progress-high { background: #dc3545; }
        
        .actions {
            padding: 30px;
            background: #f8f9fa;
            text-align: center;
        }
        
        .btn {
            display: inline-block;
            padding: 12px 24px;
            margin: 5px;
            background: #3498db;
            color: white;
            text-decoration: none;
            border-radius: 5px;
            font-weight: 600;
            transition: background 0.3s ease;
        }
        
        .btn:hover {
            background: #2980b9;
        }
        
        .btn-success { background: #28a745; }
        .btn-success:hover { background: #218838; }
        
        .btn-warning { background: #ffc107; color: #212529; }
        .btn-warning:hover { background: #e0a800; }
        
        .footer {
            padding: 20px 30px;
            background: #2c3e50;
            color: white;
            text-align: center;
            font-size: 0.9em;
        }
        
        @media (max-width: 768px) {
            .grid {
                grid-template-columns: 1fr;
                padding: 20px;
            }
            
            .header h1 {
                font-size: 2em;
            }
            
            .system-status {
                position: static;
                margin-top: 15px;
                display: inline-block;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="system-status">${systemHealth}</div>
            <h1>🎮 ${CONFIG.serverName}</h1>
            <div class="subtitle">Moonlight GameStream + CoinOps Emulation Platform</div>
        </div>
        
        <div class="grid">
            <div class="card">
                <h3>🖥️ System Resources</h3>
                <div class="metric">
                    <span class="metric-label">CPU Usage</span>
                    <div>
                        <span class="metric-value">${metrics.systemResources.cpu.toFixed(1)}%</span>
                        <div class="progress-bar">
                            <div class="progress-fill ${metrics.systemResources.cpu > 80 ? 'progress-high' : metrics.systemResources.cpu > 60 ? 'progress-medium' : 'progress-low'}" 
                                 style="width: ${metrics.systemResources.cpu}%"></div>
                        </div>
                    </div>
                </div>
                <div class="metric">
                    <span class="metric-label">Memory Usage</span>
                    <div>
                        <span class="metric-value">${metrics.systemResources.memory.toFixed(1)}%</span>
                        <div class="progress-bar">
                            <div class="progress-fill ${metrics.systemResources.memory > 80 ? 'progress-high' : metrics.systemResources.memory > 60 ? 'progress-medium' : 'progress-low'}" 
                                 style="width: ${metrics.systemResources.memory}%"></div>
                        </div>
                    </div>
                </div>
                <div class="metric">
                    <span class="metric-label">Disk Usage</span>
                    <div>
                        <span class="metric-value">${metrics.systemResources.disk}%</span>
                        <div class="progress-bar">
                            <div class="progress-fill ${metrics.systemResources.disk > 80 ? 'progress-high' : metrics.systemResources.disk > 60 ? 'progress-medium' : 'progress-low'}" 
                                 style="width: ${metrics.systemResources.disk}%"></div>
                        </div>
                    </div>
                </div>
                <div class="metric">
                    <span class="metric-label">Load Average</span>
                    <span class="metric-value">${metrics.systemResources.load.toFixed(2)}</span>
                </div>
            </div>
            
            <div class="card">
                <h3>🎮 Game Services</h3>
                ${Object.entries(metrics.servicesStatus).map(([service, status]) => {
                    const statusClass = status === 'active' ? 'status-active' : 
                                      status === 'inactive' ? 'status-inactive' : 'status-warning';
                    const displayName = {
                        'sunshine': 'Sunshine GameStream',
                        'coinops-web': 'CoinOps Web Interface',
                        'x11-server': 'X11 Display Server',
                        'openbox': 'Openbox Window Manager'
                    }[service] || service;
                    
                    return `<div class="metric">
                        <span class="metric-label">${displayName}</span>
                        <span class="metric-value ${statusClass}">${status}</span>
                    </div>`;
                }).join('')}
            </div>
            
            <div class="card">
                <h3>📊 Gaming Statistics</h3>
                <div class="metric">
                    <span class="metric-label">ROM Collection</span>
                    <span class="metric-value">${metrics.romCount} games</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Save Files</span>
                    <span class="metric-value">${metrics.saveCount} saves</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Moonlight Port</span>
                    <span class="metric-value">${CONFIG.moonlightPort}</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Web Interface</span>
                    <span class="metric-value">Port ${CONFIG.port}</span>
                </div>
            </div>
            
            <div class="card">
                <h3>ℹ️ Server Information</h3>
                <div class="metric">
                    <span class="metric-label">Uptime</span>
                    <span class="metric-value">${formatUptime(uptime)}</span>
                </div>
                <div class="metric">
                    <span class="metric-label">HTTP Requests</span>
                    <span class="metric-value">${metrics.httpRequests}</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Last Update</span>
                    <span class="metric-value">${metrics.lastUpdate.toLocaleTimeString()}</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Admin Contact</span>
                    <span class="metric-value">${CONFIG.adminEmail}</span>
                </div>
            </div>
        </div>
        
        <div class="actions">
            <h3 style="margin-bottom: 20px; color: #2c3e50;">🔗 Quick Actions</h3>
            <a href="/metrics" class="btn">📊 Prometheus Metrics</a>
            <a href="/api/status" class="btn btn-success">📡 API Status</a>
            <a href="/api/services" class="btn btn-warning">🔍 Services Info</a>
            <a href="javascript:location.reload()" class="btn">🔄 Refresh Dashboard</a>
        </div>
        
        <div class="footer">
            <p>🎮 ${CONFIG.serverName} - Enhanced Game Server Interface | 
            Powered by Moonlight GameStream & CoinOps | 
            Maintainer: ${CONFIG.adminEmail}</p>
            <p style="margin-top: 10px; opacity: 0.7;">
                Last updated: ${metrics.lastUpdate.toLocaleString()} | 
                Server uptime: ${formatUptime(uptime)}
            </p>
        </div>
    </div>
    
    <script>
        // Auto-refresh every 30 seconds
        setTimeout(() => {
            location.reload();
        }, 30000);
        
        // Add some interactivity
        document.addEventListener('DOMContentLoaded', function() {
            const cards = document.querySelectorAll('.card');
            cards.forEach(card => {
                card.addEventListener('click', function() {
                    this.style.transform = 'scale(0.98)';
                    setTimeout(() => {
                        this.style.transform = '';
                    }, 150);
                });
            });
        });
    </script>
</body>
</html>`;
};

// API endpoints
const handleAPI = async (req, res, pathname) => {
    res.setHeader('Content-Type', 'application/json');
    
    try {
        switch (pathname) {
            case '/api/status':
                res.end(JSON.stringify({
                    status: 'ok',
                    server: CONFIG.serverName,
                    uptime: Math.floor((Date.now() - metrics.startTime) / 1000),
                    systemHealth: metrics.systemStatus,
                    timestamp: new Date().toISOString(),
                    services: metrics.servicesStatus,
                    resources: metrics.systemResources
                }));
                break;
                
            case '/api/metrics':
                res.end(JSON.stringify(metrics));
                break;
                
            case '/api/services':
                res.end(JSON.stringify({
                    services: metrics.servicesStatus,
                    ports: {
                        moonlight: CONFIG.moonlightPort,
                        web: CONFIG.port
                    },
                    paths: {
                        roms: CONFIG.romsPath,
                        saves: CONFIG.savesPath,
                        config: CONFIG.configPath
                    }
                }));
                break;
                
            case '/api/gaming':
                res.end(JSON.stringify({
                    romCount: metrics.romCount,
                    saveCount: metrics.saveCount,
                    romsPath: CONFIG.romsPath,
                    savesPath: CONFIG.savesPath,
                    moonlightPort: CONFIG.moonlightPort
                }));
                break;
                
            default:
                res.statusCode = 404;
                res.end(JSON.stringify({ error: 'API endpoint not found' }));
        }
    } catch (error) {
        res.statusCode = 500;
        res.end(JSON.stringify({ error: 'Internal server error', message: error.message }));
    }
};

// HTTP server
const server = http.createServer(async (req, res) => {
    const parsedUrl = url.parse(req.url, true);
    const pathname = parsedUrl.pathname;
    
    metrics.httpRequests++;
    
    try {
        // Handle different routes
        if (pathname === '/') {
            res.setHeader('Content-Type', 'text/html');
            res.end(generateDashboard());
        } else if (pathname === '/metrics') {
            res.setHeader('Content-Type', 'text/plain');
            res.end(generateMetrics());
        } else if (pathname.startsWith('/api/')) {
            await handleAPI(req, res, pathname);
        } else {
            res.statusCode = 404;
            res.setHeader('Content-Type', 'text/html');
            res.end(`
                <html>
                <head>
                    <title>404 - Not Found</title>
                    <style>
                        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; background: #f5f5f5; }
                        .container { background: white; padding: 40px; border-radius: 10px; display: inline-block; box-shadow: 0 5px 15px rgba(0,0,0,0.1); }
                        h1 { color: #e74c3c; margin-bottom: 20px; }
                        a { color: #3498db; text-decoration: none; font-weight: bold; }
                        a:hover { text-decoration: underline; }
                    </style>
                </head>
                <body>
                    <div class="container">
                        <h1>🎮 404 - Page Not Found</h1>
                        <p>The requested page could not be found on the game server.</p>
                        <p><a href="/">← Back to Dashboard</a></p>
                    </div>
                </body>
                </html>
            `);
        }
    } catch (error) {
        console.error('Server error:', error);
        metrics.httpErrors++;
        
        res.statusCode = 500;
        res.setHeader('Content-Type', 'text/html');
        res.end(`
            <html>
            <head>
                <title>500 - Internal Server Error</title>
                <style>
                    body { font-family: Arial, sans-serif; text-align: center; padding: 50px; background: #f5f5f5; }
                    .container { background: white; padding: 40px; border-radius: 10px; display: inline-block; box-shadow: 0 5px 15px rgba(0,0,0,0.1); }
                    h1 { color: #e74c3c; margin-bottom: 20px; }
                    a { color: #3498db; text-decoration: none; font-weight: bold; }
                    a:hover { text-decoration: underline; }
                </style>
            </head>
            <body>
                <div class="container">
                    <h1>🎮 500 - Internal Server Error</h1>
                    <p>An error occurred while processing your request.</p>
                    <p><a href="/">← Back to Dashboard</a></p>
                </div>
            </body>
            </html>
        `);
    }
});

// Update metrics every 15 seconds
const updateInterval = setInterval(updateSystemMetrics, 15000);

// Graceful shutdown
process.on('SIGINT', () => {
    console.log('\n🎮 Game server web interface shutting down gracefully...');
    clearInterval(updateInterval);
    server.close(() => {
        console.log('🎮 Server stopped');
        process.exit(0);
    });
});

process.on('SIGTERM', () => {
    console.log('\n🎮 Game server web interface received SIGTERM, shutting down gracefully...');
    clearInterval(updateInterval);
    server.close(() => {
        console.log('🎮 Server stopped');
        process.exit(0);
    });
});

// Start server
const startServer = async () => {
    console.log('🎮 Game Server Enhanced Web Interface');
    console.log('==========================================');
    console.log(`Server: ${CONFIG.serverName}`);
    console.log(`Admin: ${CONFIG.adminEmail}`);
    console.log(`Port: ${CONFIG.port}`);
    console.log(`Host: ${CONFIG.host}`);
    console.log(`Moonlight Port: ${CONFIG.moonlightPort}`);
    console.log('==========================================');
    
    // Initial metrics update
    await updateSystemMetrics();
    
    server.listen(CONFIG.port, CONFIG.host, () => {
        const address = server.address();
        console.log(`🚀 Server running at http://${address.address}:${address.port}`);
        console.log('📊 Metrics available at /metrics');
        console.log('📡 API endpoints:');
        console.log('   • /api/status - Server status');
        console.log('   • /api/metrics - All metrics');
        console.log('   • /api/services - Service information');
        console.log('   • /api/gaming - Gaming statistics');
        console.log('');
        console.log('🎮 Dashboard ready for Moonlight GameStream management!');
        
        // Send startup notification
        sendNotification(
            'Web Interface Started',
            `🎮 Game Server web interface is now running

🌐 Dashboard: http://${address.address}:${address.port}
📊 Metrics: http://${address.address}:${address.port}/metrics
🎯 Moonlight Port: ${CONFIG.moonlightPort}

🖥️ Server: ${CONFIG.serverName}
⚡ Status: ${metrics.systemStatus}
🕐 Started: ${new Date().toLocaleString()}`,
            'low'
        );
    });
    
    server.on('error', (error) => {
        console.error('🚨 Server error:', error);
        
        if (error.code === 'EADDRINUSE') {
            console.error(`❌ Port ${CONFIG.port} is already in use`);
            console.error('   Try stopping the existing service or use a different port');
            console.error(`   Example: COINOPS_PORT=8081 node ${__filename}`);
        }
        
        sendNotification(
            'Web Interface Error',
            `❌ Game Server web interface failed to start

Error: ${error.message}
Port: ${CONFIG.port}
Time: ${new Date().toLocaleString()}

Please check the server logs for details.`,
            'high'
        );
        
        process.exit(1);
    });
};

// Start the server
startServer().catch((error) => {
    console.error('❌ Failed to start game server web interface:', error);
    process.exit(1);
});