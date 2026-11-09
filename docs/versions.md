# Versiones de las imágenes

Todas las imágenes usan una etiqueta fija: una reinstalación descarga exactamente
la misma versión, y las actualizaciones se hacen a mano cuando se decide.

| Servicio | Imagen | Actualizado |
|---|---|---|
| pihole | `pihole/pihole:2026.10.1` (Core 6.5, Web 6.6.1, FTL 6.8) | 2026-11-09 |
| homepage | `ghcr.io/gethomepage/homepage:v2.7.0` | 2026-11-09 |
| npm | `jc21/nginx-proxy-manager:2.16.0` | 2026-11-09 |
| portainer | `portainer/portainer-ce:2.45.3` | 2026-11-09 |
| uptime-kuma | `louislam/uptime-kuma:2.5.9` | 2026-11-09 |
| prometheus | `prom/prometheus:v3.16.0` | 2026-11-09 |
| node-exporter | `prom/node-exporter:v1.12.1` | 2026-11-09 |
| grafana | `grafana/grafana:13.3.0` | 2026-11-09 |
| minecraft | `itzg/minecraft-server:2026.11.0-java25`, juego `26.2` | 2026-11-09 |

## Notas

- **Grafana**: `grafana/grafana-oss` dejó de publicarse en la 13.0.2. Las versiones
  nuevas de la edición gratuita salen como `grafana/grafana`.
- **Uptime Kuma**: migrado de 1.23.17 a 2.x el 2026-11-09. El primer arranque de la
  2.x convierte la base de datos (unos 5 minutos en la Pi) y no se puede
  interrumpir. Copia de los datos v1 en `~/kuma-v1-data-20261109.tar.gz`.
- **Minecraft**: `VERSION` fija la versión del juego. Con `LATEST`, cualquier reinicio
  podría actualizar el servidor y dejar incompatibles los mods de Fabric. Subir
  `VERSION` solo cuando todos los mods tengan versión para la nueva.

## Cómo actualizar un servicio

1. Hacer backup: `sudo backups/backup.sh`.
2. Leer las notas de la versión nueva (cambios incompatibles).
3. Cambiar la etiqueta en su `compose.yaml` y ejecutar `docker compose up -d` en su carpeta.
4. Comprobar que arranca bien (`docker logs`, la web del servicio, Uptime Kuma).
5. Actualizar esta tabla y hacer commit.
