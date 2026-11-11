# Documentación

Guías operativas del proyecto. Ejecuta los comandos desde la raíz del
repositorio y únicamente contra una infraestructura que estés autorizado a
probar.

## Guías

1. **[Guía de k6](./GUIA-K6.md)** — recomendada para empezar: instalación,
   smoke test, carga gradual y consulta de resultados.
2. **[Guía de despliegue](./GUIA-DESPLIEGUE.md)** — validar Terraform, entender
   los nodos Swarm y desplegar la aplicación demo.
3. **[Guía de monitoreo](./GUIA-MONITOREO.md)** — acceso a Grafana, paneles,
   consultas Prometheus/Loki y comprobaciones remotas.

## Recorrido sugerido

1. Sigue la guía de despliegue y confirma que la aplicación responde.
2. Usa la guía de k6 para generar una carga pequeña desde tu equipo.
3. Abre Grafana y revisa las métricas y logs siguiendo la guía de monitoreo.

Las salidas de prueba documentadas son referencias históricas, no garantías
de rendimiento o disponibilidad. Los endpoints, IDs de recursos y credenciales
se obtienen del entorno propio y no se deben publicar.
