#!/bin/bash
# Generate regional Overture PMTiles by state
# Downloads Overture parquet from S3, filters by bounding box, and generates PMTiles

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
DATA_DIR="${REPO_ROOT}/infrastructure/tile-server/data"

# State bounding boxes [minlon, minlat, maxlon, maxlat]
declare -A STATE_BOUNDS=(
    ["colorado"]="-109.06,36.99,-102.05,41.00"
    ["minnesota"]="-97.24,43.50,-89.49,49.38"
    ["iowa"]="-96.64,40.38,-90.14,43.50"
    ["south-dakota"]="-104.06,42.48,-96.44,45.95"
    ["wyoming"]="-111.06,41.00,-104.05,45.01"
    ["utah"]="-114.05,37.00,-109.04,42.00"
    ["new-mexico"]="-109.06,31.78,-103.00,37.00"
    ["arizona"]="-114.82,31.33,-109.04,37.00"
    ["nevada"]="-120.01,35.00,-114.64,42.00"
    ["california"]="-124.42,32.54,-114.13,42.00"
)

function show_help() {
    echo "Generate regional Overture transportation PMTiles by state"
    echo ""
    echo "Prerequisites:"
    echo "  - Python 3 with duckdb: pip install duckdb"
    echo "  - tippecanoe: apt install tippecanoe"
    echo "  - AWS access for S3 (optional, uses public bucket)"
    echo ""
    echo "Usage: $(basename $0) [state] [options]"
    echo ""
    echo "Available states:"
    for state in "${!STATE_BOUNDS[@]}"; do
        echo "  - $state"
    done | sort
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help"
    echo "  -f, --force    Force regeneration"
    echo ""
    echo "Examples:"
    echo "  $(basename $0) colorado"
    echo "  $(basename $0) minnesota --force"
}

function check_tools() {
    local missing=()
    
    if ! command -v python3 &> /dev/null; then
        missing+=("python3")
    fi
    
    if ! python3 -c "import duckdb" 2>/dev/null; then
        missing+=("duckdb (pip install duckdb)")
    fi
    
    if ! command -v tippecanoe &> /dev/null; then
        missing+=("tippecanoe (apt install tippecanoe)")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo "Missing dependencies:"
        for dep in "${missing[@]}"; do
            echo "  - $dep"
        done
        exit 1
    fi
}

