#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
args=(docker compose --project-name smart_home)
[[ -f "$root/chirpstack-docker/.env" ]] && args+=(--env-file "$root/chirpstack-docker/.env")
[[ -f "$root/home-assistant/.env" ]] && args+=(--env-file "$root/home-assistant/.env")
exec "${args[@]}" -f "$root/docker-compose.yml" up -d
