# Uptime Kuma Automated Deployment

Automated installation script for [Uptime Kuma](https://github.com/louislam/uptime-kuma), the self-hosted monitoring tool.
This automatically configures the Docker container, Nginx reverse proxy, and Let's Encrypt SSL.

## Installation

### Non-Interactive (Automated)
```bash
KUMA_DOMAIN="uptime.siyalude.io" \
KUMA_PORT="3001" \
SETUP_NGINX=true SETUP_SSL=true ADMIN_EMAIL="admin@siyalude.io" \
sudo bash setup-uptime-kuma.sh --no-interaction
```

### Interactive
```bash
sudo bash setup-uptime-kuma.sh
```

## First Login
Unlike other systems, Uptime Kuma does **not** have a default admin credential. The first person to visit the website creates the root admin user. Be sure to navigate to your domain immediately after installation to secure it.
