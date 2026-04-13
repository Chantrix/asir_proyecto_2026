#!/bin/bash
#Este script es el "Configurador de Acceso Externo".
#Su función es decirle a Nextcloud que acepte conexiones desde
#internet a través de tu dominio de DuckDNS y tu puerto específico.
if [ "$1" == "--help" ]; then
	echo "Funcionamiento del programa:"
	echo "Se debe incluir 1 argumento:
		numero de puerto abierto para la comunicacion"

	exit 2
elif [[ ! $1 =~ ^-?[0-9]+$ ]]; then
    echo "Error: '$1' no es un número de puerto válido."
    exit 2
fi

#  Carga las variables del archivo .env
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
    echo " Archivo .env cargado correctamente."
else
    echo " Error: No se encuentra el archivo .env"
    exit 1
fi


#  Define el dominio (usando la variable de tu .env + el puerto)
DOMINIO_COMPLETO="${MI_DOMINIO}:$1"

echo " Configurando Nextcloud para: $DOMINIO_COMPLETO"

# Ejecuta comandos de configuración en el contenedor
docker exec --user www-data nextcloud-asir php occ config:system:set trusted_domains 1 --value=cloud.$DOMINIO_COMPLETO
docker exec --user www-data nextcloud-asir php occ config:system:set overwritehost --value=cloud.$DOMINIO_COMPLETO
docker exec --user www-data nextcloud-asir php occ config:system:set overwriteprotocol --value=https
# Limpia caché de rutas 
docker exec --user www-data nextcloud-asir php occ maintenance:update:htaccess

echo "Configuración finalizada con exito"
