# StackCodeSy - Quick Start Guide

## 🚀 Modo Development (Acceso Completo)

Para desarrollo local con **acceso completo** a todo (sin restricciones):

```bash
# Opción 1: Usando el archivo .env.development
cp .env.development .env
docker-compose up

# Opción 2: Inline (sin archivo .env)
STACKCODESY_REQUIRE_AUTH=false \
STACKCODESY_TERMINAL_MODE=full \
STACKCODESY_EXTENSION_MODE=full \
docker-compose up
```

Luego abre en tu navegador: **http://localhost:8080**

### Características en Modo Development:
- ✅ **Sin autenticación** - Acceso directo
- ✅ **Terminal completo** - Cualquier comando
- ✅ **Todas las extensiones** - Instala lo que quieras
- ✅ **Sin límites de archivos** - Sin restricciones de tamaño
- ✅ **Sin filtrado de red** - Acceso completo a internet
- ✅ **Sin logs de auditoría** - Sin monitoreo

---

## 🔒 Modo Production (Seguridad Máxima)

Para producción con **restricciones de seguridad**:

```bash
# Configura las variables de producción
cp .env.production .env

# Edita .env y configura tu API de autenticación
nano .env

# Inicia con Docker Swarm
docker stack deploy -c docker-compose.yml stackcodesy
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
# Cambiar a puerto 3000
STACKCODESY_PORT=3000 docker-compose up
```

---

## 🛑 Detener StackCodeSy

```bash
# Docker Compose
docker-compose down

# Docker Swarm
docker stack rm stackcodesy
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
# Ver logs
docker-compose logs -f stackcodesy

# Verificar salud
curl http://localhost:8080
```

---

## 🎯 Modos de Terminal

| Modo | Descripción | Uso |
|------|-------------|-----|
| `full` | Acceso completo al terminal | Desarrollo local |
| `restricted` | Solo comandos permitidos | Usuarios confiables |
| `disabled` | Terminal deshabilitado | Máxima seguridad |

```bash
# Terminal deshabilitado (máxima seguridad)
STACKCODESY_TERMINAL_MODE=disabled docker-compose up

# Terminal restringido (solo comandos permitidos)
STACKCODESY_TERMINAL_MODE=restricted docker-compose up

# Terminal completo (desarrollo)
STACKCODESY_TERMINAL_MODE=full docker-compose up
```

---

## 🎨 Modos de Extensiones

| Modo | Descripción | Uso |
|------|-------------|-----|
| `full` | Todas las extensiones permitidas | Desarrollo local |
| `whitelist` | Solo extensiones aprobadas | Producción |
| `disabled` | Marketplace deshabilitado | Máxima seguridad |

```bash
# Todas las extensiones (desarrollo)
STACKCODESY_EXTENSION_MODE=full docker-compose up

# Solo extensiones aprobadas (producción)
STACKCODESY_EXTENSION_MODE=whitelist docker-compose up

# Marketplace deshabilitado
STACKCODESY_EXTENSION_MODE=disabled docker-compose up
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

# Dev con acceso completo
docker-compose up

# Producción con Docker Swarm
docker stack deploy -c docker-compose.yml stackcodesy

# Escalar a 3 instancias
docker service scale stackcodesy_stackcodesy=3

# Ver logs
docker service logs -f stackcodesy_stackcodesy
```
