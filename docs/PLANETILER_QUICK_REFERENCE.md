# Planetiler 0.9.3 YAML Schema - Quick Reference Card

## The Core Problem: Attributes Format

```
❌ WRONG                           ✅ CORRECT
─────────────────────────────────────────────────────────
attributes:                        attributes:
  [                                  - key: highway
    highway,                          - key: name
    name,                            - key: bridge
    bridge                             type: boolean
  ]                                - key: tunnel
                                       type: boolean
```

**Remember:** Each attribute is an **object with a `key:` property**

---

## Planetiler YAML Schema Structure

```yaml
schema_name: <string>
schema_description: <string>
attribution: <string (HTML allowed)>
version: <string (optional)>
is_overlay: <boolean (default: false)>

# Define data sources
sources:
  <source_id>:
    type: <osm | shapefile | csv | etc>
    url: <file path or URL>

# Pre-parse certain tags with type coercion
tag_mappings:
  <tag_name>: <boolean | integer | long | double | string>

# Define output vector tile layers
layers:
  - id: <layer_name>
    features:
      - source: <source_id>
        geometry: <point | line | polygon | polygon_point_on_surface>
        min_zoom: <0-15>
        max_zoom: <0-15 (optional)>
        
        # Include/exclude conditions
        include_when:
          <tag>: [<value>, <value>] | __any__
        exclude_when:
          <tag>: <value>
        
        # Attributes to include in tiles
        attributes:
          - key: <output_attribute_name>
            tag_value: <source_tag (optional, defaults to key)>
            type: <boolean | integer | string | etc (optional)>
            value: <expression (optional)>
            include_when: <boolean_expression (optional)>
            exclude_when: <boolean_expression (optional)>
            min_zoom: <integer (optional)>
            else: <fallback_value (optional)>

# Test cases (optional but recommended)
examples:
  - name: <test_case_name>
    input:
      source: <source_id>
      geometry: <point | line | polygon>
      tags:
        <tag>: <value>
    output:
      - layer: <layer_id>
        geometry: <point | line | polygon>
        tags:
          <attribute>: <expected_value>
```

---

## Attributes Definition Reference

| Field | Type | Required | Example |
|-------|------|----------|---------|
| `key` | string | ✅ YES | `highway` |
| `tag_value` | string | ❌ | `name:en` |
| `type` | enum | ❌ | `boolean`, `integer` |
| `value` | expression | ❌ | See below |
| `include_when` | bool_expr | ❌ | `{bridge: yes}` |
| `exclude_when` | bool_expr | ❌ | `{access: private}` |
| `min_zoom` | number | ❌ | `11` |
| `else` | any | ❌ | `false` |

---

## Expression Syntax Cheat Sheet

### 1. Constant Value
```yaml
value: "water"
value: 42
value: true
```

### 2. Tag Value
```yaml
tag_value: surface
```

### 3. Match Expression (tag → value mapping)
```yaml
value:
  motorway: "major"
  trunk: "major"
  residential: "minor"
  default: "other"
```

### 4. Coalesce (try multiple sources)
```yaml
value:
  coalesce:
    - tag_value: name
    - tag_value: name:en
    - tag_value: ref
```

### 5. Inline Script
```yaml
value: "${ feature.length('meters') }"
value: "${ feature.area('km2') > 10 ? 'large' : 'small' }"
```

### 6. If/Else Array
```yaml
value:
  - if: { bridge: yes }
    value: true
  - else: false
```

---

## Data Types

Use in `type:` field:

| Type | Storage | Example |
|------|---------|---------|
| `boolean` | 1 bit | `true`, `false` |
| `integer` | 32-bit | `-2147483648` to `2147483647` |
| `long` | 64-bit | Large numbers |
| `double` | float | `3.14159` |
| `string` | variable | Text (default if not specified) |
| `match_key` | string | The matched key name |
| `match_value` | auto | The value that was matched |

---

## Boolean Expression Syntax

### In `include_when` and `exclude_when`:

#### Any value
```yaml
highway: __any__
```

#### Specific value
```yaml
access: private
```

#### Multiple values (OR)
```yaml
highway: [motorway, trunk, primary]
```

#### All conditions (AND)
```yaml
__all__:
  - highway: primary
  - surface: [gravel, dirt]
```

