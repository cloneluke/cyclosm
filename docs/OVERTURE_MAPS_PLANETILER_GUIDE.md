# Overture Maps + Planetiler: Complete Guide

## Overview

This guide shows how to generate vector tiles from Overture Maps data using Planetiler. Overture Maps provides GeoParquet files that can be directly processed by Planetiler (v0.9.3+) to create PMTiles archives.

---

## 1. Command-Line Examples for Running Planetiler with Overture Data

### Basic Command Structure

```bash
# Using planetiler.jar directly
java -Xmx8g -jar planetiler.jar generate-custom \
  --schema=schema.yml \
  --output=overture.pmtiles
```

### Adding Parquet Sources (Overture Data)

Planetiler supports reading GeoParquet files directly. The `addParquetSource()` method can be used in Java profiles, or configured via YAML schemas.

#### Java API Example (from OvertureBasemap.java in planetiler-examples):

```java
Path base = args.inputFile("base", "overture base directory", Path.of("data", "overture"));
Planetiler.create(args)
  .setProfile(new OvertureBasemap())
  .addParquetSource("overture-buildings",
    Glob.of(base).resolve("*", "type=building", "*.parquet").find(),
    true, // enable hive-partitioning
    fields -> fields.get("id"), // hash the ID field to generate unique long IDs
    fields -> fields.get("type")) // extract "type={}" from the filename to get layer
  .overwriteOutput(Path.of("data", "overture.pmtiles"))
  .run();
```

### Docker Command

```bash
docker run -v "$(pwd)/data":/data ghcr.io/onthegomap/planetiler:latest \
  generate-custom \
  --schema=/data/schema.yml \
  --output=/data/output.pmtiles
```

---

## 2. YAML Configuration Examples for Overture Tile Generation

### Basic YAML Schema Structure for Overture Data

```yaml
schema_name: Overture Maps
schema_description: Vector tiles from Overture Maps data
attribution: <a href="https://docs.overturemaps.org/attribution" target="_blank">&copy; Overture Maps Foundation</a>
version: 1.0.0

sources:
  overture:
    type: geoparquet  # or use local_path for parquet files
    url: <path-to-overture-parquet-files>

tag_mappings:
  # Define how to parse certain fields from parquet data
  height: integer
  building_area: double

layers:
  - id: buildings
    features:
      - source: overture
        geometry: polygon
        min_zoom: 13
        include_when:
          type: building
        attributes:
          - key: class
            tag_value: type
          - key: height
            tag_value: height
            type: integer
          - key: name
            tag_value: name
```

### Complex Example with Multiple Layers

```yaml
schema_name: Overture Complete Basemap
schema_description: Buildings and landcover from Overture Maps

sources:
  overture_buildings:
    type: geoparquet
    local_path: "/data/overture/type=building/*.parquet"
  
  overture_landcover:
    type: geoparquet
    local_path: "/data/overture/type=landcover/*.parquet"

tag_mappings:
  height: integer
  area: double

layers:
  - id: buildings
    features:
      - source: overture_buildings
        geometry: polygon
        min_zoom: 13
        attributes:
          - key: height
            tag_value: height
            type: integer
          - key: roof_color
            tag_value: roof_color
          - key: class
            tag_value: class
  
  - id: landcover
    features:
      - source: overture_landcover
        geometry: polygon
        min_zoom: 4
        include_when:
          class: [grass, tree, shrub, water]
        attributes:
          - key: class
            tag_value: class
```

---

## 3. Downloading Overture Parquet Files

### Official Overture Maps Sources

Overture Maps publishes data in GeoParquet format. Data is available from multiple sources:

#### AWS S3 (Official Release)

```bash
# Official Overture Maps beta release (2025-11-19)
# https://overturemaps.org/
# Data location: s3://overture-maps-prod/ (public bucket)

# Example: Download a specific theme and region
aws s3 cp \
  s3://overture-maps-prod/2025-11-19/theme=transportation/type=segment/*.parquet \
  ./data/overture-transportation/ \
  --recursive
```

#### GeoFabrik-style Shortcuts

While GeoFabrik provides OSM extracts, Overture data distribution is primarily through AWS S3. Planetiler v0.9.3+ includes utilities to access AWS OSM data.

### Planetiler's Built-in AWS Support

