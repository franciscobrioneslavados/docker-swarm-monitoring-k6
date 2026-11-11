# Guía de pruebas de carga con Grafana k6

Manual prioritario para ejecutar pruebas HTTP desde un equipo local, observar
los resultados y entender los umbrales de los scripts del proyecto.

> k6 es un generador de carga, no Kubernetes ni k3s. Estas pruebas generan
> requests reales contra la aplicación desplegada. Ejecuta solo contra
> infraestructura que estés autorizado a probar.

## 1. Requisitos

- App demo desplegada y accesible por Traefik.
- Conectividad desde tu equipo a Traefik por HTTP.
- Grafana k6 instalado.
- Opcional: Terraform y `jq` para obtener los endpoints, Grafana para observar
  las métricas y logs.

En macOS con Homebrew:

```bash
brew install k6
k6 version
```

Consulta la documentación oficial de k6 para otros sistemas operativos.

## 2. Obtener y comprobar el destino

Desde la raíz del repositorio:

```bash
TRAEFIK_IP=$(terraform output -json instances_config | jq -r '.traefik.public_ip')
BASE_URL="http://${TRAEFIK_IP}"
printf 'Destino de prueba: %s\n' "$BASE_URL"
```

Comprueba el endpoint antes de lanzar k6:

```bash
curl -i "$BASE_URL/health"
```

La respuesta esperada es HTTP 200 con JSON de estado `ok`. Si no responde,
confirma que el endpoint se obtuvo de los outputs actuales y que el servicio
está desplegado. No uses IPs copiadas de una ejecución anterior.

## 3. Smoke test: empezar aquí

Ejecuta primero el escenario pequeño:

```bash
BASE_URL="$BASE_URL" k6 run k6/smoke.js
```

Configuración de `k6/smoke.js`:

- 1 usuario virtual y 5 iteraciones.
- Dos requests por iteración: `/health` y `/work?delay_ms=50`.
- 10 requests en total.
- Umbrales: menos de 1% de requests fallidos y p95 inferior a 1000 ms.

Al finalizar, revisa `checks`, `http_req_failed` y `http_req_duration`. Una
salida observada anteriormente en el laboratorio:

```text
checks.........................: 100.00% 10 out of 10
http_req_duration..............: p(95)=60.19ms
http_req_failed................: 0.00%   0 out of 10
iterations.....................: 5
```

Son valores de referencia, no un objetivo garantizado. La latencia varía por
red, ubicación del generador, carga y capacidad de las instancias.

## 4. Carga gradual de baja intensidad

Solo después de validar el smoke, ejecuta:

```bash
BASE_URL="$BASE_URL" k6 run k6/load.js
```

`k6/load.js` sube hasta 3 usuarios virtuales en 30 segundos, luego hasta 5
durante 1 minuto y baja a 0 durante 30 segundos. Cada iteración consulta
`/work?delay_ms=100` y espera 1 segundo. Los umbrales son menos de 2% de
requests fallidos y p95 inferior a 1500 ms.

Salida de referencia observada:

```text
checks.........................: 100.00% 314 out of 314
http_req_duration..............: p(95)=118.63ms
http_req_failed................: 0.00%   0 out of 314
iterations.....................: 314
```

Este es un ejercicio de carga gradual pequeño, no una prueba de estrés ni una
medición de capacidad máxima. Para pruebas grandes, define límites y ventana
de ejecución con el responsable del entorno, y ejecuta k6 desde un generador
separado del Swarm y de la instancia de observabilidad.

## 5. Rutas probadas

| Ruta | Respuesta | Uso |
| --- | --- | --- |
| `/health` | HTTP 200 | Disponibilidad básica |
| `/work?delay_ms=50` | HTTP 200 | Simulación de trabajo con demora acotada |
| `/error` | HTTP 500 intencional | Verificar logs de error |

Los scripts k6 actuales usan `/health` y `/work`; no usan `/error`, para que la
respuesta de error esperada no cuente como fallo de la prueba normal.

## 6. Observar los resultados

1. Obtén la URL actual de Grafana:

   ```bash
   terraform output -raw observability_public_url
   ```

2. Ábrela en el navegador usando `https://` y el puerto devuelto. Si la
   configuración usa certificado autofirmado, sigue la política del entorno.
3. Inicia sesión con credenciales obtenidas por el proceso autorizado.
4. Abre **Dashboards → Docker Swarm overview**, selecciona `Last 15 minutes` y
   actualiza.
5. Revisa el panel de solicitudes de la aplicación.
6. En **Explore → Loki**, usa:

   ```logql
   {job="docker"} |= "http_request"
   ```

El scrape de métricas es cada 15 segundos en la configuración de referencia,
por lo que los datos pueden aparecer con un breve retraso.

## 7. Interpretar fallas

- **Timeout o conexión rechazada:** revisa `BASE_URL`, conectividad y
  `curl "$BASE_URL/health"` antes de volver a ejecutar.
- **Requests fallidos:** consulta los códigos y los checks. `/error` responde
  500 de forma deliberada, pero no forma parte de estos escenarios.
- **Umbral excedido:** significa que esta ejecución no cumplió el objetivo.
  Correlaciona latencia/fallos con CPU, memoria y logs en Grafana; no concluyas
  automáticamente que toda la infraestructura está caída.
- **No ves datos al instante:** espera al menos un intervalo de scrape, amplía
  el rango temporal y refresca.
- **Métricas de contenedor parciales:** revisa los logs de cAdvisor; un target
  `up` no asegura que todas sus métricas sean utilizables.

No lances cargas concurrentes no coordinadas. La carga puede consumir recursos
y afectar a otras aplicaciones o usuarios del mismo entorno.

## Referencias

- [Índice de guías](./README.md)
- [Guía de despliegue](./GUIA-DESPLIEGUE.md)
- [Guía de monitoreo](./GUIA-MONITOREO.md)
- [Scripts k6 del proyecto](../k6/)
