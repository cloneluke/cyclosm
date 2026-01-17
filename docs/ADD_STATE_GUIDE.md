# Adding States to CyclOSM Tile Coverage

This guide documents the process for adding new states to the cycling map tile coverage. It has been successfully used to add 10 states including Tennessee, which required solving the **duplicate node ID problem at state boundaries**.

## Key Discovery: Handling State Boundary Duplicates

When merging OSM data from multiple states, the files share identical node IDs at their shared borders. Planetiler cannot process this unsorted data and throws an error. **The solution is to re-encode the merged file with osmconvert**, which normalizes the data structure and eliminates duplicates.

This was the blocker that prevented Tennessee from being added in previous attempts. Once osmconvert deduplication was added to the pipeline, all states merged successfully.

## Overview

Adding a new state involves:
1. **Download OSM data** for the state from Geofabrik
2. **Merge** the new state data with existing states using osmium
3. **Rebuild Docker image** (if schema changed)
4. **Regenerate tiles** with Planetiler
5. **Restart tile server** to serve new tiles

## Step-by-Step Process

### 1. Download State Data

Edit `infrastructure/tile-server/entrypoint.sh` and add a download block for your state:

```bash
if [ ! -f /data/sources/STATENAME.osm.pbf ]; then
    echo "Downloading STATE NAME..."
    curl -L https://download.geofabrik.de/north-america/us/STATENAME-latest.osm.pbf \
        -o /data/sources/STATENAME.osm.pbf
fi
```

**Example for Missouri:**
```bash
if [ ! -f /data/sources/missouri.osm.pbf ]; then
    echo "Downloading Missouri..."
    curl -L https://download.geofabrik.de/north-america/us/missouri-latest.osm.pbf \
        -o /data/sources/missouri.osm.pbf
fi
```

**File to modify:** `infrastructure/tile-server/entrypoint.sh` (around line 68)

### 2. Add State to Merge Command

Find the osmium merge command in `entrypoint.sh` and add your state to the list:

```bash
osmium merge -o /data/sources/merged.osm.pbf --overwrite \
             /data/sources/colorado.osm.pbf \
             /data/sources/minnesota.osm.pbf \
             /data/sources/iowa.osm.pbf \
             /data/sources/south-dakota.osm.pbf \
             /data/sources/nebraska.osm.pbf \
             /data/sources/north-dakota.osm.pbf \
             /data/sources/missouri.osm.pbf \
             /data/sources/kansas.osm.pbf \
             /data/sources/wisconsin.osm.pbf \
             /data/sources/tennessee.osm.pbf

# CRITICAL: Clean duplicate node IDs at state boundaries
echo "Cleaning duplicate nodes with osmconvert..."
osmconvert /data/sources/merged.osm.pbf -o=/data/sources/merged_clean.pbf
mv /data/sources/merged_clean.pbf /data/sources/merged.osm.pbf
```

**Important:** 
- Order doesn't matter, but keep them organized (alphabetical or geographic)
- **Always add the osmconvert deduplication step** after merge (see below)

#### Why osmconvert deduplication is essential

When merging multiple states, the OSM data at state boundaries contains **identical node IDs** where states share borders. This causes Planetiler to fail with:
```
IllegalArgumentException: Nodes must be sorted ascending by ID, XXXXX came after XXXXX
```

The solution is to re-encode the merged file with `osmconvert`, which normalizes the data and eliminates duplicate node IDs:

```bash
# This step is mandatory when merging 2+ states
osmconvert /data/sources/merged.osm.pbf -o=/data/sources/merged_clean.pbf
mv /data/sources/merged_clean.pbf /data/sources/merged.osm.pbf
```

**What osmconvert does:**
- Re-encodes the PBF file to internal format
- Normalizes node IDs and element ordering
- Removes duplicates at boundaries
- Preserves all feature data

**Performance:** Takes ~30-60 seconds for 10 states

**File to modify:** `infrastructure/tile-server/entrypoint.sh` (around line 100-120)

### 3. Update Schema (if adding cycling features)

If the new state needs expanded cycling feature detection, update `infrastructure/tile-server/cyclosm-schema.yaml`:

**What worked for Missouri:** Added detection for:
- Bike lanes on regular roads (`bicycle: [designated, official, yes]`)
- Cycleway tags (`cycleway: [track, lane, share_busway, crossing, ...]`)
- Additional POI types (bike shops, leisure cycling areas)

**Schema structure:**
```yaml
- source: osm
  geometry: line
  min_zoom: 8  # Lower zoom = appears earlier
  include_when:
    bicycle: [designated, official, yes]
  attributes:
    - key: highway
    - key: name
    - key: bicycle
    - key: surface
```

**Files to modify:**
- `infrastructure/tile-server/cyclosm-schema.yaml` (schema source file)
- `infrastructure/tile-server/data/planetiler-config.yaml` (copy to this file for testing)

### 4. Rebuild Docker Image

**CRITICAL STEP:** If you modified the schema, you MUST rebuild the Docker image so it includes the updated schema file:

```bash
cd infrastructure/tile-server
docker-compose build --no-cache planetiler
```

