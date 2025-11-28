# Phase 2: Web App - Implementation Plan

## Overview
Build a working web PWA with MapLibre GL that displays tiles from the local tile server.

**Timeline:** 2-3 weeks  
**Goal:** MVP with basic cycling map, tile source switching, and responsive UI  
**Out of Scope:** Offline support, multiple themes, advanced features

---

## Sprint 1: Web App Scaffold & MapLibre Integration (Week 1)

### Sprint 1.1: Initialize React + Vite Project
**Time:** ~2-3 hours

**Tasks:**
1. Create `apps/web` directory structure
2. Generate Vite + React + TypeScript boilerplate
3. Install MapLibre GL and dependencies
4. Configure Vite for development
5. Setup ESLint + Prettier
6. Create basic `App.tsx` with empty map

**Deliverables:**
- Working Vite dev server (`npm run dev`)
- MapLibre GL canvas renders
- No errors in console

**Files to Create:**
```
apps/web/
├── package.json (with dependencies)
├── tsconfig.json
├── vite.config.ts
├── eslint.config.js
├── prettier.config.js
├── src/
│   ├── main.tsx
│   ├── App.tsx
│   └── index.css
├── public/
│   └── index.html
└── .gitignore
```

### Sprint 1.2: MapLibre GL Basic Setup
**Time:** ~2-3 hours

**Tasks:**
1. Create `Map.tsx` component with MapLibre GL instance
2. Initialize map with default center (Colorado coordinates)
3. Add map container styling (full screen)
4. Test map renders without tiles first
5. Verify map controls work (zoom, pan)

**Deliverables:**
- Map component renders and is interactive
- Can zoom and pan
- No tile errors yet (expected)

**Code Structure:**
```tsx
// App.tsx
import Map from './components/Map'

export default function App() {
  return <Map />
}

// components/Map.tsx
import maplibregl from 'maplibre-gl'
import { useEffect, useRef } from 'react'

export default function Map() {
  const mapContainer = useRef(null)
  const map = useRef(null)

  useEffect(() => {
    // Initialize map
    // Configure tile source
    // Add layers
  }, [])

  return <div ref={mapContainer} style={{ width: '100%', height: '100%' }} />
}
```

### Sprint 1.3: Connect to Local Tile Server
**Time:** ~2-3 hours

**Tasks:**
1. Configure map tile source to use `http://localhost:8080/tiles/{z}/{x}/{y}.pbf`
2. Add basic layer definitions (roads, water, parks)
3. Test tile loading from local server
4. Verify tiles render correctly
5. Add error handling for tile fetch failures

**Deliverables:**
- Tiles load and display on map
- No CORS errors
- Map shows Colorado cycling features

**MapLibre GL Config:**
```json
{
  "sources": {
    "cyclosm": {
      "type": "vector",
      "tiles": ["http://localhost:8080/tiles/{z}/{x}/{y}.pbf"],
      "minzoom": 0,
      "maxzoom": 14
    }
  },
  "layers": [
    {
      "id": "water",
      "type": "fill",
      "source": "cyclosm",
      "source-layer": "water",
      "paint": { "fill-color": "#aad3df" }
    }
  ]
}
```

---

## Sprint 2: Tile Provider & Source Switching (Week 2)

### Sprint 2.1: Create Tile Provider Library
**Time:** ~3-4 hours

**Tasks:**
1. Create `src/tile-provider` package
2. Define TypeScript interfaces for tile sources
3. Implement `TileSourceManager` class
4. Support local and public tile sources
5. Add configuration for switching sources

**Deliverables:**
- Tile provider library is reusable
- Can switch sources programmatically
- Types are properly exported

**File Structure:**
```
src/tile-provider/
├── package.json
├── src/
│   ├── index.ts
│   ├── types.ts
│   ├── TileSourceManager.ts
│   ├── sources/
│   │   ├── LocalSource.ts
│   │   └── PublicSource.ts
│   └── config.ts
└── tsconfig.json
```

### Sprint 2.2: Implement State Management
**Time:** ~2-3 hours

**Tasks:**
1. Choose state management (Zustand recommended)
2. Create map state store (viewport, source, zoom)
3. Persist state to localStorage
4. Connect to Map component
5. Test state updates

**Deliverables:**
- Map viewport persists across page reloads
- Source changes are captured in state
- No prop drilling needed

**Zustand Store Example:**
```ts
import { create } from 'zustand'

interface MapState {
  source: 'local' | 'public'
  center: [number, number]
  zoom: number
  setSource: (source: string) => void
  setCenter: (center: [number, number]) => void
  setZoom: (zoom: number) => void
}

export const useMapStore = create<MapState>((set) => ({
  source: 'local',
  center: [-105.2705, 40.0150],
  zoom: 8,
  setSource: (source) => set({ source }),
  setCenter: (center) => set({ center }),
  setZoom: (zoom) => set({ zoom }),
}))
```

### Sprint 2.3: Build Source Selector UI
**Time:** ~2-3 hours

**Tasks:**
1. Create `SourceSelector.tsx` component
2. Add dropdown with source options
3. Implement source switching logic
4. Handle tile source updates without page reload
5. Style the UI (minimal)

**Deliverables:**
- Dropdown in UI for source selection
- Map tiles update when source changes
- No loading delays or visual glitches

