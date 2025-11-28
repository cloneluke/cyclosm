#!/bin/bash
set -e

# If not running as docker group, re-execute with proper permissions
if ! groups | grep -q docker; then
    exec sg docker "$0"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TILE_SERVER_DIR="$PROJECT_ROOT/infrastructure/tile-server"

echo "🗺️  CyclOSM Vector - Tile Generation"
echo "====================================="
echo ""

# Verify Docker is available
if ! docker ps &> /dev/null; then
    echo "❌ Docker is not available. Run ./scripts/setup-docker.sh first."
    exit 1
fi

echo "📍 Project root: $PROJECT_ROOT"
echo "📍 Tile server: $TILE_SERVER_DIR"
echo ""

# Check if data directory exists and has tiles
if [ -f "$TILE_SERVER_DIR/data/tiles.pmtiles" ]; then
    echo "ℹ️  Existing tiles found at: $TILE_SERVER_DIR/data/tiles.pmtiles"
    echo ""
    read -p "Do you want to regenerate tiles? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "✅ Using existing tiles. Skipping generation."
        exit 0
    fi
fi

echo "🧹 Cleaning up old containers..."
cd "$TILE_SERVER_DIR"
docker compose down --remove-orphans
docker network prune -f
docker system prune -f
echo "✅ Cleanup complete"
echo ""

echo "🔨 Building Docker image..."
docker compose build --no-cache

echo ""
echo "⏳ Generating tiles from OSM data..."
echo "   This may take 10-30+ minutes depending on region size."
echo ""

docker compose --profile tile-generation up planetiler

if [ -f "$TILE_SERVER_DIR/data/tiles.pmtiles" ]; then
    SIZE=$(du -h "$TILE_SERVER_DIR/data/tiles.pmtiles" | cut -f1)
    echo ""
    echo "✅ Tile generation complete!"
    echo "   Location: $TILE_SERVER_DIR/data/tiles.pmtiles"
    echo "   Size: $SIZE"
    echo ""
    echo "Next: Run 'docker compose up tile-server' to start serving tiles"
else
    echo "❌ Tile generation failed - tiles.pmtiles not found"
    echo ""
    echo "Troubleshooting:"
    echo "  - Check Docker daemon is running: docker ps"
    echo "  - Clean up Docker: docker system prune -f"
    echo "  - Check disk space: df -h"
    echo "  - View logs: docker compose logs planetiler"
    exit 1
fi
