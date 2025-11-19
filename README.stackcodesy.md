# StackCodeSy - Web Code Editor

A customized web-based code editor built on VSCode Code-OSS with integrated authentication.

## Quick Start

```bash
# 1. Build the Docker image
docker-compose build

# 2. Run the editor
docker-compose up

# 3. Access the editor
open http://localhost:8080
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

- ✅ **Custom Branding** - StackCodeSy name and identity
- ✅ **Optional Authentication** - Enable/disable with single env var
- ✅ **Integrated Auth** - Shows user name and email in editor
- ✅ **Secure Tokens** - Your own authentication system (non-JWT)
- ✅ **Terminal Control** - Disable terminals for security (NEW)
- ✅ **Docker Ready** - Easy deployment with docker-compose
- ✅ **Security Hardened** - Production-ready with comprehensive security guide
- ✅ **MIT License** - Fully customizable and redistributable

## Documentation

- [STACKCODESY_INTEGRATION.md](STACKCODESY_INTEGRATION.md) - Complete integration guide
- [SECURITY_REPORT.md](SECURITY_REPORT.md) - Comprehensive security analysis and hardening guide

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

### Standard Production (Trusted Users)

```bash
# Build optimized image
docker build -t stackcodesy:latest .

# Run with authentication
docker run -d \
  -p 8080:8080 \
  -e STACKCODESY_REQUIRE_AUTH="true" \
  -e STACKCODESY_AUTH_API="https://yourapi.com/auth" \
  stackcodesy:latest
```

### Maximum Security (Untrusted Users)

```bash
# Run with authentication AND disabled terminals
docker run -d \
  -p 8080:8080 \
  -e STACKCODESY_REQUIRE_AUTH="true" \
  -e STACKCODESY_ENABLE_TERMINAL="false" \
  -e STACKCODESY_AUTH_API="https://yourapi.com/auth" \
  --read-only \
  --cap-drop=ALL \
  --security-opt=no-new-privileges:true \
  stackcodesy:latest
```

## Security Controls

### Authentication Control

```bash
# Development mode (default) - No authentication required
STACKCODESY_REQUIRE_AUTH=false  # or leave unset

# Production mode - Authentication required
STACKCODESY_REQUIRE_AUTH=true
```

### Terminal Control (Security Feature)

```bash
# Development mode (default) - Terminals enabled
STACKCODESY_ENABLE_TERMINAL=true  # or leave unset

# Production mode - Terminals disabled (recommended for untrusted users)
STACKCODESY_ENABLE_TERMINAL=false
```

**Why disable terminals?**
- Prevents arbitrary command execution
- Blocks potential container escape attempts
- Eliminates primary Remote Code Execution (RCE) vector
- Required for multi-tenant environments

See [SECURITY_REPORT.md](SECURITY_REPORT.md) for comprehensive security guidelines.

## License

MIT License - Based on VSCode Code-OSS

- Original: Copyright (c) Microsoft Corporation
- Modifications: Copyright (c) StackCodeSy

See LICENSE.txt for details.
