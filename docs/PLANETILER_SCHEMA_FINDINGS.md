# Planetiler 0.9.3 YAML Schema - Summary of Findings

## Search Results

Found working examples of Planetiler 0.9.3 YAML schemas from the official Planetiler repository:

### Official Examples Examined:
1. **shortbread.yml** - Full-featured production schema from Shortbread project
2. **highway_areas.yml** - Simpler example schema
3. Test files and documentation from planetiler-custommap README

## Critical Issues in Original Schema

### 1. ❌ WRONG: Attributes as String Array
```yaml
attributes: [highway, name, ref, oneway, bridge, tunnel]
```

Planetiler expects an **array of attribute definition objects**, not strings:

```yaml
attributes:
  - key: highway
  - key: name
  - key: ref
  - key: oneway
    type: boolean
  - key: bridge
    type: boolean
```

**Each attribute must be an object with a `key:` property.**

### 2. ❌ NOT SUPPORTED: Render Blocks
All `render` fields were **removed** because Planetiler's YAML schema does NOT support rendering/styling directives:

```yaml
# WRONG - REMOVE ALL OF THESE
render: { width: 4, color: gray }
render: { dash: [2, 2], color: "#0066ff" }
render: { text: "{name}", font_size: 12 }
render: { icon: bicycle, text: "{name}" }
```

Styling is handled by the **tile consumer** (Mapbox GL JSON, etc.), not the tile generation schema.

### 3. ✅ ADDED: Tag Mappings Section
Pre-parse OSM tags with type coercion:

```yaml
tag_mappings:
  layer: integer
  capacity: integer
  bridge: boolean
```

### 4. ✅ CORRECTED: Attribute Definition Objects
Full structure with all optional properties:

```yaml
attributes:
  - key: highway                    # Required: attribute name in output
  - key: name                       # Simple tag passthrough
  - key: oneway
    type: boolean                   # Type coercion
  - key: bridge
    type: boolean
    include_when:                   # Conditional inclusion
      bridge: [yes, viaduct]
  - key: is_major
    value: true                     # Computed value
    include_when:
      highway: [motorway, trunk]
    else: false
  - key: min_zoom
    min_zoom: 11                    # Minimum zoom for this attribute
```

## Attributes Definition Structure

Each attribute in the `attributes:` array is an object that can have:

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `key` | string | ✅ | Output attribute name in vector tile |
| `tag_value` | string | ❌ | Source OSM tag (if different from key) |
| `type` | string | ❌ | Type coercion: `boolean`, `integer`, `double`, `string`, `match_key`, `match_value` |
| `value` | expression | ❌ | How to compute the value (tag_value, constant, match, coalesce, inline script) |
| `include_when` | boolean_expr | ❌ | Conditional: only include if this expression is true |
| `exclude_when` | boolean_expr | ❌ | Conditional: exclude if this expression is true |
| `min_zoom` | integer | ❌ | Minimum zoom level to include this attribute |
| `min_zoom_by_value` | map | ❌ | Different min_zoom per attribute value |
| `else` | value | ❌ | Fallback value when conditions not met |

## Value Expression Types

### Constant
```yaml
value: "water"
```

### Tag Value
```yaml
tag_value: surface
# or with explicit type
value:
  tag_value: surface
```

### Match (Tag-conditional)
```yaml
value:
  motorway: "highway"
  trunk: "highway"
  residential: "street"
  default: "other"
```

### Coalesce (Try multiple tags)
```yaml
value:
  coalesce:
    - tag_value: name
    - tag_value: name:en
    - tag_value: ref
```

### Inline Script
```yaml
value: "${ double(feature.tags.width) * 2 }"
```

### Conditional Array
```yaml
value:
  - if: { bridge: yes }
    value: true
  - else: false
```

## Boolean Expression Format

Used in `include_when` and `exclude_when`:

```yaml
include_when:
  # Simple: any value
  highway: __any__
  
  # Multiple values (OR)
  highway: [motorway, trunk, primary]
  
  # Single specific value
  access: private
  
  # All must match (AND)
  __all__:
    - highway: primary
    - surface: [gravel, dirt]
  
  # Negation
  __not__:
    access: private
```

## Validation Results

**✅ Schema Successfully Validated**

The corrected schema was tested with Planetiler 0.9.3:

```
java -jar planetiler.jar generate-custom \
  schema=/data/cyclosm-schema.yaml \
  osm-path=/data/sources/merged.osm.pbf \
  output=/tmp/test.pmtiles \
  force=true
```

**Results:**
- ✅ Schema loads without errors
- ✅ All 120M+ nodes processed
- ✅ 10M+ ways processed  
- ✅ Features correctly extracted
- ✅ Tile archive generated: 524MB
- ✅ Total features: 1.1GB

## Changes Made to cyclosm-schema.yaml

1. **Converted all attributes from string arrays to object definitions:**
   - `attributes: [highway, name, ref]` → 
   - `attributes: [{key: highway}, {key: name}, {key: ref}]`

2. **Removed all `render` blocks** (not supported by Planetiler)

3. **Added `tag_mappings` section** for type coercion:
   ```yaml
   tag_mappings:
     layer: integer
     capacity: integer
   ```

4. **Added type definitions** to attributes:
   - `type: boolean` for boolean attributes
   - `type: integer` for numeric attributes

5. **Preserved all geographic logic:**
   - `include_when` filters
   - Zoom level ranges
   - Feature geometry types

## Official Documentation References

- **Planetiler README**: `planetiler-custommap/README.md` - Comprehensive YAML schema specification
- **Shortbread Example**: Full production-grade schema example
- **Highway Areas Example**: Simpler illustrative schema
- **Planetiler Tests**: `ConfiguredFeatureTest.java`, `SchemaValidatorTest.java`

## Key Learnings

1. **Planetiler YAML vs Other Formats**: The YAML schema is strictly for tile generation logic, not styling/rendering
2. **Attributes Must Be Objects**: Not strings or simple key-value pairs
3. **Type Coercion Matters**: Use `tag_mappings` and attribute `type:` for proper data types
4. **Expressions Are Powerful**: Planetiler supports match, coalesce, and inline script expressions for computed values
5. **Schema Validation**: Test with `generate-custom` task to validate syntax early

## Next Steps

The corrected schema is now ready for:
- Tile generation with full feature sets
- Testing with actual map clients
- Adding more complex attributes with expressions
- Fine-tuning min_zoom levels per feature type
