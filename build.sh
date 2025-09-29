#!/bin/bash
# Build Hadoop Docker Image
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check prerequisites
log "Checking prerequisites..."

if ! docker info >/dev/null 2>&1; then
    error "Docker is not running!"
fi

if [ ! -f "hadoop-3.3.6.tar.gz" ]; then
    error "hadoop-3.3.6.tar.gz not found! Download it with:"
    echo "wget https://archive.apache.org/dist/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz"
    exit 1
fi

if [ ! -f "Dockerfile" ]; then
    error "Dockerfile not found!"
fi

if [ ! -f "start-hadoop.sh" ]; then
    error "start-hadoop.sh not found!"
fi

# Make start script executable
chmod +x start-hadoop.sh

# Build image
log "Building Docker image: hadoop:latest"
log "This will take several minutes..."

if docker build -t hadoop:latest .; then
    log "Docker image built successfully!"

    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}BUILD COMPLETE${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo "Image: hadoop:latest"
    echo "Size: $(docker images hadoop:latest --format '{{.Size}}')"
    echo ""
    echo "Next steps:"
    echo "1. Make sure you have input.txt in your project root"
    echo "2. Run: ./run-mapreduce.sh"
    echo -e "${BLUE}========================================${NC}"
else
    error "Docker build failed!"
fi