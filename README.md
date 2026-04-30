# smart_home_setup

Personal smart-home and LoRaWAN tooling on a VPS. This repository is organized by stack:

| Directory | Purpose |
|-----------|---------|
| [`home-assistant/`](home-assistant/README.md) | Home Assistant behind nginx, Let’s Encrypt (DuckDNS), MQTT to ChirpStack Mosquitto |
| [`chirpstack-docker/`](chirpstack-docker/README.md) | ChirpStack LoRaWAN network server, Mosquitto, gateway bridge, REST API. Based on [`official chirpstack docker quickstart`](https://github.com/chirpstack/chirpstack-docker) |

ChirpStack and Home Assistant are deployed together as **one Docker Compose project** on the shared **`iot`** network (service DNS: `chirpstack`, `mosquitto`, etc.). See each folder’s README for prerequisites, ports, and first-time setup.

## Root helper scripts

From the repository root:

- **`./start.sh`** — `docker compose --project-name smart_home -f docker-compose.yml` (root file **`include:`**s [`chirpstack-docker/docker-compose.yml`](chirpstack-docker/docker-compose.yml) + [`home-assistant/docker-compose.yml`](home-assistant/docker-compose.yml) so bind-mount paths resolve correctly). Uses both `.env` files when present (`chirpstack-docker/.env` then `home-assistant/.env`; later keys override earlier ones).
- **`./stop.sh`** — stops that same project without removing volumes.

Requires **Docker Compose V2** (`docker compose`, e.g. v2.20+ for multiple `--env-file`).

### Migrating from two separate Compose projects

If you previously started each stack with its own `docker compose -f ...` (default project names), stop and remove those old projects once so you do not run duplicate containers:

```bash
docker compose --project-name smart_home -f docker-compose.yml down
```

Then use `./start.sh`. Shared network **`iot`** is created by Compose when the merged project starts.

**Nginx + ChirpStack at `/chirpstack/`:** the active TLS file `home-assistant/nginx/conf.d/default.conf` is generated and **gitignored** so pulls do not clobber it. After updating the repo, from `home-assistant/` run **`./setup_ssl.sh --apply-template`** (certs must already exist) to refresh that file from `default-ssl.conf.template`.
