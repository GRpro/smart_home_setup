# smart_home_setup

Personal smart-home and LoRaWAN tooling on a VPS. This repository is organized by stack:

| Directory | Purpose |
|-----------|---------|
| [`home-assistant/`](home-assistant/README.md) | Home Assistant behind nginx, Let’s Encrypt (DuckDNS), MQTT to ChirpStack Mosquitto |
| [`chirpstack-docker/`](chirpstack-docker/README.md) | ChirpStack LoRaWAN network server, Mosquitto, gateway bridge, REST API |

Stacks are deployed separately with Docker Compose. See each folder’s README for prerequisites, ports, and setup order.
