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
    
    cd /data
    
    # Download Colorado OSM data if not exists
    if [ ! -f /data/sources/colorado.osm.pbf ]; then
        echo "Downloading Colorado OSM extract..."
        curl -L https://download.geofabrik.de/north-america/us/colorado-latest.osm.pbf \
            -o /data/sources/colorado.osm.pbf
    fi
    
    # Use OpenMapTiles schema to generate tiles
    java -Xmx${PLANETILER_MEMORY:-8g} -jar /usr/local/bin/planetiler.jar \
        --area=colorado \
        --bounds=-109.06,36.99,-102.04,41.00 \
        --osm-path=/data/sources/colorado.osm.pbf \
        --output=/data/tiles.pmtiles \
        --force
    
    echo "Tile generation complete: /data/tiles.pmtiles"
    
elif [ "$1" = "tile-server" ]; then
    echo "Starting Nginx tile server..."
    echo "Serving PMTiles from /data/tiles.pmtiles"
    
    # Start Nginx in foreground
    nginx -g "daemon off;"
else
    exec "$@"
fi
