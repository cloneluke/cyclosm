# Setup Guide: Ubuntu Home Development Environment

This guide covers setting up CyclOSM Vector development environment on Ubuntu using snap packages for Docker and Docker Compose.

## Prerequisites

- Ubuntu 20.04 LTS or later
- 4GB RAM minimum (8GB+ recommended for tile generation)
- 50GB free disk space (for large region tiles)
- sudo access

## Installation

### 1. Update System
```bash
sudo apt update && sudo apt upgrade -y
```

### 2. Install Docker (via snap)
```bash
sudo snap install docker
```

Add your user to the docker group (avoid needing sudo for docker commands):
```bash
sudo usermod -aG docker $USER && newgrp docker
```

Verify Docker installation:
```bash
docker --version
docker run hello-world
```

### 3. Install Docker Compose (via Docker Plugin)

Instead of the deprecated snap version, install Docker Compose as a plugin:

```bash
mkdir -p ~/.docker/cli-plugins/
curl -SL https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-linux-x86_64 \
  -o ~/.docker/cli-plugins/docker-compose
chmod +x ~/.docker/cli-plugins/docker-compose
```

Verify Docker Compose installation:
```bash
docker compose version
```

**Note:** Use `docker compose` (space) instead of `docker-compose` (hyphen).

### 4. Install Git and curl
```bash
sudo apt install -y git curl
```

### 5. Install Node.js and pnpm (Optional, for web development)
If you plan to work on the web app:

**Node.js:**
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc
nvm install 20
nvm use 20
```

**pnpm:**
```bash
npm install -g pnpm
```

Verify:
```bash
node --version
pnpm --version
```

## Post-Installation Steps

### 1. Enable Docker Service (Optional but recommended)
If you want Docker to start on boot:
```bash
sudo snap start --enable docker
```

### 2. Configure Docker Socket Permissions
The snap version of Docker may need socket permission adjustments. If you get permission errors:

```bash
# Check current permissions
ls -la /run/docker.sock

# If needed, add your user to docker group (already done above)
sudo usermod -aG docker $USER
```

Log out and back in for group changes to take effect, or:
```bash
newgrp docker
```

### 3. Increase Docker Resource Limits (for tile generation)
Edit or create `~/.docker/config.json`:
```json
{
  "experimental": true,
  "builder": {
    "gc": {
      "enabled": true,
      "maxunused": "100gb"
    }
  }
}
```

For memory-intensive tile generation, you may want to configure Docker Desktop or ensure adequate system resources.

## Verification

Test the complete setup:

```bash
# Test Docker
docker run --rm hello-world

# Test Docker Compose
docker-compose --version

# Test Git
git --version

# Test Node/pnpm (if installed)
node --version
pnpm --version
```

All commands should output version information without errors.

## Troubleshooting

### Docker Permission Denied
```bash
sudo usermod -aG docker $USER
newgrp docker
# Log out and back in for group changes
```

### Docker Compose Not Found
```bash
# Verify snap is installed
snap list | grep docker-compose

# Reinstall if needed
sudo snap install docker-compose
```

### Out of Disk Space
Check available space:
```bash
df -h

# Clean up Docker resources
docker system prune -a
docker builder prune -a
```

### Slow Tile Generation
If tile generation is very slow:
- Increase available RAM/CPU
- Use a smaller region (e.g., state instead of country)
- Check that only one Docker container is running

### Docker Snap Issues
If you encounter issues with the snap version, try the official Docker installation:

```bash
# Remove snap version
sudo snap remove docker docker-compose

# Install via apt repository (alternative)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

## Development Workflow

Once setup is complete:

```bash
# Clone the repository
git clone https://github.com/cyclosm/cyclosm-vector.git
cd cyclosm-vector

# Generate tiles (one-time, ~15-30 min for small region)
cd infrastructure/tile-server
docker-compose --profile tile-generation up planetiler

# Start development server
docker-compose up

# In another terminal, the web app
cd apps/web
pnpm dev
```

## Next Steps

- Read [ARCHITECTURE.md](../ARCHITECTURE.md) for project overview
- Check [infrastructure/tile-server/README.md](../infrastructure/tile-server/README.md) for tile server usage
- Follow Phase 2+ setup in ARCHITECTURE.md

## Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Snap Documentation](https://snapcraft.io/docs)
- [Ubuntu Server Guide](https://ubuntu.com/server/docs)
