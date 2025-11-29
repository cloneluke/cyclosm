# Planetiler 0.9.3 YAML Schema Structure - Correct Format

## Key Differences Found

Based on analysis of working Planetiler schemas (shortbread.yml, highway_areas.yml) in the official Planetiler repository, here are the critical differences from your initial format:

### 1. **Attributes Field Structure** ❌ WRONG → ✅ CORRECT

**WRONG** (String array):
```yaml
attributes: [highway, name, ref, oneway, bridge, tunnel]
```

**CORRECT** (Array of attribute definition objects):
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

Each attribute is an **object with a `key` property**, not just a string. Optional properties include:
- `key` (required): The attribute name in the output tile
- `type`: Data type coercion (e.g., `boolean`, `integer`, `string`)
- `tag_value`: Which source tag to use (if different from key name)
- `include_when`: Boolean expression to conditionally include this attribute
- `exclude_when`: Boolean expression to conditionally exclude this attribute
- `min_zoom`: Minimum zoom level for this attribute
- `value`: Expression to compute attribute value at runtime
- `else`: Fallback value when conditions don't match

### 2. **Render Field Removed** ❌ NOT SUPPORTED

The `render` field used for styling (colors, widths, dashes, icons, text) is **NOT part of Planetiler's YAML schema**. 

**WRONG**:
```yaml
render: { width: 4, color: gray }
render:
  width: 2
  dash: [2, 2]
  color:
    cycleway: "#0066ff"
    path: "#00aa00"
    default: orange
render: 
  text: "{name}"
  font_size: 12
  color: black
render: { icon: bicycle, text: "{name}" }
```

All `render` blocks must be **removed**. Rendering/styling is handled by the tile consumer (map style files like Mapbox GL style JSON), not by the schema that generates the tiles.

### 3. **Tag Mappings Added** ✅ NEW FIELD

Add `tag_mappings` section after `sources` to pre-process specific OSM tags with type coercion:

```yaml
tag_mappings:
  layer: integer
  capacity: integer
  bridge: boolean
```

This tells Planetiler to parse these tags as the specified types automatically.

### 4. **Complete Feature Definition Structure**

Full structure for a feature definition:

```yaml
layers:
  - id: layer_name
    features:
      - source: osm                      # Data source ID
        geometry: line                   # point, line, polygon, polygon_point_on_surface, etc.
        min_zoom: 5                      # Minimum zoom level
        max_zoom: 14                     # Optional: maximum zoom level
        min_size: 0.5                    # Optional: minimum size threshold
        include_when:                    # Optional: boolean expression for inclusion
          highway: [cycleway, path]
          bicycle: [yes, designated]
        exclude_when:                    # Optional: boolean expression for exclusion
          access: private
        attributes:                      # Array of attribute definitions
          - key: highway                 # Simple tag passthrough
          - key: surface                 # From source tag
          - key: bicycle_friendly        # Custom attribute name
            tag_value: bicycle           # Source tag to map from
            type: boolean                # Type coercion
```

### 5. **Example from Shortbread (Working)**

From the official Shortbread schema:

```yaml
- id: water_lines
  features:
  - source: osm
    geometry: line
    min_zoom:
      default_value: 9
      overrides:
        14:
          waterway: [stream, ditch]
    include_when:
      waterway:
      - canal
      - river
      - stream
      - ditch
    attributes:
    - key: kind
      type: match_value
    - key: tunnel
      min_zoom: 11
      value: true
      include_when:
        tunnel: [yes, building_passage]
        covered: yes
      else: false
    - key: bridge
      min_zoom: 11
      value: true
      include_when:
        bridge: [yes, viaduct, boardwalk, cantilever]
      else: false
```

## Valid Expression Types

Within attribute `value:` definitions, you can use:

### Constant Value
```yaml
- key: type
  value: "water"
```

### Tag Value
```yaml
- key: name
  tag_value: name
```

### Match Expression (Tag-based conditional)
```yaml
- key: kind
  value:
    cycleway: "path"
    path: "path"
    track: "path"
    default: "road"
```

### Coalesce Expression (Fall-through multiple values)
```yaml
- key: name
  value:
    coalesce:
      - tag_value: name
      - tag_value: name:en
      - tag_value: ref
```

### Inline Script Expression
```yaml
- key: width
  value: "${ double(feature.tags.width) * 2 }"
```

### Conditional with If/Else Array
```yaml
- key: is_bridge
  type: boolean
  value:
    - if: { bridge: yes }
      value: true
    - else: false
```

## Boolean Expressions (for include_when/exclude_when)

Supported formats:

```yaml
include_when:
  # Simple tag match (any value)
  highway: __any__
  
  # Multiple values (OR)
  highway: [motorway, trunk, primary]
  
  # Single value
  access: private
  
  # Complex - all conditions must match (__all__)
  __all__:
    - highway: primary
    - surface: [gravel, dirt]
  
  # Any condition matches
  __not__:
    access: private
```

## Data Types

Coerce values with `type:`:
- `boolean` - true/false
- `integer` - whole numbers
- `long` - 64-bit integers
- `double` - floating point
- `string` - text (default)
- `match_key` - use the matching key name as value
- `match_value` - use the matched value

## Summary of Changes Made to cyclosm-schema.yaml

1. ✅ Converted all `attributes` from string arrays to proper attribute definition objects
2. ✅ Removed all `render` blocks (not supported by Planetiler)
3. ✅ Added `tag_mappings` section for type coercion
4. ✅ Added `type: boolean` and `type: integer` where appropriate
5. ✅ Used proper attribute definition syntax with `key:` properties
6. ✅ Maintained all geographic filtering and zoom level logic

This schema now follows Planetiler 0.9.3's YAML specification exactly as defined in the official documentation and working examples.
