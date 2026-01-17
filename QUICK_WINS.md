# Quick Wins - High Impact, Low Effort Upgrades

## 1. Create tiles-metadata.json (5 minutes)

Track what's currently in the tiles.pmtiles file for documentation and debugging.

**File: `infrastructure/tile-server/data/tiles-metadata.json`**
```json
{
  "version": "v20260101",
  "generated": "2026-01-01T21:54:00Z",
  "coverage": {
    "states": [
      "Colorado (CO)",
      "Minnesota (MN)",
      "Iowa (IA)",
      "South Dakota (SD)",
      "Nebraska (NE)",
      "North Dakota (ND)",
      "Missouri (MO)",
      "Kansas (KS)",
      "Wisconsin (WI)",
      "Tennessee (TN)",
      "Illinois (IL)",
      "South Carolina (SC)"
    ],
    "count": 12,
    "zoom_range": [0, 14]
  },
  "statistics": {
    "tile_file_size_bytes": 1395864371,
    "tile_file_size_gb": 1.3,
    "total_features": 46990812,
    "total_tiles": 890579
  },
  "layers": [
    "water",
    "transportation",
    "place",
    "poi"
  ],
  "notes": "Generated with Planetiler 0.9.3 + osmconvert deduplication"
}
```

---

## 2. Create .pre-commit-config.yaml (10 minutes)

Catch issues before they're committed to git.

**File: `.pre-commit-config.yaml`**
```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-json
      - id: check-added-large-files
        args: ['--maxkb=10000']

  - repo: https://github.com/pre-commit/mirrors-eslint
    rev: v9.39.1
    hooks:
      - id: eslint
        files: apps/web/.*\.[jt]sx?$
        types: [javascript, jsx, typescript, tsx]
        additional_dependencies:
          - '@eslint/js'
          - 'eslint-plugin-react-hooks'
          - 'eslint-plugin-react-refresh'
          - 'typescript-eslint'
          - 'globals'

  - repo: https://github.com/pre-commit/mirrors-prettier
    rev: v4.0.0-alpha.8
    hooks:
      - id: prettier
        types_or: [javascript, jsx, typescript, tsx, markdown, json, yaml]
```

**Setup instructions:**
```bash
pip install pre-commit
pre-commit install
pre-commit run --all-files  # Test it
```

---

## 3. Create add-state.sh Interactive Script (20 minutes)

Automate what we just proved works, preventing errors on the next state addition.

**File: `scripts/add-state.sh`**
```bash
#!/bin/bash
set -e

echo "🗺️  CyclOSM - Add State Script"
echo "=============================="
echo ""

# Validate input
if [ $# -ne 1 ]; then
    echo "Usage: ./scripts/add-state.sh STATE_NAME"
    echo ""
    echo "Examples:"
    echo "  ./scripts/add-state.sh kentucky"
    echo "  ./scripts/add-state.sh georgia"
    echo ""
    exit 1
fi

STATE_NAME="${1,,}"  # Convert to lowercase
STATE_UPPER="${1^^}" # Convert to uppercase
STATE_FILE="infrastructure/tile-server/data/sources/${STATE_NAME}.osm.pbf"
ENTRYPOINT="infrastructure/tile-server/entrypoint.sh"

echo "Adding $STATE_UPPER to CyclOSM tile coverage..."
echo ""

# Check if already in entrypoint
if grep -q "${STATE_NAME}.osm.pbf" "$ENTRYPOINT"; then
    echo "❌ Error: $STATE_UPPER is already configured in entrypoint.sh"
    exit 1
fi

# Validate state name (basic check)
if [ ${#STATE_NAME} -lt 3 ]; then
    echo "❌ Error: State name '$STATE_NAME' is too short"
    exit 1
fi

echo "1️⃣  Adding download block to entrypoint.sh..."
# Find the line before "Preparing state files" comment
INSERT_LINE=$(grep -n "echo \"Preparing state files" "$ENTRYPOINT" | cut -d: -f1)
INSERT_LINE=$((INSERT_LINE - 2))

# Create download block
DOWNLOAD_BLOCK="    if [ ! -f /data/sources/${STATE_NAME}.osm.pbf ]; then
        echo \"Downloading ${STATE_UPPER}...\"
        curl -L https://download.geofabrik.de/north-america/us/${STATE_NAME}-latest.osm.pbf \\
            -o /data/sources/${STATE_NAME}.osm.pbf
    fi
    "

# Use sed to insert (platform-aware)
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "${INSERT_LINE}a\\
${DOWNLOAD_BLOCK}" "$ENTRYPOINT"
else
    sed -i "${INSERT_LINE}a ${DOWNLOAD_BLOCK}" "$ENTRYPOINT"
fi

echo "✅ Added download block"
echo ""

echo "2️⃣  Adding $STATE_UPPER to osmium merge command..."
# Find the osmium merge line and add new state
MERGE_LINE=$(grep -n "osmium merge -o" "$ENTRYPOINT" | cut -d: -f1)
# Find the line with "echo \"Merging" and update count
ECHO_LINE=$(grep -n "echo \"Merging" "$ENTRYPOINT" | cut -d: -f1)

# Extract current count and increment
CURRENT_MSG=$(sed -n "${ECHO_LINE}p" "$ENTRYPOINT")
if [[ $CURRENT_MSG =~ ([0-9]+)\ states ]]; then
    CURRENT_COUNT="${BASH_REMATCH[1]}"
    NEW_COUNT=$((CURRENT_COUNT + 1))
    NEW_MSG="    echo \"Merging ${NEW_COUNT} states...\""
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "${ECHO_LINE}s/.*/                 ${NEW_MSG}/" "$ENTRYPOINT"
    else
        sed -i "${ECHO_LINE}s/.*/                 ${NEW_MSG}/" "$ENTRYPOINT"
    fi
fi

# Add state to osmium merge (before osmconvert)
DEDUP_LINE=$(grep -n "# CRITICAL: Clean duplicates" "$ENTRYPOINT" | cut -d: -f1)
INSERT_MERGE=$((DEDUP_LINE - 1))

STATE_ENTRY="                 /data/sources/${STATE_NAME}.osm.pbf \\"

if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "${INSERT_MERGE}a\\
${STATE_ENTRY}" "$ENTRYPOINT"
else
    sed -i "${INSERT_MERGE}a ${STATE_ENTRY}" "$ENTRYPOINT"
fi

echo "✅ Added $STATE_UPPER to merge command"
echo ""

echo "3️⃣  Validating syntax..."
if bash -n "$ENTRYPOINT"; then
    echo "✅ entrypoint.sh syntax is valid"
else
    echo "❌ Error: entrypoint.sh has syntax errors"
    echo "   Please review and fix the changes manually."
    exit 1
fi
echo ""

echo "4️⃣  Ready to generate tiles!"
echo ""
echo "Next steps:"
echo "  1. Review changes: git diff infrastructure/tile-server/entrypoint.sh"
echo "  2. Build and generate:"
echo "     cd infrastructure/tile-server"
echo "     docker build --no-cache -q -t tile-server_planetiler . && \\"
echo "     docker run --rm -v \$(pwd)/data:/data tile-server_planetiler tile-generation"
echo "  3. Restart tile server: docker compose restart"
echo "  4. Test in browser: http://localhost:5173 (Ctrl+Shift+R to hard refresh)"
echo ""
echo "✅ $STATE_UPPER successfully added!"
```

