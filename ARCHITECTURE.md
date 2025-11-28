# CyclOSM Vector - Architecture & Planning

## Project Overview

**Name:** cyclosm-vector  
**Structure:** Single repository with pnpm workspaces  
**Tech Stack:** TypeScript, MapLibre GL, Planetiler, PMTiles  
**Status:** Phase 2 complete - MVP web app with full functionality deployed  

---

## Current Status

### ✅ Phase 1: Foundation (Complete)
- Monorepo with pnpm workspaces configured
- Docker-based tile server (Planetiler + Nginx)
- Tile generation pipeline tested and working
- Colorado region tiles generated (PMTiles format)
- Build scripts for Docker setup, tile generation, and server startup
- Comprehensive setup documentation (Ubuntu/Docker/snap)

### ✅ Phase 2: Web App MVP (Complete)
**2.1-2.3: Core App Setup**
- React + Vite + TypeScript web app
- MapLibre GL integration with Carto Positron basemap
- Zustand state management
- Dev server running on localhost:5173

**2.4: Tile Source Selector**
- UI component for switching between local and public tiles
- Store integration with tile source configuration
- Active state styling

**2.5: Error Handling & Resilience**
- ErrorBoundary component catching React errors
- Toast notification system (auto-dismiss, 4 types)
- Map error event listeners
- Error state management in store

**2.6: Map Controls & UI Polish**
- MapControls with zoom, reset, geolocation buttons
- Geolocation support with browser API integration
- Attribution footer (OSM + CartoDB credits)
- Responsive design (desktop/tablet/mobile)
- Touch-friendly controls
- Proper z-index management

**Status:** ✅ Complete and deployed. See [docs/CODEBASE_EVALUATION.md](docs/CODEBASE_EVALUATION.md) for post-Phase-2 evaluation.

### 🔜 Phase 3+: Advanced Features
- Multiple style variants (light/dark/accessible)
- Offline caching with IndexedDB
- iOS/Android apps (post-MVP)
- CDN deployment infrastructure
- Advanced cycling features (route planning, etc.)
- MapLibre GL v5 upgrade (breaking changes - plan ahead)

---

## High-Level Architecture

```
┌──────────────────────────────────────────────────────────┐
│                  Data Layer                              │
├──────────────────────────────────────────────────────────┤
│  OSM Planet/Extracts → Planetiler → PMTiles             │
│  (Daily updates, cycling-optimized schema)              │
└──────────────────────────────────────────────────────────┘
                         ↓
┌──────────────────────────────────────────────────────────┐
│              Tile Storage & CDN                          │
├──────────────────────────────────────────────────────────┤
│  Primary: S3/R2 + CloudFront/Cloudflare                 │
│  Fallback: Protomaps API                                │
│  Offline: Local cache (IndexedDB/SQLite)                │
└──────────────────────────────────────────────────────────┘
                         ↓
┌──────────────────────────────────────────────────────────┐
│           Style Layer (MapLibre GL)                      │
├──────────────────────────────────────────────────────────┤
│  cyclosm-vector-style.json (source-agnostic)            │
│  • Dynamic source switching                              │
│  • Theme variants (light/dark/accessible)               │
└──────────────────────────────────────────────────────────┘
                         ↓
┌──────────────────────────────────────────────────────────┐
│              Client Applications                         │
├──────────────────────────────────────────────────────────┤
│  Web PWA    iOS Native    Android Native    Embeds      │
│  (TypeScript + Vite)  (Swift + MapLibre)                │
└──────────────────────────────────────────────────────────┘
```

---

## Repository Structure

```
cyclosm-vector/
├── src/
│   ├── style/
│   │   ├── cyclosm-vector.json       # Main MapLibre GL style
│   │   └── layers/
│   │       ├── cycleway.json
│   │       ├── bike-parking.json
│   │       └── infrastructure.json
│   │
│   ├── tile-schema/
│   │   ├── planetiler/
│   │   │   ├── config.yaml
│   │   │   └── layers/
│   │   └── cycling-extensions.yaml   # Custom cycling layers
│   │
│   └── tile-provider/
│       ├── TileSourceManager.ts
│       └── sources/
│           ├── SelfHostedSource.ts
│           ├── ProtomapsSource.ts
│           └── OfflineSource.ts
│
├── apps/
│   ├── web/                          # PWA (Vite + React + TypeScript)
│   │   ├── src/
│   │   ├── public/
│   │   └── vite.config.ts
│   │
│   ├── ios/                          # Swift + MapLibre Native
│   │   ├── CyclOSM Vector/
│   │   └── Podfile
│   │
│   └── android/                      # Kotlin + MapLibre Native
│       ├── app/
│       └── build.gradle
│
├── infrastructure/
│   ├── tile-pipeline/                # Tile generation scripts
│   │   ├── docker-compose.yml
│   │   ├── planetiler.sh
│   │   └── upload-to-cdn.sh
│   │
│   ├── cdn/                          # CDN configuration
│   │   ├── cloudflare.toml
│   │   └── workers/
│   │
│   └── k8s/                          # Kubernetes deployment
│       ├── deployment.yaml
│       └── ingress.yaml
│
├── docs/
│   ├── architecture.md
│   ├── tile-sources.md               # How to add custom tile sources
│   ├── contributing.md
│   └── deployment.md
│
├── scripts/
│   ├── generate-tiles.sh
│   ├── build-all.sh
│   └── deploy.sh
│
├── pnpm-workspace.yaml
├── package.json
├── tsconfig.json
└── README.md
```

---

## Technology Stack

