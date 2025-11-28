# Codebase & Architecture Evaluation

## Current State (Phase 1 Complete)

### ✅ What Exists

**Infrastructure:**
- [x] Docker-based tile server (Planetiler + Nginx)
- [x] PMTiles serving with HTTP range request support
- [x] Colorado test region tiles generated
- [x] docker-compose.yml for local development
- [x] Build scripts (setup-docker.sh, generate-tiles.sh, start-tile-server.sh)

**Configuration:**
- [x] pnpm monorepo setup with workspaces
- [x] TypeScript configuration (strict mode)
- [x] .gitignore with appropriate patterns
- [x] Base Planetiler config (generic OSM schema)

**Documentation:**
- [x] README.md with quick start
- [x] ARCHITECTURE.md (comprehensive)
- [x] SETUP_UBUNTU.md (detailed setup guide)
- [x] README files in all major directories
- [x] Troubleshooting guides in tile-server docs

**Directory Structure:**
```
apps/web/                    - Empty (ready for Phase 2)
src/
  ├── tile-schema/           - Minimal Planetiler config
  ├── tile-provider/         - Empty (Phase 3)
  └── style/                 - Empty (Phase 2)
infrastructure/
  ├── tile-server/           - Complete and tested
  ├── cdn/                   - Empty (Phase 3)
  └── (no k8s yet - Phase 3+)
scripts/                      - Three working build scripts
docs/                         - SETUP_UBUNTU.md (more needed)
```

---

## Phase 2 Todo List (Web App)

### 2.1 Web App Scaffold
- [ ] Initialize `apps/web` with Vite + React + TypeScript
- [ ] Add essential dependencies:
  - maplibre-gl (map rendering)
  - react-map-gl (React wrapper)
  - zustand or jotai (state management)
  - typescript, vite, eslint, prettier
- [ ] Configure Vite (dev server, build, etc)
- [ ] Setup ESLint + Prettier config for the workspace

### 2.2 MapLibre GL Integration
- [ ] Create `Map` component with MapLibre GL
- [ ] Implement basic map controls (zoom, pan, rotation)
- [ ] Connect to local tile server (localhost:8080)
- [ ] Display cycling layers (roads, POIs)
- [ ] Verify tiles render correctly

### 2.3 Tile Source Management
- [ ] Create `TileSourceManager` in `src/tile-provider/`
  - Support multiple tile sources (self-hosted, online providers)
  - Dynamic source switching without map reload
  - Configuration for local dev vs production
- [ ] Implement source selector UI component
- [ ] Test with local tile server and public sources

### 2.4 Basic Style System
- [ ] Create `src/style/` with MapLibre GL style JSONs
  - Start with single "light" theme
  - Define cycling-focused layers:
    - Cycleways (dedicated, shared, lanes)
    - Bike parking & facilities
    - Roads (for context)
    - Water, parks, etc
- [ ] Make style composable/modular
- [ ] Add theme switcher (light theme for MVP)

### 2.5 UI & UX
- [ ] Create layout shell (header, map, sidebar)
- [ ] Add map controls (zoom, locate, fullscreen)
- [ ] Add source selector dropdown
- [ ] Add basic info panel
- [ ] Ensure PWA-ready (manifest.json, service worker stub)
- [ ] Mobile responsive design

### 2.6 Build & Development
- [ ] Setup local development workflow
  - `npm run dev` for web app only
  - `npm run dev:full` for full stack (tiles + web)
- [ ] Configure shared TypeScript paths
- [ ] Add build optimization
- [ ] Ensure monorepo dependencies work correctly

---

## Phase 3+ Todo List (Future)

### 3.1 Advanced Styling
- [ ] Dark theme variant
- [ ] High contrast/accessible theme
- [ ] Dynamic theme switching
- [ ] Layer visibility toggles
- [ ] Custom color schemes

### 3.2 Offline Support
- [ ] IndexedDB tile cache
- [ ] Service Worker implementation
- [ ] Offline mode detection
- [ ] Cache management UI

### 3.3 Tile Provider Expansion
- [ ] `src/tile-provider/` implementation:
  - ProtomapsSource (online fallback)
  - S3/R2 source (production CDN)
  - OfflineSource (cached tiles)
- [ ] Automatic fallback logic
- [ ] Performance monitoring

### 3.4 Cycling Features
- [ ] Enhanced Planetiler schema:
  - Surface type filtering
  - Smoothness information
  - Lighting information
  - Bike amenity filtering
- [ ] Route planning (optional, Phase 4+)
- [ ] Cycling-specific POIs
- [ ] Elevation data (optional)

