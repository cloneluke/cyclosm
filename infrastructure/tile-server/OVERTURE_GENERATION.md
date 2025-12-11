# Overture Maps PMTiles Generation

This guide explains how to generate custom Overture Maps PMTiles for the CyclOSM project.

## Current Status

The app currently uses official Overture Maps PMTiles from AWS S3:
- URL: `https://overturemaps-tiles-us-west-2-beta.s3.amazonaws.com/2025-11-19/transportation.pmtiles`
- Layer name: `segment` (for line features)
- Limitations: Data only available at zoom 14+ for cycleways/paths

## Why Generate Custom Tiles?

The official Overture PMTiles only include detailed transportation data starting at zoom 14. To show cycleways at lower zoom levels, you need to generate custom tiles with:
- Extended zoom coverage (0-13)
- Simplified geometries for lower zooms
- Custom filtering of features

## Prerequisites

Option A: Local Java Installation
- Java 21+ (check with `java -version`)
- Install with: `sudo apt install openjdk-21-jre-headless`

Option B: Docker
- Docker installed and running

AWS Credentials (for S3 Overture data access)
- `AWS_ACCESS_KEY_ID` environment variable
- `AWS_SECRET_ACCESS_KEY` environment variable

## Configuration

The Planetiler config is defined in `infrastructure/tile-server/data/planetiler-overture-config.yaml`:

```yaml
sources:
  overture_transportation:
    type: geoparquet
    location: s3://overture-maps-prod/2025-11-19/theme=transportation/**/*.parquet
```

This will:
1. Download Overture parquet files from AWS S3
2. Extract the transportation theme (segments and connectors)
3. Generate vector tiles with zoom 0-14 coverage
4. Output as PMTiles format

## Generation Steps

### 1. Set AWS Credentials (if needed)
```bash
export AWS_ACCESS_KEY_ID=your_key
export AWS_SECRET_ACCESS_KEY=your_secret
```

### 2. Run the Generation Script
```bash
bash scripts/generate-overture-tiles.sh
```

This will:
- Detect Java or Docker availability
- Download Planetiler if needed
- Generate `infrastructure/tile-server/data/overture-transportation.pmtiles`
- Output file size: ~500MB-1GB depending on zoom levels

### 3. Update App Configuration
Update `apps/web/.env.local`:

**Option A: Local file path**
```
VITE_OVERTURE_SEGMENT_PM_TILES=file:///home/luke/git-repos/cyclosm/infrastructure/tile-server/data/overture-transportation.pmtiles
```

**Option B: Tile server URL**
If serving from localhost tile server:
```
VITE_OVERTURE_SEGMENT_PM_TILES=http://localhost:8080/overture-transportation.pmtiles
```

**Option C: Keep using AWS S3 (current)**
```
VITE_OVERTURE_SEGMENT_PM_TILES=https://overturemaps-tiles-us-west-2-beta.s3.amazonaws.com/2025-11-19/transportation.pmtiles
```

### 4. Restart Dev Server
```bash
cd apps/web && pnpm dev
```

### 5. Verify in Browser
- Navigate to http://localhost:5173/
- Toggle "Overture" on
- Zoom to lower levels (0-13)
- Purple cycleways should appear

## Troubleshooting

### Java not found
Install with: `sudo apt install openjdk-21-jre-headless`

### S3 Access Denied
- Verify AWS credentials are set
- Check Overture S3 bucket permissions
- Ensure AWS account has read access to `s3://overture-maps-prod/`

### Generation Timeout
- Increase heap memory: Modify `-Xmx8g` to `-Xmx16g` in the generation script
- Generation can take 30+ minutes for global data

### File too large
- The output PMTiles can be 500MB-1GB
- Consider filtering by region in `planetiler-overture-config.yaml`
- Or use `--maxzoom 13` instead of 14 to reduce file size

## Configuration Details

### Zoom Levels
- `min_zoom: 0` - Start from world view
- `max_zoom: 14` - Detail level (global Planetiler limit)
- Data is simplified/filtered based on `include_when` rules

### Features Included
1. **Segment layer** (lines):
   - All transportation segments (roads, paths, etc)
   - Filtered by class (cycleway, path, motorway, primary, etc)
   - Attributes: class, subtype, surface, access, oneway, toll, etc

2. **Connector layer** (points):
   - Intersection points
   - Only at zoom 13-14

### Customization

To customize which features are included, edit `planetiler-overture-config.yaml`:

```yaml
- source: overture_transportation
  include_when:
    class: [cycleway, path]  # Only cycleways and paths
    min_zoom: 0              # Start from zoom 0
```

## File Structure
```
infrastructure/tile-server/data/
├── planetiler-overture-config.yaml    # Planetiler configuration
├── overture-transportation.pmtiles     # Output (generated)
└── [other configs]
```

## Further Reading
- [Overture Maps Documentation](https://docs.overturemaps.org/)
- [Planetiler Documentation](https://planetiler.org/)
- [Overture S3 Release Structure](https://overturemaps.org/download/)
- [MapLibre GL Vector Tiles](https://maplibre.org/maplibre-gl-js/docs/API/)

## Next Steps
1. Generate custom tiles with: `bash scripts/generate-overture-tiles.sh`
2. Test locally with lower zoom levels
3. Consider hosting generated PMTiles on a CDN or tile server
4. Commit the PMTiles file (if small enough) or add generation to CI/CD pipeline
