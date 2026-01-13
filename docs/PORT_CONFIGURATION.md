# Configuración de Puerto Personalizado - StackCodeSy

Esta guía muestra cómo cambiar el puerto de StackCodeSy usando variables de entorno.

## Puerto por Defecto

Por defecto, StackCodeSy se ejecuta en el puerto **8080**.

## Cambiar el Puerto

### Opción 1: Variable de Entorno (Recomendado)

Crea un archivo `.env` en la raíz del proyecto:

```bash
# .env
STACKCODESY_PORT=3000
STACKCODESY_HOST=0.0.0.0
```

Luego ejecuta:

```bash
docker-compose up
```

StackCodeSy estará disponible en: `http://localhost:3000`

### Opción 2: Variable de Entorno en la Línea de Comandos

```bash
# Puerto 3000
STACKCODESY_PORT=3000 docker-compose up

# Puerto 5000
STACKCODESY_PORT=5000 docker-compose up

# Puerto 9000
STACKCODESY_PORT=9000 docker-compose up
```

### Opción 3: Docker Run Directo

```bash
docker run -d \
  -e PORT=3000 \
  -e HOST=0.0.0.0 \
  -p 3000:3000 \
  stackcodesy:latest
```

### Opción 4: Docker Swarm

```bash
# Opción A: Variable en .env
echo "STACKCODESY_PORT=3000" > .env
docker stack deploy -c docker-compose.yml stackcodesy

# Opción B: Configurar en docker-compose.yml directamente
# Editar docker-compose.yml y cambiar:
# - PORT=3000
```

## Ejemplos de Puertos Comunes

| Puerto | Uso Común | Comando |
|--------|-----------|---------|
| **3000** | Node.js apps | `STACKCODESY_PORT=3000 docker-compose up` |
| **5000** | Flask/Python apps | `STACKCODESY_PORT=5000 docker-compose up` |
| **8000** | Django apps | `STACKCODESY_PORT=8000 docker-compose up` |
| **8080** | Tomcat/Java apps (default) | `docker-compose up` |
| **9000** | PHP-FPM | `STACKCODESY_PORT=9000 docker-compose up` |

## Verificar la Configuración

### Ver el puerto configurado

Al iniciar StackCodeSy, verás en los logs:

```bash
=========================================
Security Configuration Summary
=========================================

Server Configuration:
  Host: 0.0.0.0
  Port: 3000

Security Settings:
  Authentication: false
  Terminal Mode: full
  ...

=========================================
Starting StackCodeSy Editor on 0.0.0.0:3000...
=========================================
```

### Verificar que el puerto está escuchando

```bash
# Ver puertos en uso
docker ps

# Salida esperada:
# PORTS
# 0.0.0.0:3000->3000/tcp

# Verificar conectividad
curl http://localhost:3000
```

## Múltiples Instancias en Diferentes Puertos

Puedes ejecutar múltiples instancias de StackCodeSy en diferentes puertos:

```bash
# Terminal 1 - Puerto 3000
STACKCODESY_PORT=3000 docker-compose -p stackcodesy-3000 up

# Terminal 2 - Puerto 4000
STACKCODESY_PORT=4000 docker-compose -p stackcodesy-4000 up

# Terminal 3 - Puerto 5000
STACKCODESY_PORT=5000 docker-compose -p stackcodesy-5000 up
```

Ahora tienes 3 instancias ejecutándose:
- `http://localhost:3000`
- `http://localhost:4000`
- `http://localhost:5000`

## Configuración de Producción

### Con Nginx Reverse Proxy

Si usas Nginx como reverse proxy, puedes mapear el puerto interno a cualquier puerto externo:

```nginx
# nginx.conf
server {
    listen 80;
    server_name editor.example.com;

    location / {
        proxy_pass http://localhost:8080;  # Puerto interno de StackCodeSy
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}
```

En este caso, StackCodeSy puede quedarse en 8080 internamente, y Nginx lo expone en el puerto 80.

