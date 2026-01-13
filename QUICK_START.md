# StackCodeSy - Quick Start Guide

## 🚀 Modo Development (Acceso Completo)

Para desarrollo local con **acceso completo** a todo (sin restricciones):

```bash
docker-compose -f docker-compose.dev.yml up
```

Luego abre en tu navegador: **http://localhost:8889**

### Características en Modo Development:
- ✅ **Sin autenticación** - Acceso directo
- ✅ **Terminal completo** - Cualquier comando
- ✅ **Todas las extensiones** - Instala lo que quieras
- ✅ **Sin límites de archivos** - Sin restricciones de tamaño
- ✅ **Sin filtrado de red** - Acceso completo a internet
- ✅ **Sin logs de auditoría** - Sin monitoreo

---

## 🧪 Modo Staging (Seguridad Moderada)

Para pruebas con **algunas restricciones**:

```bash
docker-compose -f docker-compose.staging.yml up
```

### Características en Modo Staging:
- 🔓 **Autenticación opcional** - Configurable
- 🔒 **Terminal restringido** - Comandos de desarrollo permitidos
- ✅ **Todas las extensiones** - Para testing
- 💾 **Límites moderados** - 10GB quota, archivos hasta 500MB
- 🌐 **Red abierta** - Para probar integraciones
- 📋 **Logs selectivos** - Solo comandos y autenticación

---

## 🔒 Modo Production (Seguridad Máxima)

Para producción con **restricciones de seguridad**:

```bash
# Configurar autenticación (elige un método)
export STACKCODESY_AUTH_API=https://your-platform.com/api/auth/validate

# Opción con Docker Compose
docker-compose -f docker-compose.prod.yml up

# Opción con Docker Swarm (recomendado para producción)
docker stack deploy -c docker-compose.prod.yml stackcodesy
```

### Características en Modo Production:
- 🔐 **Autenticación requerida** - Integrada con tu plataforma
- 🔒 **Terminal restringido** - Solo comandos permitidos (npm, yarn, git, etc.)
- 🛡️ **Whitelist de extensiones** - Solo extensiones aprobadas
- 💾 **Límites de archivos** - Quota de disco y tamaño máximo
- 🌐 **Filtrado de red** - Solo dominios permitidos
- 📋 **Logs completos** - Auditoría de todas las acciones

---

## 🔧 Cambiar Puerto

```bash
# Development en puerto 3000
STACKCODESY_PORT=3000 docker-compose -f docker-compose.dev.yml up

# Production en puerto 3000
STACKCODESY_PORT=3000 docker-compose -f docker-compose.prod.yml up
```

---

## 🛑 Detener StackCodeSy

### Detener sin eliminar datos

```bash
# Development
docker-compose -f docker-compose.dev.yml down

# Staging
docker-compose -f docker-compose.staging.yml down

# Production (Docker Compose)
docker-compose -f docker-compose.prod.yml down

# Production (Docker Swarm)
docker stack rm stackcodesy
```

### Detener y eliminar TODOS los datos (volúmenes)

⚠️ **ADVERTENCIA**: Esto eliminará workspace, extensiones instaladas y configuraciones

```bash
# Development - Reset completo
docker-compose -f docker-compose.dev.yml down -v

# Staging - Reset completo
docker-compose -f docker-compose.staging.yml down -v

# Production - Reset completo
docker-compose -f docker-compose.prod.yml down -v
```

---

## 📦 Build Multi-Arquitectura

Para construir para AMD64 y ARM64 (Mac M1/M2/M3):

```bash
./scripts/build-multiarch.sh stackcodesy latest
```

---

## 🔍 Verificar que está corriendo

```bash
# Ver logs - Development
docker-compose -f docker-compose.dev.yml logs -f stackcodesy

# Ver logs - Production
docker-compose -f docker-compose.prod.yml logs -f stackcodesy

# Verificar salud
curl http://localhost:8889
```

---

## 📊 Comparación de Modos

| Característica | Development | Staging | Production |
|----------------|-------------|---------|------------|
| Autenticación | ❌ Deshabilitada | 🔄 Opcional | ✅ Requerida |
| Terminal | ✅ Completo | 🔒 Restringido | 🔒 Restringido |
| Extensiones | ✅ Todas | ✅ Todas | 🛡️ Whitelist |
| Límite Disco | ∞ Sin límite | 10GB | 5GB |
| Límite Archivo | 1000MB | 500MB | 100MB |
| Red | ✅ Abierta | ✅ Abierta | 🔒 Filtrada |
| Audit Logs | ❌ Deshabilitados | 📋 Selectivos | ✅ Completos |
| CSP | ❌ Deshabilitado | 🔒 Moderado | 🔒 Estricto |

---

## 🔧 Personalización Avanzada

Si necesitas personalizar algún modo, edita el archivo correspondiente:

```bash
# Editar configuración de desarrollo
nano docker-compose.dev.yml

# Editar configuración de staging
nano docker-compose.staging.yml

# Editar configuración de producción
nano docker-compose.prod.yml
```

---

## 📚 Documentación Completa

- **Configuración de Seguridad**: `SECURITY_CONFIGURATION.md`
- **Despliegue en Docker Swarm**: `DOCKER_SWARM_DEPLOYMENT.md`
- **Configuración de Puerto**: `docs/PORT_CONFIGURATION.md`
- **Build Multi-Arquitectura**: `docs/MULTIARCH_BUILD.md`

---

## ⚡ Comandos Rápidos

```bash
# Build
docker build -t stackcodesy:latest .

# Build multi-arquitectura (AMD64 + ARM64)
./scripts/build-multiarch.sh stackcodesy latest

# Development (acceso completo)
docker-compose -f docker-compose.dev.yml up

# Staging (seguridad moderada)
docker-compose -f docker-compose.staging.yml up

# Production - Docker Compose
docker-compose -f docker-compose.prod.yml up

# Production - Docker Swarm (recomendado)
docker stack deploy -c docker-compose.prod.yml stackcodesy

# Escalar a 3 instancias (Swarm)
docker service scale stackcodesy_stackcodesy=3

# Ver logs (Swarm)
docker service logs -f stackcodesy_stackcodesy

# Detener
docker-compose -f docker-compose.dev.yml down
docker stack rm stackcodesy  # Para Swarm
```