Planetiler includes `AwsOsm` utility class for downloading from AWS:

```java
// In your Java profile, you can use:
import com.onthegomap.planetiler.util.AwsOsm;

// Access Overture data through built-in utility methods
// See: https://github.com/onthegomap/planetiler/blob/main/planetiler-core/src/main/java/com/onthegomap/planetiler/util/AwsOsm.java
```

### Manual Download Instructions

1. **Visit Overture Maps Documentation**: https://docs.overturemaps.org/
2. **Theme Options**: Transportation, Buildings, Landcover, Places, Administrative Boundaries
3. **Data Format**: GeoParquet files organized by theme and type
4. **Region Coverage**: Global data with optional regional extracts

Example directory structure after download:
```
data/overture/
├── 2025-11-19/
│   ├── theme=transportation/
│   │   ├── type=segment/
│   │   │   ├── part-00000.parquet
│   │   │   └── part-00001.parquet
│   └── theme=buildings/
│       ├── type=building/
│           ├── part-00000.parquet
│           └── part-00001.parquet
```

---

## 4. Overture Profile Built into Planetiler

### Official Overture Example Profile

Planetiler includes a built-in Overture example (`OvertureBasemap.java`) in the planetiler-examples repository:

**Location**: `planetiler-examples/src/main/java/com/onthegomap/planetiler/examples/overture/OvertureBasemap.java`

**Key Features**:
- Reads from Overture GeoParquet files
- Supports hive-partitioned parquet directories
- Uses glob patterns to discover parquet files
- Generates PMTiles output

**Profile Structure**:

```java
public class OvertureBasemap implements Profile {
  
  @Override
  public void processFeature(SourceFeature source, FeatureCollector features) {
    String layer = source.getSourceLayer();
    switch (layer) {
      case "building" -> features.polygon("building")
        .setMinZoom(13)
        .inheritAttrFromSource("height")
        .inheritAttrFromSource("roof_color");
      case null, default -> {
        // ignore for now
      }
    }
  }

  @Override
  public String name() {
    return "Overture";
  }

  @Override
  public String description() {
    return "A basemap generated from Overture data";
  }

  @Override
  public String attribution() {
    return """
      <a href="https://www.openstreetmap.org/copyright" target="_blank">&copy; OpenStreetMap</a>
      <a href="https://docs.overturemaps.org/attribution" target="_blank">&copy; Overture Maps Foundation</a>
      """.replace("\n", " ").trim();
  }

  public static void main(String[] args) throws Exception {
    run(Arguments.fromArgsOrConfigFile(args));
  }

  static void run(Arguments args) throws Exception {
    Path base = args.inputFile("base", "overture base directory", Path.of("data", "overture"));
    Planetiler.create(args)
      .setProfile(new OvertureBasemap())
      .addParquetSource("overture-buildings",
        Glob.of(base).resolve("*", "type=building", "*.parquet").find(),
        true, // hive-partitioning
        fields -> fields.get("id"), // hash the ID field to generate unique long IDs
        fields -> fields.get("type")) // extract "type={}" from the filename to get layer
      .overwriteOutput(Path.of("data", "overture.pmtiles"))
      .run();
  }
}
```

**Running the Overture Profile**:

```bash
# Download planetiler
wget https://github.com/onthegomap/planetiler/releases/latest/download/planetiler.jar

# Run with Overture data
java -Xmx8g -jar planetiler.jar overture/OvertureBasemap.java \
  --base=/path/to/overture/data
```

---

## 5. Setting Custom Min/Max Zoom Levels for Overture Data

### In YAML Configuration

```yaml
layers:
  - id: buildings
    features:
      - source: overture_buildings
        geometry: polygon
        min_zoom: 13        # Buildings start appearing at z13
        max_zoom: 14        # Don't render above z14
        attributes:
          - key: height
            tag_value: height
            type: integer
          
          # Zoom-dependent attributes
          - key: name
            tag_value: name
            min_zoom: 14    # Name only appears at z14+

  - id: landcover
    features:
      - source: overture_landcover
        geometry: polygon
        min_zoom: 4         # Landcover visible from z4
        include_when:
          class: [grass, tree]
```

### Zoom Overrides with Default Values

