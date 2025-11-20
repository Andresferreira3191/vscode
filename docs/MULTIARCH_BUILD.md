# StackCodeSy Multi-Architecture Build Guide

Esta guía explica cómo construir StackCodeSy para múltiples arquitecturas (AMD64 y ARM64).

## Arquitecturas Soportadas

| Arquitectura | Plataformas | Uso |
|-------------|-------------|-----|
| **linux/amd64** | Intel, AMD processors | Servidores Linux, PCs Windows/Linux |
| **linux/arm64** | Apple Silicon (M1/M2/M3), ARM servers | Mac M1/M2/M3, Raspberry Pi, AWS Graviton |

---

## Opción 1: Build Automático con Script (Recomendado)

### Build Local (No Push)

```bash
# Dar permisos de ejecución
chmod +x scripts/build-multiarch.sh

# Build para ambas arquitecturas
./scripts/build-multiarch.sh stackcodesy latest

# La imagen se construye localmente
```

### Build y Push a Registry

```bash
# Build y push a Docker Hub
./scripts/build-multiarch.sh stackcodesy latest true

# Build y push con tag personalizado
./scripts/build-multiarch.sh myregistry/stackcodesy v1.0.0 true
```

**Resultado:**
- Imagen disponible para AMD64 (Intel/AMD)
- Imagen disponible para ARM64 (Mac M1/M2/M3)
- Docker selecciona automáticamente la arquitectura correcta

---

## Opción 2: Build Manual con Docker Buildx

### 1. Configurar Buildx (Solo Primera Vez)

```bash
# Crear builder multi-arquitectura
docker buildx create \
  --name stackcodesy-builder \
  --driver docker-container \
  --bootstrap \
  --use

# Verificar el builder
docker buildx inspect stackcodesy-builder
```

### 2. Build para Múltiples Arquitecturas

```bash
# Build para AMD64 y ARM64
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t stackcodesy:latest \
  -f Dockerfile \
  --load \
  .

# Build y push a registry
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t myregistry/stackcodesy:latest \
  -f Dockerfile \
  --push \
  .
```

### 3. Build Solo para Tu Arquitectura

```bash
# Solo AMD64 (Intel/AMD)
docker buildx build \
  --platform linux/amd64 \
  -t stackcodesy:latest \
  --load \
  .

# Solo ARM64 (Mac M1/M2/M3)
docker buildx build \
  --platform linux/arm64 \
  -t stackcodesy:latest \
  --load \
  .
```

---

## Opción 3: Docker Compose con Buildx

### Configuración

```bash
# Habilitar buildx en Docker Compose
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# Crear builder
docker buildx create --use --name stackcodesy-builder

# Build multi-arch
docker buildx bake -f docker-compose.multiarch.yml
```

### Uso

```bash
# Build y ejecutar
docker compose -f docker-compose.multiarch.yml up --build

# Docker selecciona automáticamente la arquitectura correcta
```

---

## Verificar la Imagen Multi-Arquitectura

### Ver Arquitecturas Disponibles

```bash
# Inspeccionar la imagen
docker buildx imagetools inspect stackcodesy:latest

# Salida esperada:
# Name:      stackcodesy:latest
# MediaType: application/vnd.docker.distribution.manifest.list.v2+json
# Digest:    sha256:xxxxx
#
# Manifests:
#   Name:      stackcodesy:latest@sha256:xxxxx
#   MediaType: application/vnd.docker.distribution.manifest.v2+json
#   Platform:  linux/amd64
#
#   Name:      stackcodesy:latest@sha256:yyyyy
#   MediaType: application/vnd.docker.distribution.manifest.v2+json
#   Platform:  linux/arm64
```

### Verificar Arquitectura en Ejecución

```bash
# Ejecutar contenedor
docker run --rm stackcodesy:latest uname -m

# En Mac M1/M2/M3: aarch64
# En Intel/AMD: x86_64
```

---

## Troubleshooting

### Error: "multiple platforms feature is currently not supported"

**Problema:** Docker no tiene buildx habilitado

**Solución:**
```bash
# Instalar Docker Desktop (incluye buildx) o
# Instalar buildx manualmente
docker buildx install
```

### Error: "failed to solve with frontend dockerfile.v0"

**Problema:** Builder no está configurado correctamente

**Solución:**
```bash
# Eliminar builder existente
docker buildx rm stackcodesy-builder

# Crear nuevo builder
docker buildx create --name stackcodesy-builder --use --bootstrap
```

### Build Muy Lento en Cross-Compilation

**Problema:** Construir para arquitectura diferente a la del host es lento

**Soluciones:**

1. **Usar QEMU para emulación:**
```bash
# Instalar QEMU binfmt (Linux)
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

# Verificar
docker buildx ls
```

