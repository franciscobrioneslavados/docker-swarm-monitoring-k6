# Docker Swarm en AWS

Proyecto Terraform para un laboratorio Docker Swarm con Traefik, una app de
demostración y observabilidad con Prometheus, Grafana y Loki.

## Documentación

Empieza en [DOCS/README.md](./DOCS/README.md), índice de las tres guías:

1. [Guía de k6](./DOCS/GUIA-K6.md) — **principal para ejecutar pruebas**.
2. [Guía de despliegue](./DOCS/GUIA-DESPLIEGUE.md).
3. [Guía de monitoreo](./DOCS/GUIA-MONITOREO.md).

## Componentes

- Terraform y AWS Systems Manager para infraestructura y operación remota.
- Docker Swarm con manager y workers configurables.
- Traefik como proxy HTTP para aplicaciones.
- Prometheus, node-exporter y cAdvisor para métricas.
- Loki y Alloy para logs; Grafana para consultar métricas y logs.
- Grafana k6 para pruebas HTTP desde un generador local o dedicado.

La documentación utiliza outputs dinámicos y ejemplos genéricos. No contiene
endpoints ni identificadores de una cuenta AWS concreta. Revisa y adapta
credenciales/perfiles y variables al entorno propio antes de ejecutar
Terraform o scripts.
