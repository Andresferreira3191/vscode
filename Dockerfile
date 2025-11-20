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

# Copy package files, .nvmrc, and .npmrc first for better layer caching
COPY package.json package-lock.json* yarn.lock* .nvmrc .npmrc ./
COPY build build/
COPY scripts scripts/

# Copy remote module configuration (needed by preinstall script)
COPY remote/package.json remote/.npmrc remote/

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

# Create non-root user (UID 1001 to avoid conflict with node user at 1000)
RUN useradd -m -u 1001 -s /bin/bash stackcodesy

WORKDIR /stackcodesy

# Copy built artifacts from builder
COPY --from=builder --chown=stackcodesy:stackcodesy /stackcodesy /stackcodesy

# Switch to non-root user
USER stackcodesy

# Expose port (can be changed via PORT env var)
EXPOSE 8080

# Environment variables for StackCodeSy
ENV HOST=0.0.0.0
ENV PORT=8080
ENV NODE_ENV=production

# Note: To change the port, set PORT environment variable at runtime
# Example: docker run -e PORT=3000 -p 3000:3000 stackcodesy

# Authentication Control (set at runtime)
# Set to 'true' to enable authentication, 'false' or leave unset to disable
# ENV STACKCODESY_REQUIRE_AUTH=false

# Terminal Control (set at runtime)
# Set to 'false' to DISABLE terminal access (security), 'true' or leave unset to enable
# ENV STACKCODESY_ENABLE_TERMINAL=true

# Authentication environment variables (to be passed at runtime when auth is enabled)
# ENV STACKCODESY_USER_ID=""
# ENV STACKCODESY_USER_NAME=""
# ENV STACKCODESY_USER_EMAIL=""
# ENV STACKCODESY_AUTH_TOKEN=""
# ENV STACKCODESY_AUTH_API=""

# Health check (uses PORT env var)
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD curl -f http://localhost:${PORT:-8080} || exit 1

# Set entrypoint for security configuration
ENTRYPOINT ["/stackcodesy/resources/server/web/security/entrypoint.sh"]

# Start StackCodeSy Web server
# Note: The port is controlled by the PORT environment variable (default: 8080)
# The entrypoint will pass the correct port to code-web.sh
CMD ["./scripts/code-web.sh", "--without-connection-token"]