### 3.5 Native Apps
- [ ] iOS app (Swift + MapLibre Native)
- [ ] Android app (Kotlin + MapLibre)
- [ ] Shared logic in src/
- [ ] App store distribution

### 3.6 Deployment & Infrastructure
- [ ] CDN setup (Cloudflare/CloudFront)
- [ ] S3/R2 bucket for tiles
- [ ] Kubernetes manifests (k8s/)
- [ ] CI/CD pipeline (GitHub Actions)
- [ ] Tile update automation

---

## Architecture Gaps to Address

### High Priority (Phase 2)
1. **Web app package** - Currently empty, critical for MVP
2. **Shared tile provider interface** - Needed for source switching
3. **MapLibre GL style definitions** - Core map styling
4. **TypeScript paths** - Configure monorepo imports

### Medium Priority (Phase 3)
1. **Advanced Planetiler schema** - Cycling-focused configuration
2. **Offline support** - Service worker + IndexedDB
3. **CDN infrastructure** - S3 + CloudFront/Cloudflare
4. **Theme system** - Light/dark/accessible variants

### Lower Priority (Phase 4+)
1. **Native apps** - iOS/Android
2. **Kubernetes deployment** - Production scaling
3. **Advanced routing** - Route planning features
4. **Analytics** - Usage tracking

---

## Files That Need Creation/Update

### Phase 2 Files (Critical)
```
apps/web/
├── package.json
├── vite.config.ts
├── tsconfig.json
├── src/
│   ├── App.tsx
│   ├── main.tsx
│   ├── components/
│   │   ├── Map.tsx
│   │   ├── MapControls.tsx
│   │   ├── SourceSelector.tsx
│   │   └── Layout.tsx
│   ├── hooks/
│   │   ├── useMap.ts
│   │   └── useMapSource.ts
│   ├── stores/
│   │   └── mapStore.ts
│   └── styles/
│       └── App.css
├── public/
│   └── manifest.json
└── index.html

src/
├── tile-provider/
│   ├── package.json
│   ├── index.ts
│   ├── types.ts
│   ├── TileSourceManager.ts
│   └── sources/
│       ├── LocalSource.ts
│       └── PublicSource.ts
│
└── style/
    ├── package.json
    ├── base.json
    ├── light.json
    └── cycling-layers.json
```

### Phase 2 Updates (Important)
- `package.json` - Add workspace dependencies for web app
- `tsconfig.json` - Add path mappings for monorepo
- `scripts/` - Add build script for web app
- `README.md` - Update with web app setup instructions

---

## Recommendations for Phase 2

### Approach
1. Start with minimal MapLibre GL integration
2. Use local tile server (already running)
3. Focus on getting a working map first
4. Then add UI/controls
5. Keep styling simple (no theme variants yet)

### Technology Choices
- **State Management:** Zustand (lightweight, ESM-friendly)
- **Bundler:** Vite (already configured in root)
- **CSS:** Vanilla CSS + CSS Modules (no extra deps)
- **HTTP Client:** Fetch API (for tile requests)
- **UI Framework:** HTML5 + React hooks (no component library yet)

### Dependencies to Add
```json
{
  "dependencies": {
    "maplibre-gl": "^4.0.0",
    "zustand": "^4.4.0"
  },
  "devDependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "typescript": "^5.3.0",
    "vite": "^5.0.0",
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0",
    "eslint": "^8.50.0",
    "prettier": "^3.0.0"
  }
}
```

### Success Criteria for Phase 2
- [ ] Vite dev server running
- [ ] Map renders with MapLibre GL
- [ ] Tiles from localhost:8080 display correctly
- [ ] Can zoom/pan the map
- [ ] Source selector switches between local and online source
- [ ] Build produces optimized bundle
- [ ] Code is TypeScript strict + ESLint compliant
- [ ] Mobile responsive

---

## Critical Questions to Answer

1. **Tile Source Fallback:** If local server is down, should it automatically fall back to a public source?
   - Recommendation: Yes, for better UX (but needs design decision)

2. **State Management:** Should map state persist across refreshes?
   - Recommendation: Yes for MVP (viewport position, zoom, theme)

3. **Service Worker:** Should we implement offline support immediately?
   - Recommendation: No, defer to Phase 3 (MVP can work online only)

4. **Theme Support:** Just light for MVP, or implement dark theme infrastructure?
   - Recommendation: Just light for MVP, infrastructure for Phase 3

5. **Monorepo Structure:** Should web app import from src/ packages?
   - Recommendation: Yes, use TypeScript paths for clean imports
