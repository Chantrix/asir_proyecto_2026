# Manual de uso

Un manual exhaustivo de todas las funciones de Nextcloud, OpenLDAP o Wazuh sería inabarcable. Esta guía cubre las tareas de administración más habituales una vez el sistema ya está desplegado (ver [`instalacion.md`](instalacion.md) para el despliegue inicial).

## Gestión de identidades y control de acceso (LDAP)

### Inicializar o ampliar el árbol (DIT) mediante LDIF

Un fichero `.ldif` permite crear de golpe toda la jerarquía: Unidades Organizativas, grupos y usuarios, en vez de darlos de alta uno a uno desde la interfaz.

1. Entra en phpLDAPadmin y accede con tus credenciales de administrador.
2. Ve a la pestaña **Import**.
3. Selecciona el fichero `.ldif` con la estructura a importar (ver `organizacion.ldif` como plantilla de ejemplo).
4. Pulsa **Proceed**. phpLDAPadmin muestra un resumen de las entradas creadas.
5. Comprueba en el árbol de la izquierda que la nueva estructura organizativa aparece correctamente.

Esto sirve tanto para la carga inicial como para añadir departamentos completos más adelante sin tocar la interfaz web entrada por entrada.

### Mantenimiento del DIT

- **Mover un usuario de OU:** cambia su unidad organizativa (por ejemplo, de `marketing` a `admin`) para que sus permisos en Nextcloud cambien automáticamente, ya que Nextcloud resuelve el acceso a carpetas según el grupo LDAP del usuario.
- **Baja de un empleado:** elimínalo (o desactívalo) en OpenLDAP. Al ser la única fuente de identidad para todos los servicios integrados, una sola baja centralizada revoca el acceso en todos ellos a la vez.
- **Política de contraseñas:** puedes forzar el cambio de contraseña de un usuario o desbloquear una cuenta directamente desde el servidor LDAP, sin depender de cada aplicación cliente.

## Salud del stack (Docker)

### Comprobar que todos los servicios están arriba

```bash
docker ps
```

Revisa que cada contenedor aparece como `Up` (o `healthy` si tiene healthcheck definido).

### Consultar logs para depurar

Tráfico en tiempo real de un contenedor:

```bash
docker logs -f nginx-proxy-asir
```

Filtrar solo errores:

```bash
docker logs nginx-proxy-asir 2>&1 | grep "error"
```

Sustituye `nginx-proxy-asir` por el nombre de cualquier otro contenedor (`nextcloud-asir`, `ldap-servidor`, `nextcloud-db`, `wazuh-agente-asir`...) según el servicio que quieras revisar.

### Actualización segura

```bash
docker compose pull
docker compose up -d
```

`docker compose up -d` recrea los contenedores con la imagen actualizada sin tocar los volúmenes: el `.env` y los datos persistentes (Nextcloud, base de datos, directorio LDAP) se mantienen intactos.

## Monitorización (Wazuh)

Una vez el agente está enrolado con el manager (ver el último paso de `instalacion.md`), el dashboard de Wazuh centraliza:

- Alertas de fuerza bruta sobre el login de Nextcloud, detectadas a partir de los logs de la aplicación.
- Alertas de integridad de archivos (FIM) si se modifica algún fichero de configuración crítico monitorizado.

No requiere configuración adicional por parte del usuario final: basta con revisar el dashboard periódicamente o dejar configuradas notificaciones sobre las reglas de mayor severidad.
