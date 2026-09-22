# Manual de instalación

Guía paso a paso para desplegar SanRap desde cero: Docker, el stack principal (proxy, LDAP, Nextcloud) y el stack de monitorización (Wazuh).

## Requisitos previos

- Un dominio de [DuckDNS](https://www.duckdns.org/) apuntando a tu servidor.
- Acceso de administrador al router de la red donde vive el servidor (para el port-forwarding).
- Sistema operativo con soporte Docker: Windows, macOS o Linux (se recomienda Linux en producción; el proyecto se ha probado sobre Ubuntu 24.04 LTS).

## 1. Instalar Docker

### Windows

1. Descarga Docker Desktop for Windows (AMD64) desde la web oficial.
2. Ejecuta el instalador y marca **"Use WSL 2 instead of Hyper-V"** para mejor rendimiento.
3. Reinicia el equipo cuando lo pida.
4. Verifica la instalación:
   ```bash
   docker --version
   ```

### macOS

1. Descarga Docker Desktop para Mac (Apple Silicon o Intel, según tu equipo).
2. Abre el `.dmg` y arrastra Docker a Aplicaciones.
3. Inicia Docker desde Aplicaciones y acepta los permisos de administrador.

### Linux (Ubuntu/Debian)

```bash
sudo apt-get update
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo docker run hello-world   # verifica la instalación
```

## 2. Variables de entorno

Copia la plantilla `.env.example` a `.env` en la raíz del proyecto y rellénala con tus propios valores:

```bash
cp .env.example .env
```

```env
# --- debes tener tu dominio de duckdns apuntando a tu servidor ---
MI_DOMINIO=<tu subdominio>.duckdns.org
DUCKDNS_TOKEN=<tu token de duckdns>
MI_SUBDOMINIO=<tu subdominio>

# --- variables de OpenLDAP ---
CLAVE_ADMIN_LDAP=<contraseña de administrador de LDAP>
LDAP_CONFIG_PASS=<contraseña de configuración de LDAP>
LDAP_ORGANISATION=<nombre de tu organización>

# --- base de datos de Nextcloud ---
NC_DB_ROOT_PASS=<contraseña root de la base de datos, larga>
NC_DB_USER=<usuario de base de datos de Nextcloud>
NC_DB_PASS=<contraseña de ese usuario>
NC_DB_NAME=<nombre de la base de datos>
```

Necesitas una cuenta de DuckDNS antes de este paso: es la que te da el dominio y el token.

## 3. Firewall y router

El servidor está detrás de un router con NAT, así que el tráfico externo no llega solo:

- **Router:** crea una regla de reenvío de puertos (port-forwarding) que dirija el puerto WAN **4442** hacia la IP privada del servidor, puerto **4442**.
- **Host (UFW):** abre el mismo puerto en el firewall del propio servidor:
  ```bash
  sudo ufw allow 4442/tcp
  ```

## 4. Redes Docker y despliegue del stack principal

Crea las redes que usará `compose.yaml`:

```bash
docker network create red-publica
docker network create red-privada
```

`red-seguridad` la crea automáticamente el stack de Wazuh más adelante (se declara como `external` en `compose.yaml`).

Despliega el stack principal desde la raíz del proyecto:

```bash
docker compose up -d
```

Esto descarga las imágenes necesarias y levanta el proxy, OpenLDAP, phpLDAPadmin, MariaDB, Nextcloud y el agente de Wazuh.

## 5. Configurar Nginx Proxy Manager

1. Entra en `https://localhost:81` y crea el usuario administrador la primera vez.
2. Crea un **Proxy Host** para LDAP: nombre de dominio (p. ej. `ldap.<tu-dominio>.duckdns.org`), Forward Hostname `phpldapadmin`, Forward Port `80`. En la pestaña SSL: solicita un certificado nuevo, marca `Force SSL`, `HSTS Enabled` y `Use DNS Challenge` con proveedor DuckDNS y tu token.
3. Crea un segundo **Proxy Host** para Nextcloud: nombre `cloud.<tu-dominio>.duckdns.org`, Forward Hostname `nextcloud-asir`, Forward Port `80`. Reutiliza el certificado ya emitido y fuerza SSL igualmente.

## 6. Poblar OpenLDAP

Entra al host de LDAP a través del proxy y accede a phpLDAPadmin con `cn=admin,dc=<tu-organizacion>,...` y la contraseña que pusiste en `CLAVE_ADMIN_LDAP`.

Puedes crear Unidades Organizativas, grupos y usuarios uno a uno desde la interfaz, o importar de golpe un fichero `.ldif` (ver ejemplo de estructura en `organizacion.ldif`) desde la pestaña **Import**.

## 7. Instalar Nextcloud

Accede al host de Nextcloud a través del proxy, rellena las credenciales de administrador que quieras y espera a que termine la instalación automática.

## 8. Fijar el puerto real en las URLs de Nextcloud

Al usar un puerto no estándar (4442) para HTTPS, Nextcloud genera por defecto enlaces internos apuntando al 443. Corrígelo ejecutando, desde la raíz del proyecto:

```bash
./scriptInicio.sh 4442
```

Después, conecta Nextcloud con el directorio LDAP desde **Administration Settings → LDAP/AD integración**: como servidor usa el nombre del contenedor (`ldap-servidor`) en el puerto `389`, selecciona los object classes `inetOrgPerson`/`posixAccount`, define `LDAP/AD Username` como atributo de login y elige los grupos que hayas creado en el DIT.

## 9. Desplegar el stack de Wazuh (SIEM)

El manager de Wazuh se despliega por separado, a partir del repositorio oficial (no forma parte de este repositorio, que solo incluye el agente cliente en `compose.yaml`).

Prepara el host — Wazuh necesita un mínimo de `vm.max_map_count`:

```bash
echo "vm.max_map_count=262144" | sudo tee /etc/sysctl.d/99-wazuh.conf
sudo sysctl --system
```

Clona el repositorio oficial de Wazuh y entra en la carpeta `single-node`:

```bash
git clone https://github.com/wazuh/wazuh-docker.git -b v4.14.4
```

Sustituye el `docker-compose.yml` de esa carpeta por tu propio `compose.yaml` (adaptado para que los servicios se comuniquen por la `red-seguridad` creada en el paso 4) y despliega:

```bash
docker compose up -d
```

Da permisos de ejecución al script de conexión del agente y ejecútalo para completar el enrollment entre el agente y el manager:

```bash
sudo chmod 700 scriptConexion.sh
sudo ./scriptConexion.sh
```

Accede al dashboard de Wazuh en `https://localhost:8443`. Credenciales por defecto de la imagen oficial (cámbialas en el primer acceso):

- Usuario: `admin`
- Contraseña: `SecretPassword`

> Puertos expuestos por el manager: `1514/TCP` (comunicación con agentes), `1515/TCP` (enrollment), `514/UDP` (syslog), `55000/TCP` (API del server), `9200/TCP` (API del indexer), `443/TCP` (dashboard HTTPS).
