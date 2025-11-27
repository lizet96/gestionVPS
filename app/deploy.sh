#!/bin/bash

echo "Iniciando despliegue..."

# Variables
IMAGE_NAME="mi-backend"
CONTAINER_NAME="backend-app"
PORT=3000

# Detener y eliminar contenedor anterior
echo "Deteniendo contenedor anterior..."
docker stop $CONTAINER_NAME 2>/dev/null || true
docker rm $CONTAINER_NAME 2>/dev/null || true

# Eliminar imagen anterior
echo "Eliminando imagen anterior..."
docker rmi $IMAGE_NAME 2>/dev/null || true

# Construir nueva imagen
echo "Construyendo nueva imagen..."
docker build -t $IMAGE_NAME .

# Ejecutar nuevo contenedor
echo "Iniciando nuevo contenedor..."
docker run -d \
  --name $CONTAINER_NAME \
  -p $PORT:3000 \
  --restart unless-stopped \
  $IMAGE_NAME

# Verificar estado
echo "Verificando estado del contenedor..."
docker ps | grep $CONTAINER_NAME

echo "Despliegue completado!"
echo "API disponible en: http://$(hostname -I | awk '{print $1}'):$PORT"
