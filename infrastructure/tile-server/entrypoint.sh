#!/bin/bash
set -e

# Create data directory if it doesn't exist
mkdir -p /data

if [ "$1" = "tile-generation" ]; then
    echo "Starting Planetiler tile generation..."
    echo "Region: ${OSM_SOURCE:-colorado}"
    echo "Memory: ${PLANETILER_MEMORY:-8g}"
    
    # Create data directories
    mkdir -p /data/sources /data/tmp
    
    # Copy schema to /data where Planetiler expects it
    echo "DEBUG: Checking if /cyclosm-schema.yaml exists..."
    ls -la /cyclosm-schema.yaml || echo "ERROR: Schema file not found!"
    
    echo "DEBUG: Copying schema..."
    cp /cyclosm-schema.yaml /data/planetiler-config.yaml
    
    echo "DEBUG: Verifying copy..."
    ls -la /data/planetiler-config.yaml || echo "ERROR: Copy failed!"
    
    echo "Copied custom schema to /data/planetiler-config.yaml"
    
    cd /data
    
    # Download state OSM data if not exists
    echo "Downloading state OSM extracts..."
    
    if [ ! -f /data/sources/colorado.osm.pbf ]; then
        echo "Downloading Colorado..."
        curl -L https://download.geofabrik.de/north-america/us/colorado-latest.osm.pbf \
            -o /data/sources/colorado.osm.pbf
    fi
    
    if [ ! -f /data/sources/minnesota.osm.pbf ]; then
        echo "Downloading Minnesota..."
        curl -L https://download.geofabrik.de/north-america/us/minnesota-latest.osm.pbf \
            -o /data/sources/minnesota.osm.pbf
    fi
    
    if [ ! -f /data/sources/iowa.osm.pbf ]; then
        echo "Downloading Iowa..."
        curl -L https://download.geofabrik.de/north-america/us/iowa-latest.osm.pbf \
            -o /data/sources/iowa.osm.pbf
    fi
    
    if [ ! -f /data/sources/south-dakota.osm.pbf ]; then
        echo "Downloading South Dakota..."
        curl -L https://download.geofabrik.de/north-america/us/south-dakota-latest.osm.pbf \
            -o /data/sources/south-dakota.osm.pbf
    fi
    
    if [ ! -f /data/sources/nebraska.osm.pbf ]; then
        echo "Downloading Nebraska..."
        curl -L https://download.geofabrik.de/north-america/us/nebraska-latest.osm.pbf \
            -o /data/sources/nebraska.osm.pbf
    fi
    
    if [ ! -f /data/sources/north-dakota.osm.pbf ]; then
        echo "Downloading North Dakota..."
        curl -L https://download.geofabrik.de/north-america/us/north-dakota-latest.osm.pbf \
            -o /data/sources/north-dakota.osm.pbf
    fi
    
    # Merge all state files
    echo "Merging state OSM files..."
    osmium merge /data/sources/colorado.osm.pbf \
                 /data/sources/minnesota.osm.pbf \
                 /data/sources/iowa.osm.pbf \
                 /data/sources/south-dakota.osm.pbf \
                 /data/sources/nebraska.osm.pbf \
                 /data/sources/north-dakota.osm.pbf \
                 --overwrite \
                 -o /data/sources/merged.osm.pbf
    
    # Use custom CyclOSM YAML schema with cycleways from zoom 5
    # Must use 'generate-custom' task which requires explicit schema parameter
    java -Xmx${PLANETILER_MEMORY:-8g} -jar /usr/local/bin/planetiler.jar generate-custom \
        schema=/data/planetiler-config.yaml \
        osm-path=/data/sources/merged.osm.pbf \
        output=/data/tiles.pmtiles \
        only_download=false \
        force=true
    
    echo "Tile generation complete: /data/tiles.pmtiles"
    
elif [ "$1" = "tile-server" ]; then
    echo "Starting Nginx tile server..."
    echo "Serving PMTiles from /data/tiles.pmtiles"
    
    # Start Nginx in foreground
    nginx -g "daemon off;"
else
    exec "$@"
fi