### Core Technologies

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Tiles** | Planetiler | Generate vector tiles from OSM |
| **Tile Format** | PMTiles | Serverless, cloud-optimized tiles |
| **Styling** | MapLibre GL | Vector tile rendering |
| **Web App** | Vite + React + TypeScript | Modern PWA |
| **Mobile** | MapLibre Native (iOS/Android) | Native mobile apps |
| **Package Manager** | pnpm | Fast, efficient monorepo |
| **Offline** | Service Workers + IndexedDB | Progressive web features |
| **CDN** | Cloudflare/CloudFront | Global tile distribution |

### Why Vector Tiles?

- ✅ Better performance than raster
- ✅ Smaller file sizes
- ✅ Dynamic styling without re-rendering
- ✅ Works offline with local caching
- ✅ Better mobile experience
- ✅ Future-proof with OSM's modernization

---

## Key Design Decisions

### 1. Source-Agnostic Style

The MapLibre GL style works with any vector tile provider:
- Self-hosted tiles (primary)
- Protomaps (fallback)
- OSM vector tiles (when available)
- Custom tile server adapters

### 2. Offline-First Architecture

- Service workers cache tiles automatically
- Local tile storage (IndexedDB on web, SQLite on mobile)
- Works without internet after initial load
- Progressive enhancement (better with JS, functional without)

### 3. Single Repository

- Unified CI/CD pipeline
- Cohesive project identity
- Easier contributor onboarding
- pnpm workspaces for app organization

### 4. PMTiles Format

- Serverless tile serving
- Cloud storage compatible (S3, R2)
- No special server infrastructure needed
- Reduces operational complexity

### 5. Cycling-Focused Schema

Custom Planetiler configuration to highlight:
- Cycleways (`highway=cycleway`)
- Surface quality and suitability
- Bike parking and repair shops
- Hills and elevation
- Traffic calming measures

---

## Multi-Source Tile Provider Architecture

```typescript
export class TileSourceManager {
  private sources = {
    primary: 'self-hosted',
    fallback: ['protomaps', 'osm-vector'],
    offline: 'local-cache'
  };

  async getTileUrl(z: number, x: number, y: number): Promise<string> {
    // Try primary source
    const primaryUrl = await this.trySource('primary', z, x, y);
    if (primaryUrl) return primaryUrl;
    
    // Fallback cascade
    for (const fallback of this.sources.fallback) {
      const url = await this.trySource(fallback, z, x, y);
      if (url) return url;
    }
    
    // Return offline cache if available
    return this.sources.offline;
  }

  // Allow runtime source switching
  switchSource(newSource: string) {
    this.sources.primary = newSource;
  }
}
```

---

## Deployment Options

### Self-Hosted (Recommended for control)
- **Storage:** AWS S3 or Cloudflare R2
- **CDN:** CloudFront or Cloudflare
- **Tile Generation:** Docker on your infrastructure
- **Cost:** ~$50-200/month depending on traffic

### Hybrid Approach
- **Primary:** Self-hosted tiles
- **Fallback:** Protomaps (free, daily updates)
- **Offline:** Local cache
- **Cost:** Minimal ($0-50/month)

### Serverless
- **Cloudflare Workers:** Process tile requests
- **R2 Storage:** Store tiles
- **Cost:** Pay-per-use, often free tier sufficient

---

## Development Timeline (Estimated)

| Phase | Timeline | Focus |
|-------|----------|-------|
| **Phase 1** | Week 1-2 | Monorepo setup, tooling |
| **Phase 2** | Week 2-3 | MapLibre GL style creation |
| **Phase 3** | Week 3-4 | Planetiler tile schema |
| **Phase 4** | Week 4-5 | Web PWA |
| **Phase 5** | Week 5-6 | iOS/Android apps |
| **Phase 6** | Week 6+ | Testing, documentation, deployment |

---

## Competitive Advantages

Compared to original CyclOSM:
- ✅ Vector tiles (better performance)
- ✅ Offline-first mobile support
- ✅ Modern tech stack (TypeScript, MapLibre GL)
- ✅ Multi-source tile flexibility
- ✅ Native mobile apps
- ✅ Better developer experience
- ✅ Easier to maintain and extend

Compared to competitors:
- ✅ Free and open source (vs OpenCycleMap commercial)
- ✅ Offline support (vs web-only apps)
- ✅ Modern architecture (vs legacy OsmAnd rendering)
- ✅ Community-driven (vs proprietary)

---

## References & Resources

### OSM Ecosystem
- **OpenStreetMap Vector Tiles** - Official OSM vector tile initiative
- **Planetiler** - Vector tile generation tool
- **MapLibre GL** - Open source vector tile rendering
- **PMTiles** - Serverless tile format

### Cycling Data Standards
- **OpenCycleMap** - Established cycling map style
- **OSM Cycling Tags** - Standard tagging schema
- **iD Editor** - Community mapping tool

### Related Projects
- **OpenMapTiles** - Vector tile schema and tooling
- **Protomaps** - Free vector tile service
- **Organic Maps** - Modern offline mapping
- **Komoot** - Cycling route planning

---

## Next Steps

1. Create GitHub repository: `cyclosm-vector`
2. Initialize monorepo structure
3. Set up development environment
4. Create initial MapLibre GL style
5. Build Planetiler configuration
6. Develop web PWA prototype
7. Plan mobile app development

---

## Team & Contributions

This is a modernization of the original CyclOSM project.

**Original CyclOSM:** https://github.com/cyclosm/cyclosm-cartocss-style  
**New Project:** cyclosm-vector (fresh start)

**Contributing:** Guidelines to be established in CONTRIBUTING.md

---

*Last Updated: November 27, 2025*
