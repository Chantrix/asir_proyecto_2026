# CLAUDE.md — Proyecto SanRap

## Contexto
Soy Santiago. Este repositorio va a servir como **proyecto de portfolio para mi CV**.
Busco empleo (no prácticas) orientado a sistemas / DevOps (Docker, Kubernetes, ciberseguridad).
El repo debe mostrar que sé diseñar, desplegar, operar y documentar un sistema real.

Responde y escribe siempre en **español**.

## Qué es SanRap
Nube privada con software libre para una PYME, orientada a soberanía de datos y RGPD.
Proyecto final (TFG) del ciclo de ASIR, desplegado en un servidor en mi casa.

Stack:
- Docker Compose
- Nextcloud + MariaDB
- OpenLDAP + phpLDAPadmin
- Nginx Proxy Manager con Let's Encrypt
- DuckDNS (DNS dinámico)
- Wazuh con FIM (monitorización de integridad)
- Scripts Bash propios

Red segmentada en tres redes Docker: **pública** (solo el proxy), **privada** (Nextcloud, MariaDB, LDAP) y **seguridad** (Wazuh).

## Material de partida
La memoria completa del TFG está en `docs/memoria-tfg.pdf` (o `.docx`). Es muy extensa:
incluye diseño, justificación, manual de instalación y manual de uso.
Es la **fuente de verdad**: no inventes datos, versiones, cifras ni problemas que no aparezcan en ella.
Si falta algo, deja un marcador `<POR COMPLETAR: …>` y avísame.

## Estructura objetivo del repositorio
```
sanrap/
├── README.md              ← escaparate, 1-2 pantallas
├── CLAUDE.md
├── docs/
│   ├── instalacion.md     ← manual de instalación (desde la memoria)
│   ├── manual-usuario.md  ← manual de uso (desde la memoria)
│   ├── arquitectura.md    ← diseño y decisiones técnicas, más desarrollado
│   ├── img/               ← diagrama y capturas
│   └── memoria-tfg.pdf    ← trabajo completo
├── docker-compose.yml
├── .env.example
└── scripts/
```

## Tareas
1. **README.md** (escaparate). Secciones, en este orden:
   - Título y descripción de 2-3 líneas
   - Diagrama de arquitectura (enlace a `docs/img/`)
   - Qué resuelve
   - Stack (tabla capa → tecnología)
   - Arquitectura de red (las tres redes)
   - Decisiones técnicas: 3-4, cada una con su porqué
   - Problemas encontrados y cómo los resolví (sacados de la memoria)
   - Operación: backups, actualizaciones, monitorización
   - Despliegue rápido (3-4 comandos) y enlace a `docs/instalacion.md`
   - Documentación (enlaces a `docs/`)
   - Próximos pasos
2. **docs/instalacion.md** y **docs/manual-usuario.md**: convertir los manuales de la memoria a Markdown,
   manteniendo el contenido casi íntegro pero con encabezados, bloques de código y listas limpias.
3. **docs/arquitectura.md**: la parte de diseño de la memoria, desarrollada con más detalle que en el README.

## Criterios al condensar la memoria
- **Recortar, no resumir todo.** Fuera del README: introducción académica, marco teórico,
  justificación para el tribunal y explicaciones de qué es Docker, LDAP, etc.
- Tono de documentación técnica de un proyecto real, no de trabajo de clase.
- Priorizar decisiones con su porqué y problemas reales resueltos: es lo que más se mira en entrevistas.
- Frases cortas, en primera persona cuando hable de lo que hice.

## Seguridad del repo (obligatorio)
- Nada de contraseñas, tokens ni claves: usar `.env.example` con valores de ejemplo.
- Nada de IP pública, dominio DuckDNS real, nombres de usuario reales ni capturas con datos sensibles.
- Revisar scripts y compose antes de subir; avisarme si encuentras algo sensible.
- Comprobar que existe `.gitignore` que excluya `.env` y datos de volúmenes.

## Forma de trabajar
- Primero léete la memoria y propón el índice del README antes de escribirlo.
- Enséñame cada fichero antes de pasar al siguiente.
