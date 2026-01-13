# StackCodeSy - Integration Guide

## Overview

StackCodeSy is a customized web-based code editor built on VSCode Code-OSS with integrated authentication for your platform.

## Features

- ✅ Custom branding (StackCodeSy)
- ✅ **Optional authentication** - Enable/disable with a single environment variable
- ✅ Integrated authentication system
- ✅ Shows user name and email in editor
- ✅ Secure token-based authentication (non-JWT)
- ✅ Docker-ready deployment
- ✅ MIT License - fully customizable

---

## Authentication Control

StackCodeSy includes a **flexible authentication system** that can be enabled or disabled via environment variable:

| Mode | Configuration | Use Case |
|------|---------------|----------|
| **Public Mode** | `STACKCODESY_REQUIRE_AUTH=false` (default) | Development, testing, public editors |
| **Authenticated Mode** | `STACKCODESY_REQUIRE_AUTH=true` | Production, private user environments |

### How It Works

- **When disabled** (`STACKCODESY_REQUIRE_AUTH=false` or unset):
  - Editor runs without authentication
  - No user credentials required
  - Perfect for development and testing
  - Logs: `Authentication is DISABLED`

- **When enabled** (`STACKCODESY_REQUIRE_AUTH=true`):
  - Editor requires user authentication
  - User name and email displayed in UI
  - Validates credentials on startup
  - Logs: `User authenticated - Name (email)`

---

## Quick Start

### 1. Build the Docker Image

```bash
# Clone this repository
cd /path/to/vscode

# Build the image (this will take 15-30 minutes)
docker-compose build

# Or build manually
docker build -t stackcodesy:latest .
```

### 2. Run Without Authentication (Development/Testing)

**Default mode - no configuration needed:**

```bash
# Simply run - authentication is disabled by default
docker-compose up
```

Access at: `http://localhost:8080`

Logs will show:
```
StackCodeSy: Authentication is DISABLED (STACKCODESY_REQUIRE_AUTH is not set to true)
StackCodeSy: Editor running in public/development mode without authentication
```

### 3. Run With Authentication (Production)

Create a `.env` file:

```bash
# .env
STACKCODESY_REQUIRE_AUTH=true
STACKCODESY_USER_ID=12345
STACKCODESY_USER_NAME=John Doe
STACKCODESY_USER_EMAIL=john@example.com
STACKCODESY_AUTH_TOKEN=your-secure-token-here
```

Then run:

```bash
docker-compose up
```

Logs will show:
```
StackCodeSy: Authentication is ENABLED (STACKCODESY_REQUIRE_AUTH=true)
StackCodeSy: User authenticated - John Doe (john@example.com)
```

---

## Integration with Your Platform

### Method 1: Environment Variables (Simple)

When launching StackCodeSy for a user, pass their information via environment variables:

```bash
docker run -d \
  -p 8080:8080 \
  -e STACKCODESY_REQUIRE_AUTH="true" \
  -e STACKCODESY_USER_ID="12345" \
  -e STACKCODESY_USER_NAME="John Doe" \
  -e STACKCODESY_USER_EMAIL="john@example.com" \
  -e STACKCODESY_AUTH_TOKEN="user-secure-token" \
  stackcodesy:latest
```

**How it works:**
- Set `STACKCODESY_REQUIRE_AUTH=true` to enable authentication
- The authentication extension reads user info from environment variables on startup
- User is automatically authenticated
- Name and email appear in the editor UI

### Method 2: API Endpoint (Recommended for Production)

Expose an authentication API from your platform:

**Your API Endpoint:** `https://yourplatform.com/api/stackcodesy/auth`

**Expected Response:**
```json
{
  "userId": "12345",
  "userName": "John Doe",
  "userEmail": "john@example.com",
  "token": "user-secure-token"
}
```

