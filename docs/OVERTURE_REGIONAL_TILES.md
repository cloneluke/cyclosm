# Overture Regional Tile Generation

## Overview

Generate regional Overture PMTiles for individual US states without downloading the entire global dataset (117GB+).

## Data Source

- **Bucket**: `s3://overturemaps-us-west-2`
- **Release**: `2025-11-19.0` (latest as of Dec 2025)
- **Theme**: `transportation`
- **Type**: `segment`
- **Format**: `.zstd.parquet` (compressed)
- **Total Records**: ~6M transportation segments

## Setup Requirements

- Docker (for containerized execution)
- Sufficient disk space (~500MB per state)
- Internet connection (queries AWS S3)

## Usage

### Quick Regional Generator (Recommended)

```bash
bash scripts/quick-overture-regional.sh colorado
bash scripts/quick-overture-regional.sh minnesota
bash scripts/quick-overture-regional.sh iowa
```

**Output**: `infrastructure/tile-server/data/overture-regional-{state}.pmtiles`

### Full Regional Generator

For more control and comprehensive spatial queries:

```bash
bash scripts/generate-overture-regional-docker.sh colorado
```

## How It Works

1. **Query S3**: Uses DuckDB with httpfs extension to query Overture parquet files
2. **Spatial Filter**: Filters by state bounding box using `ST_Intersects(geometry, ST_BBox(...))`
3. **GeoJSON Conversion**: Extracts geometry and properties as NDJSON
4. **PMTiles Compression**: Uses Tippecanoe to compress GeoJSON into PMTiles format

## Adding New States

Edit the script and add to `STATE_BOUNDS`:

```bash
declare -A STATE_BOUNDS=(
    ["new-state"]="-min-lon,min-lat,max-lon,max-lat"
)
```

## Generated Tile Usage

Update `.env.local` to use local tiles:

```
VITE_OVERTURE_SEGMENT_PM_TILES=http://localhost:8000/overture-regional-colorado.pmtiles
```

Serve with: `python3 -m http.server 8000` in the data directory

## Performance

- **Generation Time**: 5-15 minutes per state (depending on density)
- **File Size**: 300-700MB per state
- **Network**: Streams from AWS S3 (no pre-download needed)

## Troubleshooting

### Docker takes too long
- Normal for first run (installing packages)
- Subsequent runs reuse Docker layers and are faster

### S3 connection errors
- Verify AWS S3 bucket is accessible: `curl -I https://overturemaps-us-west-2.s3.amazonaws.com`
- Check internet connection

### DuckDB errors
- Ensure Docker has sufficient memory
- Try with smaller state (Iowa instead of California)
