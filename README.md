# smart_home_setup

Personal smart-home and LoRaWAN tooling on a VPS. This repository is organized by stack:

| Directory | Purpose |
|-----------|---------|
| [`home-assistant/`](home-assistant/README.md) | Home Assistant behind nginx, Let’s Encrypt (DuckDNS), MQTT to ChirpStack Mosquitto |
| [`chirpstack-docker/`](chirpstack-docker/README.md) | ChirpStack LoRaWAN network server, Mosquitto, gateway bridge, REST API. Based on [`official chirpstack docker quickstart`](https://github.com/chirpstack/chirpstack-docker) |

ChirpStack and Home Assistant are deployed together as **one Docker Compose project** on the shared **`iot`** network (service DNS: `chirpstack`, `mosquitto`, etc.). See each folder’s README for prerequisites, ports, and first-time setup.

## Root helper scripts

From the repository root:

- **`./start.sh`** — `docker compose --project-name smart_home` with both compose files and both `.env` files (when present): `chirpstack-docker/.env` then `home-assistant/.env` (later keys override earlier ones).
- **`./stop.sh`** — stops that same project without removing volumes.

Requires **Docker Compose V2** (`docker compose`, e.g. v2.20+ for multiple `--env-file`).

### Migrating from two separate Compose projects

If you previously started each stack with its own `docker compose -f ...` (default project names), stop and remove those old projects once so you do not run duplicate containers:

```bash
docker compose -f chirpstack-docker/docker-compose.yml down
docker compose -f home-assistant/docker-compose.yml down
```

Then use `./start.sh`. Shared network **`iot`** is created by Compose when the merged project starts.