function generate_state_tiles() {
    local state=$1
    local bounds=$2
    local force=$3
    
    local output_file="$DATA_DIR/overture-${state}.pmtiles"
    
    if [ -f "$output_file" ] && [ "$force" != "true" ]; then
        echo "✓ Already exists: $output_file"
        return
    fi
    
    echo "=== Generating $state ==="
    echo "Bounds: $bounds"
    echo "Output: $output_file"
    echo ""
    
    # Create Python script to extract and convert
    local temp_dir="/tmp/overture-${state}"
    mkdir -p "$temp_dir"
    
    python3 << 'PYTHON_SCRIPT'
import sys
import duckdb
import json
import subprocess
import os
import shutil

state = sys.argv[1]
bounds = sys.argv[2].split(",")
minlon, minlat, maxlon, maxlat = float(bounds[0]), float(bounds[1]), float(bounds[2]), float(bounds[3])
temp_dir = sys.argv[3]
output_pmtiles = sys.argv[4]

print(f"Connecting to Overture S3...")

# Use DuckDB to query parquet from S3 directly
conn = duckdb.connect()
conn.execute("INSTALL httpfs; LOAD httpfs;")

# Query Overture data for the region
print(f"Querying Overture for {state}...")
result = conn.execute(f"""
    SELECT 
        ST_AsGeoJSON(geometry) as geometry,
        class,
        subtype,
        surface,
        access,
        oneway,
        toll,
        speed_limit,
        lanes,
        id
    FROM read_parquet('s3://overture-maps-prod/2025-11-19/theme=transportation/type=segment/part-*.parquet')
    WHERE ST_Intersects(
        geometry,
        ST_BBox({minlon}, {minlat}, {maxlon}, {maxlat})
    )
    LIMIT 10000000
""").fetch_all()

if not result:
    print(f"No data found for {state}")
    sys.exit(1)

# Convert to newline-delimited GeoJSON for tippecanoe
geojson_file = f"{temp_dir}/{state}.ndjson"
print(f"Writing {len(result)} features to {geojson_file}...")

with open(geojson_file, 'w') as f:
    for row in result:
        geometry = json.loads(row[0])
        feature = {
            "type": "Feature",
            "geometry": geometry,
            "properties": {
                "class": row[1],
                "subtype": row[2],
                "surface": row[3],
                "access": row[4],
                "oneway": row[5],
                "toll": row[6],
                "speed_limit": row[7],
                "lanes": row[8],
                "id": row[9]
            }
        }
        f.write(json.dumps(feature) + "\n")

print(f"Generated {geojson_file}")
print("Running tippecanoe...")

# Generate PMTiles with tippecanoe
cmd = [
    "tippecanoe",
    "-f",
    "-o", output_pmtiles,
    "-n", f"Overture {state}",
    "-A", "Overture Maps Foundation",
    "-z", "14",
    "-l", "segment",
    geojson_file
]

subprocess.run(cmd, check=True)
print(f"✓ Generated: {output_pmtiles}")

# Cleanup
shutil.rmtree(temp_dir, ignore_errors=True)

PYTHON_SCRIPT
    
    python3 - "$state" "$bounds" "$temp_dir" "$output_file" << 'PYTHON_SCRIPT'
import sys
import duckdb
import json
import subprocess
import os
import shutil

state = sys.argv[1]
bounds = sys.argv[2].split(",")
minlon, minlat, maxlon, maxlat = float(bounds[0]), float(bounds[1]), float(bounds[2]), float(bounds[3])
temp_dir = sys.argv[3]
output_pmtiles = sys.argv[4]

print(f"Connecting to Overture S3...")

# Use DuckDB to query parquet from S3 directly
conn = duckdb.connect()
conn.execute("INSTALL httpfs; LOAD httpfs;")

# Query Overture data for the region
print(f"Querying Overture for {state}...")
result = conn.execute(f"""
    SELECT 
        ST_AsGeoJSON(geometry) as geometry,
        class,
        subtype,
        surface,
        access,
        oneway,
        toll,
        speed_limit,
        lanes,
        id
    FROM read_parquet('s3://overture-maps-prod/2025-11-19/theme=transportation/type=segment/part-*.parquet')
    WHERE ST_Intersects(
        geometry,
        ST_BBox({minlon}, {minlat}, {maxlon}, {maxlat})
    )
    LIMIT 10000000
""").fetch_all()

if not result:
    print(f"No data found for {state}")
    sys.exit(1)

# Convert to newline-delimited GeoJSON for tippecanoe
geojson_file = f"{temp_dir}/{state}.ndjson"
print(f"Writing {len(result)} features to {geojson_file}...")

with open(geojson_file, 'w') as f:
    for row in result:
        geometry = json.loads(row[0])
        feature = {
            "type": "Feature",
            "geometry": geometry,
            "properties": {
                "class": row[1],
                "subtype": row[2],
                "surface": row[3],
                "access": row[4],
                "oneway": row[5],
                "toll": row[6],
                "speed_limit": row[7],
                "lanes": row[8],
                "id": row[9]
            }
        }
        f.write(json.dumps(feature) + "\n")

print(f"Generated {geojson_file}")
print("Running tippecanoe...")

# Generate PMTiles with tippecanoe
cmd = [
    "tippecanoe",
    "-f",
    "-o", output_pmtiles,
    "-n", f"Overture {state}",
    "-A", "Overture Maps Foundation",
    "-z", "14",
    "-l", "segment",
    geojson_file
]

subprocess.run(cmd, check=True)
print(f"✓ Generated: {output_pmtiles}")

# Cleanup
shutil.rmtree(temp_dir, ignore_errors=True)

PYTHON_SCRIPT
    
    if [ -f "$output_file" ]; then
        SIZE=$(du -h "$output_file" | cut -f1)
        echo "✓ Success: $output_file ($SIZE)"
        echo ""
        echo "Update .env.local:"
        echo "  VITE_OVERTURE_SEGMENT_PM_TILES=file://$output_file"
    else
        echo "✗ Failed to generate PMTiles"
        return 1
    fi
}

# Main
STATE=""
FORCE="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--force)
            FORCE="true"
            shift
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

if [ "$STATE" = "all" ]; then
    check_tools
    for state in "${!STATE_BOUNDS[@]}"; do
        generate_state_tiles "$state" "${STATE_BOUNDS[$state]}" "$FORCE"
        echo ""
    done
else
    if [ ! "${STATE_BOUNDS[$STATE]}" ]; then
        echo "Unknown state: $STATE"
        exit 1
    fi
    
    check_tools
    generate_state_tiles "$STATE" "${STATE_BOUNDS[$STATE]}" "$FORCE"
fi
