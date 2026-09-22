# Arquitectura

Diseño técnico completo de SanRap: cómo están organizados los contenedores, cómo se comunican, cómo se modela la identidad en LDAP y qué controles de seguridad protegen cada capa. Para una vista rápida, ver la sección de arquitectura del [`README`](../README.md).

## Arquitectura lógica de contenedores

El sistema sigue una arquitectura de microservicios: cada servicio vive en su propio contenedor, aislado del resto salvo por las redes Docker explícitas que los conectan. Frente a una estructura monolítica (todo en el mismo host, misma IP para todo), esto permite reemplazar o escalar un servicio sin tocar los demás, y en el límite, sacar un servicio a otro host por completo — como ocurre aquí con el manager de Wazuh, desplegado por separado del stack principal.

Todo el stack se describe en un único `compose.yaml`: servicios, redes y volúmenes. Cada contenedor es una instancia de una imagen, igual que un objeto es una instancia de una clase. `docker compose up` resuelve las imágenes desde Docker Hub y levanta todo con la configuración declarada — sin instalar nada de software directamente en el host.

Capas del sistema:

| Capa | Servicio(s) | Función |
|---|---|---|
| Presentación y seguridad perimetral | Nginx Proxy Manager | Punto de entrada único, terminación SSL |
| Identidad | OpenLDAP + phpLDAPadmin | Directorio central de usuarios y grupos |
| Aplicación | Nextcloud | Almacenamiento y colaboración |
| Datos | MariaDB | Persistencia de Nextcloud |
| Auditoría | Wazuh Agent (+ Manager externo) | SIEM/XDR, FIM |

## Persistencia de datos

Docker ofrece dos mecanismos de persistencia: **bind-mount** (mapea una carpeta del host tal cual dentro del contenedor) y **volume** (Docker gestiona el almacenamiento, solo accesible desde el contenedor que lo crea). SanRap usa volúmenes nombrados en lugar de bind-mounts porque el sistema de archivos varía entre sistemas operativos — un bind-mount rígido rompería la portabilidad si el stack se despliega en otro host con otra distribución o SO.

## Diseño de redes

```
Internet
   │  HTTPS (TLS 1.3), puerto 4442
   ▼
┌─────────────────────────────── red-publica (bridge) ───────────────────────────────┐
│  proxy (Nginx Proxy Manager) ──HTTP:80── phpldapadmin, nextcloud                    │
└───────────────────────────────────────┬──────────────────────────────────────────┘
                                          │
┌─────────────────────────────── red-privada (internal: true) ──────────────────────┐
│  proxy · phpldapadmin · ldap-servidor · db-nextcloud · nextcloud · wazuh-agent     │
│  (ldap-servidor y db-nextcloud SOLO existen aquí: sin salida a internet)           │
└───────────────────────────────────────┬──────────────────────────────────────────┘
                                          │
┌─────────────────────────────── red-seguridad (external) ──────────────────────────┐
│  wazuh-agent ──── wazuh-manager (stack externo)                                   │
└─────────────────────────────────────────────────────────────────────────────────┘
```

- **Red exterior — `duckdns`:** único contenedor con `network_mode: host`, porque necesita ver la IP pública real del servidor para poder actualizar el registro DNS dinámico. Rompe deliberadamente el aislamiento de Docker; es una necesidad de esta instalación concreta, no de la infraestructura en sí (si la empresa tuviera IP fija, este contenedor no haría falta).
- **`red-publica` (bridge, frontend):** puente NAT hacia el exterior. Es la única red con puertos publicados al host (80, 4442→443, 81). La usan el proxy, phpLDAPadmin y Nextcloud — solo para que el proxy pueda alcanzarlos por HTTP interno, no para exponerlos directamente.
- **`red-privada` (internal: true, backend):** sin salida a internet y sin acceso directo desde el host. LDAP y MariaDB residen exclusivamente aquí. La resolución de nombres interna de Docker solo permite que `nextcloud` resuelva `mariadb`/`ldap-servidor` dentro de esta red; cualquier intento desde un contenedor de `red-publica` falla por diseño, limitando el movimiento lateral si el proxy se viera comprometido.
- **`red-seguridad` (external):** exclusiva para la comunicación agente↔manager de Wazuh, separada del tráfico de archivos de Nextcloud.

### Tabla de redes y puertos

| Origen | Destino | Red | Uso | Puerto |
|---|---|---|---|---|
| Internet | proxy | host (dedicado) | Entrada HTTPS | 4442 |
| proxy | nextcloud | red-publica | Reenvío HTTP | 80 (interno) |
| nextcloud | db-nextcloud | red-privada | Consultas SQL | 3306 (interno) |
| nextcloud | ldap-servidor | red-privada | Autenticación | 389 (interno) |
| wazuh-agent | wazuh-manager | red-seguridad | Alertas/monitorización | 1514/1515 |

