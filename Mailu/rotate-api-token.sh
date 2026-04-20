#!/bin/bash
# ---------------------------------------------------------
# Mailu API Token Rotation Script
# ---------------------------------------------------------

# 1. Configuration
MAILU_DIR="/opt/mailu"

# 2. Generate new secure 32-Char Token (Hex)
NEW_TOKEN=$(openssl rand -hex 16 | tr '[:lower:]' '[:upper:]')

echo "🔄 Rotating Mailu API Token..."

# 3. Update .env file
# This finds API_TOKEN=... and replaces it with the new token
if grep -q "API_TOKEN=" "$MAILU_DIR/.env"; then
    sed -i "s/API_TOKEN=.*/API_TOKEN=$NEW_TOKEN/" "$MAILU_DIR/.env"
else
    echo "API_TOKEN=$NEW_TOKEN" >> "$MAILU_DIR/.env"
fi

# 4. Restart the admin container to apply changes
echo "♻️ Restarting admin service..."
cd "$MAILU_DIR" && docker compose up -d admin

echo "---------------------------------------------------"
echo "✅ SUCCESS: API Token has been rotated."
echo "🔑 New Token: $NEW_TOKEN"
echo "🌐 API UI: https://$(grep HOSTNAMES $MAILU_DIR/.env | cut -d= -f2)/api"
echo "---------------------------------------------------"
echo "Don't forget to update your Apidog environment!"
