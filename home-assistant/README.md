# Home Assistant (VPS + nginx + Let’s Encrypt)

Home Assistant runs in Docker behind **nginx** on **443** (HTTPS). **Let’s Encrypt** certificates are obtained with **Certbot** (HTTP-01). **DuckDNS** keeps your public hostname aligned with the VPS.

On the **same host**, [ChirpStack](../chirpstack-docker/) publishes LoRaWAN telemetry to **Mosquitto** on port **1883**. This stack reaches that broker via **`host.docker.internal`** (the Docker host gateway).

---

## Repository layout

| Path | Role |
|------|------|
| `docker-compose.yml` | `homeassistant`, `nginx`, `duckdns`, `certbot` |
| `setup_ssl.sh` | First-time Let’s Encrypt + switch nginx to TLS |
| `.env` / `.env.example` | DuckDNS + Let’s Encrypt email (not committed) |
| `homeassistant/configuration.yaml` | Core HA + reverse-proxy trust + MQTT sensor include |
| `homeassistant/secrets.yaml` | **Local only** — `ha_external_url` and any future secrets |
| `homeassistant/mqtt_sensors.yaml` | LoRaWAN MQTT sensors (ChirpStack JSON topics) |
| `nginx/conf.d/default-http.conf` | HTTP-only template used **before** a cert exists |
| `nginx/default-ssl.conf.template` | TLS + proxy template (**not** in `conf.d/` — nginx loads every `*.conf` there) |
| `nginx/conf.d/default.conf` | **Active** site config (HTTP-only first; replaced by `setup_ssl.sh` after issuance) |
| `certbot/` | ACME webroot + issued certs (gitignored after use) |

---

## Prerequisites

- Ubuntu 22.04+ or Debian 12+ with Docker and Compose plugin  
- **ChirpStack stack already running** on the same machine if you want LoRaWAN MQTT  
- Firewall: **80**, **443**, and (for gateways / MQTT from LAN) whatever you already expose for ChirpStack (**1883**, **1700/udp**, etc.)

---

## Setup (order matters)

### 1. Environment and secrets

```bash
cd home-assistant
cp .env.example .env
# Edit .env: DUCKDNS_SUBDOMAIN, DUCKDNS_TOKEN, LE_EMAIL

cp homeassistant/secrets.yaml.example homeassistant/secrets.yaml
# Edit secrets.yaml: set ha_external_url to https://<YOUR_SUBDOMAIN>.duckdns.org
```

Use the **same** DuckDNS subdomain in `.env` and in `ha_external_url`.

If you upgrade from an older tree that set `external_url` directly in `configuration.yaml`, remove that line and set **`ha_external_url`** in `secrets.yaml` instead (Home Assistant requires the secret to exist before start).

### 2. Start the stack (HTTP / ACME path first)

```bash
docker compose up -d
```

### 3. Issue TLS and switch nginx to HTTPS

Port **80** must reach this host from the internet for Let’s Encrypt.

```bash
chmod +x setup_ssl.sh
./setup_ssl.sh
```

The script copies `default-http.conf` → `conf.d/default.conf` before requesting a cert (so a broken SSL-only config cannot block port 80), runs Certbot with **`--keep-until-expiring`** (re-running is safe: an already-valid cert is kept and the script still reapplies the TLS nginx config), then renders `nginx/default-ssl.conf.template` into `conf.d/default.conf` with your subdomain.

### 4. Open Home Assistant

In the browser: **`https://<YOUR_SUBDOMAIN>.duckdns.org`** and complete onboarding.

### 5. MQTT (Home Assistant 2024+)

The MQTT **broker** is not configured in YAML.

1. **Settings → Devices & services → Add integration → MQTT**  
2. Broker: **`host.docker.internal`**  
3. Port: **`1883`**  
4. Leave username/password empty (matches the stock ChirpStack Mosquitto config in this repo).

Then **Developer tools → YAML → MQTT** (reload MQTT), or restart Home Assistant.

LoRaWAN entities are defined in `homeassistant/mqtt_sensors.yaml` (ChirpStack JSON integration, topic pattern `application/+/device/+/event/up`). Adjust `value_template` fields to match your device **codec** `object` payload.

In ChirpStack, enable the **MQTT integration** for each application that should forward uplinks to Mosquitto.

---

## ChirpStack and custom MQTT devices