---

## Sprint 3: UI Polish & Finalization (Week 3)

### Sprint 3.1: Layout & Controls
**Time:** ~3-4 hours

**Tasks:**
1. Create `Layout.tsx` (header, map, sidebar)
2. Add map control buttons (zoom, locate, fullscreen)
3. Position UI elements (header, source selector)
4. Ensure mobile responsiveness
5. Test on different screen sizes

**Deliverables:**
- Professional looking UI
- All controls functional
- Mobile-friendly layout

### Sprint 3.2: Styling & Polish
**Time:** ~2-3 hours

**Tasks:**
1. Create base CSS variables (colors, fonts)
2. Style map container and controls
3. Add hover effects and transitions
4. Ensure dark text on light backgrounds (accessibility)
5. Optimize performance (CSS)

**Deliverables:**
- Consistent, polished look
- Good contrast ratios
- Smooth animations

### Sprint 3.3: Build & Optimization
**Time:** ~2-3 hours

**Tasks:**
1. Configure Vite production build
2. Test production bundle size
3. Add source maps for debugging
4. Optimize MapLibre GL bundle
5. Setup build scripts in root package.json

**Deliverables:**
- `npm run build` produces optimized bundle
- Bundle size < 500KB (gzipped)
- No TypeScript/ESLint errors

### Sprint 3.4: Testing & Documentation
**Time:** ~2-3 hours

**Tasks:**
1. Manual testing on desktop browsers
2. Mobile browser testing (iOS Safari, Android Chrome)
3. Test tile server fallback scenarios
4. Document how to extend with more sources
5. Update README with web app setup

**Deliverables:**
- All features tested and working
- Documentation for developers
- Known issues documented

---

## Key Decisions & Trade-offs

### MapLibre GL Version
- **Decision:** Use latest stable (v4.x)
- **Rationale:** Better performance, latest features

### State Management
- **Decision:** Zustand over Redux/Context
- **Rationale:** Minimal boilerplate, ESM-friendly, small bundle

### Styling Approach
- **Decision:** Vanilla CSS + CSS Modules
- **Rationale:** No dependencies, fast, learns CSS properly

### Tile Source Switching
- **Decision:** Implement local + one public source for MVP
- **Rationale:** Test architecture without building all sources

### Offline Support
- **Decision:** Defer to Phase 3
- **Rationale:** Add complexity, MVP can work online-only

---

## Success Criteria (MVP)

- [x] Vite dev server runs without errors
- [x] MapLibre GL renders on screen
- [x] Tiles load from localhost:8080
- [x] Can zoom and pan map
- [x] Source selector works
- [x] State persists across reloads
- [x] Mobile responsive
- [x] No TypeScript/ESLint errors
- [x] Production build < 500KB gzipped
- [x] Documented for future development

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Tile server down during dev | Blocks development | Run tile server in background, use public fallback |
| CORS issues | Map won't load tiles | Configure CORS in Nginx (already done) |
| Large bundle size | Poor performance | Tree-shake, minify, lazy-load |
| State persistence issues | UX regression | Test localStorage thoroughly |
| Mobile responsiveness | Poor mobile UX | Test early and often |

---

## Files to Create (Complete List)

```
apps/web/                           # New directory
├── package.json                    # React, MapLibre GL, etc
├── tsconfig.json                   # TypeScript config
├── tsconfig.app.json               # App-specific config
├── vite.config.ts                  # Vite configuration
├── eslint.config.js                # ESLint setup
├── prettier.config.js              # Prettier setup
├── index.html                       # HTML entry point
├── .gitignore                       # Ignore rules
├── src/
│   ├── main.tsx                    # Entry point
│   ├── App.tsx                     # Root component
│   ├── App.css                     # Global styles
│   ├── components/
│   │   ├── Map.tsx                # Map component
│   │   ├── MapControls.tsx        # Control buttons
│   │   ├── SourceSelector.tsx     # Source dropdown
│   │   └── Layout.tsx             # Layout shell
│   ├── hooks/
│   │   ├── useMap.ts              # Map initialization hook
│   │   └── useMapSource.ts        # Source switching hook
│   ├── stores/
│   │   └── mapStore.ts            # Zustand store
│   ├── types/
│   │   └── map.ts                 # TypeScript types
│   └── styles/
│       ├── variables.css           # CSS variables
│       ├── layout.css              # Layout styles
│       └── controls.css            # Control styles
└── public/
    └── manifest.json               # PWA manifest

src/tile-provider/                  # New package
├── package.json
├── tsconfig.json
├── src/
│   ├── index.ts
│   ├── types.ts
│   ├── config.ts
│   ├── TileSourceManager.ts
│   └── sources/
│       ├── LocalSource.ts
│       └── PublicSource.ts

src/style/                          # Update
├── package.json
├── src/
│   ├── base.json                   # Base style
│   └── layers/
│       ├── roads.json
│       ├── water.json
│       ├── parks.json
│       └── poi.json
```

---

## Next Steps

1. **Week 1 (Sprints 1.1-1.3):** Get MapLibre GL rendering tiles
2. **Week 2 (Sprints 2.1-2.3):** Implement source switching
3. **Week 3 (Sprints 3.1-3.4):** Polish and finalize

Start with Sprint 1.1 - scaffold the web app!
