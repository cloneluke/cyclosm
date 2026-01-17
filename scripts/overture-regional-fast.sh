#!/bin/bash
# Fastest approach: Download single parquet file and filter locally
# No S3 querying - just direct download + local DuckDB filtering

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
DATA_DIR="${REPO_ROOT}/infrastructure/tile-server/data"

# Download one part file, filter locally, convert to PMTiles
STATE="${1:-colorado}"
OUTPUT_FILE="$DATA_DIR/overture-regional-${STATE}.pmtiles"

# State bounds
declare -A BOUNDS=(
    ["colorado"]="-109.06,36.99,-102.05,41.00"
    ["minnesota"]="-97.24,43.50,-89.49,49.38"
    ["tennessee"]="-90.31,35.00,-81.61,36.68"
)

if [ -z "${BOUNDS[$STATE]}" ]; then
    echo "Unknown state: $STATE"
    exit 1
fi

BOUNDS_STR="${BOUNDS[$STATE]}"

echo "=== Overture Regional Tiles (Fast Local) ==="
echo "State: $STATE"
echo "Bounds: $BOUNDS_STR"
echo "Output: $OUTPUT_FILE"
echo ""

docker run --rm \
    -v "$DATA_DIR:/output" \
    python:3.11-slim bash -c "
set -e

# Minimal setup - just need duckdb
pip install -q duckdb

python3 << 'PYEOF'
import os, json, subprocess, shutil, urllib.request

state = '$STATE'
bounds_str = '$BOUNDS_STR'
output_file = '$OUTPUT_FILE'
bounds = [float(b) for b in bounds_str.split(',')]
minlon, minlat, maxlon, maxlat = bounds

temp_dir = f'/tmp/ov-{state}'
os.makedirs(temp_dir, exist_ok=True)

# Download ONE parquet file (fastest part)
s3_url = 'https://overturemaps-us-west-2.s3.amazonaws.com/release/2025-11-19.0/theme=transportation/type=segment/part-00000-c3696169-a53d-4223-b951-713a65de0bbb-c000.zstd.parquet'
local_file = f'{temp_dir}/segment.parquet'

print(f'Downloading parquet file (~100MB)...')
try:
    urllib.request.urlretrieve(s3_url, local_file)
    size_mb = os.path.getsize(local_file) / (1024*1024)
    print(f'Downloaded {size_mb:.1f}MB')
except Exception as e:
    print(f'Download failed: {e}')
    exit(1)

# Query locally with DuckDB
print('Setting up DuckDB with spatial support...')
import duckdb
conn = duckdb.connect()
conn.execute('INSTALL spatial; LOAD spatial;')

print(f'Filtering for {state}...')
sql = f'''
    SELECT ST_AsGeoJSON(geometry) as geom, class, subtype, id
    FROM read_parquet('{local_file}')
    WHERE ST_Intersects(geometry, ST_GeomFromText('POLYGON(({minlon} {minlat}, {maxlon} {minlat}, {maxlon} {maxlat}, {minlon} {maxlat}, {minlon} {minlat}))'))
'''

try:
    result = conn.execute(sql).fetchall()
    print(f'Found {len(result)} features in {state}')
    
    if len(result) == 0:
        print(f'No transportation data for {state} in this file')
        exit(1)
    
    # Convert to GeoJSON
    geojson_file = f'{temp_dir}/{state}.ndjson'
    print(f'Converting to GeoJSON...')
    with open(geojson_file, 'w') as f:
        for row in result:
            try:
                feat = {
                    'type': 'Feature',
                    'geometry': json.loads(row[0]),
                    'properties': {'class': row[1], 'subtype': row[2], 'id': row[3]}
                }
                f.write(json.dumps(feat) + '\n')
            except:
                pass
    
    # Convert to PMTiles using tippecanoe
    print('Installing tippecanoe...')
    import subprocess
    subprocess.run(['apt-get', 'update', '-qq'], check=False)
    subprocess.run(['apt-get', 'install', '-y', '-qq', 'tippecanoe'], check=True)
    
    print('Converting to PMTiles (this may take a moment)...')
    subprocess.run([
        'tippecanoe', '-f', '-o', output_file,
        '-n', f'Overture {state}',
        '-l', 'segment',
        geojson_file
    ], check=True)
    
    size = os.path.getsize(output_file) / (1024*1024)
    print(f'✓ Generated {output_file} ({size:.1f}MB)')
    shutil.rmtree(temp_dir, ignore_errors=True)
    
except Exception as e:
    print(f'Error: {e}')
    import traceback
    traceback.print_exc()
    exit(1)
PYEOF
"

if [ -f "$OUTPUT_FILE" ]; then
    SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
    echo ""
    echo "✓ SUCCESS! Generated $OUTPUT_FILE ($SIZE)"
    echo ""
    echo "To use these tiles:"
    echo "  1. Start tile server: python3 -m http.server 8000 -d $DATA_DIR"
    echo "  2. Update .env.local:"
    echo "     VITE_OVERTURE_SEGMENT_PM_TILES=http://localhost:8000/overture-regional-${STATE}.pmtiles"
else
    echo "✗ Failed to generate PMTiles"
    exit 1
fi
