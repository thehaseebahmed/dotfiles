#!/bin/bash
# setup-media-dirs_homelab.sh
# Creates the directory structure for arr-stack media management on homelab devices

set -e

DATA_ROOT="${HOME}/volumes/data"

echo "Creating data directory structure at ${DATA_ROOT}..."

# Create subdirectories in torrents
mkdir -p "${DATA_ROOT}/torrents/music"
mkdir -p "${DATA_ROOT}/torrents/movies"
mkdir -p "${DATA_ROOT}/torrents/tv"
mkdir -p "${DATA_ROOT}/torrents/books"

# Create subdirectories in media
mkdir -p "${DATA_ROOT}/media/music"
mkdir -p "${DATA_ROOT}/media/movies"
mkdir -p "${DATA_ROOT}/media/tv"
mkdir -p "${DATA_ROOT}/media/books"

# Set permissions
chmod -R 755 "${DATA_ROOT}"

echo "✓ Data directory structure created successfully!"
echo ""
echo "Directory structure:"
tree -L 3 "${DATA_ROOT}" 2>/dev/null || find "${DATA_ROOT}" -type d | sed 's|[^/]*/| |g'
echo ""
echo "Usage:"
echo "  - torrents/: qBittorrent download location"
echo "  - media/: Organized media for Plex and *arr apps"