**Launch StackCodeSy:**
```bash
docker run -d \
  -p 8080:8080 \
  -e STACKCODESY_REQUIRE_AUTH="true" \
  -e STACKCODESY_AUTH_API="https://yourplatform.com/api/stackcodesy/auth" \
  stackcodesy:latest
```

**Security:**
- The API should validate the user's session (cookies, headers, etc.)
- Only return user info if the session is valid
- Return 401/403 for unauthenticated requests

---

## Architecture

### Authentication Flow

```
User logs into your platform
         ↓
Platform generates secure session
         ↓
Platform launches StackCodeSy container with user context
         ↓
StackCodeSy Auth Extension validates user
         ↓
User sees their name/email in editor
```

### File Structure

```
/home/user/vscode/
├── product.json                          # StackCodeSy branding
├── extensions/stackcodesy-auth/          # Authentication extension
│   ├── src/extension.ts                  # Auth provider logic
│   └── package.json                      # Extension manifest
├── Dockerfile                            # Docker build
├── docker-compose.yml                    # Compose configuration
└── STACKCODESY_INTEGRATION.md           # This file
```

---

## Production Deployment

### Option 1: Docker Compose with Nginx

Create `nginx.conf`:

```nginx
server {
    listen 80;
    server_name editor.yourplatform.com;

    location / {
        proxy_pass http://stackcodesy:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Uncomment nginx section in `docker-compose.yml` and add SSL certificates.

### Option 2: Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stackcodesy
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: stackcodesy
        image: stackcodesy:latest
        ports:
        - containerPort: 8080
        env:
        - name: STACKCODESY_AUTH_API
          value: "https://yourplatform.com/api/stackcodesy/auth"
```

### Option 3: Per-User Containers

Launch a separate container for each user:

```python
# Example in Python
import docker

client = docker.from_env()

def launch_editor_for_user(user_id, user_name, user_email, user_token):
    container = client.containers.run(
        "stackcodesy:latest",
        detach=True,
        ports={'8080/tcp': None},  # Random port
        environment={
            'STACKCODESY_USER_ID': user_id,
            'STACKCODESY_USER_NAME': user_name,
            'STACKCODESY_USER_EMAIL': user_email,
            'STACKCODESY_AUTH_TOKEN': user_token,
        },
        name=f'stackcodesy-{user_id}'
    )

    # Get the assigned port
    port = container.attrs['NetworkSettings']['Ports']['8080/tcp'][0]['HostPort']

    return f"http://localhost:{port}"
```

---

## Security Best Practices

### 1. Use Connection Tokens in Production

Edit `Dockerfile` line 91:

```dockerfile
# Change from:
CMD ["./scripts/code-web.sh", "--host", "0.0.0.0", "--port", "8080", "--without-connection-token"]

# To:
CMD ["./scripts/code-web.sh", "--host", "0.0.0.0", "--port", "8080", "--connection-token-file", "/run/secrets/connection_token"]
```

Generate tokens:
```bash
# Generate a random token
openssl rand -base64 32 > connection_token.txt

# Pass to container
docker run -d \
  -v $(pwd)/connection_token.txt:/run/secrets/connection_token:ro \
  stackcodesy:latest
```

### 2. Token Validation

Your authentication tokens should:
- Be randomly generated per session
- Expire after a set time
- Be validated on each request
- Be stored securely (not in JWT)

### 3. Network Isolation

```yaml
# docker-compose.yml
networks:
  stackcodesy-network:
    driver: bridge
    internal: true  # Prevent external access
```

### 4. HTTPS Only

Always use HTTPS in production with valid SSL certificates.

---

## Customization

### Change Port

```yaml
# docker-compose.yml
ports:
  - "3000:8080"  # Access on port 3000
```

### Add Logo

Replace logo files:
```
resources/linux/code.png
resources/win32/code.ico
resources/darwin/code.icns
```

Then rebuild:
```bash
docker-compose build
```

### Modify Branding

Edit `product.json`:
```json
{
  "nameShort": "YourName",
  "nameLong": "YourName - Code Editor"
}
```