- **ChirpStack**: same broker as HA; uplinks use the application/device topic tree above.  
- **Custom ESP8266 / other publishers**: same broker; either [MQTT Discovery](https://www.home-assistant.io/integrations/mqtt/#mqtt-discovery) from the device or [manual MQTT entities](https://www.home-assistant.io/integrations/sensor.mqtt/) / UI. Use a separate topic prefix from `application/...` unless you intentionally share the tree.

---

## SSL troubleshooting

| Symptom | What to check |
|---------|----------------|
| Let’s Encrypt **timeout** / “firewall” | `docker ps`: if **`ha_nginx`** is **Restarting**, nothing listens on **80**. `docker logs ha_nginx`. Do **not** put `default-ssl.conf.template` inside `conf.d/` as a `*.conf` file. Re-run `./setup_ssl.sh`. |
| **000** / curl fails on `http://<domain>/.well-known/...` | DNS must point to this VPS; port 80 open; nginx **Up**. |

---

## TLS / Let’s Encrypt certificates

Certificates and renewal metadata live under **`certbot/conf/`** on the host (mounted as `/etc/letsencrypt` in the Certbot and nginx containers). Port **80** must stay reachable from the internet for HTTP-01 renewals.

### Automatic renewal (default)

The **`certbot`** service in `docker-compose.yml` runs **`certbot renew`** on a schedule while the stack is up. Your TLS nginx config already serves **`/.well-known/acme-challenge/`** on port **80**, which renewals rely on.

After a successful renewal, **reload nginx** so it picks up new files on disk (the long-running `nginx` process may keep the old cert open until reload):

```bash
cd home-assistant
docker compose exec nginx nginx -s reload
# or: docker compose restart nginx
```

### Renew manually (no new key unless Let’s Encrypt says so)

Use this if you want to trigger renewal now (e.g. before expiry) without changing the setup script:

```bash
cd home-assistant
docker compose run --rm --entrypoint certbot certbot renew --webroot -w /var/www/certbot
docker compose exec nginx nginx -s reload
```

`renew` only requests a new certificate when Let’s Encrypt considers the existing one due for renewal (typically within **30 days** of expiry).

### Regenerate / force a new certificate (same hostname)

Use when you explicitly need a **new** certificate before normal renewal (e.g. after a key compromise, or debugging TLS). This counts against [Let’s Encrypt rate limits](https://letsencrypt.org/docs/rate-limits/) (e.g. **5 duplicate certificates per hostname per week** — avoid repeated `--force-renewal` in a loop).

1. Ensure nginx still serves HTTP-01 on **80** (normal post-`setup_ssl.sh` config is fine).
2. From `home-assistant/`, run (reads `DUCKDNS_SUBDOMAIN` and `LE_EMAIL` from `.env`):

```bash
cd home-assistant
SUBDOMAIN=$(grep ^DUCKDNS_SUBDOMAIN= .env | cut -d= -f2- | sed 's/#.*//;s/^[[:space:]]*//;s/[[:space:]]*$//')
EMAIL=$(grep ^LE_EMAIL= .env | cut -d= -f2- | sed 's/#.*//;s/^[[:space:]]*//;s/[[:space:]]*$//')
docker compose run --rm --entrypoint certbot certbot certonly \
  --webroot -w /var/www/certbot \
  -d "${SUBDOMAIN}.duckdns.org" \
  --email "$EMAIL" \
  --agree-tos --non-interactive \
  --force-renewal

docker compose exec nginx nginx -s reload
```

Alternatively, **`./setup_ssl.sh`** reapplies nginx and uses **`--keep-until-expiring`**, so it **does not** force a new cert by itself; use the **`certonly … --force-renewal`** flow above when you truly need regeneration.

### Full redo (delete cert and run first-time flow again)

Only if you want to discard the current line and start like a fresh install (e.g. wrong domain, corrupted `certbot/conf`):

1. Stop the stack (optional but safer): `docker compose down`
2. Remove the Let’s Encrypt data for this project, e.g. delete the contents of **`certbot/conf/`** (and keep **`certbot/www/`** if you like). **This revokes local files only** — it does not revoke the cert at Let’s Encrypt’s side; use [Certbot revoke](https://eff-certbot.readthedocs.io/en/stable/using.html#revoking-certificates) if you must revoke.
3. Start again: `docker compose up -d`, then **`./setup_ssl.sh`** to obtain a new certificate and rewrite nginx TLS config.

---

## Operations

- **Restarting** `docker compose restart` or `down`/`up` does **not** remove TLS: certs live under `certbot/conf/` on the host.  
- **Logs**: `docker logs homeassistant -f` / `docker logs ha_nginx -f` / `docker logs ha_certbot`  
- **Listen to LoRaWAN MQTT** (on the VPS, if `mosquitto-clients` is installed):  
  `mosquitto_sub -h 127.0.0.1 -p 1883 -t 'application/#' -v`  
  Or `docker exec` into your ChirpStack **mosquitto** container and run `mosquitto_sub` there.

---

## Companion app

Use **`https://<YOUR_SUBDOMAIN>.duckdns.org`** (port **443**). That must match `ha_external_url` in `secrets.yaml` and the MQTT integration as above.
