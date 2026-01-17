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
    
    # Download state OSM data if not exists (parallel downloads)
    echo "Downloading state OSM extracts (parallel)..."
    
    # Define all states to download
    declare -A STATES=(
        ["colorado"]="colorado-latest.osm.pbf"
        ["minnesota"]="minnesota-latest.osm.pbf"
        ["iowa"]="iowa-latest.osm.pbf"
        ["south-dakota"]="south-dakota-latest.osm.pbf"
        ["nebraska"]="nebraska-latest.osm.pbf"
        ["north-dakota"]="north-dakota-latest.osm.pbf"
        ["missouri"]="missouri-latest.osm.pbf"
        ["kansas"]="kansas-latest.osm.pbf"
        ["wisconsin"]="wisconsin-latest.osm.pbf"
        ["tennessee"]="tennessee-latest.osm.pbf"
        ["illinois"]="illinois-latest.osm.pbf"
        ["south-carolina"]="south-carolina-latest.osm.pbf"
        ["arkansas"]="arkansas-latest.osm.pbf"
        ["michigan"]="michigan-latest.osm.pbf"
        ["indiana"]="indiana-latest.osm.pbf"
        ["ohio"]="ohio-latest.osm.pbf"
        ["oklahoma"]="oklahoma-latest.osm.pbf"
        ["texas"]="texas-latest.osm.pbf"
    )
    
    # Start all downloads in parallel
    DOWNLOAD_PIDS=()
    for state in "${!STATES[@]}"; do
        if [ ! -f "/data/sources/${state}.osm.pbf" ]; then
            echo "  → Starting download: $state"
            (
                curl -L --retry 3 --retry-delay 2 --progress-bar \
                    "https://download.geofabrik.de/north-america/us/${STATES[$state]}" \
                    -o "/data/sources/${state}.osm.pbf" && \
                echo "  ✓ Completed: $state"
            ) &
            DOWNLOAD_PIDS+=($!)
        else
            echo "  ✓ Already exists: $state"
        fi
    done
    
    # Wait for all downloads to complete
    if [ ${#DOWNLOAD_PIDS[@]} -gt 0 ]; then
        echo "Waiting for ${#DOWNLOAD_PIDS[@]} parallel downloads to complete..."
        for pid in "${DOWNLOAD_PIDS[@]}"; do
            wait "$pid" || echo "WARNING: Download process $pid failed"
        done
        echo "All downloads completed!"
    else
        echo "All state files already present, skipping downloads"
    fi
    
    # Extract Tennessee without boundary overlap to avoid merging duplicate nodes
    # Don't merge - let Planetiler handle multiple files directly
    # This avoids duplicate node IDs at state boundaries
    echo "Preparing state files for Planetiler..."
    
    # MERGE STATES WITH DEDUPLICATION
    # ================================
    # State boundary OSM files have identical node IDs at shared borders.
    # Without deduplication, Planetiler fails: "Nodes must be sorted ascending by ID"
    # 
    # Solution: Use osmium merge + osmconvert to normalize the data
    
    # Clean up any old merged file before starting
    rm -f /data/sources/merged.osm.pbf /data/sources/merged_clean.pbf
    
    echo "Collecting OSM PBF sources from /data/sources..."
    echo "DEBUG: Contents of /data/sources:"
    ls -lh /data/sources/ || echo "ERROR: Cannot list /data/sources"
    
    mapfile -t MERGE_INPUTS < <(ls -1 /data/sources/*.osm.pbf 2>/dev/null || true)
    if [ ${#MERGE_INPUTS[@]} -eq 0 ]; then
        echo "ERROR: No OSM PBF files found in /data/sources"
        echo "       Ensure downloads succeeded or mount host data into /data/sources"
        echo "DEBUG: Checking if directory exists: $(ls -ld /data/sources)"
        exit 1
    fi
    
    echo "Merging ${#MERGE_INPUTS[@]} file(s) into merged.osm.pbf..."
    echo "DEBUG: Files to merge:"
    printf '  - %s\n' "${MERGE_INPUTS[@]}"
    
    osmium merge --overwrite -o /data/sources/merged.osm.pbf "${MERGE_INPUTS[@]}"
    echo "Verifying merge output..."
    ls -lh /data/sources/merged.osm.pbf || { echo "ERROR: Merge output missing"; exit 1; }
    
    # CRITICAL: Clean duplicates via osmconvert re-encoding
    # This removes duplicate node IDs at state boundaries
    echo "Cleaning duplicate nodes with osmconvert..."
    osmconvert /data/sources/merged.osm.pbf -o=/data/sources/merged_clean.pbf
    mv /data/sources/merged_clean.pbf /data/sources/merged.osm.pbf
    
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
