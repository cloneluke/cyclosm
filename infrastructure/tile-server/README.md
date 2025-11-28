# CyclOSM Vector - Tile Server

Containerized tile generation and serving for development and deployment.

## Quick Start

### Generate tiles (one-time)
```bash
docker compose build --no-cache
docker compose --profile tile-generation up planetiler
```

This will:
1. Download OSM data (configured region in docker-compose.yml)
2. Process with Planetiler using cycling-optimized schema
3. Output PMTiles archive to `./data/tiles.pmtiles`

**Note:** First run takes time depending on region size:
- Colorado extract: ~10-15 minutes
- Full US: ~2-3 hours
- Full planet: ~6-8 hours

### Run tile server
```bash
docker compose up tile-server
```

Access tiles at: `http://localhost:8080/tiles/{z}/{x}/{y}.pbf`

## Configuration

### Region Selection
Edit `docker-compose.yml`:

```yaml
OSM_SOURCE: "https://download.geofabrik.de/north-america/us/colorado-latest.osm.pbf"
```

Options:
- **Full planet** (70GB+): `https://planet.openstreetmap.org/pbf/planet-latest.osm.pbf`
- **Regional extracts**: https://download.geofabrik.de/
- **Pre-processed**: https://www.interline.io/osm/extracts/

### Memory
Adjust `PLANETILER_MEMORY` in docker-compose.yml based on OSM data size:
- Small region (<500MB): `4g`
- Medium region (500MB-2GB): `8g`
- Large region (2GB-10GB): `16g`
- Full planet: `32g+`

### Tile Schema
Edit `planetiler-config.yaml` to include/exclude layers or adjust features.

## Architecture

**Planetiler Service:**
- Reads OSM PBF data
- Applies cycling-focused schema
- Outputs PMTiles archive

**Nginx Tile Server:**
- Serves PMTiles via HTTP range requests
- Supports caching headers
- CORS-enabled for web clients

## Development Workflow

```bash
# Start everything (uses cached tiles if available)
docker compose up

# In another terminal, test the API
curl http://localhost:8080/health
curl http://localhost:8080/tiles/2/1/1.pbf

# Stop services
docker compose down

# View logs
docker compose logs -f tile-server
docker compose logs -f planetiler
```

## Production Deployment

1. Generate tiles once on your infrastructure
2. Upload `tiles.pmtiles` to S3/R2/GCS
3. Serve via CloudFront/Cloudflare cache
4. Or use Cloudflare Workers for serverless serving

See `../../docs/deployment.md` for detailed instructions.

## Docker Compose Syntax

Use `docker compose` (space) instead of the deprecated `docker-compose` (hyphen) command. The plugin version is built into modern Docker installations and receives active maintenance. If you have the old snap version installed, consider uninstalling it:

```bash
sudo snap remove docker-compose
```

## Troubleshooting

### Docker Permission Denied
```bash
sudo usermod -aG docker $USER
newgrp docker
# Log out and back in for group changes
```

### Container Already Exists
If you get "container name already in use" error:
```bash
docker compose down
docker compose --profile tile-generation up planetiler
```

Or clean up all Docker resources:
```bash
docker system prune -f
docker compose --profile tile-generation up planetiler
```

### Docker Compose Not Found
The modern `docker compose` command should be built into Docker. If missing:
```bash
mkdir -p ~/.docker/cli-plugins/
curl -SL https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-linux-x86_64 \
  -o ~/.docker/cli-plugins/docker-compose
chmod +x ~/.docker/cli-plugins/docker-compose
```
