#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHIRPSTACK_DIR="$SCRIPT_DIR/chirpstack-docker"
HOME_ASSISTANT_DIR="$SCRIPT_DIR/home-assistant"

if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD=(docker compose)
elif docker-compose version >/dev/null 2>&1; then
  COMPOSE_CMD=(docker-compose)
else
  echo "[ERROR] Neither 'docker compose' nor 'docker-compose' found."
  exit 1
fi

echo "[start] Starting chirpstack-docker stack..."
"${COMPOSE_CMD[@]}" -f "$CHIRPSTACK_DIR/docker-compose.yml" up -d

echo "[start] Starting home-assistant stack..."
"${COMPOSE_CMD[@]}" -f "$HOME_ASSISTANT_DIR/docker-compose.yml" up -d

echo "[OK] Both stacks are starting."
echo " - Home Assistant: https://<your-domain>/"
echo " - ChirpStack:     https://<your-domain>/chirpstack/"
