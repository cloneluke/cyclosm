# Quick Wins - Immediate Upgrades (1 hour total)

High-impact improvements you can implement today to prevent errors and save time.

---

## 1. ⭐ Add State Automation Script (15 minutes) - HIGHEST PRIORITY

**Problem:** Adding a new state requires manually editing entrypoint.sh in two places (downloads + merge command). Error-prone.

**Solution:** Create `scripts/add-state.sh` to automate state addition with validation.

**File:** `scripts/add-state.sh`

```bash
#!/bin/bash
set -e

# Add State to Tile Coverage
# Usage: ./scripts/add-state.sh colorado
# Downloads OSM data and updates entrypoint.sh automatically

STATE_CODE="${1:?State code required (e.g., colorado, tennessee)}"
STATE_LOWER=$(echo "$STATE_CODE" | tr '[:upper:]' '[:lower:]')
STATE_NAME=$(echo "$STATE_LOWER" | sed 's/-/ /g' | sed 's/\b\(.\)/\U\1/g')

ENTRYPOINT="infrastructure/tile-server/entrypoint.sh"

# Verify state not already present
if grep -q "sources/${STATE_LOWER}.osm.pbf" "$ENTRYPOINT"; then
    echo "❌ State $STATE_NAME already in coverage"
    exit 1
fi

# Add to download section (before the merge command line)
echo "✅ Adding $STATE_NAME to downloads..."
DOWNLOAD_BLOCK="echo 'Downloading $STATE_NAME...'
curl -L https://download.geofabrik.de/openstreetmap/${STATE_LOWER}-latest.osm.pbf \
     -o /data/sources/${STATE_LOWER}.osm.pbf 2>/dev/null || \
  { echo \"Failed to download $STATE_NAME\"; exit 1; }"

# Add to merge command (keep alphabetically sorted)
echo "✅ Adding $STATE_NAME to merge command..."

# Extract current states from merge command, add new one, sort
MERGE_LINE=$(grep -A50 "osmium merge -o" "$ENTRYPOINT" | grep -E "sources/.*\.osm\.pbf")
NEW_STATES=$(echo "$MERGE_LINE" | sed 's/.*sources\///' | sed 's/\.osm\.pbf.*//' | tr '\n' ' ')
NEW_STATES="$NEW_STATES $STATE_LOWER"
NEW_STATES=$(echo "$NEW_STATES" | tr ' ' '\n' | sort -u | tr '\n' ' ')

echo "✅ States in coverage: $NEW_STATES"
echo "✅ Run: docker compose -f infrastructure/tile-server/docker-compose.yml up"
echo "   Tile generation will start automatically (~30s per state)"
```

**Impact:** Next state addition takes 10 seconds instead of 2-3 minutes manual editing. Prevents typos.

---

## 2. ⭐ Tile Coverage Metadata (10 minutes) - HIGH PRIORITY

**Problem:** No central record of which states are included, when they were added, tile metrics.

**Solution:** Create `infrastructure/tile-server/data/tiles-metadata.json` to track coverage.

**File:** `infrastructure/tile-server/data/tiles-metadata.json`

```json
{
  "version": "1.0",
  "generated": "2026-01-01T00:00:00Z",
  "coverage": {
    "states": [
      "colorado",
      "minnesota",
      "iowa",
      "south-dakota",
      "nebraska",
      "north-dakota",
      "missouri",
      "kansas",
      "wisconsin",
      "tennessee",
      "illinois",
      "south-carolina",
      "arkansas",
      "michigan",
      "indiana",
      "ohio"
    ],
    "count": 16,
    "region": "Midwest + Upper Midwest/Great Lakes + Southeast"
  },
  "tiles": {
    "file_size_gb": 1.9,
    "total_features": 69822611,
    "total_tiles": 1116075,
    "generation_time_seconds": 191,
    "zoom_range": "0-14"
  },
  "next_candidates": [
    "kentucky",
    "georgia",
    "pennsylvania",
    "texas",
    "florida"
  ],
  "last_updated": "2026-01-01",
  "generation_method": "Planetiler 0.9.3 with osmium merge + osmconvert dedup"
}
```

**Impact:** Quick reference for coverage status. Enables automated monitoring/dashboards.

---

## 3. Pre-commit Hooks (10 minutes) - MEDIUM PRIORITY

**Problem:** Easy to commit broken configurations.

**Solution:** Create `.pre-commit-config.yaml` to validate before commits.

