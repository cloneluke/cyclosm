# CyclOSM Vector - Component Upgrade Analysis

## Overview
A comprehensive assessment of all major components and upgrade opportunities.

---

## 1. WEB APPLICATION (apps/web/)

### Current Stack
- **Framework:** React 19.2.0 ✅ Latest stable
- **Build Tool:** Vite 7.2.4 ✅ Latest stable  
- **Map Library:** MapLibre GL 5.13.0 ✅ Latest stable
- **Tile Format:** PMTiles 4.3.0 ✅ Latest stable
- **State Management:** Zustand 5.0.8 ✅ Latest stable
- **TypeScript:** 5.9.3 ✅ Current stable
- **ESLint:** 9.39.1 ✅ Latest stable
- **Node:** 20+ ✅ Recommended

### Assessment: ✅ EXCELLENT - No upgrades needed
The web app dependencies are all at latest versions. The stack is modern and well-maintained.

### Potential Improvements (Non-Critical)
1. **TypeScript 5.10 (when released)** - Minor improvements, can wait
2. **Consider adding:** 
   - Testing framework (Vitest, React Testing Library)
   - Storybook for component development
   - Build size optimization monitoring

---

## 2. TILE SERVER (infrastructure/tile-server/)

### Current Stack
- **Base Image:** Eclipse Temurin 21-JRE (Ubuntu Noble) ✅ Latest LTS
- **Planetiler:** 0.9.3 (May 2025) ✅ Latest stable
- **OSM Tools:** osmium-tool ✅ Latest (apt package)
- **Osmconvert:** osmctools ✅ Latest (apt package)
- **Web Server:** Nginx (apt package) ✅ Latest
- **Docker:** 3.8 compose format ✅ Current stable

### Assessment: ✅ VERY GOOD
Planetiler 0.9.3 is recent and has excellent YAML schema support.

### Upgrade Path (Optional)
1. **Planetiler 0.10+ (when released)** 
   - Monitor: https://github.com/onthegomap/planetiler/releases
   - Action: Update URL in Dockerfile when released
   - Risk: LOW (point releases are usually compatible)

2. **Base Image - Eclipse Temurin 23 (Java 23)**
   - Current: Java 21 (LTS)
   - Benefit: Latest performance improvements
   - Timeline: When tested with Planetiler 0.10+
   - Risk: LOW (JVM compatibility good)

---

## 3. DEPLOYMENT & ORCHESTRATION

### Current Setup
- **Docker Compose:** Version 3.8 ✅ Stable
- **Multi-service:** Planetiler + Nginx tile server
- **Volume management:** Local bind mounts

### Assessment: ⚠️ FUNCTIONAL - COULD IMPROVE

#### Issues Found
1. **No production deployment setup**
   - No Kubernetes/Swarm manifests
   - No environment variable management beyond local
   - No backup strategy for tiles.pmtiles

2. **nginx.conf not reviewed** - Need to check:
   - HTTPS/TLS support
   - Cache headers optimization
   - CORS configuration
   - Rate limiting

#### Recommended Upgrades
1. **Add production docker-compose file**
   ```
   docker-compose.prod.yml with:
   - Resource limits
   - Restart policies
   - Health checks
   - Volume backup strategy
   ```

2. **Consider Kubernetes (Future)**
   - If multi-node tile server needed
   - If high-availability required
   - Provides: Auto-scaling, self-healing, rolling updates

---

## 4. INFRASTRUCTURE (scripts/)

### Current Status
- **setup-docker.sh** - ✅ Working
- **generate-tiles.sh** - ⚠️ Outdated (references old states)
- **Various overture scripts** - ⚠️ Incomplete (references missing data)

### Assessment: ⚠️ NEEDS CLEANUP

#### Issues
1. **Obsolete scripts**: overture-regional-*.sh scripts have:
   - References to missing Overture data files
   - Incomplete implementation
   - Not maintained with recent changes

2. **Documentation drift**: scripts/README.md out of sync with actual state coverage

#### Recommended Actions
1. **Archive old overture scripts** (v1.0 attempt)
2. **Update generate-tiles.sh** to use current 12-state setup
3. **Create state-management utility**:
   ```bash
   add-state.sh - Interactive script to:
   - Add download block
   - Add to merge command
   - Validate before building
   - Run generation
   ```

---

## 5. BUILD & CI/CD PIPELINE

### Current Status
- **No CI/CD** ❌
- **No automated testing** ❌
- **No linting in git hooks** ⚠️
- **Manual rebuild process** ⚠️

### Assessment: ⚠️ MISSING CRITICAL INFRASTRUCTURE

#### Recommended Setup
1. **GitHub Actions (if on GitHub)**
   ```yaml
   - Lint on PR
   - TypeScript check
   - Build web app
   - Build Docker image (on push to main)
   - Run tile generation test (small region)
   - Push Docker to registry
   ```

