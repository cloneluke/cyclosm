#!/bin/bash
# Configure app to use local Overture tiles

REPO_ROOT="/home/luke/git-repos/cyclosm"
ENV_FILE="$REPO_ROOT/apps/web/.env.local"
PMTILES_FILE="$REPO_ROOT/infrastructure/tile-server/data/overture-transportation.pmtiles"

if [ ! -f "$PMTILES_FILE" ]; then
    echo "ERROR: PMTiles file not found at $PMTILES_FILE"
    echo "Download may still be in progress. Check with:"
    echo "  ls -lh $PMTILES_FILE"
    exit 1
fi

echo "Found PMTiles file: $(du -h $PMTILES_FILE | cut -f1)"

# Update .env.local to use local file
# Use file:// URL for local PMTiles with pmtiles:// protocol handler
cat > "$ENV_FILE" << 'EOF'
VITE_OVERTURE_SEGMENT_PM_TILES=file:///home/luke/git-repos/cyclosm/infrastructure/tile-server/data/overture-transportation.pmtiles
VITE_OVERTURE_SEGMENT_LAYER=segment
EOF

echo "✓ Updated .env.local to use local Overture tiles"
echo ""
echo "Next steps:"
echo "1. Restart the dev server: cd $REPO_ROOT/apps/web && pnpm dev"
echo "2. Refresh browser at http://localhost:5173/"
echo "3. Toggle Overture on and zoom to different levels"
echo "4. Purple cycleways should appear at all zoom levels now!"
