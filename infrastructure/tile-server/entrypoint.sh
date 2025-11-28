#!/bin/bash
set -e

# Create data directory if it doesn't exist
mkdir -p /data

if [ "$1" = "tile-generation" ]; then
    echo "Starting Planetiler tile generation..."
    echo "Region: ${OSM_SOURCE:-planet}"
    echo "Memory: ${PLANETILER_MEMORY:-16g}"
    
    cd /data
    # Use Planetiler's built-in OpenStreetMap schema
    # We'll customize the schema in a future iteration
    java -Xmx${PLANETILER_MEMORY:-16g} -jar /usr/local/bin/planetiler.jar \
        --download \
        --output=tiles.pmtiles
    
    echo "Tile generation complete: /data/tiles.pmtiles"
    
elif [ "$1" = "tile-server" ]; then
    echo "Starting Nginx tile server..."
    echo "Serving PMTiles from /data/tiles.pmtiles"
    
    # Start Nginx in foreground
    nginx -g "daemon off;"
else
    exec "$@"
fi
