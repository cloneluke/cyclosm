#!/bin/bash
# Simplest approach: Query Overture directly from S3 with DuckDB, convert to PMTiles

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
DATA_DIR="${REPO_ROOT}/infrastructure/tile-server/data"

STATE="${1:-colorado}"
OUTPUT_FILE="$DATA_DIR/overture-regional-${STATE}.pmtiles"

# State bounds
declare -A BOUNDS=(
    ["colorado"]="-109.06,36.99,-102.05,41.00"
    ["minnesota"]="-97.24,43.50,-89.49,49.38"
)

if [ -z "${BOUNDS[$STATE]}" ]; then
    echo "Unknown state: $STATE"
    exit 1
fi

BOUNDS_STR="${BOUNDS[$STATE]}"

echo "=== Overture Regional Tiles ==="
echo "State: $STATE"
echo "Bounds: $BOUNDS_STR"
echo "Output: $OUTPUT_FILE"
echo ""

docker run --rm \
    -v "$DATA_DIR:/output" \
    python:3.11-slim bash -c "
set -e

pip install -q duckdb

python3 << 'PYEOF'
import os, json, subprocess

state = '$STATE'
bounds_str = '$BOUNDS_STR'
output_file = '$OUTPUT_FILE'
bounds = [float(b) for b in bounds_str.split(',')]
minlon, minlat, maxlon, maxlat = bounds

temp_dir = f'/tmp/ov-{state}'
os.makedirs(temp_dir, exist_ok=True)

print(f'Setting up DuckDB with spatial extension...')
import duckdb
conn = duckdb.connect()
conn.execute('INSTALL spatial; LOAD spatial;')

print(f'Querying Overture transportation data for {state}...')
print(f'  Bounds: lon [{minlon},{maxlon}], lat [{minlat},{maxlat}]')

# Build bbox polygon
bbox_wkt = f'POLYGON(({minlon} {minlat}, {maxlon} {minlat}, {maxlon} {maxlat}, {minlon} {maxlat}, {minlon} {minlat}))'

sql = f'''
    SELECT ST_AsGeoJSON(geometry) as geom, class, subtype, id
    FROM read_parquet('s3://overturemaps-us-west-2/release/2025-11-19.0/theme=transportation/type=segment/part-*.zstd.parquet')
    WHERE ST_Intersects(geometry, ST_GeomFromText('{bbox_wkt}'))
    LIMIT 100000
'''

try:
    result = conn.execute(sql).fetchall()
    count = len(result)
    print(f'  Found {count} features')
    
    if count == 0:
        print(f'No transportation data for {state}')
        exit(1)
    
    # Convert to NDJSON
    geojson_file = f'{temp_dir}/{state}.ndjson'
    print(f'Writing {count} features to GeoJSON...')
    with open(geojson_file, 'w') as f:
        for row in result:
            try:
                feat = {
                    'type': 'Feature',
                    'geometry': json.loads(row[0]),
                    'properties': {'class': row[1], 'subtype': row[2], 'id': row[3]}
                }
                f.write(json.dumps(feat) + '\\n')
            except Exception as e:
                pass
    
    print(f'Installing tippecanoe...')
    subprocess.run(['apt-get', 'update', '-qq'], check=False, capture_output=True)
    subprocess.run(['apt-get', 'install', '-y', '-qq', 'tippecanoe'], check=True, capture_output=True)
    
    print(f'Converting to PMTiles...')
    subprocess.run([
        'tippecanoe', '-f', '-o', output_file,
        '-n', f'Overture {state}',
        '-l', 'segment',
        '--minimum-zoom=0', '--maximum-zoom=14',
        geojson_file
    ], check=True)
    
    size = os.path.getsize(output_file) / (1024*1024)
    print(f'✓ Generated {output_file} ({size:.1f}MB)')
    
    import shutil
    shutil.rmtree(temp_dir, ignore_errors=True)
    
except Exception as e:
    print(f'ERROR: {e}')
    import traceback
    traceback.print_exc()
    exit(1)
PYEOF
"

if [ -f "$OUTPUT_FILE" ]; then
    SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
    echo ""
    echo "SUCCESS: Generated $OUTPUT_FILE ($SIZE)"
else
    echo "FAILED: Could not generate PMTiles"
    exit 1
fi
