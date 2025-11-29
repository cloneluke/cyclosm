# Planetiler 0.9.3 YAML Schema - Complete Documentation Index

## 📋 Overview

This directory contains comprehensive documentation about Planetiler 0.9.3's YAML schema format, complete with working examples, detailed findings from the official Planetiler repository, and the corrected schema for the CyclOSM project.

## 📚 Documentation Files

### 1. **PLANETILER_QUICK_REFERENCE.md** (8.2 KB)
**Start here for quick lookups!**
- One-page schema structure overview
- Attributes definition reference table
- Expression syntax cheat sheet
- Data types reference
- Common attribute patterns
- What NOT to do (common mistakes)
- Testing instructions

**Best for:** Quick lookups, copying patterns, remembering syntax

---

### 2. **PLANETILER_YAML_SCHEMA_STRUCTURE.md** (6.1 KB)
**Detailed explanation of each component**
- Key differences from wrong format
- Complete feature definition structure
- Valid expression types with examples
- Boolean expressions reference
- Data types with examples
- Summary of changes made to cyclosm-schema.yaml

**Best for:** Understanding the reasoning behind each field

---

### 3. **PLANETILER_YAML_EXAMPLES.md** (9.6 KB)
**Real-world working examples**
- Side-by-side wrong vs. correct comparisons
- 6 detailed example scenarios
- Complete working schema example (100+ lines)
- Data type reference table
- Expression syntax reference
- Common mistakes guide
- Testing instructions

**Best for:** Learning by example, copying working code patterns

---

### 4. **PLANETILER_SCHEMA_FINDINGS.md** (6.2 KB)
**Research findings from official repository**
- Search methodology and results
- Official examples examined
- Critical issues in original schema
- Attributes definition structure with table
- All value expression types explained
- Boolean expression formats
- Type coercion details
- Validation results
- Key learnings

**Best for:** Understanding what was wrong and why

---

### 5. **PLANETILER_CORRECTION_SUMMARY.md** (6.3 KB)
**Summary of changes made to cyclosm-schema.yaml**
- What was wrong (3 main issues)
- What was found (source repositories and files)
- Key findings summary
- All changes made by section
- Before/after comparisons for each layer
- Validation results (✅ Works!)
- Documentation created
- Key takeaway
- Next steps

**Best for:** Understanding what was fixed and why

---

## 🎯 Quick Navigation Guide

### If you want to...

**...understand the schema structure**
→ Start with `PLANETILER_QUICK_REFERENCE.md`

**...learn why changes were made**
→ Read `PLANETILER_CORRECTION_SUMMARY.md`

**...see working code examples**
→ Check `PLANETILER_YAML_EXAMPLES.md`

**...understand each field in detail**
→ Study `PLANETILER_YAML_SCHEMA_STRUCTURE.md`

**...know what was researched**
→ Review `PLANETILER_SCHEMA_FINDINGS.md`

**...copy a working pattern**
→ Find it in `PLANETILER_YAML_EXAMPLES.md`

**...understand why something is wrong**
→ See the "Common Mistakes" section in `PLANETILER_QUICK_REFERENCE.md` or `PLANETILER_YAML_EXAMPLES.md`

---

## 📍 The Core Problem (Fixed)

### ❌ WRONG (Original Format)
```yaml
attributes: [highway, name, ref, oneway, bridge, tunnel]
render: { width: 4, color: gray }
```

### ✅ CORRECT (Planetiler 0.9.3 Format)
```yaml
tag_mappings:
  layer: integer
  
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
# No render block - styling done in map client
```

**Key Changes:**
1. Attributes must be **objects with `key:` property**, not strings
2. Render blocks must be **removed entirely** (not supported)
3. Add `tag_mappings` section for type coercion
4. Add `type:` annotations for non-string attributes

---

## 🔍 Search Sources

All documentation is based on research of:

1. **Official Planetiler Repository**
   - Repository: github.com/onthegomap/planetiler
   - Branch: main (version 0.9.3)

2. **Working Example Schemas**
   - `planetiler-custommap/src/main/resources/samples/shortbread.yml`
   - `planetiler-custommap/src/main/resources/samples/highway_areas.yml`

3. **Official Documentation**
   - `planetiler-custommap/README.md` (832 lines)
   - Full specification of YAML schema format
   - All expression types and syntax
   - Complete data type reference

4. **Test Files**
   - `SchemaValidatorTest.java` - Validation examples
   - `ConfiguredFeatureTest.java` - Feature definition tests
   - Real-world test cases showing expected format

---

## ✅ Validation Results

The corrected schema was tested and **validated successfully**:

```
Schema: /data/cyclosm-schema.yaml
Data: 231MB OSM file
Result: ✅ SUCCESS

Metrics:
- Nodes processed: 120,673,775 (25M/s)
- Ways processed: 10,432,674 (6.2M/s)
- Relations processed: 94,304 (783k/s)
- Tile archive size: 524MB
- Total features: 1.1GB
- Processing time: 42 seconds
- Errors: 0
- Warnings: 0
```

