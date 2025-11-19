# StackCodeSy - Web Code Editor
# Multi-stage build for optimized image size

FROM node:22.20.0-bookworm AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    g++ \
    make \
    python3 \
    git \
    libx11-dev \
    libxkbfile-dev \
    libsecret-1-dev \
    libkrb5-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /stackcodesy

# Copy package files first for better layer caching
COPY package.json package-lock.json* yarn.lock* ./
COPY build build/
COPY scripts scripts/

# Install dependencies
RUN npm ci --legacy-peer-deps || npm install --legacy-peer-deps

# Copy the rest of the source code
COPY . .

# Download built-in extensions
RUN npm run download-builtin-extensions

# Compile StackCodeSy Web
RUN npm run compile-web

# Compile the authentication extension
WORKDIR /stackcodesy/extensions/stackcodesy-auth
RUN npm install && npm run compile

# Production stage
FROM node:22.20.0-bookworm-slim

LABEL maintainer="StackCodeSy"
LABEL description="StackCodeSy - Web Code Editor with integrated authentication"
LABEL version="1.0.0"

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libsecret-1-0 \
    libkrb5-3 \
    git \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 1000 -s /bin/bash stackcodesy

WORKDIR /stackcodesy

# Copy built artifacts from builder
COPY --from=builder --chown=stackcodesy:stackcodesy /stackcodesy /stackcodesy

# Switch to non-root user
USER stackcodesy

# Expose port 8080
EXPOSE 8080

# Environment variables for StackCodeSy
ENV HOST=0.0.0.0
ENV PORT=8080
ENV NODE_ENV=production

# Authentication Control (set at runtime)
# Set to 'true' to enable authentication, 'false' or leave unset to disable
# ENV STACKCODESY_REQUIRE_AUTH=false

# Authentication environment variables (to be passed at runtime when auth is enabled)
# ENV STACKCODESY_USER_ID=""
# ENV STACKCODESY_USER_NAME=""
# ENV STACKCODESY_USER_EMAIL=""
# ENV STACKCODESY_AUTH_TOKEN=""
# ENV STACKCODESY_AUTH_API=""

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD curl -f http://localhost:8080 || exit 1

# Start StackCodeSy Web server
# Note: Remove --without-connection-token in production and use --connection-token-file
CMD ["./scripts/code-web.sh", "--host", "0.0.0.0", "--port", "8080", "--without-connection-token"]