**Usage:**
```bash
chmod +x scripts/add-state.sh
./scripts/add-state.sh Kentucky
./scripts/add-state.sh Georgia
```

---

## 4. Update scripts/README.md (5 minutes)

Document current state coverage and update obsolete information.

**Current content is outdated** - Should include:
- Current 12-state coverage
- Why overture-regional scripts are deprecated
- How to use add-state.sh instead
- Performance metrics from recent runs

---

## 5. Clean up obsolete scripts (10 minutes)

Move old Overture experimentation scripts out of the way.

```bash
# Archive old scripts
mkdir scripts/archive
mv scripts/overture-regional-*.sh scripts/archive/
mv scripts/generate-overture-*.sh scripts/archive/
mv scripts/quick-overture-regional.sh scripts/archive/

# Update scripts/README.md to reference archive/
```

---

## 6. Create production docker-compose.yml (10 minutes)

Enable deployment to production with proper resource limits and restarts.

**File: `infrastructure/tile-server/docker-compose.prod.yml`**
```yaml
version: '3.8'

services:
  tile-server:
    image: cyclosm-tile-server:latest  # Use pre-built image
    container_name: cyclosm-tile-server
    ports:
      - "8080:80"
    volumes:
      - ./data/tiles.pmtiles:/data/tiles.pmtiles:ro
      - ./data/tiles-metadata.json:/data/tiles-metadata.json:ro
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    environment:
      - TZ=UTC
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 1G
        reservations:
          cpus: '1'
          memory: 512M
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

volumes:
  tiles:
    driver: local
```

**Deploy with:**
```bash
docker compose -f docker-compose.prod.yml up -d
```

---

## 7. Create GitHub Actions workflow (15 minutes)

Automate linting and testing on every push.

**File: `.github/workflows/ci.yml`**
```yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v2
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'pnpm'
      
      - run: pnpm install
      - run: pnpm -r lint
      - run: pnpm -r build
      
  docker:
    runs-on: ubuntu-latest
    needs: lint
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/build-push-action@v5
        with:
          context: ./infrastructure/tile-server
          tags: cyclosm-tile-server:latest
          # Add registry push when ready: push: true
```

---

## Implementation Order

1. **Today:** tiles-metadata.json (5 min) + add-state.sh (20 min)
2. **This week:** .pre-commit-config.yaml (10 min) + clean scripts (10 min)
3. **Next week:** GitHub Actions (15 min) + docker-compose.prod.yml (10 min)
4. **Soon:** Update all READMEs and docs

## Total time: ~1 hour for all quick wins

Each provides immediate value:
- Metadata: Better documentation
- add-state.sh: Prevents human error on next state
- pre-commit: Catches issues early
- Clean scripts: Reduces confusion
- CI/CD: Automates testing
- Prod compose: Enables deployment

