#!/usr/bin/env bash

# Automated SSL + nginx TLS config from default-ssl.conf.template (merged Compose).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$SCRIPT_DIR"

compose() {
  (
    cd "$ROOT_DIR"
    local cmd=(docker compose --project-name smart_home)
    [[ -f chirpstack-docker/.env ]] && cmd+=(--env-file chirpstack-docker/.env)
    [[ -f home-assistant/.env ]] && cmd+=(--env-file home-assistant/.env)
    cmd+=(-f docker-compose.yml)
    "${cmd[@]}" "$@"
  )
}

get_env_var() {
  grep "^$1=" .env | cut -d '=' -f2- | sed 's/[[:space:]]*#.*$//' | xargs
}

apply_tls_template() {
  EMAIL=$(get_env_var LE_EMAIL)
  SUBDOMAIN=$(get_env_var DUCKDNS_SUBDOMAIN)
  DOMAIN="${SUBDOMAIN}.duckdns.org"

  if [ -z "$SUBDOMAIN" ]; then
    echo "[ERROR] DUCKDNS_SUBDOMAIN missing in .env"
    exit 1
  fi

  if [ ! -f nginx/default-ssl.conf.template ]; then
    echo "[ERROR] nginx/default-ssl.conf.template not found."
    exit 1
  fi

  local cert_dir="$SCRIPT_DIR/certbot/conf/live/$DOMAIN"
  if [ ! -d "$cert_dir" ]; then
    echo "[ERROR] No certs at $cert_dir — run full setup_ssl.sh without --apply-template first."
    exit 1
  fi

  sed "s/YOUR_SUBDOMAIN/$SUBDOMAIN/g" nginx/default-ssl.conf.template > nginx/conf.d/default.conf
  echo "[ssl] Wrote TLS config for $DOMAIN → nginx/conf.d/default.conf"
  compose restart nginx
  echo "[OK] nginx reloaded with updated template."
}

if [ "${1:-}" = "--apply-template" ]; then
  if [ ! -f .env ]; then
    echo "[ERROR] .env not found."
    exit 1
  fi
  apply_tls_template
  exit 0
fi

# ─── Full Let's Encrypt flow ─────────────────────────────────────

if [ ! -f .env ]; then
  echo "[ERROR] .env not found. Run: cp .env.example .env and fill it."
  exit 1
fi

EMAIL=$(get_env_var LE_EMAIL)
SUBDOMAIN=$(get_env_var DUCKDNS_SUBDOMAIN)
DOMAIN="${SUBDOMAIN}.duckdns.org"

if [ -z "$EMAIL" ] || [ -z "$SUBDOMAIN" ]; then
  echo "[ERROR] LE_EMAIL or DUCKDNS_SUBDOMAIN missing in .env"
  exit 1
fi

echo "[ssl] Starting for $DOMAIN (email: $EMAIL)"

echo "[ssl] Preparing ACME webroot..."
mkdir -p certbot/www/.well-known/acme-challenge
echo "test" > certbot/www/.well-known/acme-challenge/test.txt

if [ ! -f nginx/conf.d/default-http.conf ]; then
  echo "[ERROR] nginx/conf.d/default-http.conf missing."
  exit 1
fi
echo "[ssl] Resetting nginx/conf.d/default.conf from default-http.conf"
cp nginx/conf.d/default-http.conf nginx/conf.d/default.conf

echo "[ssl] Starting nginx, certbot, duckdns (merged stack project smart_home)..."
compose up -d nginx certbot duckdns

echo "[ssl] Waiting 15s for nginx/DNS..."
sleep 15

echo "[ssl] Checking HTTP access to ACME test file..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$DOMAIN/.well-known/acme-challenge/test.txt" || echo "failed")

if [ "$HTTP_CODE" != "200" ]; then
  echo "[WARN] Expected HTTP 200 from ACME test URL; got: $HTTP_CODE (continuing)"
else
  echo "[OK] Port 80 reachable for ACME path"
fi

echo "[ssl] Requesting Let's Encrypt certificate (if needed)..."
compose run --rm --entrypoint certbot certbot certonly \
  --webroot -w /var/www/certbot \
  -d "$DOMAIN" \
  --email "$EMAIL" \
  --agree-tos \
  --non-interactive \
  --keep-until-expiring

sed "s/YOUR_SUBDOMAIN/$SUBDOMAIN/g" nginx/default-ssl.conf.template > nginx/conf.d/default.conf

echo "[ssl] Applying full merged stack and restarting nginx..."
compose up -d
compose restart nginx

echo "[OK] HTTPS: https://$DOMAIN"
