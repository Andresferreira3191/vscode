#!/bin/bash
# StackCodeSy Multi-Architecture Build Script
# Builds Docker images for both AMD64 (Linux/Intel) and ARM64 (Mac M1/M2/M3)

set -e

IMAGE_NAME="${1:-stackcodesy}"
IMAGE_TAG="${2:-latest}"
PUSH="${3:-false}"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${GREEN}StackCodeSy Multi-Architecture Build${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
echo "Platforms: linux/amd64, linux/arm64"
echo "Push: ${PUSH}"
echo ""

# Check if buildx is available
if ! docker buildx version &>/dev/null; then
    echo -e "${YELLOW}Docker buildx not found. Installing...${NC}"
    echo "Please ensure you have Docker Desktop or Docker with buildx support"
    exit 1
fi

# Create buildx builder if it doesn't exist
BUILDER_NAME="stackcodesy-builder"

if ! docker buildx inspect "$BUILDER_NAME" &>/dev/null; then
    echo -e "${YELLOW}Creating buildx builder: ${BUILDER_NAME}${NC}"
    docker buildx create \
        --name "$BUILDER_NAME" \
        --driver docker-container \
        --bootstrap \
        --use
else
    echo -e "${GREEN}Using existing builder: ${BUILDER_NAME}${NC}"
    docker buildx use "$BUILDER_NAME"
fi

# Build for multiple architectures
echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${YELLOW}Building for AMD64 and ARM64...${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

BUILD_ARGS="--platform linux/amd64,linux/arm64"
BUILD_ARGS="$BUILD_ARGS -t ${IMAGE_NAME}:${IMAGE_TAG}"
BUILD_ARGS="$BUILD_ARGS -f Dockerfile"
BUILD_ARGS="$BUILD_ARGS ."

if [ "$PUSH" = "true" ]; then
    BUILD_ARGS="$BUILD_ARGS --push"
    echo "Building and pushing to registry..."
else
    BUILD_ARGS="$BUILD_ARGS --load"
    echo "Building locally (no push)..."
fi

# Execute build
docker buildx build $BUILD_ARGS

echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${GREEN}Build Complete!${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

if [ "$PUSH" = "true" ]; then
    echo "Image pushed: ${IMAGE_NAME}:${IMAGE_TAG}"
    echo "Platforms: linux/amd64, linux/arm64"
else
    echo "Image built locally: ${IMAGE_NAME}:${IMAGE_TAG}"
    echo "To push to registry, run:"
    echo "  ./scripts/build-multiarch.sh ${IMAGE_NAME} ${IMAGE_TAG} true"
fi

echo ""
echo "Inspect image:"
echo "  docker buildx imagetools inspect ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""
