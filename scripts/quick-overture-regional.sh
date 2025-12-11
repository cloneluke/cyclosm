#!/bin/bash
# Quick regional Overture PMTiles generation
# Downloads small regional parquet file and converts to PMTiles
# Much faster than full spatial query approach

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
DATA_DIR="${REPO_ROOT}/infrastructure/tile-server/data"

# State bounding boxes [minlon, minlat, maxlon, maxlat]
declare -A STATE_BOUNDS=(
    ["colorado"]="-109.06,36.99,-102.05,41.00"
    ["minnesota"]="-97.24,43.50,-89.49,49.38"
    ["iowa"]="-96.64,40.38,-90.14,43.50"
)

function generate_state() {
    local state=$1
    local bounds=$2
    local output_file="$DATA_DIR/overture-regional-${state}.pmtiles"
    
    echo "=== Generating Overture regional tiles for $state ==="
    echo "Bounds: $bounds"
    echo "Output: $output_file"
    
    docker run --rm \
        -v "$DATA_DIR:/output" \
        -e STATE="$state" \
        -e BOUNDS="$bounds" \
        -e OUTPUT="/output/overture-regional-${state}.pmtiles" \
        python:3.11-slim bash -c '
set -e

# Install only essentials
apt-get update -qq && apt-get install -y -qq tippecanoe
pip install -q duckdb

python3 << "PYTHONEOF"
import os, json, subprocess, shutil, duckdb

state = os.environ["STATE"]
bounds_str = os.environ["BOUNDS"]
output_file = os.environ["OUTPUT"]
bounds = [float(b) for b in bounds_str.split(",")]
minlon, minlat, maxlon, maxlat = bounds

temp_dir = f"/tmp/ov-{state}"
os.makedirs(temp_dir, exist_ok=True)

print(f"Setting up DuckDB...")
conn = duckdb.connect()
conn.execute("INSTALL httpfs; LOAD httpfs;")
conn.execute("INSTALL spatial; LOAD spatial;")

s3_path = "s3://overturemaps-us-west-2/release/2025-11-19.0/theme=transportation/type=segment/part-*.zstd.parquet"

print(f"Querying {state}...")
sql = f"""
    SELECT ST_AsGeoJSON(geometry) as geom, class, subtype, id
    FROM read_parquet('\''{s3_path}'\'')
    WHERE ST_Intersects(geometry, ST_BBox({minlon}, {minlat}, {maxlon}, {maxlat}))
"""

try:
    result = conn.execute(sql).fetchall()
    print(f"Found {len(result)} features")
    
    if len(result) == 0:
        print(f"No data for {state}")
        exit(1)
    
    # Write NDJSON
    geojson_file = f"{temp_dir}/{state}.ndjson"
    with open(geojson_file, "w") as f:
        for row in result:
            try:
                feat = {
                    "type": "Feature",
                    "geometry": json.loads(row[0]),
                    "properties": {"class": row[1], "subtype": row[2], "id": row[3]}
                }
                f.write(json.dumps(feat) + "\n")
            except: pass
    
    # Convert to PMTiles
    print(f"Converting to PMTiles...")
    subprocess.run([
        "tippecanoe", "-f", "-o", output_file,
        "-n", f"Overture {state}", "-l", "segment",
        geojson_file
    ], check=True)
    
    print(f"✓ Generated {output_file}")
    shutil.rmtree(temp_dir, ignore_errors=True)
    
except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()
    exit(1)
PYTHONEOF
'
    
    if [ -f "$output_file" ]; then
        SIZE=$(du -h "$output_file" | cut -f1)
        echo "✓ Success: $output_file ($SIZE)"
        return 0
    else
        echo "✗ Failed"
        return 1
    fi
}

# Main
if [ $# -eq 0 ]; then
    echo "Usage: $0 [state]"
    echo "Available: colorado, minnesota, iowa"
    exit 1
fi

generate_state "$1" "${STATE_BOUNDS[$1]}"
