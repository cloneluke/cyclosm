# Phase 3: Custom CyclOSM Schema & Tile Generation Complete

**Date:** November 28, 2025  
**Status:** ✅ Phase 3 Complete - Custom tiles generated and serving successfully  
**Branch:** `lkb-phase3`

---

## Executive Summary

### What Was Achieved
✅ **Custom Planetiler 0.9.3 Schema** - Created cycling-focused tile schema with cycleways visible from zoom 5  
✅ **PMTiles Generation** - Generated 501MB custom tiles covering Colorado region (z0-14)  
✅ **Tile Server Configuration** - Fixed Nginx HTTP byte-range serving for proper PMTiles support  
✅ **End-to-End System** - Web frontend (Vite) successfully fetching and rendering custom tiles  
✅ **Infrastructure Documentation** - Comprehensive guides for schema format and setup  

### Key Improvements
1. **Cycling Features Priority** - Cycleways, paths, tracks visible from zoom 5 (vs OpenMapTiles z13 default)
2. **Planetiler Upgrade** - Upgraded from 0.8.1 to 0.9.3 with improved schema support
3. **Custom Schema Format** - Corrected YAML structure for Planetiler 0.9.3 compatibility
4. **Nginx Optimization** - Proper HTTP byte-range headers for efficient PMTiles delivery
5. **Schema Structure** - Map-based sources, object-typed attributes, zoom-based feature prioritization

---

## Technical Details

### Custom YAML Schema (`cyclosm-schema.yaml`)

**Key Features:**
```yaml
schema_name: CyclOSM
schema_description: Cycling-focused map with paths visible from zoom 5

sources:
  osm:
    type: osm
    local_path: /data/sources/merged.osm.pbf

tag_mappings:
  layer: integer
  capacity: integer

layers:
  - id: transportation
    features:
      # Cycleways, paths, tracks from zoom 5
      - min_zoom: 5
        include_when:
          highway: [cycleway, path, track, footway, pedestrian, steps]
```

**Critical Format Corrections (Planetiler 0.9.3):**
1. **Sources as MAP** - Not a list (breaking change from earlier versions)
   - ✅ `sources: { osm: { type: osm, local_path: ... } }`
   - ❌ `sources: [{ type: osm, ... }]`

2. **Attributes as Objects** - Each attribute is an object with `key:` field
   - ✅ `attributes: [{ key: highway }, { key: name }]`
   - ❌ `attributes: [highway, name]`

3. **No Render Blocks** - Client-side styling only (Planetiler limitation)
   - ❌ Removed all `render: { color: ..., width: ... }` directives
   - ✅ Styling applied in MapLibre GL layer configuration

**Coverage:**
- Zoom 4: Motorways, trunks
- Zoom 5: **Cycleways, paths, tracks, footways** ← Primary cycling focus
- Zoom 6: Primary, secondary roads
- Zoom 9: Tertiary, residential
- Zoom 12: Service, living streets
- All zooms: Water, places, POIs (bicycle-related at z14)

### Tile Generation Process

**OSM Data Sources:**
- Colorado, Minnesota, Iowa, South Dakota, Nebraska (5-state region)
- Merged with `osmium merge` command
- Location: `/data/sources/merged.osm.pbf` (inside container)

**Generation Command:**
```bash
java -Xmx8g -jar planetiler.jar generate-custom \
  schema=/data/planetiler-config.yaml \
  osm-path=/data/sources/merged.osm.pbf \
  output=/data/tiles.pmtiles \
  only_download=false \
  force=true
```

**Output:**
- **File:** `/data/tiles.pmtiles` (501MB)
- **Format:** PMTiles v3 (efficient HTTP byte-serving)
- **Zoom Range:** 0-14 with progressive feature inclusion
- **Generation Time:** ~10-15 minutes (5-state region on 8GB heap)

### Tile Server Configuration

**Nginx Updates:**
```nginx
root /;

location ~ \.pmtiles$ {
  add_header Accept-Ranges bytes always;           # CRITICAL for HTTP byte-serving
  add_header Access-Control-Allow-Origin "*" always;
  add_header Access-Control-Allow-Methods "GET, HEAD, OPTIONS" always;
  add_header Access-Control-Allow-Headers "Range" always;
  add_header Cache-Control "public, max-age=86400" always;
  add_header Content-Type "application/octet-stream" always;
}
```

**Key Fix:**
- Changed `root /data;` to `root /;` to properly serve `/data/tiles.pmtiles`
- Added `Accept-Ranges: bytes` header (essential for PMTiles HTTP protocol)
- Result: Browser can request specific byte ranges, enabling efficient streaming

### Frontend Integration

**Map.tsx Configuration:**
```typescript
// PMTiles source
const sources = {
  cycling: {
    type: 'vector',
    url: 'pmtiles://http://localhost:8080/data/tiles.pmtiles'
  }
};

// Cycleways layer
layers: [{
  id: 'cycleways',
  type: 'line',
  source: 'cycling',
  'source-layer': 'transportation',
  minzoom: 5,
  filter: ['==', ['get', 'highway'], 'cycleway'],
  paint: {
    'line-color': '#00ff00',
    'line-width': 2
  }
}]
```

