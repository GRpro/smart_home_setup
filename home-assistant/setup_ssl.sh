#!/bin/bash

# ─────────────────────────────────────────────────────────────────
#  Automated SSL Setup for Home Assistant (NGINX + Certbot)
# ─────────────────────────────────────────────────────────────────

set -e

# 1. Load context
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found. Please run 'cp .env.example .env' and fill it first."
    exit 1
fi

# Function to extract variables safely (strips comments and whitespace)
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

echo "🚀 Starting SSL setup for $DOMAIN (Email: $EMAIL)..."

# 2. Start initial HTTP stack
echo "👉 Starting NGINX in HTTP-only mode..."
$DOCKER_CMD up -d nginx certbot duckdns

echo "⏳ Waiting for NGINX to wake up..."
sleep 5

# 3. Obtain certificate
echo "🔐 Requesting certificate from Let's Encrypt..."
$DOCKER_CMD run --rm certbot certonly \
    --webroot -w /var/www/certbot \
    -d "$DOMAIN" \
    --email "$EMAIL" \
    --agree-tos \
    --non-interactive

# 4. Swap to SSL config
echo "📝 Swapping NGINX configuration to SSL version..."
if [ ! -f nginx/conf.d/default-ssl.conf ]; then
    echo "❌ Error: nginx/conf.d/default-ssl.conf not found."
    exit 1
fi

# Replace YOUR_SUBDOMAIN in the template
sed "s/YOUR_SUBDOMAIN/$SUBDOMAIN/g" nginx/conf.d/default-ssl.conf > nginx/conf.d/default.conf

# 5. Restart with full stack
echo "🔄 Restarting NGINX in SSL mode..."
$DOCKER_CMD up -d
$DOCKER_CMD restart nginx

echo "✅ Success! Your stack is now running at https://$DOMAIN"
echo "   (It may take a minute for the HA container to finish starting up)"