---

## Monitoring

### Health Checks

```bash
# Check if container is healthy
docker ps

# View logs
docker-compose logs -f stackcodesy

# Check health endpoint
curl http://localhost:8080
```

### User Authentication Status

Logs will show:
```
StackCodeSy: User authenticated - John Doe (john@example.com)
```

---

## Troubleshooting

### User not authenticated

**Symptoms:** User name doesn't appear in editor

**Solutions:**
1. Check environment variables are set correctly
2. Verify API endpoint is reachable
3. Check container logs: `docker logs stackcodesy-editor`
4. Ensure auth extension compiled: `ls extensions/stackcodesy-auth/out/`

### Build fails

**Common issues:**
- Not enough RAM (need 4GB+)
- Network timeout downloading dependencies
- Missing build dependencies

**Solution:**
```bash
# Increase Docker memory
# Docker Desktop → Settings → Resources → Memory → 6GB

# Retry build
docker-compose build --no-cache
```

### Port already in use

```bash
# Change port in docker-compose.yml
ports:
  - "8081:8080"
```

---

## API Reference

### Authentication API Specification

Your platform should implement this endpoint:

**Endpoint:** `GET /api/stackcodesy/auth`

**Headers:**
- `Cookie: session=xyz` (or your session mechanism)

**Response (Success - 200 OK):**
```json
{
  "userId": "string",
  "userName": "string",
  "userEmail": "string",
  "token": "string"
}
```

**Response (Unauthorized - 401):**
```json
{
  "error": "Not authenticated"
}
```

---

## Environment Variables Reference

| Variable | Required | Description | Default | Example |
|----------|----------|-------------|---------|---------|
| **Authentication Control** |
| `STACKCODESY_REQUIRE_AUTH` | No | Enable/disable authentication | `false` | `true` or `false` |
| **Server Configuration** |
| `HOST` | Yes | Bind host | `0.0.0.0` | `0.0.0.0` |
| `PORT` | Yes | Bind port | `8080` | `8080` |
| `NODE_ENV` | No | Environment | `production` | `production` |
| **User Credentials** (only when `STACKCODESY_REQUIRE_AUTH=true`) |
| `STACKCODESY_USER_ID` | Conditional | User's unique ID | - | `12345` |
| `STACKCODESY_USER_NAME` | Conditional | User's display name | - | `John Doe` |
| `STACKCODESY_USER_EMAIL` | Conditional | User's email | - | `john@example.com` |
| `STACKCODESY_AUTH_TOKEN` | Conditional | User's auth token | - | `abc123...` |
| **API Authentication** (alternative to user credentials) |
| `STACKCODESY_AUTH_API` | Conditional | Auth API endpoint | - | `https://api.example.com/auth` |

**Notes:**
- When `STACKCODESY_REQUIRE_AUTH=false` (default), no authentication variables are required
- When `STACKCODESY_REQUIRE_AUTH=true`, you must provide either:
  - User credentials (`USER_ID`, `USER_NAME`, `USER_EMAIL`, `AUTH_TOKEN`), OR
  - API endpoint (`STACKCODESY_AUTH_API`)

---

## License

StackCodeSy is based on VSCode Code-OSS and is licensed under the MIT License.

- Original copyright: Microsoft Corporation
- Modifications: StackCodeSy

You can freely:
- Use commercially
- Modify the code
- Distribute
- Sublicense

See `LICENSE.txt` for full terms.

---

## Support

For issues and questions:
- Check the troubleshooting section
- Review container logs
- Verify authentication integration

---

## Next Steps

1. **Build the image:** `docker-compose build`
2. **Test locally:** `docker-compose up`
3. **Integrate auth:** Implement authentication API
4. **Deploy:** Use Kubernetes/Docker Swarm for production
5. **Customize:** Add your logo and branding

Happy coding with StackCodeSy! 🚀
