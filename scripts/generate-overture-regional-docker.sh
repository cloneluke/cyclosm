#!/bin/bash
# Generate regional Overture PMTiles using Docker
# Generates only the state data needed, avoiding 117GB download

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
    echo "Generate regional Overture transportation PMTiles by state (Docker-based)"
    echo ""
    echo "Prerequisites:"
    echo "  - Docker installed and running"
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
    echo "  $(basename $0) all"
}

function generate_state_tiles() {
    local state=$1
    local bounds=$2
    local force=$3
    
    local output_file="$DATA_DIR/overture-${state}.pmtiles"
    
    if [ -f "$output_file" ] && [ "$force" != "true" ]; then
        SIZE=$(du -h "$output_file" | cut -f1)
        echo "✓ Already exists: $output_file ($SIZE)"
        return 0
    fi
    
    echo "=== Generating Overture PMTiles for $state ==="
    echo "Bounds: $bounds"
    echo "Output: $output_file"
    echo ""
    
    if ! command -v docker &> /dev/null; then
        echo "ERROR: Docker not found. Install Docker first."
        return 1
    fi
    
    # Run DuckDB + Tippecanoe in Docker container
    docker run --rm \
        -v "$DATA_DIR:/output" \
        -e STATE="$state" \
        -e BOUNDS="$bounds" \
        -e OUTPUT="/output/overture-${state}.pmtiles" \
        python:3.11-slim \
        bash -c '
set -e
apt-get update -qq && apt-get install -y -qq tippecanoe git libspatialindex-dev
pip install -q duckdb

python3 << "PYTHONEOF"
import sys
import os
import json
import subprocess
import shutil
import duckdb

state = os.environ.get("STATE", "colorado")
bounds_str = os.environ.get("BOUNDS", "-109.06,36.99,-102.05,41.00")
output_file = os.environ.get("OUTPUT", f"/output/overture-{state}.pmtiles")

bounds = bounds_str.split(",")
minlon, minlat, maxlon, maxlat = float(bounds[0]), float(bounds[1]), float(bounds[2]), float(bounds[3])

temp_dir = f"/tmp/overture-{state}"
os.makedirs(temp_dir, exist_ok=True)

print(f"Setting up DuckDB with httpfs...")
conn = duckdb.connect()
conn.execute("INSTALL httpfs; LOAD httpfs;")
conn.execute("INSTALL spatial; LOAD spatial;")

print(f"Querying Overture S3 for {state} in bounds {minlon},{minlat},{maxlon},{maxlat}...")

try:
    # Overture Maps S3 bucket: s3://overturemaps-us-west-2/release/YYYY-MM-DD.0/
    # Files are compressed .zstd.parquet format
    s3_base = "s3://overturemaps-us-west-2/release/2025-11-19.0"
    s3_path = f"{s3_base}/theme=transportation/type=segment/part-*.zstd.parquet"
    
    print(f"Querying S3 path: {s3_path}")
    
    # Build SQL query with proper string escaping
    sql_template = """
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
        FROM read_parquet('%s')
        WHERE ST_Intersects(
            geometry,
            ST_BBox(%s, %s, %s, %s)
        )
        LIMIT 1000000
    """
    sql = sql_template % (s3_path, minlon, minlat, maxlon, maxlat)
    result = conn.execute(sql).fetchall()
    print(f"✓ Successfully queried Overture S3")
        
except Exception as e:
    print(f"Error querying S3: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

if not result:
    print(f"No data found for {state}")
    sys.exit(1)

print(f"Retrieved {len(result)} features")

geojson_file = f"{temp_dir}/{state}.ndjson"
print(f"Writing GeoJSON to {geojson_file}...")

with open(geojson_file, "w") as f:
    for row in result:
        try:
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
        except Exception as e:
            print(f"Error processing feature: {e}")
            continue

print(f"Running tippecanoe...")
cmd = [
    "tippecanoe",
    "-f",
    "-o", output_file,
    "-n", f"Overture {state.title()}",
    "-A", "Overture Maps Foundation",
    "-z", "14",
    "-l", "segment",
    geojson_file
]

result = subprocess.run(cmd, capture_output=True, text=True)
if result.returncode != 0:
    print(f"Tippecanoe error: {result.stderr}")
    sys.exit(1)

print(f"✓ Generated: {output_file}")
shutil.rmtree(temp_dir, ignore_errors=True)
PYTHONEOF
'
    
    if [ -f "$output_file" ]; then
        SIZE=$(du -h "$output_file" | cut -f1)
        echo "✓ Success: $output_file ($SIZE)"
        echo ""
        echo "Update .env.local:"
        echo "  VITE_OVERTURE_SEGMENT_PM_TILES=file://$output_file"
        return 0
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
    FAILED=0
    for state in "${!STATE_BOUNDS[@]}"; do
        generate_state_tiles "$state" "${STATE_BOUNDS[$state]}" "$FORCE" || ((FAILED++))
        echo ""
    done
    if [ $FAILED -gt 0 ]; then
        echo "Failed to generate $FAILED states"
        exit 1
    fi
else
    if [ ! "${STATE_BOUNDS[$STATE]}" ]; then
        echo "Unknown state: $STATE"
        exit 1
    fi
    
    generate_state_tiles "$STATE" "${STATE_BOUNDS[$STATE]}" "$FORCE"
fi
