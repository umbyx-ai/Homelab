# Versiones de las imágenes

Versiones en uso el 2026-10-21. Fijar estas etiquetas evita que una reinstalación
descargue versiones distintas con cambios incompatibles.

> Pendiente: aplicar las etiquetas en los `compose.yaml`. Cambiar la etiqueta
> recrea el contenedor (unos segundos sin servicio), así que se hará en casa.

| Servicio | Etiqueta actual | Etiqueta a fijar |
|---|---|---|
| pihole | `pihole/pihole:latest` | `pihole/pihole:2026.07.2` |
| homepage | `ghcr.io/gethomepage/homepage:latest` | `ghcr.io/gethomepage/homepage:v2.3.0` |
| npm | `jc21/nginx-proxy-manager:latest` | `jc21/nginx-proxy-manager:2.15.1` |
| portainer | `portainer/portainer-ce:latest` | `portainer/portainer-ce:2.45.0` |
| uptime-kuma | `louislam/uptime-kuma:1` | `louislam/uptime-kuma:1.23.17` |
| prometheus | `prom/prometheus:latest` | `prom/prometheus:v3.14.0` |
| node-exporter | `prom/node-exporter:latest` | `prom/node-exporter:v1.12.1` |
| grafana | `grafana/grafana-oss:latest` | `grafana/grafana-oss:13.0.2` |
| minecraft | `itzg/minecraft-server:latest` | `itzg/minecraft-server@sha256:c1a267d9ed6de3d1157859753a002aa35f8366d8db00463df3d6b07e86d2bf1d` |

La imagen de Minecraft no publica una etiqueta por versión, así que se fija por
digest (huella exacta de la imagen).
