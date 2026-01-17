#!/bin/bash
set -euo pipefail

# CyclOSM: Update all map data/tiles to latest (automated)
# - Cleans old data and tiles
# - Builds Docker image
# - Runs Planetiler generation (downloads latest OSM extracts, merges, generates PMTiles)
# - Starts tile server and verifies health

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TILE_SERVER_DIR="$PROJECT_ROOT/infrastructure/tile-server"
DATA_DIR="$TILE_SERVER_DIR/data"

info() { echo -e "\033[1;34m$1\033[0m"; }
ok()   { echo -e "\033[1;32m$1\033[0m"; }
err()  { echo -e "\033[1;31m$1\033[0m"; }

# Ensure docker permissions: re-exec inside docker group if needed
if ! groups | grep -q docker; then
  info "Adding docker group for this session (sg docker)"
  exec sg docker "$0"
fi

info "CyclOSM - Updating tiles to latest"
info "Project: $PROJECT_ROOT"
info "Tile server: $TILE_SERVER_DIR"

# Prepare data directory
mkdir -p "$DATA_DIR/sources" "$DATA_DIR/tmp"

# Ensure data directory is writable; if not, recreate with proper ownership
if ! touch "$DATA_DIR/.permcheck" 2>/dev/null; then
  info "Fixing permissions on $DATA_DIR (requires sudo)"
  if sudo -n true 2>/dev/null; then
    sudo rm -rf "$DATA_DIR"
    sudo mkdir -p "$DATA_DIR/sources" "$DATA_DIR/tmp"
    sudo chown -R "$USER":"$USER" "$DATA_DIR"
  else
    err "Data dir not writable and sudo not available. Please run:"
    echo "  sudo rm -rf '$DATA_DIR' && sudo mkdir -p '$DATA_DIR/sources' '$DATA_DIR/tmp' && sudo chown -R $USER:$USER '$DATA_DIR'"
    exit 1
  fi
fi
rm -f "$DATA_DIR/.permcheck"

# Stop any running services
info "Stopping existing containers (if any)..."
docker compose -f "$TILE_SERVER_DIR/docker-compose.yml" down --remove-orphans || true
info "Pruning stale Docker networks..."
docker network prune -f || true
docker system prune -f || true

# Clean old artifacts
info "Cleaning old data and tiles..."
rm -rf "$DATA_DIR/sources" "$DATA_DIR/tiles.pmtiles" "$DATA_DIR/tmp"
mkdir -p "$DATA_DIR/sources" "$DATA_DIR/tmp"
ok "Clean slate prepared in $DATA_DIR"

# Build/rebuild docker image
info "Building Docker image (no cache)..."
docker compose -f "$TILE_SERVER_DIR/docker-compose.yml" build --no-cache
ok "Docker image built"

# Pre-download OSM extracts to ensure merge has inputs (container will also download if missing)
states=(
  colorado minnesota iowa south-dakota nebraska north-dakota missouri kansas wisconsin tennessee \
  illinois south-carolina arkansas michigan indiana ohio oklahoma texas
)
info "Pre-downloading OSM extracts into $DATA_DIR/sources (parallel)..."
DOWNLOAD_PIDS=()
for s in "${states[@]}"; do
  if [ ! -f "$DATA_DIR/sources/$s.osm.pbf" ]; then
    info "  → Starting download: $s"
    (
      curl -L --retry 3 --retry-delay 2 --progress-bar \
        "https://download.geofabrik.de/north-america/us/$s-latest.osm.pbf" \
        -o "$DATA_DIR/sources/$s.osm.pbf" && \
      ok "  ✓ Completed: $s"
    ) &
    DOWNLOAD_PIDS+=($!)
  else
    ok "  ✓ Already exists: $s"
  fi
done

# Wait for all parallel downloads to complete
if [ ${#DOWNLOAD_PIDS[@]} -gt 0 ]; then
  info "Waiting for ${#DOWNLOAD_PIDS[@]} parallel downloads to complete..."
  for pid in "${DOWNLOAD_PIDS[@]}"; do
    wait "$pid" || err "WARNING: Download process $pid failed"
  done
  ok "All downloads completed!"
else
  ok "All state files already present"
fi

# Generate tiles (Planetiler)
info "Starting tile generation (this can take 10–40+ min)..."
# Run attached; if interrupted, you can re-run and it will resume/redo
set +e
GENERATE_LOG=$(docker compose -f "$TILE_SERVER_DIR/docker-compose.yml" --profile tile-generation up planetiler 2>&1)
GEN_EXIT=$?
set -e

# Show last logs for quick context
echo "$GENERATE_LOG" | tail -n 50

# Verify output
if [ $GEN_EXIT -ne 0 ]; then
  err "Tile generation process exited with code $GEN_EXIT"
  err "Check logs: docker compose logs planetiler"
  exit $GEN_EXIT
fi

if [ ! -f "$DATA_DIR/tiles.pmtiles" ]; then
  err "tiles.pmtiles not found in $DATA_DIR"
  err "Check logs: docker compose logs planetiler"
  exit 1
fi
ok "Tile generation complete: $DATA_DIR/tiles.pmtiles"

# Start tile server
info "Starting tile server..."
docker compose -f "$TILE_SERVER_DIR/docker-compose.yml" up -d tile-server

# Health check loop
info "Waiting for tile server health..."
ATTEMPTS=30
for i in $(seq 1 $ATTEMPTS); do
  STATUS=$(curl -sSf "http://localhost:8080/health" || true)
  if [[ "$STATUS" == "OK" ]]; then
    ok "Tile server healthy (attempt $i/$ATTEMPTS)"
    break
  fi
  sleep 2
done

if [[ "$STATUS" != "OK" ]]; then
  err "Tile server health check failed"
  err "Try: docker compose logs tile-server"
  exit 1
fi

ok "All set! Latest tiles are serving at http://localhost:8080"
info "PMTiles: $DATA_DIR/tiles.pmtiles"

# Helpful next steps
cat <<EOT

Follow-ups:
- Preview web app: (in another terminal)
  cd "$PROJECT_ROOT/apps/web" && npm run dev
- View logs:
  docker compose -f "$TILE_SERVER_DIR/docker-compose.yml" logs -f tile-server
- Stop services:
  docker compose -f "$TILE_SERVER_DIR/docker-compose.yml" down
EOT
