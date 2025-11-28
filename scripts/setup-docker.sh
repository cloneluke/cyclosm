#!/bin/bash
set -e

echo "🐳 CyclOSM Vector - Docker Setup Script"
echo "========================================"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    echo "   See docs/SETUP_UBUNTU.md for installation instructions."
    exit 1
fi

echo "✅ Docker found: $(docker --version)"

# Check if Docker daemon is running
if ! docker ps &> /dev/null; then
    echo "❌ Docker daemon is not running or you don't have permission to access it."
    echo ""
    
    # Add user to docker group if not already a member
    if ! groups $USER | grep -q docker; then
        echo "📝 Adding $USER to docker group..."
        sudo usermod -aG docker $USER
        echo "✅ User added to docker group"
        echo ""
        echo "⚠️  Please log out and back in, or run: newgrp docker"
        exit 1
    else
        # User is in the group but socket still not accessible
        # This usually means we need to restart docker or the user needs to log in again
        echo "💡 You're in the docker group but socket is not accessible."
        echo "   Please log out and log back in, then try again."
        exit 1
    fi
fi

echo "✅ Docker daemon is accessible"
echo ""

# Check if Docker Compose is installed
if ! command -v docker &> /dev/null || ! docker compose version &> /dev/null; then
    echo "📥 Installing Docker Compose plugin..."
    
    mkdir -p ~/.docker/cli-plugins/
    
    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            COMPOSE_URL="https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-linux-x86_64"
            ;;
        aarch64)
            COMPOSE_URL="https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-linux-aarch64"
            ;;
        *)
            echo "❌ Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
    
    curl -SL "$COMPOSE_URL" -o ~/.docker/cli-plugins/docker-compose
    chmod +x ~/.docker/cli-plugins/docker-compose
    echo "✅ Docker Compose installed"
else
    echo "✅ Docker Compose found: $(docker compose version --short)"
fi

echo ""
echo "========================================"
echo "✅ All Docker prerequisites installed!"
echo ""
echo "Next steps:"
echo "  1. Generate tiles:"
echo "     docker compose --profile tile-generation up planetiler"
echo ""
echo "  2. Start tile server:"
echo "     docker compose up tile-server"
echo ""
echo "  3. Or use npm scripts from root:"
echo "     npm run tile-gen   # Generate tiles"
echo "     npm run dev        # Start tile server"