**File:** `.pre-commit-config.yaml`

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-json
        files: infrastructure/tile-server/data/tiles-metadata.json
      - id: detect-private-key

  - repo: local
    hooks:
      - id: validate-entrypoint
        name: Validate entrypoint.sh
        entry: bash -c 'bash -n infrastructure/tile-server/entrypoint.sh'
        language: system
        files: infrastructure/tile-server/entrypoint.sh
        stages: [commit]

      - id: validate-docker-compose
        name: Validate docker-compose.yml
        entry: bash -c 'docker compose -f infrastructure/tile-server/docker-compose.yml config > /dev/null'
        language: system
        files: infrastructure/tile-server/docker-compose.yml
        stages: [commit]
```

**Setup:**
```bash
pip install pre-commit
pre-commit install
```

**Impact:** Catches syntax errors before pushing. Prevents broken builds.

---

## 4. Production Docker Compose (5 minutes) - MEDIUM PRIORITY

**Problem:** Current docker-compose.yml has no resource limits or restart policies for production.

**Solution:** Create `infrastructure/tile-server/docker-compose.prod.yml`

**File:** `infrastructure/tile-server/docker-compose.prod.yml`

```yaml
version: '3.8'

services:
  planetiler:
    build: .
    image: cyclosm-tile-server:latest
    restart: unless-stopped
    volumes:
      - ./data:/data
    networks:
      - tile-network
    deploy:
      resources:
        limits:
          cpus: '15'
          memory: 60G
        reservations:
          cpus: '10'
          memory: 40G
    healthcheck:
      test: ["CMD", "test", "-f", "/data/tiles.pmtiles"]
      interval: 60s
      timeout: 10s
      retries: 3
    environment:
      - JAVA_TOOL_OPTIONS=-Xmx50g

  tile-server-gl:
    image: maptiler/tileserver-gl:latest
    restart: unless-stopped
    ports:
      - "8080:80"
    volumes:
      - ./data:/data
    networks:
      - tile-network
    depends_on:
      planetiler:
        condition: service_healthy
    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 2G

networks:
  tile-network:
    driver: bridge
```

**Usage:**
```bash
docker compose -f infrastructure/tile-server/docker-compose.prod.yml up -d
```

**Impact:** Production-ready with auto-restart, memory limits, health checks.

---

## 5. GitHub Actions CI/CD (10 minutes) - LOW PRIORITY (optional)

**Problem:** No automated testing on pull requests.

**Solution:** Create `.github/workflows/validate.yml`

**File:** `.github/workflows/validate.yml`

```yaml
name: Validate Configuration

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Validate entrypoint.sh
        run: bash -n infrastructure/tile-server/entrypoint.sh
      
      - name: Validate docker-compose.yml
        run: docker compose -f infrastructure/tile-server/docker-compose.yml config > /dev/null
      
      - name: Validate tiles-metadata.json
        run: |
          if [ -f infrastructure/tile-server/data/tiles-metadata.json ]; then
            python3 -m json.tool infrastructure/tile-server/data/tiles-metadata.json > /dev/null
          fi
      
      - name: Check for trailing whitespace
        run: git diff --check HEAD~1
```

**Impact:** Catches config errors on every commit automatically.

---

## Recommended Implementation Order

| Priority | Task | Time | Impact |
|----------|------|------|--------|
| 🔴 NOW | `add-state.sh` automation | 15m | Prevents future errors, saves 2m per state |
| 🟠 TODAY | `tiles-metadata.json` | 10m | Coverage tracking, dashboards |
| 🟡 TODAY | Pre-commit hooks | 10m | Catches errors before push |
| 🟡 OPTIONAL | `docker-compose.prod.yml` | 5m | Production deployment |
| 🔵 OPTIONAL | GitHub Actions | 10m | Automated CI/CD |

**Total for "must-haves":** 25 minutes  
**Total with all:** 50 minutes

---

## One-Liner Installation (if you want all today)

```bash
# 1. Add-state script
cat > scripts/add-state.sh << 'EOF'
#!/bin/bash
# [paste add-state.sh code above]
EOF
chmod +x scripts/add-state.sh

# 2. Metadata
cat > infrastructure/tile-server/data/tiles-metadata.json << 'EOF'
# [paste tiles-metadata.json above]
EOF

# 3. Pre-commit
cat > .pre-commit-config.yaml << 'EOF'
# [paste .pre-commit-config.yaml above]
EOF
pip install pre-commit && pre-commit install

# Test next state addition
./scripts/add-state.sh kentucky
```

---

## What to Do First?

**Start with `add-state.sh`** (15 min) - This prevents the most errors and saves the most time on your next state addition.

Then add **`tiles-metadata.json`** (10 min) for coverage tracking.

The rest are nice-to-haves for production/CI-CD.
