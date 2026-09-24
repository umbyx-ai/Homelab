# 🍓 Raspberry Pi 5 Homelab & Services Stack

A complete, production-grade 24/7 homelab setup running on **Raspberry Pi OS Lite** with Docker Compose, local DNS routing, network-wide ad-blocking (with remote Tailscale coverage), automated Discord monitoring, and a dedicated Minecraft game server.

---

## 🖥️ 1. Hardware Specifications

- **Device:** Raspberry Pi 5 (8 GB RAM)
- **Boot & OS Storage:** High-Performance MicroSD Card (Raspberry Pi OS Lite 64-bit)
- **External Storage:** 1 TB Western Digital External Drive (USB)
- **Power Supply:** Official Raspberry Pi 27W USB-PD (5.1V / 5.0A)
- **Cooling:** Official Raspberry Pi Active Cooler

---

## 🌐 2. Network Topology & Architecture

```text
       [ Public Internet / School / 5G ]
                       │
             (Tailscale Encrypted Mesh)
                       ▼
              [ Raspberry Pi 5 ] (Static LAN IP: 192.168.1.50)
                       │
       ┌───────────────┴───────────────┐
       ▼                               ▼
 [ Pi-hole DNS ]               [ Nginx Proxy Manager ]
(Blocks Ads & Maps *.lab.internal)  (Routes HTTP/HTTPS to Containers)
       │                               │
       └───────────────┬───────────────┘
                       ▼
   [ Docker Services (Portainer, Kuma, Grafana, etc.) ]
```

### Key Network Rules & Decisions:
1. **Pure Ethernet (Zero Wireless Churn):**
   - Wi-Fi is powered down at the firmware level by adding `dtoverlay=disable-wifi` to `/boot/firmware/config.txt`.
   - Eliminates dual-interface routing conflicts, ARP churn, and power-saving sleep disconnects.
2. **Static LAN Address:**
   - Configured manually on `eth0` via `nmtui` (`192.168.1.50/24`, Gateway: `192.168.1.1`).
3. **Upstream Resolver on Host:**
   - The Raspberry Pi host uses `1.1.1.1` in its own network config so system package updates (`apt update`) and Docker image pulls never fail even if the Pi-hole container is temporarily restarting.
4. **Anywhere Ad-Blocking (Tailscale + Pi-hole):**
   - Tailscale is installed on client devices (phones, laptops).
   - In the Tailscale Admin Console, the Pi's Tailscale IP (`100.64.0.5`) is set as a **Global Nameserver** with **"Override local DNS"** enabled.
   - Result: All internet queries on school Wi-Fi, home Wi-Fi, and cellular 5G route DNS through the homelab Pi-hole, blocking ads everywhere without touching home router DNS.

---

## 📦 3. Directory Structure

All services are organized in an isolated, modular layout under `~/homelab/`:

```text
/home/user/homelab/
├── portainer/          # Docker Container Manager
├── pihole/             # Ad-Blocking & Local DNS
├── npm/                # Nginx Proxy Manager (Reverse Proxy)
├── uptime-kuma/        # Uptime Monitor & Discord Webhook
├── monitoring/         # Prometheus, Node-Exporter & Grafana
├── minecraft/          # Java Fabric Server
└── homepage/           # Dashboard Start Page
```

---

## 🚀 4. Installed Services & Configuration Details

### 1. Portainer CE (Container Management)
- **Purpose:** Web-based GUI to inspect container health, view logs, and manage stacks.
- **Ports:** Internal HTTP port `9000`, HTTPS `9443`.
- **Lesson Learned / Reverse Proxy Fix:** 
  - Accessing Portainer through a reverse proxy over plain HTTP caused the browser to drop `Secure` session cookies, resulting in a persistent `401 Unauthorized` error when forwarding to HTTPS port `9443`.
  - Forwarding from Nginx Proxy Manager to Portainer's HTTP port (`9000`) completely resolved the authentication loop.

### 2. Pi-hole (Ad-Blocker & Local DNS)
- **Purpose:** Drops tracking and ad domains at the DNS level before they load on client devices; maps private domain names (e.g. `*.lab.internal`) to the server IP.
- **Ports:** `53` (UDP/TCP), `8080` (Web Admin UI).
- **Key Configuration:**
  - `DNSMASQ_LISTENING: all` ("Permit all origins") enabled in DNS settings so DNS queries arriving over the Tailscale VPN tunnel are accepted and processed.

