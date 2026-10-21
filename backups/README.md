# Backups

Copias semanales de `~/homelab` con [restic](https://restic.net): cifradas,
deduplicadas (cada copia solo guarda lo que ha cambiado) y con retención automática.

## Qué se copia

Todo `~/homelab` (compose, `.env` y datos de cada servicio), excepto:

- `monitoring/prometheus-data`: histórico de métricas, se regenera solo.
- `homepage/config/logs`: logs de Homepage.
- `.git`: ya está en GitHub.

## Cómo se hace una copia sin corromper datos

1. **Minecraft**: `save-all flush` vuelca el mundo a disco y `save-off` pausa el
   autoguardado mientras se copia. El servidor sigue encendido.
2. **Uptime Kuma, Grafana, NPM y Portainer** (bases de datos SQLite) se paran
   unos segundos durante la copia. `docker pause` no sirve porque deja colgado el
   healthcheck de Uptime Kuma.
3. **Pi-hole** no se para, para no cortar el DNS de la red.
4. Al terminar (o si algo falla) todo vuelve a arrancar y se reactiva el guardado.

## Retención

Se guardan las últimas **8 copias semanales** y **12 mensuales**. Después de cada
copia se verifica el 5 % de los datos del repositorio al azar.

## Configuración

```bash
cp backups/backup.env.example backups/backup.env   # ajustar el destino
sudo sh -c 'umask 077; head -c 32 /dev/urandom | base64 > /root/.restic-password'
sudo restic -r /mnt/backup/restic --password-file /root/.restic-password init
sudo backups/backup.sh
```

> **La contraseña de `/root/.restic-password` es imprescindible para restaurar.**
> Si se pierde junto con la Pi, los backups no se pueden abrir. Guárdala también
> fuera de la Pi (por ejemplo, en un gestor de contraseñas).

## Restaurar

```bash
source backups/backup.env; export RESTIC_REPOSITORY RESTIC_PASSWORD_FILE
sudo -E restic snapshots                                    # ver copias
sudo -E restic restore latest --target /tmp/restore          # restaurar todo aparte
sudo -E restic restore latest --target /tmp/restore \
  --include /home/umbyx/homelab/minecraft/data/world         # solo el mundo
```

Para volver a poner un servicio en marcha: parar su contenedor, copiar sus datos
desde `/tmp/restore` a su carpeta en `~/homelab` y arrancarlo.
