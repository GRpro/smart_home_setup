# Home Assistant — VPS Deployment Guide

Deploy **Home Assistant** on a VPS, connected to your existing **ChirpStack LoRaWAN** stack over an internal bridge.

## Architecture

```
Internet
    │ HTTPS :443
 [NGINX] ◄── Let's Encrypt SSL (DuckDNS)
    │ proxy_pass :8123
[Home Assistant]
    │ MQTT :1883 (connected via 'host.docker.internal' to ChirpStack/Mosquitto)
```

This stack is pre-configured to reach your Mosquitto container using the special hostname `host.docker.internal`. This setup is robust and works even if Port 80 is blocked.

---

## Prerequisites

- VPS with **Ubuntu 22.04+** / Debian 12+
- **Docker + Docker Compose** installed
- Ports **443**, **1883**, **1700 UDP** open in the VPS firewall (**Port 80 is NOT required**)
- Your **ChirpStack stack already running**

---

## Deployment Steps

### Step 1 — Configure Home Assistant

Inside this `home-assistant/` directory:

```bash
cp .env.example .env
nano .env   # fill in DUCKDNS_SUBDOMAIN (grpro), DUCKDNS_TOKEN, LE_EMAIL
cp homeassistant/secrets.yaml.example homeassistant/secrets.yaml
```

Update `homeassistant/configuration.yaml` — ensure it matches your domain:

```yaml
homeassistant:
  external_url: "https://grpro.duckdns.org"

mqtt:
  broker: host.docker.internal
  port: 1883
```

### Step 2 — Automate SSL & Start

I have provided a script that handles SSL verification via **DNS** (using your DuckDNS token). This bypasses all firewall/Port 80 issues.

```bash
chmod +x setup_ssl.sh
./setup_ssl.sh
```

Once finished, open **`https://grpro.duckdns.org`** to start Home Assistant onboarding!

---

## Integration

### How data flows
`Device → Gateway → ChirpStack (decodes payload) → Mosquitto (port 1883) → Home Assistant (MQTT sensors)`

### Sensor configuration
The `configuration.yaml` is pre-configured to use `host.docker.internal`. To add sensors, edit `homeassistant/sensors.yaml` using the "Live Data" fields from your ChirpStack UI.

---

## Maintenance

### SSL Renewal
Renewal is **fully automatic**. The `certbot` container checks for expiry every 12 hours. 

### Useful Commands

```bash
# Verify HA can reach Mosquitto
docker exec homeassistant ping host.docker.internal

# View HA logs
docker logs homeassistant -f

# Test MQTT (run inside HA container)
docker exec homeassistant mosquitto_sub -h host.docker.internal -t 'application/#' -v
```
