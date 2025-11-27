#!/bin/bash

echo "  Iniciando ROLLBACK..."

# Obtener ambiente activo
ACTIVE_ENV=$(cat /tmp/active_env 2>/dev/null || echo "none")

if [ "$ACTIVE_ENV" == "none" ]; then
    echo " No hay ambiente activo registrado"
    exit 1
fi

# Determinar el ambiente anterior
if [ "$ACTIVE_ENV" == "blue" ]; then
    ROLLBACK_ENV="green"
    ROLLBACK_PORT=3002
else
    ROLLBACK_ENV="blue"
    ROLLBACK_PORT=3001
fi

echo " Haciendo rollback a: $ROLLBACK_ENV"

# Verificar que el contenedor anterior existe
if ! docker ps -a --filter name=backend-app-${ROLLBACK_ENV} | grep -q backend-app-${ROLLBACK_ENV}; then
    echo " El contenedor $ROLLBACK_ENV no existe"
    exit 1
fi

# Iniciar el contenedor anterior
echo "Iniciando ambiente $ROLLBACK_ENV..."
docker start backend-app-${ROLLBACK_ENV}

# Esperar
sleep 5

# Cambiar NGINX
echo "Redirigiendo tráfico a $ROLLBACK_ENV..."
sudo rm /etc/nginx/sites-enabled/backend-* 2>/dev/null || true
sudo ln -s /etc/nginx/sites-available/backend-${ROLLBACK_ENV}.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# Actualizar ambiente activo
echo "$ROLLBACK_ENV" > /tmp/active_env

# Detener ambiente con problemas
echo "Deteniendo ambiente $ACTIVE_ENV..."
docker stop backend-app-${ACTIVE_ENV}

echo "Rollback completado. Ambiente activo: $ROLLBACK_ENV"