### 3. Nginx Proxy Manager (Reverse Proxy)
- **Purpose:** Listens on standard ports 80/443 and routes incoming domain names to the appropriate container port.
- **Ports:** `80` (HTTP), `443` (HTTPS), `81` (Admin Dashboard).
- **Domain Mappings Configured:**
  - `portainer.lab.internal` → `192.168.1.50:9000`
  - `pihole.lab.internal` → `192.168.1.50:8080`
  - `npm.lab.internal` → `192.168.1.50:81`
  - `kuma.lab.internal` → `192.168.1.50:3001`
  - `grafana.lab.internal` → `192.168.1.50:3000`
  - `home.lab.internal` → `192.168.1.50:3005`

### 4. Uptime Kuma (Health Monitoring & Discord Alerts)
- **Purpose:** Constantly checks service responsiveness and home internet availability.
- **Port:** `3001`.
- **Alert System:** Integrated with a **Discord Webhook** channel to send instant notifications whenever a service crashes or home internet drops.
- **Active Monitors:** Pi-hole, Portainer, NPM, Grafana, Minecraft Server, and Cloudflare Ping (`1.1.1.1`).

### 5. Grafana + Prometheus + Node Exporter (Telemetry)
- **Purpose:** Full visual dashboard tracking real-time CPU load, temperatures, RAM usage, and disk I/O.
- **Ports:** Grafana `3000`, Prometheus `9090`, Node Exporter `9100`.
- **Dashboard:** Official *Node Exporter Full* (Dashboard ID: `1860`).
- **Lesson Learned / Permissions Fix:**
  - Grafana (`UID 472`) and Prometheus (`UID 65534`) run as dedicated non-root users inside their containers.
  - When directories were created by the default user, both containers entered crash-restart loops due to `Permission Denied` errors.
  - Fixed with:
    ```bash
    sudo chown -R 472:472 ./grafana-data
    sudo chown -R 65534:65534 ./prometheus-data
    ```

### 6. Minecraft Dedicated Server
- **Purpose:** 24/7 multiplayer game server for friends.
- **Engine:** Fabric (Java Edition) running on the `itzg/minecraft-server` image.
- **RAM Allocation:** Min 2 GB / Max 4 GB (`INIT_MEMORY: 2G`, `MAX_MEMORY: 4G`).
- **Networking:** Home router port `25565` (TCP/UDP) forwarded to server IP. Verified open on the public internet (No CG-NAT restriction).
- **Security:** In-game whitelist enabled (`rcon-cli whitelist on`) to prevent automated internet port scanners from joining.
- **Client Mods Supported:** Xaero's Minimap & World Map, EMI / JEI, Jade, Sodium, Mod Menu, and Zoomify.

### 7. Homepage Dashboard
- **Purpose:** Centralized command center and browser start page displaying live server stats.
- **Port:** `3005`.
- **Search Integration:** Native Brave Search widget with live query suggestions.
- **Lessons Learned / Security & Socket Fixes:**
  1. **Host Header Validation:** Homepage v1.0+ enforces security against DNS rebinding. Resolved by declaring allowed domains in `compose.yaml`:
     ```yaml
     HOMEPAGE_ALLOWED_HOSTS: home.lab.internal,192.168.1.50:3005
     ```
  2. **Docker Socket Permissions:** Displayed red `EACCES /var/run/docker.sock` errors because `PGID` was set to 1000 instead of the host's actual `docker` group ID. Resolved by matching `PGID` to the host Docker GID (`getent group docker | cut -d: -f3`).

---

## 🛡️ 5. Stability & 24/7 Reliability Checklist

To guarantee multi-month continuous uptime without suspension or freezes:
- [x] Raspberry Pi OS Lite installed on MicroSD (clean, lightweight OS).
- [x] Masked all systemd sleep states:
  ```bash
  sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
  ```
- [x] Official 27W 5A power supply deployed (verified `vcgencmd get_throttled` reports `0x0`).
- [x] Wi-Fi hardware powered off at boot via `/boot/firmware/config.txt`.
- [x] Each container isolated with its own persistent configuration volume for easy backups.

---

## 🔒 6. Recommended Repository `.gitignore`

When publishing this setup to GitHub, use this `.gitignore` to prevent committing sensitive data or large binary files:

```gitignore
# Ignore persistent container data & databases
**/data/
**/etc-pihole/
**/etc-dnsmasq.d/
**/grafana-data/
**/prometheus-data/
**/letsencrypt/

# Ignore environment files & secrets
**/.env
**/*.key
**/*.pem

# Ignore logs
*.log
.DS_Store
```
