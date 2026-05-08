#!/bin/bash

# ==============================================================================
# Komodo v2 Automated Installer for Ubuntu 24.04
# Domain: komodo.ravact.com
# Version: 2.1.2
# ==============================================================================

set -e

# Set colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Configurations
DOMAIN="komodo.ravact.com"
INSTALL_DIR="/opt/komodo"
NGINX_CONF="/etc/nginx/sites-available/komodo.conf"
NGINX_LINK="/etc/nginx/sites-enabled/komodo.conf"

echo -e "${GREEN}Starting Komodo v2 Installation...${NC}"

# 1. Prerequisites Check
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   exit 1
fi

# 2. Install Docker and Docker Compose if missing
if ! [ -x "$(command -v docker)" ]; then
    echo -e "${GREEN}Installing Docker...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
fi

# 3. Create Directories
echo -e "${GREEN}Creating deployment directory at $INSTALL_DIR...${NC}"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# 4. Create .env
echo -e "${GREEN}Generating environment variables...${NC}"
cat > .env <<EOF
# Komodo Core Environment Variables
KOMODO_HOST=https://$DOMAIN
KOMODO_LOCAL_AUTH=true

# Database (MongoDB)
KOMODO_DATABASE_ADDRESS=mongo:27017
KOMODO_DATABASE_USERNAME=komodo_admin
KOMODO_DATABASE_PASSWORD=l1XQEY+rJ5jQOIXM
KOMODO_DATABASE_DB_NAME=komodo

# Core Security
KOMODO_JWT_SECRET=8ae4b5e6951995aa1da752f307bfb75157d87f5751a1396093104af89a578582
KOMODO_WEBHOOK_SECRET=8ae4b5e6951995aa1da752f307bfb75157d87f5751a1396093104af89a578582

# Initial Admin (One-time use)
KOMODO_INIT_ADMIN_USERNAME=admin
KOMODO_INIT_ADMIN_PASSWORD=l1XQEY+rJ5jQOIXM
EOF

# 5. Create docker-compose.yml
echo -e "${GREEN}Creating docker-compose.yml...${NC}"
cat > docker-compose.yml <<EOF
services:
  komodo:
    image: ghcr.io/moghtech/komodo-core:2
    container_name: komodo-core
    restart: always
    ports:
      - "9120:9120"
    volumes:
      - ./data:/app/data
      - ./logs:/app/logs
    env_file:
      - .env
    depends_on:
      - mongo

  mongo:
    image: mongo:5
    container_name: komodo-mongo
    restart: always
    volumes:
      - ./mongo-data:/data/db
    environment:
      - MONGO_INITDB_ROOT_USERNAME=\${KOMODO_DATABASE_USERNAME}
      - MONGO_INITDB_ROOT_PASSWORD=\${KOMODO_DATABASE_PASSWORD}
EOF

# 6. Start the Stack
echo -e "${GREEN}Deploying Komodo Core Docker stack...${NC}"
docker compose up -d

# 7. Install Periphery Agent
echo -e "${GREEN}Installing Periphery Agent...${NC}"
curl -sSL https://raw.githubusercontent.com/moghtech/komodo/main/scripts/setup-periphery.py | python3 -
systemctl enable periphery

# 8. Configure Nginx Reverse Proxy
echo -e "${GREEN}Configuring Nginx reverse proxy...${NC}"
cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:9120;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

ln -sf "$NGINX_CONF" "$NGINX_LINK"
if nginx -t; then
    systemctl reload nginx
    echo -e "${GREEN}Nginx configured and reloaded.${NC}"
else
    echo -e "${RED}Nginx configuration test failed! Please check manually.${NC}"
fi

echo -e "=========================================================="
echo -e "${GREEN}Komodo v2 installation complete!${NC}"
echo -e "Dashboard: https://$DOMAIN"
echo -e "Admin: admin / l1XQEY+rJ5jQOIXM"
echo -e "=========================================================="
echo -e "${GREEN}Recommended: Run 'sudo certbot --nginx -d $DOMAIN' for SSL.${NC}"
echo -e "${GREEN}Final Step: Add your server in the dashboard using https://84.46.255.169:8120${NC}"
