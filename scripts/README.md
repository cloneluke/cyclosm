# Build Scripts

Helper scripts for setting up and building CyclOSM Vector.

## setup-docker.sh

Verifies Docker installation and installs Docker Compose plugin.

**Usage:**
```bash
./scripts/setup-docker.sh
```

**What it does:**
- Checks if Docker is installed and running
- Fixes Docker socket permissions if needed
- Downloads and installs modern Docker Compose plugin (v2.24.0)
- Detects CPU architecture (x86_64 / ARM64)
- Automatically activates docker group membership

## generate-tiles.sh

Generates PMTiles from OSM data using Planetiler.

**Usage:**
```bash
./scripts/generate-tiles.sh
```

**What it does:**
- Verifies Docker is accessible
- Checks for existing tiles (asks before regenerating)
- Cleans up old Docker containers and networks
- Rebuilds the Planetiler Docker image with `--no-cache`
- Runs tile generation (10-30+ minutes depending on region)
- Reports final tile file size and location

**Configuration:**
Edit `infrastructure/tile-server/docker-compose.yml` to change:
- `OSM_SOURCE` - Region URL (default: Colorado from Geofabrik)
- `PLANETILER_MEMORY` - Heap size for Java (default: 8g)

## start-tile-server.sh

Starts the tile server to serve generated PMTiles.

**Usage:**
```bash
./scripts/start-tile-server.sh
```

**What it does:**
- Verifies Docker is accessible
- Checks that tiles exist
- Stops any running tile server containers
- Starts Nginx server on port 8080
- Shows test URLs and health check commands

**Test the server:**
```bash
curl http://localhost:8080/health
curl http://localhost:8080/tiles/0/0/0.pbf
```

## Quick Start

```bash
# 1. Setup Docker (one-time)
./scripts/setup-docker.sh

# 2. Generate tiles (one-time, ~15-30 min for Colorado)
./scripts/generate-tiles.sh

# 3. Start tile server
./scripts/start-tile-server.sh

# 4. Test (in another terminal)
curl http://localhost:8080/health
```

## npm Scripts

From the project root, you can also use npm scripts:

```bash
npm run tile-gen   # Generate tiles
npm run dev        # Start tile server
npm run build      # Build all packages
npm run lint       # Lint all packages
npm run format     # Format all packages
```

## Notes

- All scripts automatically activate docker group membership using `sg docker`
- Docker Compose v2.24.0 is used (modern plugin, replaces deprecated snap version)
- Tile generation is memory-intensive; adjust `PLANETILER_MEMORY` based on OSM data size:
  - Small region (<500MB): `4g`
  - Medium region (500MB-2GB): `8g` (default, Colorado)
  - Large region (2GB-10GB): `16g`
  - Full planet: `32g+`
- Tile server runs on `http://localhost:8080`
- See [infrastructure/tile-server/README.md](../infrastructure/tile-server/README.md) for server configuration

From the project root, you can also use npm scripts:

```bash
npm run tile-gen   # Generate tiles
npm run dev        # Start tile server
npm run build      # Build all packages
```

See root `package.json` for all available scripts.
