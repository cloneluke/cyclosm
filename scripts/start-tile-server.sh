#!/bin/bash
set -e

# If not running as docker group, re-execute with proper permissions
if ! groups | grep -q docker; then
    exec sg docker "$0"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TILE_SERVER_DIR="$PROJECT_ROOT/infrastructure/tile-server"

echo "🚀 CyclOSM Vector - Tile Server"
echo "================================"
echo ""

# Verify Docker is available
if ! docker ps &> /dev/null; then
    echo "❌ Docker is not available. Run ./scripts/setup-docker.sh first."
    exit 1
fi

# Check if tiles exist
if [ ! -f "$TILE_SERVER_DIR/data/tiles.pmtiles" ]; then
    echo "❌ Tiles not found at: $TILE_SERVER_DIR/data/tiles.pmtiles"
    echo ""
    echo "Generate tiles first:"
    echo "  ./scripts/generate-tiles.sh"
    exit 1
fi

SIZE=$(du -h "$TILE_SERVER_DIR/data/tiles.pmtiles" | cut -f1)
echo "✅ Tiles found: $SIZE"
echo ""

echo "🏗️  Starting tile server..."
cd "$TILE_SERVER_DIR"

# Check if containers are already running
if docker compose ps --services | grep -q tile-server; then
    echo "⚠️  Stopping existing containers..."
    docker compose down
fi

echo ""
echo "Starting services..."
docker compose up tile-server

echo ""
echo "📍 Tile server running at: http://localhost:8080"
echo ""
echo "Test endpoints:"
echo "  curl http://localhost:8080/health"
echo "  curl http://localhost:8080/tiles/0/0/0.pbf"
echo ""
echo "Press Ctrl+C to stop"
