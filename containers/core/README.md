# 🔒 Core Infrastructure Services

VPN, networking, and essential infrastructure services that everything else depends on.

## Services Included:
- **Gluetun** - VPN Gateway (all downloads route through this)
- **FlareSolverr** - Cloudflare bypass for indexers

## Quick Deploy:
```bash
cd containers/core
docker-compose up -d
```

## Individual Services:
```bash
# Start VPN only
docker-compose up -d gluetun

# Start FlareSolverr only
docker-compose up -d flaresolverr
```

## Notes:
- Gluetun must be running before any download clients
- Configure your VPN credentials in the `.env` file
- Downloads services depend on this being healthy
