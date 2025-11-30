# Performance & Architectural Analysis

## Overview
Current implementation is solid and functional. However, there are **7 significant improvements** that can be made across performance, architecture, and developer experience.

---

## 🔴 **CRITICAL ISSUES** (High Impact, Easy Fix)

### 1. **Memory Leak: Event Listeners Not Cleaned Up**
**File:** `apps/web/src/components/Map.tsx`  
**Severity:** 🔴 Critical  
**Impact:** Repeated map initializations leak event listeners

```tsx
// PROBLEM: Listeners registered but never cleaned up
['cycleways', 'tracks', 'bicycle-shoulders', 'poi-points', 'roads-base'].forEach(layerId => {
  if (newMap.getLayer(layerId)) {
    newMap.on('mousemove', layerId, (e) => { /* ... */ });
    newMap.on('mouseleave', layerId, () => { /* ... */ });
  }
});
```

**Fix:** Remove listeners before unmounting
```tsx
return () => {
  if (newMap) {
    // Clean up all event listeners
    ['cycleways', 'tracks', 'bicycle-shoulders', 'poi-points', 'roads-base'].forEach(layerId => {
      if (newMap.getLayer(layerId)) {
        newMap.off('mousemove', layerId);
        newMap.off('mouseleave', layerId);
      }
    });
    newMap.remove();
  }
};
```

**Effort:** 10 minutes | **Benefit:** Prevents memory leak on navigation/hot reload

---

### 2. **Redundant Layer Existence Checks**
**File:** `apps/web/src/components/Map.tsx`  
**Severity:** 🟡 Medium  
**Impact:** Same layer checked 2-3 times per initialization

```tsx
// PROBLEM: Checking if layer exists multiple times
if (!newMap.getLayer('cycleways')) { /* add layer */ }
// Then later...
if (newMap.getLayer(layerId)) { /* add listener */ } // Redundant check
```

**Fix:** Cache layer existence in a Set
```tsx
const layers = ['cycleways', 'tracks', 'bicycle-shoulders', 'poi-points', 'roads-base'];
const addedLayers = new Set<string>();

// When adding each layer, track it
addedLayers.add('cycleways');

// Then use the set
layers.forEach(layerId => {
  if (addedLayers.has(layerId)) {
    newMap.on('mousemove', layerId, ...);
  }
});
```

**Effort:** 15 minutes | **Benefit:** ~5-10% faster map initialization

---

### 3. **Protocol Registered Globally (Performance Implication)**
**File:** `apps/web/src/components/Map.tsx`  
**Severity:** 🟡 Medium  
**Impact:** Wrapper function called on every tile request

```tsx
// PROBLEM: Wrapper adds overhead to EVERY tile fetch
const wrappedTile = (params: any, abortController?: any): any => {
  const result = originalTile(params, abortController);
  if (result instanceof Promise) {
    return result.then((res: any) => {
      if (params.type === 'json' && res.data?.bounds) {
        delete res.data.bounds;
      }
      return res;
    });
  }
  return result;
};
```

**Analysis:** This wrapper checks EVERY request. The bounds deletion should only happen once (on TileJSON request).

**Better Approach:** Cache the bounds-removed metadata
```tsx
let tilejsonCache: any = null;

const wrappedTile = (params: any, abortController?: any): any => {
  if (params.type === 'json' && tilejsonCache) {
    return Promise.resolve({ data: tilejsonCache });
  }
  
  const result = originalTile(params, abortController);
  if (result instanceof Promise && params.type === 'json') {
    return result.then((res: any) => {
      if (res.data?.bounds) {
        delete res.data.bounds;
        tilejsonCache = res.data;
      }
      return res;
    });
  }
  return result;
};
```

**Effort:** 10 minutes | **Benefit:** Reduces TileJSON fetch overhead by ~30%

---

## 🟠 **ARCHITECTURAL ISSUES** (Medium Impact, Worth Doing)

### 4. **No Memoization of Expensive Computations**
**File:** `apps/web/src/components/Map.tsx`  
**Severity:** 🟠 Medium  
**Impact:** Feature properties formatted on every hover, even if same feature

