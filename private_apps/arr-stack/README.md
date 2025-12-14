# arr-stack - Media Management Stack

A modular Docker Compose setup for managing a complete media automation stack. This configuration uses individual compose files for each service, making it easy to enable/disable specific services while maintaining shared networking.

## Architecture

### Modular Design

Each service has its own compose file, allowing for:
- **Granular control**: Start/stop individual services without affecting others
- **Easy maintenance**: Update or modify a single service in isolation
- **Clear organization**: Each service configuration is self-contained
- **Selective deployment**: Include only the services you need

### Shared Network

All services communicate via the `arr-stack` Docker bridge network, enabling:
- Inter-service communication (e.g., Radarr → Prowlarr → qBittorrent)
- Network isolation from other Docker services
- Consistent networking across all media management tools

## Services

| Service | Port | Purpose | Compose File |
|---------|------|---------|--------------|
| **Plex** | 32400 | Media server for streaming content | `plex-compose.yaml` |
| **Sonarr** | 8989 | TV show collection management | `sonarr-compose.yaml` |
| **Radarr** | 7878 | Movie collection management | `radarr-compose.yaml` |
| **Lidarr** | 8686 | Music collection management | `lidarr-compose.yaml` |
| **Bazarr** | 6767 | Subtitle management for Sonarr/Radarr | `bazarr-compose.yaml` |
| **Prowlarr** | 9696 | Indexer manager for all *arr apps | `prowlarr-compose.yaml` |
| **Overseerr** | 5055 | Media request and discovery platform | `overseerr-compose.yaml` |
| **qBittorrent** | 8080 | Torrent download client | `qbittorrent-compose.yaml` |
| **Qui** | 7476 | Alternative qBittorrent web UI | `qui-compose.yaml` |
| **Bookshelf** | 8787 | Ebook library management | `bookshelf-compose.yaml` |

## Host Deployment

### homelab-001
- Full arr-stack deployment
- All services available

### homelab-003
- Full arr-stack deployment
- All services available
- Additional: booklore service

## Directory Structure

```
arr-stack/
├── docker-compose.yaml          # Main orchestration file (includes all services)
├── bazarr-compose.yaml          # Individual service files
├── bookshelf-compose.yaml
├── lidarr-compose.yaml
├── overseerr-compose.yaml
├── prowlarr-compose.yaml
├── plex-compose.yaml
├── qbittorrent-compose.yaml
├── qui-compose.yaml
├── radarr-compose.yaml
├── sonarr-compose.yaml
└── README.md                    # This file
```

## Usage

### Managing the Entire Stack

```bash
# Start all services
docker compose up -d

# Stop all services
docker compose down

# View logs for all services
docker compose logs -f

# Pull latest images for all services
docker compose pull
```

### Managing Individual Services

```bash
# Start a specific service (e.g., sonarr)
docker compose up -d sonarr

# Stop a specific service
docker compose stop sonarr

# View logs for a specific service
docker compose logs -f sonarr

# Restart a specific service
docker compose restart sonarr

# Pull latest image for a specific service
docker compose pull sonarr
```

### Network Management

The `arr-stack` network is automatically created when starting the stack. To manually manage:

```bash
# Create the network (if needed)
docker network create arr-stack

# Inspect the network
docker network inspect arr-stack

# Remove the network (all services must be stopped first)
docker network rm arr-stack
```

## Configuration

### Environment Variables

All services use common environment variables:
- `PUID=1000` - User ID for file permissions
- `PGID=1000` - Group ID for file permissions
- `UMASK=002` - File creation mask
- `TZ=Europe/Amsterdam` - Timezone

### Volume Mounts

Each service stores data in `~/volumes/<service>/`:
- `config/` - Service configuration files
- `data/` - Media libraries and downloads (where applicable)
- `transcode/` - Transcoding directory (Plex only)

### Customization

To customize a service:
1. Edit the corresponding `<service>-compose.yaml` file
2. Modify environment variables, ports, or volumes as needed
3. Restart the service: `docker compose up -d <service>`

## Adding New Services

To add a new service to the stack:

1. Create a new compose file (e.g., `newservice-compose.yaml`):
```yaml
services:
  newservice:
    image: ghcr.io/author/newservice
    container_name: newservice
    restart: unless-stopped
    networks:
      - arr-stack
    ports:
      - "PORT:PORT"
    volumes:
      - ~/volumes/newservice/config:/config
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Amsterdam

networks:
  arr-stack:
    name: arr-stack
    external: true
```

2. Add the new file to `docker-compose.yaml`:
```yaml
include:
  - path: newservice-compose.yaml  # Description
```

3. Start the new service:
```bash
docker compose up -d newservice
```

## Removing Services

To remove a service from the stack:

1. Comment out or remove the service from `docker-compose.yaml`:
```yaml
include:
  # - path: unwanted-compose.yaml  # Disabled
```

2. Stop and remove the service:
```bash
docker compose stop unwanted
docker compose rm unwanted
```

3. Optionally delete the compose file and volumes:
```bash
rm unwanted-compose.yaml
rm -rf ~/volumes/unwanted
```

## Troubleshooting

### Service won't start
```bash
# Check service logs
docker compose logs <service>

# Verify network exists
docker network ls | grep arr-stack

# Check if port is already in use
sudo netstat -tulpn | grep <port>
```

### Network issues
```bash
# Recreate the network
docker compose down
docker network rm arr-stack
docker compose up -d
```

### Permission issues
```bash
# Verify PUID/PGID match your user
id

# Fix volume permissions
sudo chown -R 1000:1000 ~/volumes/<service>
```

## Workflow Overview

1. **Prowlarr** manages indexers (torrent/nzb sources)
2. **Sonarr/Radarr/Lidarr** search for content via Prowlarr
3. **qBittorrent** downloads content requested by *arr apps
4. **Bazarr** automatically downloads subtitles for media
5. **Plex** serves the downloaded media to clients
6. **Overseerr** provides a user-friendly request interface

## Security Notes

- All services run as non-root user (PUID/PGID 1000)
- Network is isolated from other Docker services
- Configuration files contain API keys - ensure proper file permissions
- Consider using reverse proxy (Traefik/Nginx) for HTTPS access

## Maintenance

### Regular Tasks

```bash
# Update all services to latest images
docker compose pull
docker compose up -d

# Clean up unused images
docker image prune

# Backup configurations
tar -czf arr-stack-backup.tar.gz ~/volumes/*/config

# Check disk space
df -h ~/volumes
```

### Monitoring

- **Qui**: Monitor qBittorrent downloads at `http://homelab:7476`
- **Service logs**: `docker compose logs -f <service>`
- **Resource usage**: `docker stats`

## Related Documentation

- [Chezmoi dotfiles repository](../../CLAUDE.md)
- [Main apps docker-compose](../docker-compose.yaml.tmpl)
- Service-specific documentation:
  - [Prowlarr Wiki](https://wiki.servarr.com/prowlarr)
  - [Sonarr Wiki](https://wiki.servarr.com/sonarr)
  - [Radarr Wiki](https://wiki.servarr.com/radarr)
  - [Plex Support](https://support.plex.tv/)
