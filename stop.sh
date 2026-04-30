#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
args=(docker compose --project-name smart_home)
[[ -f "$root/chirpstack-docker/.env" ]] && args+=(--env-file "$root/chirpstack-docker/.env")
[[ -f "$root/home-assistant/.env" ]] && args+=(--env-file "$root/home-assistant/.env")
exec "${args[@]}" -f "$root/chirpstack-docker/docker-compose.yml" -f "$root/home-assistant/docker-compose.yml" stop
