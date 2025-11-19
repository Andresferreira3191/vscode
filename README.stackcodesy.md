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
- ✅ **Docker Ready** - Easy deployment with docker-compose
- ✅ **MIT License** - Fully customizable and redistributable

## Documentation

See [STACKCODESY_INTEGRATION.md](STACKCODESY_INTEGRATION.md) for complete integration guide.

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

```bash
# Build optimized image
docker build -t stackcodesy:latest .

# Run in production with authentication
docker run -d \
  -p 8080:8080 \
  -e STACKCODESY_REQUIRE_AUTH="true" \
  -e STACKCODESY_AUTH_API="https://yourapi.com/auth" \
  stackcodesy:latest
```

## Authentication Control

Control authentication with a single environment variable:

```bash
# Development mode (default) - No authentication required
STACKCODESY_REQUIRE_AUTH=false  # or leave unset

# Production mode - Authentication required
STACKCODESY_REQUIRE_AUTH=true
```

## License

MIT License - Based on VSCode Code-OSS

- Original: Copyright (c) Microsoft Corporation
- Modifications: Copyright (c) StackCodeSy

See LICENSE.txt for details.