```yaml
attributes:
  - key: size_category
    value:
      default_value: "small"
      overrides:
        13: "medium"
        14: "large"
        
  # Conditional min_zoom based on area
  - key: name
    tag_value: name
    min_zoom:
      default_value: 14
      overrides:
        # Only show names for large buildings at z13
        13: "${ double(feature.tags.area) > 5000 }"
```

### In Java Profile

```java
@Override
public void processFeature(SourceFeature source, FeatureCollector features) {
  // Building features from Overture
  if ("building".equals(source.getSourceLayer())) {
    var building = features.polygon("building")
      .setMinZoom(13)
      .setMaxZoom(14)
      .inheritAttrFromSource("height")
      .inheritAttrFromSource("roof_color");
    
    // Zoom-dependent feature inclusion
    int area = source.getTag("area") instanceof Number n ? n.intValue() : 0;
    if (area > 5000) {
      building.putAttr("name", source.getString("name"));
    }
  }
}
```

### Built-in Planetiler Arguments for Zoom Control

These apply globally across all zoom levels:

```bash
# Generate tiles from z0 to z14
java -jar planetiler.jar generate-custom \
  --schema=schema.yml \
  --minzoom=0 \
  --maxzoom=14 \
  --output=overture.pmtiles

# Or in schema YAML args section:
args:
  minzoom:
    default: 0
  maxzoom:
    default: 14
```

---

## Important Notes for Overture Maps Data

### Zoom Level Limitations

Overture Maps data has inherent zoom limitations:
- **Buildings**: Data available at high zoom levels (z14+)
- **Landcover**: Data available from z4+ depending on theme
- **Transportation**: Data available from z0+ (if using Overture transportation theme)

**Limitation in Official PMTiles**: The pre-built Overture PMTiles (2025-11-19) only includes cycleways at zoom 14+. For lower zoom levels, you need to generate custom PMTiles using Planetiler with filtered/simplified data.

### Field Names from Overture Parquet

Common Overture field names:
- `id` - Unique identifier (H3 index)
- `geometry` - GeoArrow encoded geometry
- `names` - Array of name variants
- `types` - Classifications (e.g., "building", "segment")
- `height` - Building height (buildings theme)
- `class` - Feature classification
- `area` - Computed area for features

### Hive Partitioning

Overture data is organized in Hive-partitioned directories:

```
theme=transportation/type=segment/*.parquet
theme=buildings/type=building/*.parquet
```

Planetiler's `addParquetSource()` with hive partitioning enabled automatically extracts type and theme values for filtering.

---

## Working Example: Cycleways from Overture Transportation

Based on your current implementation, here's the full workflow:

### 1. Download Overture Transportation Data

```bash
aws s3 cp \
  s3://overture-maps-prod/2025-11-19/theme=transportation/ \
  ./data/overture/transportation/ \
  --recursive
```

### 2. Create Schema for Cycleways Only

```yaml
schema_name: CyclOSM Overture
schema_description: Cycleway-filtered transportation from Overture Maps

sources:
  overture_transportation:
    type: geoparquet
    local_path: /data/overture/transportation/type=segment/*.parquet

layers:
  - id: cycleways
    features:
      - source: overture_transportation
        geometry: line
        min_zoom: 14  # Overture limitation
        include_when:
          class: [cycleway, cycle_track, path]
        attributes:
          - key: class
            tag_value: class
          - key: name
            tag_value: names
```

### 3. Run Planetiler

```bash
java -Xmx8g -jar planetiler.jar generate-custom \
  --schema=schema.yml \
  --output=overture-cycleways.pmtiles
```

---

## Documentation URLs

- **Overture Maps**: https://overturemaps.org/
- **Overture Documentation**: https://docs.overturemaps.org/
- **Planetiler GitHub**: https://github.com/onthegomap/planetiler
- **Planetiler Custom Map Docs**: https://github.com/onthegomap/planetiler/blob/main/planetiler-custommap/README.md
- **Planetiler Examples**: https://github.com/onthegomap/planetiler-examples
- **GeoParquet Format**: https://github.com/opengeospatial/geoparquet

---

## References

- **Planetiler Version**: 0.9.3+ required for full GeoParquet/Overture support
- **Java Version**: Java 21+ required
- **Parquet Support**: Planetiler includes Apache Parquet reader with minimal dependencies via parquet-floor
- **Attribution**: Overture Maps Foundation attribution required when using their data
