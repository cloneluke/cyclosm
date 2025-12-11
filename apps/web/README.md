# CyclOSM Web App

React + Vite frontend that renders MapLibre GL vector tiles produced by the CyclOSM Planetiler pipeline.

## Prerequisites

- Node.js 18+
- pnpm 10.24.0 (install via Corepack)

```
corepack enable
corepack prepare pnpm@10.24.0 --activate
```

## Install & Run

```
pnpm install            # run from the repo root to hydrate all workspaces
pnpm --filter web dev   # launch the Vite dev server (http://localhost:5173)
```

The dev server expects a tile endpoint at `http://localhost:8080/tiles.pmtiles`.

## Building

```
pnpm run build          # runs tsc + Vite build for this workspace
```

## Bundle Analysis

```
cd apps/web
ANALYZE=true pnpm vite build
open dist/bundle-report.html
```

This enables the Rollup visualizer plugin and writes a treemap report (with gzip/brotli sizes) into `dist/`.

## Optional: Overture Transportation Overlay

You can stream the Overture Maps "transportation" tiles directly as an overlay.

1. Create `apps/web/.env.local` (if it doesn't exist).
2. Provide the official Overture PMTiles URL and source-layer name:

```
VITE_OVERTURE_SEGMENT_PM_TILES=https://overturemaps-tiles-us-west-2-beta.s3.amazonaws.com/2025-11-19/transportation.pmtiles
VITE_OVERTURE_SEGMENT_LAYER=segment
```

3. Restart `pnpm dev` so Vite picks up the env vars. A new "Overture" toggle will appear in the layer controls to toggle the transportation network overlay on top of the base map.
