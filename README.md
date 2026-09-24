# 🍓 Raspberry Pi 5 Homelab & Services Stack

A complete, production-grade 24/7 homelab setup running on **Raspberry Pi OS Lite** with Docker Compose, local DNS routing, network-wide ad-blocking (with remote Tailscale coverage), automated Discord monitoring, and a dedicated Minecraft game server.

---

## 🖥️ 1. Hardware Specifications

- **Device:** Raspberry Pi 5 (8 GB RAM)
- **Boot & OS Storage:** High-Performance MicroSD Card (Raspberry Pi OS Lite 64-bit)
- **Power Supply:** Official Raspberry Pi 27W USB-PD (5.1V / 5.0A)
- **Cooling:** Official Raspberry Pi Active Cooler

---

## 🌐 2. Network Topology & Architecture

```text
       [ Public Internet / School / 5G ]
                       │
             (Tailscale Encrypted Mesh)
                       ▼
              [ Raspberry Pi 5 ] (Static LAN IP)
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
   - Configured manually on `eth0` via `nmtui` to ensure services always bind to a predictable internal IP.
3. **Upstream Resolver on Host:**
   - The Raspberry Pi host uses `1.1.1.1` in its own network config so system package updates (`apt update`) and Docker image pulls never fail even if the Pi-hole container is temporarily restarting.
4. **Anywhere Ad-Blocking (Tailscale + Pi-hole):**
   - Tailscale is installed on client devices (phones, laptops).
   - In the Tailscale Admin Console, the Pi is set as a **Global Nameserver** with **"Override local DNS"** enabled.
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

### 1. Portainer CE
- **Use / Purpose:** Web-based graphical interface for container administration.
- **How It Works:** Connects directly to the host's `/var/run/docker.sock` to inspect, monitor, restart, and update all active Docker containers and stacks.
- **For What:** Eliminates the need to manage container lifecycles solely through the command line; allows instant log viewing, terminal access, and status monitoring from any browser.
- **Ports:** Internal HTTP port `9000`, HTTPS `9443`.
- **Lesson Learned / Reverse Proxy Fix:** 
  - Accessing Portainer through a reverse proxy over plain HTTP caused the browser to drop `Secure` session cookies, resulting in a persistent `401 Unauthorized` error when forwarding to HTTPS port `9443`.
  - Forwarding from Nginx Proxy Manager to Portainer's HTTP port (`9000`) completely resolved the authentication loop.

---

### 2. Pi-hole
- **Use / Purpose:** Network-wide DNS sinkhole and local DNS management.
- **How It Works:** Acts as the DNS server for the network. When client devices request a domain, Pi-hole checks incoming requests against known ad/tracking blocklists. Ads are resolved to `0.0.0.0` (dropped), while legitimate queries are forwarded to upstream resolvers (`1.1.1.1`).
- **For What:** Blocks ads, telemetry, and tracking across all personal devices (phones, laptops, browsers) without browser extensions, and maps friendly custom domains (e.g. `*.lab.internal`) to local services.
- **Ports:** `53` (UDP/TCP DNS), `8080` (Web Admin UI).
- **Key Configuration:**
  - `DNSMASQ_LISTENING: all` ("Permit all origins") enabled in DNS settings so DNS queries arriving over the Tailscale VPN tunnel are accepted and processed.

---

### 3. Nginx Proxy Manager (NPM)
- **Use / Purpose:** Reverse proxy with a centralized management web interface.
- **How It Works:** Listens on external web ports 80 (HTTP) and 443 (HTTPS). When a request arrives for a specific hostname (e.g. `grafana.lab.internal`), it inspects the HTTP `Host` header and internally passes the traffic to the corresponding container and port on the Raspberry Pi.
- **For What:** Eliminates memorizing confusing port numbers (e.g. `:3000`, `:8080`, `:9000`), allowing clean domain-based navigation and centralized SSL certificate management.
- **Ports:** `80` (HTTP), `443` (HTTPS), `81` (Admin Dashboard).
- **Domain Mappings Configured:**
  - `portainer.lab.internal` → Port `9000`
  - `pihole.lab.internal` → Port `8080`
  - `npm.lab.internal` → Port `81`
  - `kuma.lab.internal` → Port `3001`
  - `grafana.lab.internal` → Port `3000`
  - `home.lab.internal` → Port `3005`

---

### 4. Uptime Kuma
- **Use / Purpose:** Self-hosted uptime monitoring service.
- **How It Works:** Sends regular heartbeat pings (HTTP requests, TCP handshakes, or ICMP pings) every 60 seconds to specified endpoints. When a service fails to respond or exceeds latency thresholds, it triggers automated webhook events.
- **For What:** Provides immediate visibility into service health and dispatches instant push notifications directly to a private **Discord channel via Webhook** if any container crashes or home internet drops.
- **Port:** `3001`.
- **Active Monitors:** Pi-hole, Portainer, NPM, Grafana, Minecraft Server, and Cloudflare Ping (`1.1.1.1`).

---

### 5. Grafana + Prometheus + Node Exporter
- **Use / Purpose:** Full infrastructure monitoring and metrics visualization pipeline.
- **How It Works:**
  - **Node Exporter:** Gathers low-level hardware metrics directly from `/proc`, `/sys`, and rootfs.
  - **Prometheus:** Scrapes metrics from Node Exporter every 15 seconds and stores them in a lightweight time-series database (TSDB).
  - **Grafana:** Queries Prometheus to render interactive, real-time visual graphs and gauges.
- **For What:** Tracking CPU temperatures, core loads, memory consumption, storage space, and network bandwidth over time.
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

---

### 6. Minecraft Dedicated Server
- **Use / Purpose:** Persistent 24/7 dedicated multiplayer Minecraft server.
- **How It Works:** Runs the `itzg/minecraft-server` Docker container with the Fabric mod loader on the ARM64 architecture, writing chunk data and player files to a persistent volume.
- **For What:** Allowing friends to play together at any time without keeping a power-hungry gaming PC running 24/7.
- **RAM Allocation:** Min 2 GB / Max 4 GB (`INIT_MEMORY: 2G`, `MAX_MEMORY: 4G`).
- **Networking:** Home router port `25565` (TCP/UDP) forwarded to the server. Verified open to the public internet (No CG-NAT restriction).
- **Security:** In-game whitelist enabled (`rcon-cli whitelist on`) to prevent automated internet port scanners from entering or griefing.
- **Client Mods Supported:** Xaero's Minimap & World Map, EMI / JEI, Jade, Sodium, Mod Menu, and Zoomify.

---

### 7. Homepage Dashboard
- **Use / Purpose:** Modern, fast, highly customizable application dashboard and browser start page.
- **How It Works:** Reads YAML configuration files and communicates with Docker (`/var/run/docker.sock`) to display real-time container health pills, custom bookmarks, and live service widgets.
- **For What:** Acts as the daily single-pane-of-glass home screen on PC and mobile, featuring an integrated Brave search bar, live Minecraft player count, and 1-click links to all homelab tools.
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
- [x] Official 27W 5A power supply deployed (verified `vcgencmd get_throttled` reports `0x0`).
- [x] Wi-Fi hardware powered off at boot via `/boot/firmware/config.txt`.
- [x] Each container isolated with its own persistent configuration volume for easy backups.