2. **Pre-commit hooks**
   ```bash
   - ESLint check
   - TypeScript type check
   - Prettier formatting
   ```

3. **Automated tile generation**
   - Scheduled weekly generation
   - Triggered on add-state changes
   - Upload to CDN/storage

---

## 6. DOCUMENTATION SITE (docs/)

### Current State
- **ADD_STATE_GUIDE.md** ✅ Just updated (excellent)
- **ARCHITECTURE.md** ✅ Comprehensive
- **Multiple technical docs** ✅ Well organized
- **Missing:** User/deployment documentation

### Assessment: ⚠️ GOOD TECHNICAL, NEEDS USER DOCS

#### What's Missing
1. **Deployment guide** - How to:
   - Deploy to production server
   - Configure HTTPS/DNS
   - Monitor tile generation
   - Scale to more states

2. **User guide** - How to:
   - Use the web app
   - Contribute cycling data
   - Report issues

3. **Architecture decision record (ADR)** - Document:
   - Why osmconvert deduplication
   - Why PMTiles over MBTiles
   - Why Planetiler over other tools

---

## 7. DATA MANAGEMENT

### Current Status
- **State files:** Downloaded on-demand ✅
- **Merged file:** Not retained ⚠️
- **Tile cache:** Single file (1.3GB) ⚠️
- **No versioning** ⚠️

### Assessment: ⚠️ FUNCTIONAL BUT BRITTLE

#### Issues
1. **No tile history** - Can't roll back to previous tiles
2. **Single point of failure** - One tiles.pmtiles file for all states
3. **No incremental updates** - Must regenerate all states even if 1 changes

#### Recommended Improvements
1. **Versioned tiles directory**
   ```
   data/tiles/
   ├── v20260101_12states.pmtiles
   ├── v20251220_10states.pmtiles
   └── current -> v20260101_12states.pmtiles
   ```

2. **Tile metadata file**
   ```json
   {
     "version": "v20260101",
     "states": ["CO", "MN", "IA", "SD", "NE", "ND", "MO", "KS", "WI", "TN", "IL", "SC"],
     "generated": "2026-01-01T21:54:00Z",
     "size_bytes": 1395864371,
     "features": 46990812
   }
   ```

3. **Incremental state updates** (Future):
   - Generate per-state PMTiles
   - Merge at runtime with TileServer's multi-source support
   - Allows updating individual states

---

## 8. MONITORING & OBSERVABILITY

### Current Status
- **Docker healthcheck** ✅ Tile server
- **No metrics** ❌
- **No logging strategy** ⚠️
- **No uptime monitoring** ❌

### Assessment: ❌ MISSING

#### Recommended Additions
1. **Prometheus metrics**
   - Tile generation duration
   - Tile cache hit rate
   - HTTP request latency
   - Disk usage

2. **Logging**
   - Tile server access logs
   - Planetiler generation logs (already captured)
   - Error tracking (Sentry integration)

3. **Uptime monitoring**
   - Ping tile server endpoint
   - Alert on failures
   - Dashboard (Grafana)

---

## UPGRADE PRIORITY MATRIX

### 🔴 Critical (Do immediately if deploying)
- [ ] Add CI/CD pipeline
- [ ] Add pre-commit hooks
- [ ] Create production docker-compose.yml
- [ ] Add deployment documentation

### 🟡 Important (Nice to have soon)
- [ ] Clean up obsolete scripts
- [ ] Add monitoring/logging
- [ ] Version tiles with metadata
- [ ] Create state management utility script

### 🟢 Nice to have (Can wait)
- [ ] Add testing framework to web app
- [ ] Add Storybook for components
- [ ] Kubernetes manifests
- [ ] Incremental tile updates

---

## QUICK WIN: Immediate Actions (30 minutes)

1. **Create add-state.sh script** - Automate the process we just proved works
2. **Update scripts/README.md** - Document current state setup
3. **Add .pre-commit-config.yaml** - Catch issues before commit
4. **Create tiles-metadata.json** - Track what's in current tiles.pmtiles

---

## Summary Table

| Component | Version | Status | Action |
|-----------|---------|--------|--------|
| React | 19.2.0 | Latest | None |
| Vite | 7.2.4 | Latest | None |
| MapLibre GL | 5.13.0 | Latest | None |
| Planetiler | 0.9.3 | Recent | Monitor for 0.10 |
| Java | 21 LTS | Good | Update with Planetiler 0.10 |
| Docker | 3.8 | Current | None |
| CI/CD | None | Missing | **Implement** |
| Testing | None | Missing | **Consider** |
| Monitoring | None | Missing | **Consider** |
| Deployment docs | None | Missing | **Create** |

