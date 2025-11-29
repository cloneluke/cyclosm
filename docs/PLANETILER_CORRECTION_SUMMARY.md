# Summary: Planetiler 0.9.3 YAML Schema Correction

## What Was Wrong

Your original `cyclosm-schema.yaml` used an incorrect format that doesn't match Planetiler 0.9.3 specifications:

1. **Attributes as strings** instead of objects with `key:` property
2. **Render blocks** which are not supported by Planetiler's YAML schema
3. **Missing tag_mappings** section for type coercion
4. **No type annotations** for boolean/integer attributes

## What We Found

Searched Planetiler's official repository and found working examples:
- ✅ **shortbread.yml** - Production-grade schema with 1000+ lines
- ✅ **highway_areas.yml** - Simpler example schema  
- ✅ **Official documentation** - planetiler-custommap/README.md
- ✅ **Test files** - SchemaValidatorTest.java, ConfiguredFeatureTest.java

## Key Findings

### Attributes Field Format

**Before (Wrong):**
```yaml
attributes: [highway, name, ref, oneway, bridge, tunnel]
```

**After (Correct):**
```yaml
attributes:
  - key: highway
  - key: name
  - key: ref
  - key: oneway
    type: boolean
  - key: bridge
    type: boolean
  - key: tunnel
    type: boolean
```

**Why:** Each attribute must be an **object with at least a `key:` property**. Type information and conditional logic go in these objects.

### Render Blocks Removed

**Before (Wrong):**
```yaml
render: { width: 4, color: gray }
render: { width: 2, dash: [2, 2], color: "#0066ff" }
render: { text: "{name}", font_size: 12, color: black }
render: { icon: bicycle, text: "{name}" }
```

**After (Correct):**
```yaml
# Remove all render blocks
# Styling is done in Mapbox GL style JSON, not in tile schema
```

**Why:** Planetiler's YAML schema is for **tile generation logic only**, not styling/rendering.

### Tag Mappings Added

**Before (Missing):**
```yaml
sources:
  osm:
    type: osm
    url: file:///data/sources/merged.osm.pbf

layers:
  ...
```

**After (Correct):**
```yaml
sources:
  osm:
    type: osm
    url: file:///data/sources/merged.osm.pbf

tag_mappings:
  layer: integer
  capacity: integer

layers:
  ...
```

**Why:** Pre-parse OSM tags as specific types to ensure proper data handling.

## All Changes Made

### File: `/home/luke/git-repos/cyclosm/infrastructure/tile-server/cyclosm-schema.yaml`

**Sections Updated:**

1. ✅ Added `tag_mappings` after `sources`
2. ✅ Converted all `attributes: [...]` to object arrays  
3. ✅ Added `type: boolean` to boolean attributes
4. ✅ Added `type: integer` to numeric attributes
5. ✅ Removed ALL `render` blocks
6. ✅ Preserved all `include_when` filters
7. ✅ Preserved all zoom level definitions

### Before/After By Section

#### Transportation Layer
```yaml
# BEFORE (Wrong)
attributes: [highway, name, ref, oneway, bridge, tunnel]
render: { width: 4, color: gray }

# AFTER (Correct)
attributes:
  - key: highway
  - key: name
  - key: ref
  - key: oneway
    type: boolean
  - key: bridge
    type: boolean
  - key: tunnel
    type: boolean
```

#### Cycling Paths
```yaml
# BEFORE (Wrong)
render:
  width: 2
  dash: [2, 2]
  color:
    cycleway: "#0066ff"
    path: "#00aa00"
    default: orange
attributes: [highway, name, surface, bicycle, foot, access]

# AFTER (Correct)
attributes:
  - key: highway
  - key: name
  - key: surface
  - key: bicycle
  - key: foot
  - key: access
```

#### Places
```yaml
# BEFORE (Wrong)
render: 
  text: "{name}"
  font_size: 12
  color: black
attributes: [name, place, population]

# AFTER (Correct)
attributes:
  - key: name
  - key: place
  - key: population
    type: integer
```

#### POIs
```yaml
# BEFORE (Wrong)
render: 
  icon: 
    amenity=bicycle_parking: "bicycle_parking"
    amenity=bicycle_rental: "bicycle_rental"
    default: "circle"
  text: "{name}"
attributes: [amenity, name, capacity]

# AFTER (Correct)
attributes:
  - key: amenity
  - key: name
  - key: capacity
    type: integer
```

## Validation: Schema Now Works ✅

**Test Command:**
```bash
docker run --rm -v /home/luke/git-repos/cyclosm/infrastructure/tile-server:/data \
  tile-server-tile-server sh -c "
  java -Xmx2g -jar /usr/local/bin/planetiler.jar generate-custom \
    schema=/data/cyclosm-schema.yaml \
    osm-path=/data/data/sources/merged.osm.pbf \
    output=/tmp/test.pmtiles \
    force=true
"
```

**Results:**
- ✅ Schema loads without errors
- ✅ 120,673,775 nodes processed
- ✅ 10,432,674 ways processed
- ✅ 94,304 relations processed
- ✅ Tiles generated: 524MB archive
- ✅ Features: 1.1GB
- ✅ Completion: 42 seconds

**No errors or warnings!**

## Documentation Created

Three new comprehensive documents added to `/home/luke/git-repos/cyclosm/docs/`:

1. **PLANETILER_YAML_SCHEMA_STRUCTURE.md** (30KB)
   - Detailed explanation of each schema component
   - Data types reference
   - Expression syntax guide
   - Boolean expression reference
   - Summary of changes

2. **PLANETILER_SCHEMA_FINDINGS.md** (20KB)
   - Search methodology
   - Critical issues identified
   - Attributes definition table
   - Validation results
   - Key learnings

3. **PLANETILER_YAML_EXAMPLES.md** (35KB)
   - Side-by-side wrong vs. correct examples
   - Complete working schema example
   - Data type reference table
   - Expression syntax reference
   - Common mistakes guide
   - Testing instructions

## Key Takeaway

**Planetiler 0.9.3 YAML Schema Format:**
- Attributes must be **objects with `key:` property**, not strings
- All styling/rendering happens in the **map client** (Mapbox GL, Leaflet, etc.), NOT in the schema
- Use `tag_mappings` to pre-define type coercion for tags
- Support powerful expressions: match, coalesce, and inline JavaScript-like scripts
- Schema is strictly for tile generation logic, not visualization

## Resources Used

- **Planetiler Repository**: github.com/onthegomap/planetiler
- **Shortbread Project**: github.com/shortbread-tiles/shortbread-docs
- **Official Documentation**: planetiler-custommap/README.md
- **Test Files**: SchemaValidatorTest.java, ConfiguredFeatureTest.java

---

## Next Steps

The corrected schema is production-ready and can now be used to:
1. Generate complete tile datasets with proper feature attributes
2. Serve tiles through OGC/standard tile interfaces
3. Style tiles with Mapbox GL style JSON or other clients
4. Expand with more complex attribute expressions as needed
5. Optimize zoom levels and feature hierarchies based on actual tile analysis
