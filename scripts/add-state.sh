#!/bin/bash
set -e

# Add State to Cyclosm Tile Coverage
# Usage: ./scripts/add-state.sh colorado
# Downloads OSM data and updates entrypoint.sh automatically

if [ -z "$1" ]; then
    echo "Usage: $0 <state-code>"
    echo "Example: $0 kentucky"
    echo ""
    echo "Available states on Geofabrik:"
    echo "  alabama, alaska, arizona, arkansas, california, colorado"
    echo "  connecticut, delaware, florida, georgia, hawaii, idaho"
    echo "  illinois, indiana, iowa, kansas, kentucky, louisiana"
    echo "  maine, maryland, massachusetts, michigan, minnesota, mississippi"
    echo "  missouri, montana, nebraska, nevada, new-hampshire, new-jersey"
    echo "  new-mexico, new-york, north-carolina, north-dakota, ohio, oklahoma"
    echo "  oregon, pennsylvania, rhode-island, south-carolina, south-dakota"
    echo "  tennessee, texas, utah, vermont, virginia, washington"
    echo "  west-virginia, wisconsin, wyoming"
    exit 1
fi

STATE_CODE="${1}"
STATE_LOWER=$(echo "$STATE_CODE" | tr '[:upper:]' '[:lower:]')
STATE_NAME=$(echo "$STATE_LOWER" | sed 's/-/ /g' | sed 's/\b\(.\)/\U\1/g')

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENTRYPOINT="$REPO_ROOT/infrastructure/tile-server/entrypoint.sh"

if [ ! -f "$ENTRYPOINT" ]; then
    echo "❌ entrypoint.sh not found at $ENTRYPOINT"
    exit 1
fi

# Verify state not already present
if grep -q "sources/${STATE_LOWER}.osm.pbf" "$ENTRYPOINT"; then
    echo "❌ $STATE_NAME already in coverage!"
    grep "sources/${STATE_LOWER}.osm.pbf" "$ENTRYPOINT" | head -1
    exit 1
fi

echo "📍 Adding $STATE_NAME to Cyclosm tile coverage..."

# Find the line with "# Download state files" or similar
DOWNLOAD_SECTION_LINE=$(grep -n "download\|Download" "$ENTRYPOINT" | head -1 | cut -d: -f1)

if [ -z "$DOWNLOAD_SECTION_LINE" ]; then
    DOWNLOAD_SECTION_LINE=$(grep -n "curl.*geofabrik" "$ENTRYPOINT" | head -1 | cut -d: -f1)
fi

# Find the osmium merge line
MERGE_LINE=$(grep -n "osmium merge -o" "$ENTRYPOINT" | cut -d: -f1)

if [ -z "$MERGE_LINE" ]; then
    echo "❌ Could not find osmium merge command in entrypoint.sh"
    exit 1
fi

# Extract all current states from merge command (in order)
CURRENT_STATES=$(sed -n "${MERGE_LINE},$((MERGE_LINE+50))p" "$ENTRYPOINT" | \
    grep -oE "sources/[a-z0-9\-]+\.osm\.pbf" | \
    sed 's|sources/||' | sed 's/\.osm\.pbf//' | tr '\n' ' ')

# Add new state and sort alphabetically
ALL_STATES=$(echo "$CURRENT_STATES $STATE_LOWER" | tr ' ' '\n' | sort | tr '\n' ' ')

echo "✅ Current states: $CURRENT_STATES"
echo "➕ Adding state: $STATE_LOWER"
echo "📦 New coverage: $ALL_STATES"

# Build new merge command with all states (8 states per line for readability)
NEW_MERGE_CMD="echo \"Merging $(($(echo $ALL_STATES | wc -w)) - 1) states...\"
osmium merge -o /data/sources/merged.osm.pbf --overwrite \\"

count=0
for state in $ALL_STATES; do
    if [ $count -eq 0 ]; then
        NEW_MERGE_CMD="$NEW_MERGE_CMD
             /data/sources/${state}.osm.pbf \\"
    elif [ $((count % 8)) -eq 0 ]; then
        NEW_MERGE_CMD="$NEW_MERGE_CMD
             /data/sources/${state}.osm.pbf \\"
    else
        NEW_MERGE_CMD="$NEW_MERGE_CMD /data/sources/${state}.osm.pbf \\"
    fi
    ((count++))
done

# Remove last backslash
NEW_MERGE_CMD=$(echo "$NEW_MERGE_CMD" | sed '$ s/ \\$//')

# Find and replace the merge block (from osmium merge to osmconvert line)
START_LINE=$MERGE_LINE
END_LINE=$(sed -n "${MERGE_LINE},$((MERGE_LINE+100))p" "$ENTRYPOINT" | \
    grep -n "osmconvert /data/sources/merged.osm.pbf" | cut -d: -f1)

if [ -z "$END_LINE" ]; then
    END_LINE=$((MERGE_LINE + 30))  # Fallback
else
    END_LINE=$((MERGE_LINE + END_LINE - 2))  # 2 lines before osmconvert
fi

# Create backup
cp "$ENTRYPOINT" "${ENTRYPOINT}.backup"
echo "📋 Backup created: entrypoint.sh.backup"

# Replace the merge command section
{
    sed -n "1,$((START_LINE - 1))p" "$ENTRYPOINT"
    echo "$NEW_MERGE_CMD"
    echo ""
    sed -n "$((END_LINE + 1)),\$p" "$ENTRYPOINT"
} > "$ENTRYPOINT.new"

mv "$ENTRYPOINT.new" "$ENTRYPOINT"

echo ""
echo "✅ Updated entrypoint.sh with $STATE_NAME"
echo ""
echo "Next steps:"
echo "  1. Review changes: git diff infrastructure/tile-server/entrypoint.sh"
echo "  2. Test: cd infrastructure/tile-server && docker compose up"
echo "  3. Tile generation starts automatically (check with: docker ps)"
echo ""
echo "Generation time for this state: ~30 seconds"
echo "Total with $(echo $ALL_STATES | wc -w) states: ~3-5 minutes"