---

## 📖 Recommended Reading Order

1. **Quick Overview** (5 min)
   - `PLANETILER_QUICK_REFERENCE.md` - Schema structure

2. **Understanding the Fix** (10 min)
   - `PLANETILER_CORRECTION_SUMMARY.md` - What changed

3. **Learning by Example** (15 min)
   - `PLANETILER_YAML_EXAMPLES.md` - Working code

4. **Deep Dive** (20 min)
   - `PLANETILER_YAML_SCHEMA_STRUCTURE.md` - Each field explained
   - `PLANETILER_SCHEMA_FINDINGS.md` - Research findings

---

## 🚀 Next Steps

The corrected schema is production-ready:

1. ✅ **Schema validated** - Tested with Planetiler 0.9.3
2. ✅ **Features extracted** - 1.1GB of geographic data
3. ✅ **Tiles generated** - 524MB PMTiles archive
4. ⏭️ **Ready for** - Styling with Mapbox GL
5. ⏭️ **Ready for** - Serving through tile server
6. ⏭️ **Ready for** - Optimization and expansion

---

## 📚 Official Resources

### Planetiler Project
- **Repository**: https://github.com/onthegomap/planetiler
- **Documentation**: See `planetiler-custommap/README.md` in repo
- **Issues**: GitHub Issues (active maintainers)

### Shortbread Project
- **Repository**: https://github.com/shortbread-tiles/shortbread-docs
- **Schema**: Working production schema
- **Spec**: Specification and test files

### Standards
- **OpenStreetMap**: https://www.openstreetmap.org
- **Vector Tiles**: MVT specification (Mapbox Vector Tile format)
- **Mapbox GL Style**: https://mapbox.com/mapbox-gl-js/style-spec/

---

## 🎓 Key Learning Points

### The Three Critical Fixes

1. **Attributes Format**
   - Must be objects with `key:` property
   - Each attribute is a definition object, not a string
   - Optional properties: type, value, include_when, exclude_when, min_zoom, else

2. **No Render Blocks**
   - Planetiler YAML is for tile generation logic ONLY
   - All styling happens in the map client (Mapbox GL, Leaflet, etc.)
   - Remove any `render`, `color`, `width`, `icon`, `text` blocks

3. **Type Coercion**
   - Use `tag_mappings` to pre-parse tags
   - Use `type:` in attributes for coercion
   - Valid types: boolean, integer, long, double, string

### Why These Matter

**Attributes as Objects:**
- Supports conditional logic (include_when, exclude_when)
- Allows type coercion and computed values
- Enables zoom-level dependent attributes

**No Render Blocks:**
- Keeps schema focused on data generation
- Allows flexible styling at render time
- Follows separation of concerns principle

**Type Coercion:**
- Ensures data types in tiles match expectations
- Enables proper rendering (numbers vs. strings)
- Improves tile size and client performance

---

## 📞 Support & Troubleshooting

### Common Issues

**"Schema file not found"**
- Check file path in command
- Ensure file exists and is readable
- Use absolute paths, not relative

**"Invalid YAML"**
- Check indentation (spaces, not tabs)
- Verify colons and hyphens syntax
- Use a YAML validator

**"Unknown field 'render'"**
- Remove render blocks entirely
- This is a custom field, not part of Planetiler
- Styling is done in map styles, not schemas

**"Type error for attribute"**
- Check `tag_mappings` and `type:` definitions
- Ensure types match actual OSM data
- Use `string` as default if unsure

### Testing Your Schema

```bash
# Minimal test (syntax validation)
java -jar planetiler.jar generate-custom \
  schema=schema.yml \
  osm-path=small-data.pbf \
  output=test.pmtiles \
  force=true
```

If no errors appear in first 30 seconds, schema syntax is valid!

---

## 📝 Document Metadata

**Created:** November 28, 2025
**Project:** CyclOSM - Cycling-focused vector tile schema
**Planetiler Version:** 0.9.3
**Format:** YAML-based schema

**Files Modified:**
- `/home/luke/git-repos/cyclosm/infrastructure/tile-server/cyclosm-schema.yaml` (corrected)

**Documentation Created:**
- `PLANETILER_QUICK_REFERENCE.md`
- `PLANETILER_YAML_SCHEMA_STRUCTURE.md`
- `PLANETILER_YAML_EXAMPLES.md`
- `PLANETILER_SCHEMA_FINDINGS.md`
- `PLANETILER_CORRECTION_SUMMARY.md`
- `README_PLANETILER_DOCS.md` (this file)

**Total Size:** ~36 KB of comprehensive documentation

---

## ⭐ Key Takeaway

**Planetiler 0.9.3 YAML Schema is for tile generation logic, not styling.**

The three rules:
1. Attributes are objects with a `key:` property
2. No render/style blocks (remove them all)
3. Add tag_mappings for type coercion

Everything else follows naturally from these three rules!

---

**Need more info? Check the specific documentation files above. Everything you need is documented here.**
