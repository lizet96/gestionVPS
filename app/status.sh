#!/bin/bash

echo " =================================="
echo " ESTADO DE AMBIENTES"
echo " =================================="

ACTIVE_ENV=$(cat /tmp/active_env 2>/dev/null || echo "none")
echo " Ambiente activo: $ACTIVE_ENV"
echo ""

echo " BLUE (puerto 3001):"
docker ps --filter name=backend-app-blue --format "   Estado: {{.Status}}" 2>/dev/null || echo "   No desplegado"

echo ""
echo " GREEN (puerto 3002):"
docker ps --filter name=backend-app-green --format "   Estado: {{.Status}}" 2>/dev/null || echo "   No desplegado"

echo ""
echo " NGINX:"
if [ -f /etc/nginx/sites-enabled/backend-blue.conf ]; then
    echo "   Apuntando a: BLUE"
elif [ -f /etc/nginx/sites-enabled/backend-green.conf ]; then
    echo "   Apuntando a: GREEN"
else
    echo "   No configurado"
fi

echo " =================================="