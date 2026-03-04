#!/bin/bash

#  Carga las variables del archivo .env
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
    echo " Archivo .env cargado correctamente."
else
    echo " Error: No se encuentra el archivo .env"
    exit 1
fi

#  Define el dominio (usando la variable de tu .env + el puerto)
DOMINIO_COMPLETO="${MI_DOMINIO}:4443"

echo " Configurando Nextcloud para: $DOMINIO_COMPLETO"

# Ejecuta comandos de configuración en el contenedor
docker exec --user www-data nextcloud-asir php occ config:system:set trusted_domains 1 --value=cloud.$DOMINIO_COMPLETO
docker exec --user www-data nextcloud-asir php occ config:system:set overwritehost --value=cloud.$DOMINIO_COMPLETO
docker exec --user www-data nextcloud-asir php occ config:system:set overwriteprotocol --value=https
# Limpia caché de rutas 
docker exec --user www-data nextcloud-asir php occ maintenance:update:htaccess

echo "Configuración finalizada con exito"
