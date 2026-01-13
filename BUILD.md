# StackCodeSy - Build Instructions

## The Problem

Compiling VSCode inside Docker fails with "cannot allocate memory" because the compilation requires 8-16GB of RAM.

## The Solution (Like code-server does it)

**Compile OUTSIDE Docker, then copy the binaries.**

Code-server does exactly this:
1. Compiles vscode-reh-web in their CI/CD (not in Docker)
2. Creates .deb packages
3. Docker just installs the pre-compiled packages

We do the same approach:
1. Compile `vscode-reh-web` on your HOST machine
2. Docker copies the pre-built binaries
3. Docker just runs the server

---

## Step-by-Step Instructions

### Step 1: Build vscode-reh-web (On your Mac)

```bash
# Make the build script executable
chmod +x build-vscode-web.sh

# Run the build (takes 10-20 minutes, uses ~16GB RAM)
./build-vscode-web.sh
```

**What this does:**
- Installs all dependencies
- Compiles VSCode Remote Extension Host for Web
- Creates `../vscode-reh-web-linux-arm64/` directory with the complete server

**Requirements:**
- Node.js 22.x
- 16GB+ RAM available
- 30-40 minutes

### Step 2: Build and Run Docker Image

```bash
# Build the Docker image (uses pre-built binaries from Step 1)
docker-compose -f docker-compose.prebuilt.yml up --build
```

**What this does:**
- Creates a lightweight Docker image
- Copies the pre-built `vscode-reh-web` server
- Starts the server on http://localhost:8889

---

## Architecture Detection

The build script automatically detects your architecture:
- **Mac M1/M2/M3**: Builds `vscode-reh-web-linux-arm64`
- **Intel Mac/Linux**: Builds `vscode-reh-web-linux-x64`

---

## Troubleshooting

### Build fails with "out of memory"

Your machine doesn't have enough RAM. Try:
```bash
# Increase Node.js memory limit
NODE_OPTIONS="--max-old-space-size=20480" ./build-vscode-web.sh
```

### Docker build can't find pre-built server

Make sure Step 1 completed successfully:
```bash
# Check if the server directory exists
ls -la ../vscode-reh-web-linux-*/
```

You should see:
- `node` (Node.js binary)
- `out/` (compiled code)
- `bin/` (scripts)
- `resources/` (assets)

---

## Why This Approach?

✅ **Same as code-server** - Proven in production
✅ **Latest VSCode** - You control the version
✅ **No memory issues** - Compilation happens on host
✅ **Fast Docker builds** - Just copies binaries
✅ **Official server** - Uses Microsoft's vscode-reh-web

---

## What Gets Built?

`vscode-reh-web` = **VSCode Remote Extension Host for Web**

This is the **official production server** that Microsoft uses for vscode.dev.

**NOT** `@vscode/test-web` (development tool)
**NOT** custom implementations
**YES** Official Microsoft production server ✅