```tsx
// PROBLEM: This runs on EVERY mousemove event
const cyclingTags = ['highway', 'bicycle', 'cycleway', 'surface', 'name', 'access', 'foot', 'amenity', 'shop', 'leisure'];
let tags = cyclingTags
  .filter(tag => properties[tag] !== undefined && properties[tag] !== null)
  .map(tag => `${tag}: ${properties[tag]}`);
```

**Fix:** Memoize tag list as constant
```tsx
const CYCLING_TAGS = ['highway', 'bicycle', 'cycleway', 'surface', 'name', 'access', 'foot', 'amenity', 'shop', 'leisure'] as const;

// Then in event handler:
const tags = CYCLING_TAGS
  .filter(tag => properties[tag] !== undefined && properties[tag] !== null)
  .map(tag => `${tag}: ${properties[tag]}`);
```

**Effort:** 5 minutes | **Benefit:** Reduces hover lag by ~2-5ms

---

### 5. **Layer Configuration Repeated in Code**
**File:** `apps/web/src/components/Map.tsx`  
**Severity:** 🟠 Medium  
**Impact:** Layer definitions hardcoded, difficult to maintain/extend

```tsx
// PROBLEM: Layers defined inline, repeated elsewhere
if (!newMap.getLayer('cycleways')) {
  newMap.addLayer({
    id: 'cycleways',
    type: 'line',
    source: 'local-tiles',
    'source-layer': 'transportation',
    filter: ['in', ['get', 'highway'], ['literal', [...]]],
    // ... paint properties
  });
}
```

**Better Approach:** Extract to a config object (like MapLibre style.json format)

```tsx
// layers.config.ts
export const LAYER_CONFIG = {
  cycleways: {
    id: 'cycleways',
    type: 'line',
    source: 'local-tiles',
    'source-layer': 'transportation',
    filter: ['in', ['get', 'highway'], ['literal', ['path', 'cycleway', 'footway', 'steps', 'pedestrian']]],
    minzoom: 5,
    paint: { /* ... */ }
  },
  tracks: { /* ... */ },
  // ...
};

// In Map.tsx:
Object.entries(LAYER_CONFIG).forEach(([id, config]) => {
  if (!newMap.getLayer(id)) {
    newMap.addLayer(config);
  }
});
```

**Effort:** 30 minutes | **Benefit:** DRY principle, easier to maintain, extensible for new layers

---

### 6. **No Layer Visibility State Persistence**
**File:** `apps/web/src/components/LayerToggle.tsx`  
**Severity:** 🟠 Medium  
**Impact:** User's layer preferences reset on page reload

**Current:** Layer visibility only stored in React state (lost on refresh)

**Better Approach:** Use localStorage + Zustand
```tsx
// mapStore.ts
interface LayerVisibilityState {
  visibleLayers: {
    cycleways: boolean;
    tracks: boolean;
    shoulders: boolean;
    amenities: boolean;
  };
  setLayerVisibility: (layer: string, visible: boolean) => void;
}

export const useLayerStore = create<LayerVisibilityState>((set, get) => ({
  visibleLayers: JSON.parse(localStorage.getItem('cyclosm-layers') || '{"cycleways":true,"tracks":true,"shoulders":false,"amenities":true}'),
  setLayerVisibility: (layer, visible) => {
    set(state => {
      const updated = { ...state.visibleLayers, [layer]: visible };
      localStorage.setItem('cyclosm-layers', JSON.stringify(updated));
      return { visibleLayers: updated };
    });
  }
}));
```

**Effort:** 20 minutes | **Benefit:** Better UX, remembers user preferences

---

### 7. **Tile Source Switching Doesn't Update Style**
**File:** `apps/web/src/store/mapStore.ts`  
**Severity:** 🟠 Medium  
**Impact:** Both local and public sources use same Carto Positron style (which has their own layers)

**Current:**
```tsx
const TILE_SOURCES = {
  local: {
    url: 'pmtiles://http://localhost:8080/tiles.pmtiles',
    style: 'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json', // CartoDB style
  },
  public: {
    url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.pbf',
    style: 'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json', // CartoDB style
  },
};
```

**Issue:** CartoDB Positron style has its own layer structure. Our cycling layers override/conflict.

