# asir_proyecto_2026
el proyecto final de ASIR

Este proyecto despliega una nube privada Nextcloud con autenticacion
centralizada mediante openLDAP y proxy inverso INGNX todo mediante 
Docker.

Servicios:
+NEXTCLOUD: servicio de almacenamiento
+OPENLDAP PHPLDAPADMIN: gestion de usuarios y contraseñas
+NGINX: proxy inverso en puerto 4443, gestion de ssl
+MARIADB: servicio de base de datos para Nextcloud

Requisitos:
+Tener instalado Docker
+Tener un subdominio de duckdns.org
+Abrir los puertos del router 80 y 4443 y apuntando al servidor

Despliegue:
1+Crear las variables de entorno a partir del archivo .env.demo 
	y guardarlas como .env
2+Levantar la infraestructura con:
		docker compose up -d
3+Debido a el uso del puerto 4443 debemos ejecutar el script:
	./scriptInicio.sh
