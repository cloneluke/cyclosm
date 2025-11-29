# Planetiler 0.9.3 YAML Schema - Real Working Examples

## Side-by-Side Comparison: Wrong vs. Right

### Example 1: Simple Attribute Passthrough

#### ❌ WRONG (String Array)
```yaml
layers:
  - id: transportation
    features:
      - source: osm
        geometry: line
        min_zoom: 4
        include_when:
          highway: [motorway, trunk]
        attributes: [highway, name, ref]
```

#### ✅ CORRECT (Object Array)
```yaml
layers:
  - id: transportation
    features:
      - source: osm
        geometry: line
        min_zoom: 4
        include_when:
          highway: [motorway, trunk]
        attributes:
          - key: highway
          - key: name
          - key: ref
```

---

### Example 2: With Type Coercion

#### ❌ WRONG
```yaml
attributes: [oneway, bridge, tunnel]
```

#### ✅ CORRECT
```yaml
attributes:
  - key: oneway
    type: boolean
  - key: bridge
    type: boolean
  - key: tunnel
    type: boolean
```

---

### Example 3: Conditional Attributes

#### ❌ WRONG (With removed `render` field)
```yaml
- source: osm
  geometry: line
  min_zoom: 5
  include_when:
    highway: [cycleway, path, track]
  render:
    width: 2
    dash: [2, 2]
    color:
      cycleway: "#0066ff"
      path: "#00aa00"
      default: orange
  attributes: [highway, name, surface, bicycle]
```

#### ✅ CORRECT
```yaml
- source: osm
  geometry: line
  min_zoom: 5
  include_when:
    highway: [cycleway, path, track]
  attributes:
    - key: highway
    - key: name
    - key: surface
    - key: bicycle
    - key: is_cycleway
      value: true
      include_when:
        highway: cycleway
      else: false
```

---

### Example 4: Computed Values with Expressions

#### ❌ WRONG (No expression support in old format)
```yaml
attributes: [width, length]
```

#### ✅ CORRECT (Multiple expression types)
```yaml
attributes:
  - key: width
    type: double
    value: "${ double(feature.tags.width) }"
  
  - key: length
    type: integer
    value: "${ feature.length('meters') }"
  
  - key: kind
    value:
      motorway: "major"
      trunk: "major"
      residential: "minor"
      default: "other"
  
  - key: surface
    tag_value: surface
    include_when:
      surface: [asphalt, gravel, dirt]
```

---

### Example 5: Complex Feature Definition

#### ❌ WRONG (With all unsupported features)
```yaml
- id: poi
  features:
    - source: osm
      geometry: point
      min_zoom: 14
      include_when:
        amenity: [bicycle_parking, cafe, restaurant]
      render: 
        icon: 
          amenity=bicycle_parking: "bicycle_parking"
          amenity=cafe: "cafe"
          default: "circle"
        text: "{name}"
      attributes: [amenity, name, capacity]
```

#### ✅ CORRECT
```yaml
- id: poi
  features:
    - source: osm
      geometry: point
      min_zoom: 14
      include_when:
        amenity: [bicycle_parking, cafe, restaurant]
      attributes:
        - key: amenity
        - key: name
        - key: capacity
          type: integer
        - key: wheelchair
          type: boolean
          value:
            - if: { wheelchair: yes }
              value: true
            - else: false
```

---

### Example 6: Real-World from Shortbread (Working Production Schema)

```yaml
layers:
  - id: water
    features:
      - source: osm
        geometry: polygon
        min_zoom:
          default_value: 4
          overrides:
            10:
              waterway: [riverbank, dock, canal]
        include_when:
          natural: [water, glacier]
          waterway: [riverbank, dock, canal]
        attributes:
          - key: kind
            type: match_value
          - key: name
            tag_value: name
          - key: way_area
            value: "${ feature.area('m2') }"
            type: double
          - key: water_type
            value:
              water: "pond"
              glacier: "ice"
              dock: "dock"
              default: "water"
```

---

## Schema Structure: Complete Working Example