Without rebuilding, the entrypoint.sh will copy the old schema from the Docker image, and your changes won't be used.

**What happens internally:**
1. Dockerfile copies `cyclosm-schema.yaml` to `/cyclosm-schema.yaml` in the image
2. During tile generation, entrypoint.sh copies this to `/data/planetiler-config.yaml`
3. Planetiler uses this config to generate tiles

### 5. Regenerate Tiles

Run tile generation with the tile-generation profile:

```bash
cd infrastructure/tile-server
docker-compose -p tile-server run --rm planetiler tile-generation
```

**Expected output:**
```
archive 755MB        # File size (grows with added states)
features  1.7GB      # Feature count (increases with new data)
Tile generation complete: /data/tiles.pmtiles
```

**Timeline:** ~40-50 seconds for 7 states worth of data

### 6. Restart Tile Server

```bash
cd infrastructure/tile-server
docker-compose restart tile-server
```

Verify it's serving the new tiles:
```bash
curl -I http://localhost:8080/tiles.pmtiles | grep Content-Length
```

Content-Length should match the new file size.

### 7. Test in Browser

1. Go to `http://localhost:5173`
2. **Hard refresh:** `Ctrl+Shift+R` (Windows/Linux) or `Cmd+Shift+R` (Mac)
3. Zoom to the new state and verify cycling features appear

## What Was Added: 10-State Coverage

### Recent Addition: Tennessee
- **File size:** 165 MB OSM data
- **Key challenge:** State boundary duplicate node IDs blocked tile generation
- **Solution:** Added osmconvert deduplication step to merge pipeline
- **Result:** Successfully merged with other 9 states, cycling features visible from zoom 5+

### Previous Additions (North Dakota, Missouri, etc.)
- **North Dakota:** 119.8 MB - cycling infrastructure already well mapped
- **Missouri:** 173.4 MB - required schema expansion for cycling feature detection
- **Kansas, Wisconsin, Iowa, South Dakota, Nebraska, Colorado:** Similar patterns

### All 10 States Now Covered
```
Colorado (CO)      Minnesota (MN)     Iowa (IA)
South Dakota (SD)  Nebraska (NE)      North Dakota (ND)
Missouri (MO)      Kansas (KS)        Wisconsin (WI)
Tennessee (TN)     ← Most recently added
```

**Total coverage:** 1.1 GB PMTiles file with 36M+ features across all zoom levels

## Common Pitfalls

### Issue: "Nodes must be sorted ascending by ID" error
**Cause:** You added a state to the merge command but forgot the osmconvert deduplication step
```
java.lang.IllegalArgumentException: Nodes must be sorted ascending by ID, XXXXX came after XXXXX
```

**Solution:** Ensure you have this block after the `osmium merge` command:
```bash
osmconvert /data/sources/merged.osm.pbf -o=/data/sources/merged_clean.pbf
mv /data/sources/merged_clean.pbf /data/sources/merged.osm.pbf
```

This re-encodes the file and removes duplicate node IDs at state boundaries. **Do not skip this step when merging multiple states.**

### Issue: Tiles don't change size after adding state
**Solution:** You probably forgot to rebuild the Docker image if you modified the schema. Run:
```bash
docker-compose build --no-cache planetiler
```

### Issue: New state appears in merge but not in tiles
**Causes:**
1. Browser cache (hard refresh needed)
2. State has sparse cycling data in OSM
3. Schema doesn't match the tags used in that state

**Solutions:**
- Always hard refresh browser (`Ctrl+Shift+R`)
- Check OSM data quality in the state
- Add more tag variations to schema (e.g., `access=yes` or `surface=asphalt`)

### Issue: Tile server shows old file size
**Solution:** Completely restart docker-compose:
```bash
docker-compose down
docker-compose up -d
```

## File References

| File | Purpose |
|------|---------|
| `infrastructure/tile-server/entrypoint.sh` | OSM downloads and merge commands |
| `infrastructure/tile-server/cyclosm-schema.yaml` | Planetiler schema (source of truth) |
| `infrastructure/tile-server/Dockerfile` | Copies schema to image |
| `infrastructure/tile-server/data/planetiler-config.yaml` | Config used during tile generation (generated from schema) |
| `infrastructure/tile-server/nginx.conf` | HTTP server configuration |
| `apps/web/src/styles/cycling-style.json` | MapLibre GL style (tile URLs) |

## Performance Metrics

- **Per state:** ~8-15 seconds generation time
- **Total states:** 10 (CO, MN, IA, SD, NE, ND, MO, KS, WI, TN)
- **Total tile file:** 1.1 GB
- **Total features:** 2.5 GB uncompressed
- **Merge file:** 1.2 GB (before osmconvert cleaning)
- **Total generation time:** ~1m 37s (download + merge + osmconvert + Planetiler)

## Git Workflow

After making changes, commit them separately:

```bash
git add infrastructure/tile-server/entrypoint.sh
git commit -m "feat: Add STATENAME to tile generation"

git add infrastructure/tile-server/cyclosm-schema.yaml
git commit -m "feat: Expand schema for STATENAME cycling features"
```

This keeps your history clean and makes it easy to revert individual changes if needed.
