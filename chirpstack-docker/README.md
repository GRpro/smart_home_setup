# ChirpStack Docker example

This repository contains a skeleton to setup the [ChirpStack](https://www.chirpstack.io)
open-source LoRaWAN Network Server (v4) using [Docker Compose](https://docs.docker.com/compose/).

**Note:** Please use this `docker-compose.yml` file as a starting point for testing
but keep in mind that for production usage it might need modifications. 

## Directory layout

* `docker-compose.yml`: the docker-compose file containing the services
* `configuration/chirpstack`: directory containing the ChirpStack configuration files
* `configuration/chirpstack-gateway-bridge`: directory containing the ChirpStack Gateway Bridge configuration
* `configuration/mosquitto`: directory containing the Mosquitto (MQTT broker) configuration
* `configuration/postgresql/initdb/`: directory containing PostgreSQL initialization scripts

## Configuration

This setup is pre-configured for all regions. You can either connect a ChirpStack Gateway Bridge
instance (v3.14.0+) to the MQTT broker (port 1883) or connect a Semtech UDP Packet Forwarder.
Please note that:

* You must prefix the MQTT topic with the region
  Please see the region configuration files in the `configuration/chirpstack` for a list
  of topic prefixes (e.g. eu868, us915_0, au915, as923_2, ...).
* Gateway Bridge marshaler is configured in `configuration/chirpstack-gateway-bridge/chirpstack-gateway-bridge.toml`.
* Mosquitto exposes MQTT over TCP (`1883`) and WebSockets (`9001`).

This setup also comes with a ChirpStack Gateway Bridge instance which is configured to the
eu868 topic prefix. You can connect your UDP packet-forwarder based gateway to port 1700.

# Data persistence

PostgreSQL and Redis data is persisted in Docker volumes, see the `docker-compose.yml`
`volumes` definition.

## Requirements

Before using this `docker-compose.yml` file, make sure you have [Docker](https://www.docker.com/community-edition)
installed.

## Importing device repository

To import the [lorawan-devices](https://github.com/TheThingsNetwork/lorawan-devices)
repository (optional step), run the following command:

```bash
make import-lorawan-devices
```

This will clone the `lorawan-devices` repository and execute the import command of ChirpStack.
Please note that for this step you need to have the `make` command installed.

**Note:** an older snapshot of the `lorawan-devices` repository is cloned as the
latest revision no longer contains a `LICENSE` file.

## Usage

To start the ChirpStack simply run:

```bash
$ docker-compose up
```

### Configure MQTT (before start)

Anonymous MQTT is off (`configuration/mosquitto/mosquitto.conf`). Create **`passwd` first**, then align **`.env`** with the password you chose for **`chirpstack_devices`**. Compose passes those values into the NS and Gateway Bridge (see below).

**1. Create three broker users** (`configuration/mosquitto/acl`):

| User | Used by |
|------|---------|
| `chirpstack_devices` | ChirpStack NS (integration + per-region gateway MQTT in `region_*.toml`), Gateway Bridge |
| `external_devices` | Gateways / devices on the public internet |
| `mqtt_admin` | Home Assistant MQTT, MQTTX Web, CLI debugging |

```bash
docker run --rm -it \
  -v "$(pwd)/configuration/mosquitto:/mosquitto/config" \
  eclipse-mosquitto:2 \
  sh -lc '
    mosquitto_passwd -c /mosquitto/config/passwd chirpstack_devices &&
    mosquitto_passwd /mosquitto/config/passwd external_devices &&
    mosquitto_passwd /mosquitto/config/passwd mqtt_admin
  '
```

**2. Copy passwords into `.env`** — only these variables are read by Compose (`docker-compose.yml`):

```bash
cp .env.example .env
```

Set `MQTT_CHIRPSTACK_PASSWORD` (and username if you changed it) to **exactly** the password you entered for **`chirpstack_devices`** in step 1.  
Configure **`external_devices`** and **`mqtt_admin`** on your gateways / Home Assistant / MQTTX manually — they are **not** in `.env`.

**3. Start the stack**

```bash
docker-compose up -d
```

**4. Quick check**

```bash
# anonymous → should fail
mosquitto_sub -h 127.0.0.1 -p 1883 -t 'application/#' -C 1

# mqtt_admin → should work
mosquitto_sub -h 127.0.0.1 -p 1883 -u mqtt_admin -P '<mqtt_admin_password>' -t 'application/#' -C 1
```

Optional: restrict **`1883/tcp`** in your cloud firewall to known gateway IPs.

#### How credentials are wired (important)

- **ChirpStack Network Server** — `[integration.mqtt]` in `configuration/chirpstack/chirpstack.toml` uses `$MQTT_BROKER_USERNAME` / `$MQTT_BROKER_PASSWORD`. Compose sets those from **`MQTT_CHIRPSTACK_*`** in `.env`.
- **Per-region gateway MQTT** — each `configuration/chirpstack/region_*.toml` has `[regions.gateway.backend.mqtt]` with the same **`$MQTT_BROKER_USERNAME`** / **`$MQTT_BROKER_PASSWORD`**. With `allow_anonymous false`, empty credentials here cause NS crash loops (**CONNACK not authorized**). Do not strip these lines when editing regions.
- **ChirpStack Gateway Bridge** — the bridge **does not** expand `$VAR` inside its TOML (unlike the NS). User/password are supplied only via compose env: **`INTEGRATION__MQTT__AUTH__GENERIC__USERNAME`** and **`INTEGRATION__MQTT__AUTH__GENERIC__PASSWORD`** (Viper style: config path dots → double underscores). See `docker-compose.yml` service `chirpstack-gateway-bridge-eu868`.

#### Troubleshooting

- **`mosquitto` fails to start**, `bind: address already in use` on **1883**: another MQTT broker on the host is using the port (common: **`snap` Mosquitto**). Stop or disable it (`snap stop mosquitto`) or change this compose file’s **host** port mapping for Mosquitto.
- **Gateway Bridge logs** `not Authorized` / **NS logs** `CONNACK return code` on gateway backend: wrong or missing MQTT user/password for that component (bridge env vars vs. `$MQTT_BROKER_*` in NS/region files vs. `passwd` / `.env`).

After all the components have been initialized and started, you should be able
to open http://localhost:8080/ in your browser.

##

The example includes the [ChirpStack REST API](https://github.com/chirpstack/chirpstack-rest-api).
You should be able to access the UI by opening http://localhost:8090 in your browser.

**Note:** It is recommended to use the [gRPC](https://www.chirpstack.io/docs/chirpstack/api/grpc.html)
interface over the [REST](https://www.chirpstack.io/docs/chirpstack/api/rest.html) interface.

## MQTT topic browser (web)

This stack includes `mqttx-web` (web MQTT client) on:

- `http://<host>:8081`

Connection settings in MQTTX Web:

- Host: `<host>`
- Port: `9001`
- Protocol: `ws://` (WebSocket, non-TLS)
- Username / password: use `mqtt_admin` credentials from `passwd`

You can subscribe to:

- `application/#` (device events from ChirpStack integration)
- `+/gateway/#` (gateway bridge topics across region prefixes)
