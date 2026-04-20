#!/bin/bash
# ---------------------------------------------------------
# Mailu Admin Creation Helper
# ---------------------------------------------------------

cd /opt/mailu

# 1. Input Details
read -p "Enter Admin Email (e.g. admin@yourdomain.com): " EMAIL
if [[ -z "$EMAIL" ]]; then
    echo "Error: Email is required."
    exit 1
fi

USER=$(echo $EMAIL | cut -d@ -f1)
DOMAIN=$(echo $EMAIL | cut -d@ -f2)

# 2. Input Password
read -s -p "Enter Password for $EMAIL: " PASSWORD
echo ""

# 3. Create User
docker compose exec admin flask mailu admin "$USER" "$DOMAIN" "$PASSWORD"

echo "✅ Admin user $EMAIL created successfully!"
