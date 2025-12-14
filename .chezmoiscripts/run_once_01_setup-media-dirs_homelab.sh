#!/bin/bash
# setup-media-dirs_homelab.sh
# Creates the directory structure for arr-stack media management on homelab devices

set -e

MEDIA_ROOT="${HOME}/volumes/media"

echo "Creating media directory structure at ${MEDIA_ROOT}..."

# Create main directories
mkdir -p "${MEDIA_ROOT}/torrents"
mkdir -p "${MEDIA_ROOT}/data"

# Create subdirectories in torrents
mkdir -p "${MEDIA_ROOT}/torrents/music"
mkdir -p "${MEDIA_ROOT}/torrents/movies"
mkdir -p "${MEDIA_ROOT}/torrents/tv"
mkdir -p "${MEDIA_ROOT}/torrents/books"

# Create subdirectories in data
mkdir -p "${MEDIA_ROOT}/data/music"
mkdir -p "${MEDIA_ROOT}/data/movies"
mkdir -p "${MEDIA_ROOT}/data/tv"
mkdir -p "${MEDIA_ROOT}/data/books"

# Set permissions
chmod -R 755 "${MEDIA_ROOT}"

echo "✓ Media directory structure created successfully!"
echo ""
echo "Directory structure:"
tree -L 3 "${MEDIA_ROOT}" 2>/dev/null || find "${MEDIA_ROOT}" -type d | sed 's|[^/]*/| |g'
echo ""
echo "Usage:"
echo "  - torrents/: qBittorrent download location"
echo "  - data/: Organized media for Plex and *arr apps"