2. **Build solo para tu arquitectura:**
```bash
# En Mac M1/M2/M3
docker buildx build --platform linux/arm64 -t stackcodesy:latest --load .

# En Intel/AMD
docker buildx build --platform linux/amd64 -t stackcodesy:latest --load .
```

3. **Usar builders nativos (avanzado):**
```bash
# Configurar nodos de build remotos con diferentes arquitecturas
docker buildx create --name multiarch \
  --platform linux/amd64 \
  --node amd64 \
  ssh://user@amd64-machine

docker buildx create --name multiarch \
  --platform linux/arm64 \
  --node arm64 \
  --append \
  ssh://user@arm64-machine
```

### Error: "--load can only be used with a single platform"

**Problema:** `--load` solo funciona con una plataforma

**Solución:**
```bash
# Opción 1: Build para una sola plataforma
docker buildx build --platform linux/arm64 -t stackcodesy:latest --load .

# Opción 2: Push a registry en lugar de load local
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t myregistry/stackcodesy:latest \
  --push \
  .
```

---

## CI/CD: GitHub Actions

### Ejemplo de Workflow

```yaml
# .github/workflows/build-multiarch.yml
name: Build Multi-Architecture Image

on:
  push:
    branches: [main]
    tags: ['v*']

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: true
          tags: |
            stackcodesy/stackcodesy:latest
            stackcodesy/stackcodesy:${{ github.ref_name }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

---

## Optimizaciones de Build

### 1. Usar Caché de GitHub Actions

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --cache-from type=gha \
  --cache-to type=gha,mode=max \
  -t stackcodesy:latest \
  --push \
  .
```

### 2. Usar Caché Local

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --cache-from type=local,src=/tmp/.buildx-cache \
  --cache-to type=local,dest=/tmp/.buildx-cache-new,mode=max \
  -t stackcodesy:latest \
  --push \
  .
```

### 3. Build Incremental

```bash
# Build solo si hay cambios
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --cache-from stackcodesy:latest \
  -t stackcodesy:latest \
  --push \
  .
```

---

## Despliegue Multi-Arquitectura

### Docker Swarm

```bash
# Stack en cluster heterogéneo (AMD64 + ARM64)
docker stack deploy -c docker-compose.yml stackcodesy

# Docker Swarm distribuye automáticamente según arquitectura de nodos
```

### Kubernetes

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stackcodesy
spec:
  replicas: 3
  selector:
    matchLabels:
      app: stackcodesy
  template:
    metadata:
      labels:
        app: stackcodesy
    spec:
      containers:
      - name: stackcodesy
        image: stackcodesy:latest
        # Kubernetes selecciona automáticamente la imagen correcta
        # basándose en la arquitectura del nodo
      nodeSelector:
        # Opcional: forzar arquitectura específica
        # kubernetes.io/arch: arm64
```

---

## Resumen de Comandos

| Acción | Comando |
|--------|---------|
| **Build local multi-arch** | `./scripts/build-multiarch.sh stackcodesy latest` |
| **Build y push multi-arch** | `./scripts/build-multiarch.sh stackcodesy latest true` |
| **Build solo ARM64** | `docker buildx build --platform linux/arm64 -t stackcodesy:latest --load .` |
| **Build solo AMD64** | `docker buildx build --platform linux/amd64 -t stackcodesy:latest --load .` |
| **Inspeccionar imagen** | `docker buildx imagetools inspect stackcodesy:latest` |
| **Verificar arquitectura** | `docker run --rm stackcodesy:latest uname -m` |

---

## Recomendaciones

1. **Desarrollo Local:**
   - Build solo para tu arquitectura (más rápido)
   - Usa `docker compose build` normal

2. **CI/CD:**
   - Build multi-arch automático en cada push
   - Usa caché de GitHub Actions
   - Push a registry

3. **Producción:**
   - Usa imágenes multi-arch en registry
   - Docker/Kubernetes selecciona automáticamente
   - No necesitas configuración especial

---

## Soporte de Plataformas

| Plataforma | AMD64 | ARM64 |
|------------|-------|-------|
| **Mac Intel** | ✅ | ⚠️ (emulado, lento) |
| **Mac M1/M2/M3** | ⚠️ (emulado, lento) | ✅ |
| **Linux Intel/AMD** | ✅ | ⚠️ (emulado, lento) |
| **Linux ARM (Raspberry Pi, Graviton)** | ⚠️ (emulado, lento) | ✅ |
| **Windows Intel/AMD** | ✅ | ⚠️ (emulado, lento) |
| **Docker Desktop** | ✅ | ✅ |

✅ = Nativo (rápido)
⚠️ = Emulado via QEMU (lento, pero funciona)

---

**Para más información sobre Docker Buildx:**
- https://docs.docker.com/build/buildx/
- https://docs.docker.com/build/building/multi-platform/
