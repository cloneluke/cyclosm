# src/ - Reserved for Shared Libraries

This directory is reserved for future shared packages and configurations that may be needed across applications.

## Future Use

Currently, all active development is in `apps/web` and `infrastructure/tile-server`. This directory can be populated with:
- Shared TypeScript utilities and types
- Tile schema definitions (currently in `infrastructure/tile-server/planetiler-config.yaml`)
- Shared configuration management

## Current Workspace Structure

- **apps/web/** - React web application (active)
- **infrastructure/tile-server/** - Docker tile server and Planetiler config (active)
- **scripts/** - Build and automation scripts (active)
- **src/** - Future shared libraries (reserved)
