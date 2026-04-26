#!/bin/bash

# ─────────────────────────────────────────────────────────────────
#  Automated SSL Setup for Home Assistant (HTTP-01 Method)
# ─────────────────────────────────────────────────────────────────

set -e

# 1. Load context
if [ ! -f .env ]; then
    echo "[ERROR] .env not found. Run: cp .env.example .env and fill it."
    exit 1
fi

# Function to extract variables safely
get_env_var() {
    grep "^$1=" .env | cut -d '=' -f2- | sed 's/[[:space:]]*#.*$//' | xargs
}

EMAIL=$(get_env_var LE_EMAIL)
SUBDOMAIN=$(get_env_var DUCKDNS_SUBDOMAIN)
DOMAIN="${SUBDOMAIN}.duckdns.org"

if [ -z "$EMAIL" ] || [ -z "$SUBDOMAIN" ]; then
    echo "[ERROR] LE_EMAIL or DUCKDNS_SUBDOMAIN missing in .env"
    exit 1
fi

# Detect docker compose vs docker-compose
if docker compose version >/dev/null 2>&1; then
    DOCKER_CMD="docker compose"
elif docker-compose version >/dev/null 2>&1; then
    DOCKER_CMD="docker-compose"
else
    echo "[ERROR] Neither 'docker compose' nor 'docker-compose' found."
    exit 1
fi

echo "[ssl] Starting for $DOMAIN (email: $EMAIL)"

# 2. Pre-flight checks
echo "[ssl] Preparing ACME webroot..."
mkdir -p certbot/www/.well-known/acme-challenge
echo "test" > certbot/www/.well-known/acme-challenge/test.txt

# Nginx must serve HTTP-01 only until certs exist. If default.conf was
# replaced by an SSL config with missing certs (or unreplaced YOUR_SUBDOMAIN),
# nginx crash-loops and Let's Encrypt sees a timeout — not a firewall issue.
if [ ! -f nginx/conf.d/default-http.conf ]; then
    echo "[ERROR] nginx/conf.d/default-http.conf missing."
    exit 1
fi
echo "[ssl] Resetting nginx/conf.d/default.conf from default-http.conf"
cp nginx/conf.d/default-http.conf nginx/conf.d/default.conf

# 3. Start initial HTTP stack
echo "[ssl] Starting nginx, certbot, duckdns..."
$DOCKER_CMD up -d nginx certbot duckdns

echo "[ssl] Waiting 15s for nginx/DNS..."
sleep 15

# 4. Diagnostic check
echo "[ssl] Checking HTTP access to ACME test file..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$DOMAIN/.well-known/acme-challenge/test.txt" || echo "failed")

if [ "$HTTP_CODE" != "200" ]; then
    echo "[WARN] Expected HTTP 200 from ACME test URL; got: $HTTP_CODE (continuing)"
else
    echo "[OK] Port 80 reachable for ACME path"
fi

# 5. Obtain certificate (--keep-until-expiring: re-run is OK if cert already valid)
echo "[ssl] Requesting Let's Encrypt certificate (if needed)..."
$DOCKER_CMD run --rm --entrypoint certbot certbot certonly \
    --webroot -w /var/www/certbot \
    -d "$DOMAIN" \
    --email "$EMAIL" \
    --agree-tos \
    --non-interactive \
    --keep-until-expiring

# 6. Swap to SSL config (template outside conf.d — nginx only loads *.conf there)
echo "[ssl] Writing TLS nginx config from template..."
if [ ! -f nginx/default-ssl.conf.template ]; then
    echo "[ERROR] nginx/default-ssl.conf.template not found."
    exit 1
fi

sed "s/YOUR_SUBDOMAIN/$SUBDOMAIN/g" nginx/default-ssl.conf.template > nginx/conf.d/default.conf

# 7. Restart with full stack
echo "[ssl] Applying stack and restarting nginx..."
$DOCKER_CMD up -d
$DOCKER_CMD restart nginx

echo "[OK] HTTPS: https://$DOMAIN"
