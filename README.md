# CyclOSM Vector

Modern vector tile map for cyclists built with MapLibre GL, Planetiler 0.9.3, and PMTiles.

**Status:** Phase 3 Complete - Custom cycling-focused tiles with cycleways visible from zoom 5 ✅

## Quick Start

### Prerequisites
- Linux/macOS (Ubuntu 20.04+ or equivalent)
- Docker & Docker Compose
- Node.js 20+ and pnpm 9+ (for web development)
- 4GB RAM minimum (8GB+ recommended for tile generation)

### Setup

1. **Install Docker and dependencies:**
   ```bash
   ./scripts/setup-docker.sh
   ```

2. **Generate custom tiles (one-time, ~10-15 min for 5-state region):**
   ```bash
   # Start tile generation service
   docker compose -f infrastructure/tile-server/docker-compose.yml up planetiler
   ```

3. **Start tile server:**
   ```bash
   docker compose -f infrastructure/tile-server/docker-compose.yml up tile-server
   # Or: ./scripts/start-tile-server.sh
   ```

4. **Start web dev server:**
   ```bash
   cd apps/web && npm run dev
   # Opens http://localhost:5173
   ```

5. **Verify tiles are serving:**
   ```bash
   curl http://localhost:8080/health              # Should return: OK
   curl -I http://localhost:8080/data/tiles.pmtiles  # Should return: 200 OK
   ```

## Project Structure

```
cyclosm-vector/
├── apps/
│   └── web/              # React PWA (Phase 2)
├── src/
│   ├── tile-schema/      # Planetiler configuration
│   ├── tile-provider/    # Tile source management
│   └── style/            # MapLibre GL styles
├── infrastructure/
│   ├── tile-server/      # Docker tile generation & serving
│   └── cdn/              # CDN configuration (future)
├── scripts/              # Build automation
│   ├── setup-docker.sh
│   ├── generate-tiles.sh
│   └── start-tile-server.sh
└── docs/
    └── SETUP_UBUNTU.md   # Detailed setup guide
```

## Development

### Useful Commands

```bash
# Setup Docker for the first time
./scripts/setup-docker.sh

# Generate tiles from OSM data
./scripts/generate-tiles.sh

# Start tile server (port 8080)
./scripts/start-tile-server.sh

# Build all packages
npm run build

# Build web app only (Phase 2)
cd apps/web && npm run build
```

### npm Scripts (root)

```bash
npm run build       # Build all packages
npm run dev         # Start tile server
npm run tile-gen    # Generate tiles (same as ./scripts/generate-tiles.sh)
npm run lint        # Lint all packages
npm run format      # Format all packages
```

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed architecture, design decisions, and roadmap.

### Current Tech Stack
- **Tiles:** Planetiler (generates) + Nginx (serves) + PMTiles (format)
- **Web:** React + Vite + TypeScript + MapLibre GL (Phase 2)
- **Infrastructure:** Docker + docker-compose
- **Package Manager:** pnpm with workspaces
- **Data:** OpenStreetMap (Geofabrik extracts)

## Phases

### Phase 1: Foundation ✅
- [x] Monorepo structure (pnpm workspaces)
- [x] Docker tile server (Planetiler + Nginx)
- [x] Tile generation working
- [x] Build scripts
- [x] Documentation

### Phase 2: Web App 📋
- [ ] React + Vite scaffold
- [ ] MapLibre GL integration
- [ ] Basic cycling map UI
- [ ] Tile source switching

### Phase 3+: Advanced Features
- [ ] Multiple style themes
- [ ] Offline support (IndexedDB)
- [ ] iOS/Android apps
- [ ] CDN deployment
- [ ] Route planning
- [ ] Advanced cycling layers

## Setup Guide

For detailed setup instructions on Ubuntu with Docker snaps, see [docs/SETUP_UBUNTU.md](docs/SETUP_UBUNTU.md).

## Tile Server

The tile server provides PMTiles via HTTP with:
- HTTP range request support for efficient loading
- Caching headers (max-age: 86400)
- CORS enabled for web clients
- Health check endpoint

See [infrastructure/tile-server/README.md](infrastructure/tile-server/README.md) for configuration options.

## Contributing

This is an active development project. See [ARCHITECTURE.md](ARCHITECTURE.md) for the roadmap and next steps.

## License

MIT (to be determined)

## Resources

- [MapLibre GL Documentation](https://maplibre.org/)
- [Planetiler Documentation](https://github.com/onthegomap/planetiler)
- [PMTiles Specification](https://protomaps.com/docs/pmtiles)
- [OpenStreetMap](https://www.openstreetmap.org/)
- [CyclOSM Original](https://cyclosm.org/)