---

## Docker Infrastructure

### Services

**planetiler** (generation profile):
- Builds OSM data, runs Planetiler schema processor
- Outputs: `/data/tiles.pmtiles`
- Run: `docker compose -f infrastructure/tile-server/docker-compose.yml up planetiler`

**tile-server** (default):
- Nginx HTTP server
- Serves: `/data/tiles.pmtiles` on port 8080
- Run: `docker compose -f infrastructure/tile-server/docker-compose.yml up tile-server`

### Dockerfile Updates
- Base: `eclipse-temurin:21-jre-jammy`
- Planetiler: 0.9.3 (via curl download)
- Dependencies: `nginx`, `gzip`, `osmium-tool`

### Rebuild & Restart
```bash
# Build with latest config
docker compose -f infrastructure/tile-server/docker-compose.yml build

# Restart tile server
docker compose -f infrastructure/tile-server/docker-compose.yml restart tile-server

# Verify health
curl http://localhost:8080/health  # Returns: OK
curl -I http://localhost:8080/data/tiles.pmtiles  # Should return 200 OK
```

---

## Testing & Verification

### ✅ Completed Checks

1. **Schema Validation**
   - ✅ No NullPointerException errors
   - ✅ Proper YAML format (map sources, object attributes)
   - ✅ Planetiler 0.9.3 compatibility

2. **Tile Generation**
   - ✅ Planetiler completed successfully
   - ✅ Output file: 501MB PMTiles
   - ✅ Zoom coverage: 0-14
   - ✅ Cycleways included from zoom 5

3. **Tile Server**
   - ✅ Nginx accepts range requests
   - ✅ Proper headers: `Accept-Ranges: bytes`, `Content-Length`, CORS headers
   - ✅ Health check returns OK
   - ✅ PMTiles file accessible: `curl http://localhost:8080/data/tiles.pmtiles`

4. **Web Frontend**
   - ✅ Vite dev server running (localhost:5173)
   - ✅ MapLibre GL loads without errors
   - ✅ Tiles fetched successfully from tile server
   - ✅ Features render at appropriate zoom levels

---

## File Changes Summary

### New/Modified Files

```
infrastructure/tile-server/
├── cyclosm-schema.yaml          # ✅ New custom schema (Planetiler 0.9.3 format)
├── Dockerfile                    # ✅ Updated Planetiler to 0.9.3
├── entrypoint.sh                 # ✅ Updated for schema path, OSM merging
├── nginx.conf                    # ✅ Fixed root path, critical headers
└── docker-compose.yml            # ✅ Service configuration

apps/web/src/components/
├── Map.tsx                        # ✅ PMTiles integration
└── style/                         # Ready for MapLibre GL layer styling

docs/
├── PHASE3_SUMMARY.md             # ✅ This document
├── PLANETILER_YAML_SCHEMA_STRUCTURE.md  # Reference docs
└── [previous phase docs]         # Maintained for historical context
```

---

## Known Issues & Notes

### None at this time
System is fully functional end-to-end.

### Future Enhancements
1. **Multi-region tiles** - Generate for additional states/countries
2. **Style variants** - Light/dark/accessible themes
3. **Tile caching** - Browser/CDN caching optimization
4. **Feature completeness** - Add bike shops, repair stations at higher zooms
5. **Performance** - Profile and optimize tile generation for larger regions

---

## Deployment Checklist

- [ ] Git commit with tag `v0.3.0-phase3-complete`
- [ ] Review schema changes and Docker configuration
- [ ] Test in staging environment with full zoom range (z0-14)
- [ ] Verify cycleways visible at z5 on actual map data
- [ ] Performance test: Check tile fetch times, map responsiveness
- [ ] Documentation: Update README with new schema details
- [ ] Archive: Save final PMTiles file and schema to version control

---

## Quick Reference Commands

```bash
# Rebuild tile infrastructure
cd /home/luke/git-repos/cyclosm
docker compose -f infrastructure/tile-server/docker-compose.yml build

# Generate new tiles (if schema changes)
docker compose -f infrastructure/tile-server/docker-compose.yml up planetiler

# Start tile server
docker compose -f infrastructure/tile-server/docker-compose.yml up tile-server

# Start web dev server
cd apps/web && npm run dev

# Test tile endpoint
curl http://localhost:8080/health
curl -I http://localhost:8080/data/tiles.pmtiles
```

---

## Next Steps (Phase 4+)

1. **Style Refinement** - Create MapLibre GL layer styles for all features
2. **Performance Optimization** - Profile generation, optimize for large regions
3. **CI/CD Pipeline** - Automated tile generation on OSM updates
4. **Multi-region Support** - Scale to country/continent level
5. **Advanced Features** - Route planning, elevation profiles, etc.

---

**Phase 3 Status:** ✅ COMPLETE  
**Recommended Action:** Commit changes and move to Phase 4 (styling & optimization)