## Modelo de datos e identidad (LDAP)

El árbol de directorio (DIT) se organiza con:

- **Base DN:** representa el dominio de la organización, por ejemplo `dc=empresa,dc=duckdns,dc=org`.
- **Unidades Organizativas (OU):** `ou=people` agrupa las cuentas de usuario, `ou=groups` los grupos (departamentos o roles).
- **Esquemas:** `inetOrgPerson` y `posixAccount` definen qué atributos puede tener cada entrada (apellido, contraseña, UID, etc.) — sin ellos LDAP no sabe qué es cada campo.

Cada usuario pertenece a un grupo, y Nextcloud traduce esa pertenencia en permisos de carpeta (p. ej. una carpeta de Contabilidad solo visible para el grupo correspondiente).

## Certificados y cifrado en tránsito

- **Protocolo ACME:** Nginx Proxy Manager actúa como cliente ACME, automatizando la verificación del dominio y la emisión de certificados.
- **Entidad certificadora:** Let's Encrypt (certificados de validación de dominio, gratuitos).
- **Renovación automática:** el proxy revisa la validez del certificado y renueva cuando quedan menos de 30 días, evitando caídas de servicio por expiración.
- **TLS 1.3 forzado + HSTS:** se eliminan cifrados obsoletos (SHA-1, MD5) y se obliga al navegador a usar siempre HTTPS, mitigando ataques de degradación de protocolo (SSL stripping).

## Flujo de autenticación centralizada

1. **Cifrado en origen:** el usuario envía sus credenciales por un túnel TLS 1.3 hasta el puerto público del proxy.
2. **Terminación SSL:** el proxy descifra, identifica que el destino es Nextcloud y reenvía por `red-publica` en HTTP plano (tráfico ya interno a Docker).
3. **Procesamiento:** Nextcloud no consulta su base de datos local de usuarios, sino que delega en el plugin LDAP.
4. **Validación:** Nextcloud hace un LDAP Bind contra `ldap-servidor` por `red-privada` (puerto 389). Si las credenciales casan con un objeto `inetOrgPerson`, LDAP responde éxito.
5. **Acceso concedido:** Nextcloud crea la sesión y aplica los permisos según el grupo LDAP del usuario.

## Hardening y control de accesos

- **Principio de mínimo privilegio:** los contenedores corren, cuando es posible, con usuarios no privilegiados.
- **Permisos de volúmenes:** los volúmenes de datos se configuran con `0770`, de forma que solo el motor de contenedores y el administrador pueden listar o acceder al contenido — ningún otro proceso u usuario del host puede secuestrar esa información.
- **Aislamiento de red:** como se describe arriba, `red-privada` bloquea cualquier ruta directa hacia LDAP o MariaDB desde fuera de Docker o desde `red-publica`.
- **Imágenes oficiales:** solo se usan imágenes con sello "Official Image" de Docker Hub, y las actualizaciones se aplican recreando el contenedor con la imagen `latest` en vez de parchear en caliente, evitando residuos de configuración vulnerable.

## Monitorización y respuesta ante incidentes (Wazuh)

El agente Wazuh vive en `red-privada` (con visibilidad sobre los volúmenes de datos) y se comunica con el manager por `red-seguridad`. Su función:

- **Logcollector:** lee en tiempo real los logs de Nginx y Nextcloud.
- **Detección de fuerza bruta:** varios intentos de login fallidos generan una alerta de nivel alto en el dashboard.
- **FIM (File Integrity Monitoring):** cualquier modificación no autorizada en ficheros de configuración críticos (`/etc/`, `config.php`) dispara una alerta inmediata — algo que una simple lectura de logs no detectaría.
- **Transporte cifrado:** la comunicación agente↔manager va cifrada en AES-256.

### Amenazas consideradas y medida implementada

| Amenaza | Riesgo | Medida implementada |
|---|---|---|
| Fuerza bruta al login de Nextcloud | Alto | Reglas de detección en Wazuh |
| Interceptación de tráfico (MitM) | Muy alto | TLS 1.3 forzado + HSTS |
| Inyección SQL en la base de datos | Medio | Aislamiento de red (3306 cerrado al host) |
| Secuestro de sesión | Medio | Cookies seguras y `HttpOnly` en el proxy |

### Validado en pruebas

- **Fuerza bruta simulada:** 10 intentos de login fallidos desde una IP externa. Nextcloud cortó la escritura de eventos de autenticación tras los primeros intentos y devolvió HTTP 429.
- **Aislamiento de red:** un ping desde el contenedor `proxy` hacia `db-nextcloud` fue rechazado, confirmando que el hardening de `red-privada` funciona como está diseñado.
- **Consumo de recursos:** el stack completo se mantuvo en ~3.2 GB de RAM en reposo (hasta 3.8 GB indexando archivos), dentro del límite de un host con 4 GB dedicados a Docker.
