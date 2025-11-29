#!/bin/bash
# refresh-tiles.sh - Refresh all tiles with latest OSM data
# Can be run manually or via cron for scheduled updates

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data/sources"
LOG_FILE="$SCRIPT_DIR/refresh-tiles.log"

# Check for --cron flag for automated runs (no prompts)
CRON_MODE=false
if [[ "$1" == "--cron" ]]; then
    CRON_MODE=true
fi

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=========================================="
log "CyclOSM Tile Refresh Script"
log "=========================================="

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    log "Error: docker-compose is not installed"
    exit 1
fi

log "Step 1: Removing old OSM source files..."
cd "$SCRIPT_DIR"

# List files that will be deleted
log "Files to be deleted and re-downloaded:"
ls -lh "$DATA_DIR"/*.osm.pbf 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}' || log "  (no files found)"

# Skip prompt in cron mode
if [ "$CRON_MODE" = false ]; then
    read -p "Continue with refresh? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Refresh cancelled."
        exit 0
    fi
fi

log ""
log "Removing OSM files..."
rm -f "$DATA_DIR"/*.osm.pbf
log "✓ Old OSM files removed"

log ""
log "Step 2: Removing old merged file..."
rm -f "$DATA_DIR/merged.osm.pbf"
log "✓ Merged file removed"

log ""
log "Step 3: Removing old tiles..."
rm -f "$DATA_DIR/../tiles.pmtiles"
log "✓ Tiles file removed"

log ""
log "Step 4: Building Docker image..."
docker-compose build --no-cache planetiler 2>&1 | tail -3 | tee -a "$LOG_FILE"

log ""
log "Step 5: Downloading latest OSM data and generating fresh tiles..."
log "This will take several minutes..."
log ""

docker-compose -p tile-server run --rm planetiler tile-generation 2>&1 | tail -20 | tee -a "$LOG_FILE"

log ""
log "Step 6: Restarting tile server..."
docker-compose restart tile-server
sleep 2

# Verify
SIZE=$(curl -s -I http://localhost:8080/tiles.pmtiles 2>/dev/null | grep Content-Length | awk '{print $2}' | tr -d '\r')
if [ ! -z "$SIZE" ]; then
    log "✓ Tile server running with new tiles ($(numfmt --to=iec $SIZE 2>/dev/null || echo $SIZE bytes))"
else
    log "⚠ Could not verify tile size"
fi

log ""
log "=========================================="
log "Tile refresh complete!"
log "=========================================="
log ""

if [ "$CRON_MODE" = false ]; then
    log "Next steps:"
    log "1. Go to http://localhost:5173"
    log "2. Hard refresh browser: Ctrl+Shift+R (Windows/Linux) or Cmd+Shift+R (Mac)"
    log "3. Tiles will now show latest OSM data"
    log ""
fi