```yaml
schema_name: Example Map
schema_description: An example Planetiler YAML schema
attribution: <a href="https://openstreetmap.org">&copy; OSM contributors</a>

sources:
  osm:
    type: osm
    url: file:///data/merged.osm.pbf

tag_mappings:
  layer: integer
  capacity: integer
  bridge: boolean
  tunnel: boolean
  oneway: boolean

layers:
  - id: roads
    features:
      # Feature 1: Major roads with all attributes
      - source: osm
        geometry: line
        min_zoom: 4
        max_zoom: 14
        include_when:
          highway: [motorway, trunk, primary]
        attributes:
          # Basic attributes
          - key: highway
          
          # With source tag mapping
          - key: name
            tag_value: name
          
          # With type coercion
          - key: layer
            type: integer
          
          # Conditional boolean
          - key: bridge
            type: boolean
            value:
              - if: { bridge: yes }
                value: true
              - else: false
          
          # With zoom-dependent inclusion
          - key: ref
            min_zoom: 10
          
          # Computed from expression
          - key: length_meters
            type: integer
            value: "${ feature.length('meters') }"
          
          # Match expression
          - key: kind
            value:
              motorway: "highway"
              trunk: "trunk_road"
              primary: "main_road"
          
          # Coalesce expression
          - key: label
            value:
              coalesce:
                - tag_value: name
                - tag_value: ref
                - value: "Unnamed"
      
      # Feature 2: Simpler feature
      - source: osm
        geometry: line
        min_zoom: 10
        include_when:
          highway: [secondary, tertiary]
        attributes:
          - key: highway
          - key: name
          - key: surface

  - id: points_of_interest
    features:
      - source: osm
        geometry: point
        min_zoom: 14
        include_when:
          amenity: [cafe, restaurant, parking]
        attributes:
          - key: amenity
          - key: name
          - key: capacity
            type: integer
          - key: wheelchair
            type: boolean
            value:
              - if: { wheelchair: yes }
                value: true
              - else: false
          - key: cuisine
            include_when:
              amenity: [cafe, restaurant]
```

---

## Data Type Reference

When using `type:` in attributes:

| Type | Example | Notes |
|------|---------|-------|
| `boolean` | `true`, `false` | Stored as 1-bit flag |
| `integer` | `42`, `1200` | 32-bit signed integer |
| `long` | `999999999` | 64-bit signed integer |
| `double` | `3.14`, `2.5` | Floating point |
| `string` | `"John"` | Text (default if not specified) |
| `match_key` | The matched key name | Use key that matched in include_when |
| `match_value` | The matched value | Use value that matched in include_when |

---

## Expression Syntax Reference

### Constant Value
```yaml
value: "fixed_string"
value: 42
value: true
```

### Tag Value (get from source feature)
```yaml
tag_value: highway
# or
value:
  tag_value: surface
```

### Match Expression (conditional on tag values)
```yaml
value:
  motorway: "highway"
  trunk: "main"
  residential: "street"
  default: "other"
```

### Coalesce (fall through multiple options)
```yaml
value:
  coalesce:
    - tag_value: name
    - tag_value: name:en
    - tag_value: ref
    - value: "Unnamed"
```

### Inline Script (JavaScript-like expressions)
```yaml
value: "${ feature.length('meters') }"
value: "${ double(feature.tags.width) * 2 }"
value: "${ feature.area('km2') > 100 ? 'large' : 'small' }"
```

### Conditional Array (if/else structure)
```yaml
value:
  - if: { bridge: yes }
    value: true
  - if: { tunnel: yes }
    value: true
  - else: false
```

---

## Common Mistakes

### ❌ Mistake 1: String attributes
```yaml
attributes: [name, highway, surface]  # WRONG
```
✅ Fix: Make them objects
```yaml
attributes:
  - key: name
  - key: highway
  - key: surface
```

### ❌ Mistake 2: Including render/style information
```yaml
render:
  color: red
  width: 3
attributes: [...]
```
✅ Fix: Remove render block entirely
```yaml
attributes: [...]
# Styling is done in Mapbox GL style JSON, not here
```

### ❌ Mistake 3: Forgetting tag_mappings
```yaml
sources: {...}
layers: [...]  # Missing tag_mappings!
```
✅ Fix: Add tag_mappings for numeric/boolean tags
```yaml
sources: {...}
tag_mappings:
  capacity: integer
  level: integer
layers: [...]
```

### ❌ Mistake 4: Wrong expression syntax
```yaml
value:
  match: [name, highway, surface]  # WRONG structure
```
✅ Fix: Use proper syntax
```yaml
value:
  motorway: "highway"
  residential: "street"
  default: "other"
```

### ❌ Mistake 5: Missing key property
```yaml
attributes:
  - name  # Just string
  - highway
```
✅ Fix: Use key property
```yaml
attributes:
  - key: name
  - key: highway
```

---

## Testing Your Schema

```bash
# Test schema loading and validation
java -jar planetiler.jar generate-custom \
  schema=/path/to/schema.yml \
  osm-path=/path/to/data.pbf \
  output=/tmp/test.pmtiles \
  force=true

# With Docker
docker run -v /your/path:/data planetiler \
  generate-custom \
  schema=/data/schema.yml \
  osm-path=/data/data.pbf \
  output=/data/output.pmtiles \
  force=true
```

If there are no errors in the first 30 seconds, your schema syntax is valid!

---

## Further Reading

- Planetiler Repository: https://github.com/onthegomap/planetiler
- Shortbread Schema: https://github.com/shortbread-tiles/shortbread-docs
- Official Documentation: `planetiler-custommap/README.md` in repository
