#!/bin/bash

echo "🚀 Iniciando Blue-Green Deployment..."

# Variables
IMAGE_NAME="gps-backend"
PORT_BLUE=3001
PORT_GREEN=3002
NGINX_PORT=3000

# Detectar cuál está activo actualmente
ACTIVE_ENV=$(cat /tmp/active_env 2>/dev/null || echo "none")

echo "📊 Ambiente activo actual: $ACTIVE_ENV"

# Determinar el nuevo ambiente
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

echo "$COLOR_EMOJI Desplegando en ambiente: $NEW_ENV ($COLOR_NAME) en puerto $NEW_PORT"

# Construir nueva imagen
echo "🔨 Construyendo imagen Docker..."
docker build -t ${IMAGE_NAME}:${NEW_ENV} .

# Detener y eliminar contenedor anterior del nuevo ambiente (si existe)
echo "🧹 Limpiando ambiente $NEW_ENV..."
docker stop backend-app-${NEW_ENV} 2>/dev/null || true
docker rm backend-app-${NEW_ENV} 2>/dev/null || true

# Iniciar nuevo contenedor CON VARIABLE DE ENTORNO
echo "$COLOR_EMOJI Iniciando contenedor en ambiente $NEW_ENV ($COLOR_NAME)..."
docker run -d \
  --name backend-app-${NEW_ENV} \
  -p ${NEW_PORT}:3000 \
  -e ENVIRONMENT=${NEW_ENV} \
  --restart unless-stopped \
  ${IMAGE_NAME}:${NEW_ENV}

# Esperar a que el contenedor esté listo
echo "⏳ Esperando que el servicio esté listo..."
sleep 5

# Verificar que el nuevo contenedor funciona
echo "🔍 Verificando salud del nuevo ambiente..."
HEALTH_CHECK=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${NEW_PORT}/api/health)

if [ "$HEALTH_CHECK" != "200" ]; then
    echo "❌ ERROR: El nuevo ambiente no responde correctamente"
    echo "🔄 Rollback: manteniendo ambiente $OLD_ENV activo"
    docker stop backend-app-${NEW_ENV}
    docker rm backend-app-${NEW_ENV}
    exit 1
fi

echo "✅ Nuevo ambiente funcionando correctamente"

# Cambiar NGINX para apuntar al nuevo ambiente
echo "🔀 Cambiando tráfico a ambiente $NEW_ENV ($COLOR_NAME)..."

# Crear configuración de NGINX
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

# Eliminar link simbólico anterior
sudo rm /etc/nginx/sites-enabled/backend-* 2>/dev/null || true

# Crear nuevo link simbólico
sudo ln -s /etc/nginx/sites-available/backend-${NEW_ENV}.conf /etc/nginx/sites-enabled/

# Verificar configuración de NGINX
sudo nginx -t

# Recargar NGINX
sudo systemctl reload nginx

# Guardar ambiente activo
echo "$NEW_ENV" > /tmp/active_env

echo "✅ Tráfico redirigido a ambiente $NEW_ENV ($COLOR_NAME)"

# Esperar un poco antes de detener el ambiente anterior
echo "⏳ Esperando 10 segundos antes de detener ambiente anterior..."
sleep 10

# Detener ambiente anterior (pero no eliminarlo por si necesitamos rollback)
if [ "$ACTIVE_ENV" != "none" ]; then
    echo "🛑 Deteniendo ambiente anterior ($OLD_ENV)..."
    docker stop backend-app-${OLD_ENV} 2>/dev/null || true
    echo "💾 Ambiente $OLD_ENV detenido pero conservado para rollback"
fi

echo ""
echo "🎉 =================================="
echo "✅ DESPLIEGUE COMPLETADO"
echo "🎉 =================================="
echo "$COLOR_EMOJI Ambiente activo: $NEW_ENV ($COLOR_NAME)"
echo "🔌 Puerto interno: $NEW_PORT"
echo "🌍 Acceso público: http://$(curl -s ifconfig.me)"
echo "🔵 Blue (3001): $(docker ps --filter name=backend-app-blue --format '{{.Status}}' 2>/dev/null || echo '⏹️  Detenido')"
echo "🟢 Green (3002): $(docker ps --filter name=backend-app-green --format '{{.Status}}' 2>/dev/null || echo '⏹️  Detenido')"
echo "🎉 =================================="