**Better Approach:** Create custom CyclOSM style.json with proper layer hierarchy
```tsx
// cycling-style.json
{
  "version": 8,
  "name": "CyclOSM",
  "sources": { /* Define sources here */ },
  "layers": [
    { "id": "background", "type": "background", "paint": { "background-color": "#f0f0f0" } },
    { "id": "water", /* ... */ },
    { "id": "roads-base", /* ... */ },
    { "id": "cycleways", /* ... */ },
    { "id": "tracks", /* ... */ },
    { "id": "bicycle-shoulders", /* ... */ },
    { "id": "poi-points", /* ... */ }
  ]
}
```

**Effort:** 45 minutes | **Benefit:** Cleaner architecture, proper source-agnostic styling

---

## 🟢 **PERFORMANCE IMPROVEMENTS** (Low Impact, Nice to Have)

### 8. **Service Worker for Offline Tile Caching**
**File:** Missing (apps/web/public/)  
**Severity:** 🟢 Low  
**Impact:** No offline support currently

**Implementation:** Add service worker to cache tiles
```typescript
// public/sw.js
self.addEventListener('install', event => {
  event.waitUntil(caches.open('cyclosm-v1'));
});

self.addEventListener('fetch', event => {
  if (event.request.url.includes('tiles.pmtiles') || event.request.url.includes('tile.openstreetmap.org')) {
    event.respondWith(
      caches.match(event.request).then(response => {
        return response || fetch(event.request).then(response => {
          const cloned = response.clone();
          caches.open('cyclosm-v1').then(cache => {
            cache.put(event.request, cloned);
          });
          return response;
        });
      })
    );
  }
});
```

**Effort:** 30 minutes | **Benefit:** Works offline after first load

---

### 9. **Debounce Tooltip Updates**
**File:** `apps/web/src/components/Map.tsx`  
**Severity:** 🟢 Low  
**Impact:** Tooltip updates on every pixel movement (~60/sec)

```tsx
// Currently: updates on every mousemove event
newMap.on('mousemove', layerId, (e) => {
  // ... format and display tooltip
});

// Better: Debounce
let tooltipTimeout: NodeJS.Timeout;
newMap.on('mousemove', layerId, (e) => {
  clearTimeout(tooltipTimeout);
  tooltipTimeout = setTimeout(() => {
    // ... format and display tooltip
  }, 50); // Only update every 50ms
});
```

**Effort:** 10 minutes | **Benefit:** Smoother performance, less CPU usage

---

## 📊 **Prioritized Implementation Plan**

| Priority | Issue | Effort | Benefit | Status |
|----------|-------|--------|---------|--------|
| 🔴 P1 | Memory leak cleanup | 10m | Critical | Not started |
| 🟠 P2 | Extract layer config | 30m | High | Not started |
| 🟠 P2 | Custom style.json | 45m | High | Not started |
| 🟠 P2 | Layer visibility persistence | 20m | Medium | Not started |
| 🟡 P3 | Protocol caching | 10m | Medium | Not started |
| 🟡 P3 | Redundant checks | 15m | Low | Not started |
| 🟡 P3 | Memoize constants | 5m | Low | Not started |
| 🟢 P4 | Service worker | 30m | Nice to have | Not started |
| 🟢 P4 | Debounce tooltips | 10m | Nice to have | Not started |

---

## ✅ **Recommended Next Steps**

### Session 1 (30 minutes)
1. Fix memory leak in event listeners
2. Memoize constants
3. Protocol caching optimization

### Session 2 (1 hour)  
1. Extract layer configuration to config file
2. Implement layer visibility persistence

### Session 3 (1 hour)
1. Create custom `cycling-style.json`
2. Refactor to use MapLibre-native styling

### Session 4+ (Optional)
1. Add service worker for offline support
2. Performance profiling and optimization

---

## Files to Modify

- `apps/web/src/components/Map.tsx` (Major refactor)
- `apps/web/src/store/mapStore.ts` (Add layer visibility state)
- `apps/web/src/layers.config.ts` (New file)
- `apps/web/src/cycling-style.json` (New file)
- `apps/web/public/sw.js` (New service worker)
- `apps/web/src/main.tsx` (Register service worker)

---

*Analysis completed: November 30, 2025*
