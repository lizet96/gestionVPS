#!/bin/bash

log() { printf "[BG] %s\n" "$1"; }
ok() { printf "[OK] %s\n" "$1"; }
warn() { printf "[WARN] %s\n" "$1"; }
fail() { printf "[FAIL] %s\n" "$1"; }

log "Inicio de despliegue Blue-Green"

IMAGE_NAME="gps-backend"
PORT_BLUE=3001
PORT_GREEN=3002
NGINX_PORT=3000

ACTIVE_ENV=$(cat /tmp/active_env 2>/dev/null || echo "none")

echo " Ambiente activo actual: $ACTIVE_ENV"

if [ "$ACTIVE_ENV" == "blue" ]; then
    NEW_ENV="green"
    NEW_PORT=$PORT_GREEN
    OLD_ENV="blue"
    OLD_PORT=$PORT_BLUE
    COLOR_EMOJI="🟢"
    COLOR_NAME="VERDE"
else
    NEW_ENV="blue"
    NEW_PORT=$PORT_BLUE
    OLD_ENV="green"
    OLD_PORT=$PORT_GREEN
    COLOR_EMOJI="🔵"
    COLOR_NAME="AZUL"
fi

log "Objetivo: entorno $NEW_ENV ($COLOR_NAME) en puerto $NEW_PORT"


log "Construyendo imagen Docker: ${IMAGE_NAME}:${NEW_ENV}"
docker build -t ${IMAGE_NAME}:${NEW_ENV} .

log "Limpieza del entorno $NEW_ENV"
docker stop backend-app-${NEW_ENV} 2>/dev/null || true
docker rm backend-app-${NEW_ENV} 2>/dev/null || true

log "Arrancando contenedor backend-app-${NEW_ENV} en puerto ${NEW_PORT}"
docker run -d \
  --name backend-app-${NEW_ENV} \
  -p ${NEW_PORT}:3000 \
  -e ENVIRONMENT=${NEW_ENV} \
  --restart unless-stopped \
  ${IMAGE_NAME}:${NEW_ENV}

log "Esperando disponibilidad del servicio..."
sleep 5

log "Verificando salud del entorno $NEW_ENV"
HEALTH_CHECK=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${NEW_PORT}/api/health)

if [ "$HEALTH_CHECK" != "200" ]; then
    fail "El entorno $NEW_ENV no respondió al health-check (HTTP $HEALTH_CHECK)"
    warn "Manteniendo activo: $OLD_ENV"
    docker stop backend-app-${NEW_ENV}
    docker rm backend-app-${NEW_ENV}
    exit 1
fi

echo " Nuevo ambiente funcionando correctamente"

log "Conmutando NGINX hacia $NEW_ENV ($COLOR_NAME)"


sudo tee /etc/nginx/sites-available/backend-${NEW_ENV}.conf > /dev/null <<EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:${NEW_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

sudo rm /etc/nginx/sites-enabled/backend-* 2>/dev/null || true

sudo ln -s /etc/nginx/sites-available/backend-${NEW_ENV}.conf /etc/nginx/sites-enabled/


sudo nginx -t


sudo systemctl reload nginx

echo "$NEW_ENV" > /tmp/active_env

echo " Tráfico redirigido a ambiente $NEW_ENV ($COLOR_NAME)"

echo " Esperando 10 segundos antes de detener ambiente anterior..."
sleep 10

if [ "$ACTIVE_ENV" != "none" ]; then
    echo " Deteniendo ambiente anterior ($OLD_ENV)..."
    docker stop backend-app-${OLD_ENV} 2>/dev/null || true
    echo " Ambiente $OLD_ENV detenido pero conservado para rollback"
fi

echo ""
echo "================ Blue-Green Summary ================"
ok "Despliegue completado"
log "Activo: $NEW_ENV ($COLOR_NAME)"
log "Puerto interno: $NEW_PORT"
log "Acceso público: http://$(curl -s ifconfig.me)"
log "Blue (3001): $(docker ps --filter name=backend-app-blue --format '{{.Status}}' 2>/dev/null || echo 'Detenido')"
log "Green (3002): $(docker ps --filter name=backend-app-green --format '{{.Status}}' 2>/dev/null || echo 'Detenido')"
echo "===================================================="