#### Negation (NOT)
```yaml
__not__:
  access: private
```

#### Complex
```yaml
__all__:
  - name: __any__
  - __not__:
      access: private
```

---

## Common Attribute Patterns

### Pattern 1: Simple Tag Passthrough
```yaml
- key: name
- key: highway
- key: surface
```

### Pattern 2: Type Coercion
```yaml
- key: capacity
  type: integer
- key: layer
  type: integer
- key: bridge
  type: boolean
```

### Pattern 3: Conditional Boolean
```yaml
- key: has_bridge
  type: boolean
  value:
    - if: { bridge: yes }
      value: true
    - else: false
```

### Pattern 4: Match Expression
```yaml
- key: road_class
  value:
    motorway: "highway"
    trunk: "trunk"
    residential: "street"
    default: "other"
```

### Pattern 5: Conditional Inclusion
```yaml
- key: ref
  min_zoom: 10           # Only at zoom 10+
  include_when:
    ref: __any__        # Only if tag exists
```

### Pattern 6: Fallback Chain
```yaml
- key: label
  value:
    coalesce:
      - tag_value: name
      - tag_value: name:en
      - tag_value: ref
      - value: "Unnamed"
```

---

## Geometry Types

Use in features `geometry:` field:

| Type | When to Use |
|------|------------|
| `point` | POI, city centers |
| `line` | Roads, rivers, paths |
| `polygon` | Buildings, parks, water bodies |
| `polygon_centroid` | Use polygon area, place at centroid |
| `polygon_point_on_surface` | Use polygon area, place on surface |
| `line_centroid` | Use line, place at center point |

---

## Real-World Example: Complete Feature

```yaml
- source: osm
  geometry: line
  min_zoom: 9
  max_zoom: 14
  include_when:
    highway: [secondary, tertiary]
  exclude_when:
    access: private
  attributes:
    # Basic tag passthrough
    - key: highway
    
    # With custom source tag
    - key: name
      tag_value: name
    
    # Type coercion
    - key: layer
      type: integer
    
    # Conditional
    - key: bridge
      type: boolean
      value:
        - if: { bridge: yes }
          value: true
        - else: false
    
    # Zoom-dependent
    - key: ref
      min_zoom: 12
    
    # Match expression
    - key: surface_type
      value:
        asphalt: "paved"
        gravel: "unpaved"
        dirt: "unpaved"
        default: "unknown"
    
    # Computed
    - key: length_km
      type: double
      value: "${ feature.length('km') }"
```

---

## What NOT to Do

### ❌ DON'T: Use render blocks
```yaml
render:
  color: red
  width: 3
  dash: [2, 2]
```
(Not supported in Planetiler YAML; use Mapbox GL style instead)

### ❌ DON'T: String attributes
```yaml
attributes: [highway, name, bridge]
```
(Must be objects with `key:` property)

### ❌ DON'T: Forget tag_mappings
```yaml
sources: { ... }
layers: { ... }
```
(Missing type hints for numeric/boolean tags)

### ❌ DON'T: Wrong value syntax
```yaml
value:
  - motorway
  - trunk
```
(Should be match expression with keys and values)

---

## Testing Your Schema

```bash
# Quick test - if no errors in 30s, syntax is valid
java -jar planetiler.jar generate-custom \
  schema=schema.yml \
  osm-path=data.pbf \
  output=test.pmtiles \
  force=true
```

If successful, you'll see:
- Schema loads without errors
- OSM data is processed (nodes, ways, relations)
- Tiles are generated
- Output file created

---

## Key Files to Consult

1. **Working Examples**
   - `shortbread.yml` - Full production schema
   - `highway_areas.yml` - Simple example

2. **Official Documentation**
   - `planetiler-custommap/README.md` - Complete specification
   - Includes all data types, expressions, and boolean syntax

3. **Test Files**
   - `SchemaValidatorTest.java` - Real test cases
   - `ConfiguredFeatureTest.java` - Feature definition examples

---

## Remember!

The three critical fixes:

1. **Attributes are objects:** `{key: highway}` not just `highway`
2. **No render blocks:** Remove all styling directives
3. **Add tag_mappings:** Pre-define types for numeric/boolean tags

Everything else follows from these three rules!
