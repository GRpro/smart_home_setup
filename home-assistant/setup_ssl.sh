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

# Extract variables from .env
EMAIL=$(grep LE_EMAIL .env | cut -d '=' -f2)
DOMAIN="$(grep DUCKDNS_SUBDOMAIN .env | cut -d '=' -f2).duckdns.org"

echo "🚀 Starting SSL setup for $DOMAIN (Email: $EMAIL)..."

# 2. Start initial HTTP stack
echo "👉 Starting NGINX in HTTP-only mode..."
docker compose up -d nginx certbot duckdns

echo "⏳ Waiting for NGINX to wake up..."
sleep 5

# 3. Obtain certificate
echo "🔐 Requesting certificate from Let's Encrypt..."
docker compose run --rm certbot certonly \
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

# Replace YOUR_SUBDOMAIN in the template if not already done by user
SUBDOMAIN="$(grep DUCKDNS_SUBDOMAIN .env | cut -d '=' -f2)"
sed "s/YOUR_SUBDOMAIN/$SUBDOMAIN/g" nginx/conf.d/default-ssl.conf > nginx/conf.d/default.conf

# 5. Restart with full stack
echo "🔄 Restarting NGINX in SSL mode..."
docker compose up -d
docker compose restart nginx

echo "✅ Success! Your stack is now running at https://$DOMAIN"
echo "   (It may take a minute for the HA container to finish starting up)"
