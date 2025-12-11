#!/bin/bash
# Generate Overture Maps PMTiles using Planetiler in Docker
# This script generates custom Overture PMTiles with extended zoom coverage

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
DATA_DIR="${REPO_ROOT}/infrastructure/tile-server/data"
OUTPUT_FILE="${DATA_DIR}/overture-transportation.pmtiles"
CONFIG_FILE="${DATA_DIR}/planetiler-overture-config.yaml"

echo "=== Overture PMTiles Generation with Planetiler ==="
echo "Output: $OUTPUT_FILE"
echo "Config: $CONFIG_FILE"
echo ""

# Check if config exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config file not found: $CONFIG_FILE"
    exit 1
fi

# Method 1: Using Planetiler JAR directly (requires Java 21+)
if command -v java &> /dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | grep -oP 'version "\K[0-9]+' | head -1)
    if [ "$JAVA_VERSION" -ge 21 ]; then
        echo "Using local Java $JAVA_VERSION..."
        
        # Download Planetiler if not exists
        if [ ! -f "/usr/local/bin/planetiler.jar" ]; then
            echo "Downloading Planetiler..."
            curl -L https://github.com/onthegomap/planetiler/releases/download/v0.9.3/planetiler.jar \
                -o /usr/local/bin/planetiler.jar
            chmod +x /usr/local/bin/planetiler.jar
        fi
        
        echo "Starting Planetiler generation..."
        java -Xmx8g -jar /usr/local/bin/planetiler.jar \
            --schema "$CONFIG_FILE" \
            --output "$OUTPUT_FILE" \
            --minzoom 0 \
            --maxzoom 14 \
            --tile-compression gzip \
            --threads 4
    fi
fi

# Method 2: Using Docker (fallback)
if [ ! -f "$OUTPUT_FILE" ] && command -v docker &> /dev/null; then
    echo "Using Docker to generate tiles..."
    docker run --rm \
        -v "$DATA_DIR:/data" \
        eclipse-temurin:21-jre \
        bash -c 'apt-get update && apt-get install -y curl && \
            curl -L https://github.com/onthegomap/planetiler/releases/download/v0.9.3/planetiler.jar \
                -o /usr/local/bin/planetiler.jar && \
            java -Xmx8g -jar /usr/local/bin/planetiler.jar \
                --schema /data/planetiler-overture-config.yaml \
                --output /data/overture-transportation.pmtiles \
                --minzoom 0 \
                --maxzoom 14 \
                --tile-compression gzip \
                --threads 4'
fi

# Check if generation succeeded
if [ -f "$OUTPUT_FILE" ]; then
    SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
    echo "✓ Successfully generated: $OUTPUT_FILE ($SIZE)"
    echo ""
    echo "Next steps:"
    echo "1. Update .env.local to use local tiles:"
    echo "   VITE_OVERTURE_SEGMENT_PM_TILES=file://$OUTPUT_FILE"
    echo "   or serve from tile server and use:"
    echo "   VITE_OVERTURE_SEGMENT_PM_TILES=http://localhost:8080/overture-transportation.pmtiles"
    echo ""
    echo "2. Restart the dev server"
    echo "3. Refresh browser and verify purple cycleways appear at lower zoom levels"
else
    echo "ERROR: Tile generation failed or Java/Docker not available"
    echo "Requirements:"
    echo "  - Java 21+ (for local generation)"
    echo "  - OR Docker (for containerized generation)"
    echo "  - AWS credentials for S3 access (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)"
    exit 1
fi