### Con Docker Swarm + Load Balancer

```yaml
# docker-compose.yml para Swarm
version: '3.8'

services:
  stackcodesy:
    image: stackcodesy:latest
    environment:
      - PORT=${STACKCODESY_PORT:-8080}
    ports:
      - target: ${STACKCODESY_PORT:-8080}
        published: ${STACKCODESY_PORT:-8080}
        protocol: tcp
        mode: host
    deploy:
      replicas: 3
      ...
```

Desplegar:

```bash
# Puerto 8080 (default)
docker stack deploy -c docker-compose.yml stackcodesy

# Puerto personalizado
echo "STACKCODESY_PORT=3000" > .env
docker stack deploy -c docker-compose.yml stackcodesy
```

## Troubleshooting

### Error: "Port already in use"

```bash
Error starting userland proxy: listen tcp4 0.0.0.0:8080: bind: address already in use
```

**Solución**: Cambiar a un puerto diferente

```bash
# Ver qué está usando el puerto
lsof -i :8080
# o
netstat -tulpn | grep 8080

# Usar otro puerto
STACKCODESY_PORT=8081 docker-compose up
```

### Error: "Cannot access on configured port"

Verificar:

1. El puerto está mapeado correctamente
   ```bash
   docker ps
   # Debe mostrar: 0.0.0.0:3000->3000/tcp
   ```

2. El firewall no está bloqueando el puerto
   ```bash
   # Linux
   sudo ufw allow 3000

   # Verificar
   sudo ufw status
   ```

3. El contenedor está escuchando en 0.0.0.0 (no solo localhost)
   ```bash
   docker exec <container> netstat -tulpn | grep 3000
   ```

## Variables Relacionadas

| Variable | Descripción | Default |
|----------|-------------|---------|
| `STACKCODESY_HOST` | Host a escuchar | `0.0.0.0` |
| `STACKCODESY_PORT` | Puerto a escuchar | `8080` |
| `NODE_ENV` | Entorno de Node.js | `production` |

## Ejemplos Completos

### Ejemplo 1: Desarrollo Local en Puerto 3000

```bash
# .env
STACKCODESY_PORT=3000
STACKCODESY_HOST=0.0.0.0
STACKCODESY_REQUIRE_AUTH=false
STACKCODESY_TERMINAL_MODE=full

# Ejecutar
docker-compose -f docker-compose.dev.yml up

# Acceder en http://localhost:3000
```

### Ejemplo 2: Producción en Puerto 8443

```bash
# .env
STACKCODESY_PORT=8443
STACKCODESY_HOST=0.0.0.0
STACKCODESY_REQUIRE_AUTH=true
STACKCODESY_TERMINAL_MODE=restricted
STACKCODESY_EXTENSION_MODE=whitelist

# Ejecutar
docker stack deploy \
  -c docker-compose.yml \
  -c docker-compose.prod-security.yml \
  stackcodesy

# Acceder en https://editor.example.com:8443
```

### Ejemplo 3: Desarrollo con Puerto Dinámico por Usuario

```bash
#!/bin/bash
# start-stackcodesy.sh

USER_ID=$1
PORT=$((8000 + USER_ID))

echo "Starting StackCodeSy for user $USER_ID on port $PORT"

STACKCODESY_PORT=$PORT \
docker-compose -p "stackcodesy-user-$USER_ID" up -d

echo "StackCodeSy available at: http://localhost:$PORT"
```

Uso:
```bash
./start-stackcodesy.sh 1  # Puerto 8001
./start-stackcodesy.sh 2  # Puerto 8002
./start-stackcodesy.sh 10 # Puerto 8010
```

---

**Nota**: Siempre asegúrate de que el puerto elegido:
- No esté en uso por otra aplicación
- Esté permitido por tu firewall
- Esté dentro del rango de puertos válidos (1024-65535 para usuarios no-root)
- Sea consistente entre el mapeo de Docker y la configuración interna
