# VSCode Web Docker Image
# Multi-stage build for optimized image size

FROM node:22.20.0-bookworm AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    g++ \
    make \
    python3 \
    python3-pip \
    git \
    libx11-dev \
    libxkbfile-dev \
    libsecret-1-dev \
    libkrb5-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /vscode

# Copy package files first for better layer caching
COPY package.json package-lock.json* ./
COPY build build/
COPY scripts scripts/

# Install dependencies
RUN npm install

# Copy the rest of the source code
COPY . .

# Download built-in extensions
RUN npm run download-builtin-extensions

# Compile VSCode Web
RUN npm run compile-web

# Production stage
FROM node:22.20.0-bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libsecret-1-0 \
    libkrb5-3 \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 1000 -s /bin/bash vscode

WORKDIR /vscode

# Copy built artifacts from builder
COPY --from=builder --chown=vscode:vscode /vscode /vscode

# Switch to non-root user
USER vscode

# Expose port 8080
EXPOSE 8080

# Set environment variables
ENV HOST=0.0.0.0
ENV PORT=8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD node -e "require('http').get('http://localhost:8080', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start VSCode Web server
CMD ["./scripts/code-web.sh", "--host", "0.0.0.0", "--port", "8080", "--without-connection-token"]
