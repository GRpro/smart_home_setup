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

## Prerequisites

- VPS with **Ubuntu 22.04+** / Debian 12+
- **Docker + Docker Compose** installed
- Ports **80**, **443**, **1883**, **1700 UDP** open in the VPS firewall
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

Update `homeassistant/configuration.yaml` — ensure the domain matches:

```yaml
homeassistant:
  external_url: "https://grpro.duckdns.org"

mqtt:
  broker: host.docker.internal
  port: 1883
```

### Step 2 — Automate SSL & Start

I have provided a script that handles the initial certificate obtainment and NGINX configuration automatically. It requires Port 80 to be open.

```bash
chmod +x setup_ssl.sh
./setup_ssl.sh
```

Once finished, open **`https://grpro.duckdns.org`** to start Home Assistant onboarding!

### Troubleshooting SSL

**Let's Encrypt reports timeout / “likely firewall” but UFW is open**

Check `docker ps`: if `ha_nginx` is **Restarting**, port 80 is not bound. Nginx loads **every** `*.conf` in `nginx/conf.d/`; a stray SSL template there (with missing certs) prevents startup. This repo keeps the SSL **template** as `nginx/default-ssl.conf.template` (outside `conf.d/`). Inspect logs with `docker logs ha_nginx`. **`setup_ssl.sh` resets `default.conf` from `default-http.conf` before requesting a certificate**; after a successful run it writes only `default.conf` with real paths. Re-run `./setup_ssl.sh` if nginx was stuck.

---

## Maintenance

### SSL Renewal
Renewal is **fully automatic**. The `certbot` container checks for expiry every 12 hours. 

### Useful Commands

```bash
# View HA logs
docker logs homeassistant -f

# Test MQTT (run inside HA container)
docker exec homeassistant mosquitto_sub -h host.docker.internal -t 'application/#' -v
```
