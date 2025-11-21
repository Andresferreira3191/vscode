#!/bin/bash
# Build vscode-reh-web OUTSIDE of Docker
# This avoids memory issues during Docker build

set -e

echo "========================================="
echo "StackCodeSy - Build Script"
echo "========================================="
echo ""

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    echo "Error: Run this script from the VSCode root directory"
    exit 1
fi

echo "[1/5] Installing dependencies..."
npm install --legacy-peer-deps --ignore-scripts

echo "[2/5] Installing build dependencies..."
cd build && npm install && cd ..

echo "[3/5] Installing remote dependencies..."
cd remote && npm install && cd ..
cd remote/web && npm install && cd ../..

echo "[4/5] Installing extensions dependencies..."
cd extensions && npm install --ignore-scripts && cd ..

echo "[5/5] Downloading built-in extensions..."
npm run download-builtin-extensions

echo ""
echo "========================================="
echo "Building vscode-reh-web..."
echo "This will take 10-20 minutes..."
echo "========================================="
echo ""

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
    VSCODE_ARCH="arm64"
elif [ "$ARCH" = "x86_64" ]; then
    VSCODE_ARCH="x64"
else
    VSCODE_ARCH="$ARCH"
fi

echo "Architecture: $VSCODE_ARCH"
echo "Starting compilation..."

# Build vscode-reh-web
VERSION=1.107.0 node --max-old-space-size=16384 ./node_modules/gulp/bin/gulp.js vscode-reh-web-linux-${VSCODE_ARCH}

echo ""
echo "========================================="
echo "Build Complete!"
echo "========================================="
echo ""
echo "Output directory: ../vscode-reh-web-linux-${VSCODE_ARCH}"
ls -lh ../vscode-reh-web-linux-${VSCODE_ARCH}

echo ""
echo "Next step: Run 'docker-compose -f docker-compose.rehweb.yml up --build'"
