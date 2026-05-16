# Nextcloud Deployment Setup

This directory contains the automated setup script for deploying Nextcloud via Docker on Ubuntu. 

## Requirements
- Ubuntu 22.04 or 24.04
- Root access (`sudo`)
- Ports `80` and `443` available for Nginx (if using the built-in Nginx proxy)
- Port `8888` available for Nextcloud's internal app container
- Domain name pointing to the server's IP address (e.g. `cloud.ravact.com`)

## Installation

You can run the script in two ways:

### 1. Interactive Mode
Run the script without any arguments and it will prompt you for configuration details:

```bash
sudo ./setup-nextcloud.sh
```

### 2. Non-Interactive Mode (Automated)
Run the script with the `--no-interaction` flag. It will use the default variables or ones you supply via environment variables.

```bash
sudo NEXTCLOUD_DOMAIN=cloud.ravact.com \
     SETUP_NGINX=true \
     SETUP_SSL=true \
     ADMIN_EMAIL=admin@ravact.com \
     ./setup-nextcloud.sh --no-interaction
```

## What it does
1. Installs Docker, Docker Compose, Nginx, and Certbot.
2. Creates the `/opt/nextcloud` directory with data folders for Postgres, Redis, and Nextcloud.
3. Generates a `.env` file and a `docker-compose.yml` file.
4. Starts the PostgreSQL, Redis, and Nextcloud containers.
5. Configures Nginx as a reverse proxy.
6. Requests an SSL certificate from Let's Encrypt.
7. Saves database credentials to `/opt/nextcloud/credentials.txt`.

## Maintenance

To check the logs:
```bash
cd /opt/nextcloud
docker compose logs -f
```

To update Nextcloud (pulling the latest images):
```bash
cd /opt/nextcloud
docker compose pull
docker compose up -d
```

## Troubleshooting

### Desktop App HTTPS Error
If you see the error: *"The returned server URL does not start with HTTPS despite the login URL started with HTTPS"*, it means the reverse proxy configuration needs to be explicitly set in Nextcloud.

The setup script now handles this automatically via environment variables in `docker-compose.yml`:
- `OVERWRITEPROTOCOL=https`
- `OVERWRITEHOST=your-domain.com`
- `OVERWRITECLIURL=https://your-domain.com`
- `TRUSTED_PROXIES=127.0.0.1`

If you need to fix an existing installation manually, run:
```bash
docker exec --user www-data nextcloud-app php occ config:system:set overwriteprotocol --value="https"
docker exec --user www-data nextcloud-app php occ config:system:set overwritehost --value="your-domain.com"
docker exec --user www-data nextcloud-app php occ config:system:set overwrite.cli.url --value="https://your-domain.com"
```
