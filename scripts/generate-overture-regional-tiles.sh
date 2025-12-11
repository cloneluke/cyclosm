#!/bin/bash
# Generate regional Overture PMTiles by state
# Downloads Overture parquet from S3 and generates tiles for specific US states

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
DATA_DIR="${REPO_ROOT}/infrastructure/tile-server/data"
STATES_DIR="${DATA_DIR}/states"

# Define state bounding boxes [minlon, minlat, maxlon, maxlat]
# Source: https://en.wikipedia.org/wiki/U.S._state_and_territory_bounding_and_extreme_coordinates
declare -A STATE_BOUNDS=(
    ["colorado"]="-109.06 36.99 -102.05 41.00"
    ["minnesota"]="-97.24 43.50 -89.49 49.38"
    ["iowa"]="-96.64 40.38 -90.14 43.50"
    ["south-dakota"]="-104.06 42.48 -96.44 45.95"
    ["wyoming"]="-111.06 41.00 -104.05 45.01"
    ["utah"]="-114.05 37.00 -109.04 42.00"
    ["new-mexico"]="-109.06 31.78 -103.00 37.00"
    ["arizona"]="-114.82 31.33 -109.04 37.00"
    ["nevada"]="-120.01 35.00 -114.64 42.00"
    ["california"]="-124.42 32.54 -114.13 42.00"
)

function show_help() {
    echo "Generate regional Overture transportation PMTiles by state"
    echo ""
    echo "Usage: $(basename $0) [state] [options]"
    echo ""
    echo "States available:"
    for state in "${!STATE_BOUNDS[@]}"; do
        echo "  - $state"
    done | sort
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -d, --dry-run       Show what would be generated without running Planetiler"
    echo "  -j, --java          Use local Java (requires Java 21+)"
    echo "  --docker            Use Docker (default)"
    echo ""
    echo "Examples:"
    echo "  $(basename $0) colorado               # Generate Colorado tiles with Docker"
    echo "  $(basename $0) minnesota --java       # Generate Minnesota tiles with Java"
    echo "  $(basename $0) all --docker           # Generate all states"
}

function generate_config() {
    local state=$1
    local bounds=$2
    local config_file="$DATA_DIR/planetiler-overture-${state}-config.yaml"
    
    IFS=' ' read -r minlon minlat maxlon maxlat <<< "$bounds"
    
    cat > "$config_file" << EOF
schema_name: CyclOSM Overture $(echo $state | sed 's/-/ /g' | sed 's/\b./\u&/g')
schema_description: Cycling-focused map using Overture Maps data for $(echo $state | sed 's/-/ /g') region
attribution: <a href="https://overturemaps.org">&copy; Overture Maps Foundation</a>

sources:
  overture_transportation:
    type: geoparquet
    location: s3://overture-maps-prod/2025-11-19/theme=transportation/type=segment/part-*.parquet
    sql: |
      SELECT * FROM \`{file}\` 
      WHERE ST_Intersects(geometry, ST_BBox($minlon, $minlat, $maxlon, $maxlat))

tag_mappings:
  zoom_level: integer
  confidence: integer

layers:
  - id: segment
    features:
      - source: overture_transportation
        geometry: line
        min_zoom: 0
        max_zoom: 14
        attributes:
          - key: class
          - key: subtype
          - key: surface
          - key: access
          - key: oneway
            type: boolean
          - key: toll
            type: boolean
          - key: speed_limit
            type: integer
          - key: lanes
            type: integer
          - key: id

defaults:
  postprocess:
    zoom: 14

tile_compression: gzip
EOF
    
    echo "$config_file"
}

function generate_tiles() {
    local state=$1
    local use_java=${2:-false}
    
    if [ ! "${STATE_BOUNDS[$state]}" ]; then
        echo "ERROR: Unknown state: $state"
        echo "Available states: ${!STATE_BOUNDS[@]}"
        exit 1
    fi
    
    echo "=== Generating Overture PMTiles for $state ==="
    echo ""
    
    # Generate config
    local config_file=$(generate_config "$state" "${STATE_BOUNDS[$state]}")
    local output_file="$DATA_DIR/overture-${state}.pmtiles"
    
    echo "Config: $config_file"
    echo "Output: $output_file"
    echo "Bounds: ${STATE_BOUNDS[$state]}"
    echo ""
    
    if [ "$use_java" = true ]; then
        # Local Java execution
        if ! command -v java &> /dev/null; then
            echo "ERROR: Java not found. Install with: sudo apt install openjdk-21-jre-headless"
            exit 1
        fi
        
        JAVA_VERSION=$(java -version 2>&1 | grep -oP 'version "\K[0-9]+' | head -1)
        if [ "$JAVA_VERSION" -lt 21 ]; then
            echo "ERROR: Java 21+ required, found $JAVA_VERSION"
            exit 1
        fi
        
        if [ ! -f "/usr/local/bin/planetiler.jar" ]; then
            echo "Downloading Planetiler..."
            sudo curl -L https://github.com/onthegomap/planetiler/releases/download/v0.9.3/planetiler.jar \
                -o /usr/local/bin/planetiler.jar
            sudo chmod +x /usr/local/bin/planetiler.jar
        fi
        
        echo "Starting Planetiler with Java..."
        java -Xmx16g -jar /usr/local/bin/planetiler.jar \
            --schema "$config_file" \
            --output "$output_file" \
            --minzoom 0 \
            --maxzoom 14 \
            --tile-compression gzip \
            --threads $(nproc)
    else
        # Docker execution
        if ! command -v docker &> /dev/null; then
            echo "ERROR: Docker not found. Install Docker or use --java flag"
            exit 1
        fi
        
        echo "Starting Planetiler with Docker..."
        docker run --rm \
            -v "$DATA_DIR:/data" \
            -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
            -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
            eclipse-temurin:21-jre \
            bash -c 'apt-get update -qq && apt-get install -y -qq curl && \
                curl -sL https://github.com/onthegomap/planetiler/releases/download/v0.9.3/planetiler.jar \
                    -o /usr/local/bin/planetiler.jar && \
                java -Xmx16g -jar /usr/local/bin/planetiler.jar \
                    --schema /data/planetiler-overture-'${state}'-config.yaml \
                    --output /data/overture-'${state}'.pmtiles \
                    --minzoom 0 \
                    --maxzoom 14 \
                    --tile-compression gzip \
                    --threads '$(nproc)
    fi
    
    if [ -f "$output_file" ]; then
        SIZE=$(du -h "$output_file" | cut -f1)
        echo ""
        echo "✓ Successfully generated: $output_file ($SIZE)"
        echo ""
        echo "Next steps:"
        echo "1. Update .env.local to use this file:"
        echo "   VITE_OVERTURE_SEGMENT_PM_TILES=file://$output_file"
        echo "2. Restart dev server"
        echo "3. Test in browser"
    else
        echo "ERROR: Tile generation failed"
        exit 1
    fi
}

# Parse arguments
STATE=""
USE_JAVA=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -j|--java)
            USE_JAVA=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        --docker)
            USE_JAVA=false
            shift
            ;;
        all)
            for state in "${!STATE_BOUNDS[@]}"; do
                generate_tiles "$state" "$USE_JAVA"
                echo ""
            done
            exit 0
            ;;
        *)
            STATE=$1
            shift
            ;;
    esac
done

if [ -z "$STATE" ]; then
    show_help
    exit 1
fi

generate_tiles "$STATE" "$USE_JAVA"
