#!/bin/bash

# ─────────────────────────────────────────────────────────────────
#  Automated SSL Setup for Home Assistant (DNS-01 Method)
# ─────────────────────────────────────────────────────────────────

set -e

# 1. Load context
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found. Please run 'cp .env.example .env' and fill it first."
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
    echo "❌ Error: Could not find LE_EMAIL or DUCKDNS_SUBDOMAIN in .env"
    exit 1
fi

# Detect docker compose vs docker-compose
if docker compose version >/dev/null 2>&1; then
    DOCKER_CMD="docker compose"
elif docker-compose version >/dev/null 2>&1; then
    DOCKER_CMD="docker-compose"
else
    echo "❌ Error: Neither 'docker compose' nor 'docker-compose' found."
    exit 1
fi

echo "🚀 Starting SSL setup (DNS-01 challenge) for $DOMAIN..."

# 2. Obtain certificate via DNS-01 (No Port 80 needed!)
echo "🔐 Requesting certificate from Let's Encrypt via DuckDNS API..."
# Note: infinityofzero/certbot-dns-duckdns image uses DUCKDNS_TOKEN env var automatically
$DOCKER_CMD run --rm --entrypoint certbot certbot certonly \
    --authenticator dns-duckdns \
    --dns-duckdns-propagation-seconds 120 \
    -d "$DOMAIN" \
    --email "$EMAIL" \
    --agree-tos \
    --non-interactive

# 3. Swap to SSL config
echo "📝 Swapping NGINX configuration to SSL version..."
if [ ! -f nginx/conf.d/default-ssl.conf ]; then
    echo "❌ Error: nginx/conf.d/default-ssl.conf not found."
    exit 1
fi

# Replace YOUR_SUBDOMAIN in the template
sed "s/YOUR_SUBDOMAIN/$SUBDOMAIN/g" nginx/conf.d/default-ssl.conf > nginx/conf.d/default.conf

# 4. Start the full stack
echo "🔄 Starting Home Assistant stack in SSL mode..."
$DOCKER_CMD up -d
$DOCKER_CMD restart nginx

echo "✅ Success! Your stack is now running at https://$DOMAIN"
echo "   (DNS verification can take a minute, please wait if it's not up instantly)"
