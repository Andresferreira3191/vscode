# StackCodeSy - Web Code Editor

A customized web-based code editor built on VSCode Code-OSS with integrated authentication.

## Quick Start

```bash
# 1. Build the Docker image
docker-compose build

# 2. Run the editor (default port 8080)
docker-compose up

# 3. Access the editor
open http://localhost:8080

# Custom port (e.g., 3000)
STACKCODESY_PORT=3000 docker-compose up
# Access on http://localhost:3000
```

## With Authentication

```bash
# Create .env file from example
cp .env.example .env

# Edit .env and enable authentication
cat > .env << 'EOF'
STACKCODESY_REQUIRE_AUTH=true
STACKCODESY_USER_ID=12345
STACKCODESY_USER_NAME=John Doe
STACKCODESY_USER_EMAIL=john@example.com
STACKCODESY_AUTH_TOKEN=your-secure-token
EOF

# Run with authentication
docker-compose up

# Logs will show:
# StackCodeSy: Authentication is ENABLED
# StackCodeSy: User authenticated - John Doe (john@example.com)
```

## Features

### Core Features
- ✅ **Custom Branding** - StackCodeSy name and identity
- ✅ **Optional Authentication** - Enable/disable with single env var
- ✅ **Integrated Auth** - Shows user name and email in editor
- ✅ **Secure Tokens** - Your own authentication system (non-JWT)
- ✅ **Docker Swarm Ready** - Production deployment with high availability
- ✅ **MIT License** - Fully customizable and redistributable

### Security Features (NEW)
- ✅ **Granular Terminal Control** - 3 security modes: disabled, restricted, full
- ✅ **Restricted Terminal Mode** - Allow `yarn build` but block dangerous commands
- ✅ **Extension Marketplace Whitelist** - Control which extensions users can install
- ✅ **File System Security** - Disk quotas, file size limits, type restrictions
- ✅ **Network Security** - Egress filtering, domain whitelist, port control
- ✅ **Comprehensive Audit Logging** - Track commands, file access, auth events
- ✅ **Content Security Policy** - HTTP security headers (XSS, clickjacking protection)
- ✅ **Runtime Protection** - AppArmor/Seccomp profiles for syscall filtering
- ✅ **Security Scanning** - Automated vulnerability scanning with Trivy/Grype

## Documentation

- [STACKCODESY_INTEGRATION.md](STACKCODESY_INTEGRATION.md) - Complete integration guide
- [SECURITY_CONFIGURATION.md](SECURITY_CONFIGURATION.md) - Security configuration guide with all features
- [SECURITY_REPORT.md](SECURITY_REPORT.md) - Comprehensive security analysis and hardening guide
- [ADDITIONAL_SECURITY.md](ADDITIONAL_SECURITY.md) - Advanced security hardening measures
- [DOCKER_SWARM_DEPLOYMENT.md](DOCKER_SWARM_DEPLOYMENT.md) - Docker Swarm production deployment guide
- [docs/PORT_CONFIGURATION.md](docs/PORT_CONFIGURATION.md) - Port configuration guide

## Build from Source

```bash
# Install dependencies
npm install

# Download extensions
npm run download-builtin-extensions

# Compile web version
npm run compile-web

# Run development server
./scripts/code-web.sh --port 8080
```

## Production Deployment

### Docker Compose (Development)

```bash
# Development mode (local testing)
docker-compose -f docker-compose.dev.yml up
```

### Docker Swarm (Production - RECOMMENDED)

```bash
# Initialize Swarm (if not already done)
docker swarm init

# Deploy stack with restricted terminals
docker stack deploy -c docker-compose.yml stackcodesy

# Scale to multiple replicas
docker service scale stackcodesy_stackcodesy=3
```

### Standard Production (Restricted Terminals)

```bash
# Build platforms - allow build commands but restrict dangerous operations
docker stack deploy \
  --env STACKCODESY_REQUIRE_AUTH=true \
  --env STACKCODESY_TERMINAL_MODE=restricted \
  --env STACKCODESY_TERMINAL_ALLOWED_COMMANDS=npm,yarn,node,git,make \
  -c docker-compose.yml \
  stackcodesy
```

### Maximum Security (Terminals Disabled)

```bash
# For public platforms - no terminal access
docker stack deploy \
  --env STACKCODESY_REQUIRE_AUTH=true \
  --env STACKCODESY_TERMINAL_MODE=disabled \
  -c docker-compose.yml \
  stackcodesy
```

## Security Controls

### Authentication Control

```bash
# Development mode (default) - No authentication required
STACKCODESY_REQUIRE_AUTH=false  # or leave unset

# Production mode - Authentication required
STACKCODESY_REQUIRE_AUTH=true
```

### Terminal Security Modes (Granular Control)

```bash
# Mode 1: DISABLED - No terminal access (maximum security)
STACKCODESY_TERMINAL_MODE=disabled

# Mode 2: RESTRICTED - Limited commands only (RECOMMENDED for production)
STACKCODESY_TERMINAL_MODE=restricted
STACKCODESY_TERMINAL_WORKSPACE_ONLY=true
STACKCODESY_TERMINAL_ALLOWED_COMMANDS=npm,yarn,node,git,python,make
STACKCODESY_TERMINAL_BLOCKED_COMMANDS=rm -rf,sudo,wget,curl

# Mode 3: FULL - Complete access (development only)
STACKCODESY_TERMINAL_MODE=full
```

**Restricted Mode Benefits:**
- ✅ Users can run: `yarn build`, `npm install`, `git commit`
- ❌ Users CANNOT run: `rm -rf /`, `sudo`, `wget malicious.com`
- ❌ Users CANNOT escape workspace directory
- ✅ Perfect for build platforms and coding environments

See [SECURITY_REPORT.md](SECURITY_REPORT.md) for comprehensive security guidelines.

## License

MIT License - Based on VSCode Code-OSS

- Original: Copyright (c) Microsoft Corporation
- Modifications: Copyright (c) StackCodeSy

See LICENSE.txt for details.
