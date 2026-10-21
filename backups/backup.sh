#!/usr/bin/env bash
# Backup semanal de ~/homelab con restic.
# Uso: sudo backups/backup.sh   (lee la configuración de backups/backup.env)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
HOMELAB="$(dirname "$HERE")"
source "$HERE/backup.env"
export RESTIC_REPOSITORY RESTIC_PASSWORD_FILE

log() { echo "[$(date '+%F %T')] $*"; }

# Contenedores con bases de datos SQLite: se paran durante la copia para que
# no escriban a medias. Pi-hole no se para para no cortar el DNS.
# (docker pause no sirve: deja colgado el healthcheck de Uptime Kuma.)
STOP=(uptime-kuma grafana npm portainer)

resume() {
  log "Reanudando servicios"
  docker start "${STOP[@]}" >/dev/null 2>&1 || true
  docker exec minecraft rcon-cli save-on >/dev/null 2>&1 || true
}
trap resume EXIT

log "Minecraft: guardando el mundo y pausando el autoguardado"
docker exec minecraft rcon-cli save-all flush >/dev/null
docker exec minecraft rcon-cli save-off >/dev/null
sleep 5

log "Parando: ${STOP[*]}"
docker stop "${STOP[@]}" >/dev/null

log "Copiando $HOMELAB"
restic backup "$HOMELAB" \
  --tag homelab \
  --exclude "$HOMELAB/monitoring/prometheus-data" \
  --exclude "$HOMELAB/homepage/config/logs" \
  --exclude "$HOMELAB/.git"

resume
trap - EXIT

log "Aplicando retención: 8 semanales, 12 mensuales"
restic forget --tag homelab --keep-weekly 8 --keep-monthly 12 --prune

log "Verificando el repositorio (5% de los datos)"
restic check --read-data-subset 5%

log "Backup terminado"
