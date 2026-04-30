# Home Assistant (VPS + nginx + Let’s Encrypt)

Dockerized Home Assistant behind **nginx** on **443**. Certificates come from **Let’s Encrypt** (HTTP-01). When deployed with the repo root [`start.sh`](../start.sh) (merged Compose + **`iot`** network), [ChirpStack](../chirpstack-docker/) **Mosquitto** is reachable at **`mosquitto:1883`** from the HA container.

---

## URLs (replace `<subdomain>` with your DuckDNS name)

| What | URL |
|------|-----|
| **Home Assistant** | `https://<subdomain>.duckdns.org/` |
| **ChirpStack UI** | `https://<subdomain>.duckdns.org/chirpstack/` |

ChirpStack runs in the merged stack; nginx proxies `/chirpstack/` to `http://chirpstack:8080` on the **`iot`** network.

---

## DuckDNS (short)

1. Sign in at [duckdns.org](https://www.duckdns.org), create a **subdomain**, copy the **token**.
2. Ensure the hostname resolves to this VPS (DuckDNS dashboard sets the **A** record for `*.duckdns.org`).
3. Put **`DUCKDNS_SUBDOMAIN`** (name only, no `.duckdns.org`), **`DUCKDNS_TOKEN`**, and **`LE_EMAIL`** in `.env` (see `.env.example`).

---

## First run (certs and HTTPS)

**Requirements:** Docker + Compose; ports **80** and **443** open to the internet (80 is required for Let’s Encrypt).

Prepare env files for **both** stacks (ChirpStack credentials in [`chirpstack-docker/.env`](../chirpstack-docker/.env.example), DuckDNS in `home-assistant/.env`). Then start the **merged** project from the repo root so HA, nginx, Mosquitto, and ChirpStack share the **`iot`** network:

```bash
cd home-assistant
cp .env.example .env
# Fill DUCKDNS_SUBDOMAIN, DUCKDNS_TOKEN, LE_EMAIL

cp homeassistant/secrets.yaml.example homeassistant/secrets.yaml
# Set ha_external_url: https://<subdomain>.duckdns.org  (same subdomain as .env)
```

```bash
# From repository root:
./start.sh

cd home-assistant
chmod +x setup_ssl.sh
./setup_ssl.sh
```

`setup_ssl.sh` uses the **merged** compose project (`smart_home`, same as [`../start.sh`](../start.sh)), installs an HTTP-only nginx config first, obtains the cert, then writes TLS from `nginx/default-ssl.conf.template` to **`nginx/conf.d/default.conf`** (that file is **not** in git so `git pull` never overwrites your live TLS config).

Re-running the full script is safe (`--keep-until-expiring`).

**After `git pull`** (certs already on disk): from `home-assistant/` run **`./setup_ssl.sh --apply-template`** to re-render `default.conf` from the updated template and reload nginx (no new Let’s Encrypt call).

Open **`https://<subdomain>.duckdns.org/`** and finish HA onboarding.

**Note:** `ha_external_url` must live in `secrets.yaml` (not hardcoded `external_url` in old trees).

---

## MQTT (Home Assistant 2024+)

Broker is configured in the UI, not YAML.

1. **Settings → Devices & services → Add integration → MQTT**
2. Broker: **`mosquitto`** (hostname on Docker network **`iot`**), port **`1883`**
3. User/password: e.g. **`mqtt_admin`** from Mosquitto — see [chirpstack-docker README](../chirpstack-docker/README.md) for creating `passwd`.

Reload MQTT or restart HA. LoRaWAN sensors live in `homeassistant/mqtt_sensors.yaml`; enable ChirpStack’s MQTT integration per application.

---

## Firewall and prerequisites

- **80** / **443** for this stack. Gateways and MQTT: see [chirpstack-docker README](../chirpstack-docker/README.md) (**1883**, **1700/udp**, etc.).

---

## Let’s Encrypt maintenance

- Certs and renewal state: **`certbot/conf/`** on the host. **Port 80** must stay reachable for HTTP-01 renewals.
- The **`certbot`** service runs `certbot renew` on a schedule. After a renewal, reload nginx:

```bash
docker exec ha_nginx nginx -s reload
```

- To renew on demand (from the **repository root**, same compose project as [`start.sh`](../start.sh)):  
  `docker compose --project-name smart_home --env-file chirpstack-docker/.env --env-file home-assistant/.env -f docker-compose.yml run --rm --entrypoint certbot certbot renew --webroot -w /var/www/certbot`  
  then `docker exec ha_nginx nginx -s reload` again.
- **Redo from scratch** (wrong domain, broken `certbot/conf`): stop stack (`./stop.sh` from repo root), clear `certbot/conf/`, `./start.sh`, run `home-assistant/setup_ssl.sh` again. For forced re-issue before normal renewal, see [Let’s Encrypt rate limits](https://letsencrypt.org/docs/rate-limits/) before using `--force-renewal`.

---

## If HTTPS issuance fails

| Symptom | Check |
|---------|--------|
| Let’s Encrypt **timeout** | `docker ps`: **`ha_nginx`** stuck **Restarting** → nothing on **80**. `docker logs ha_nginx`. Do not put `default-ssl.conf.template` in `conf.d/` as a live `*.conf`. Re-run `./setup_ssl.sh`. |
| **HTTP** / ACME path fails | DNS points to this VPS; **80** open; nginx **Up**. |
| **`/chirpstack/` → 404** or empty UI | Ensure **`./start.sh`** is used (shared **`iot`** network). Re-render TLS: `cd home-assistant && ./setup_ssl.sh --apply-template` (or full **`./setup_ssl.sh`** if you have no certs yet). In `default.conf` you should see ChirpStack `location` blocks and **`proxy_pass` via `$chirp_upstream` → `chirpstack:8080`. |

---

## Useful commands

- Logs: `docker logs homeassistant -f`, `docker logs ha_nginx -f`
- Restarts do **not** delete certs (they stay under `certbot/conf/`).

**Companion app:** same URL as **`https://<subdomain>.duckdns.org`** (443); must match `ha_external_url`.
