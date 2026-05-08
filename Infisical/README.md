# Infisical Deployment Setup

This directory contains the necessary scripts and reference configurations to easily deploy a self-hosted instance of **Infisical** using Docker Compose.

## 🚀 Deployment Instructions

You can deploy Infisical interactively on the target server (e.g., `iperamuna`).

### Option 1: Interactive Installation

Run the setup script with `sudo` and answer the prompts:

```bash
sudo bash setup-infisical.sh
```

By default, the script will suggest:
- **Domain**: `infisical.siyalude.io`
- **Install Directory**: `/opt/infisical`
- Automatically generate secure passwords, encryption keys, and tokens.
- Configure Nginx reverse proxy.
- Request Let's Encrypt SSL certificates.

### Option 2: Non-Interactive (Automated) Installation

You can bypass the prompts by providing the necessary environment variables and the `--no-interaction` flag:

```bash
INFISICAL_DOMAIN="infisical.siyalude.io" \
INFISICAL_INSTALL_DIR="/opt/infisical" \
ADMIN_EMAIL="admin@siyalude.io" \
sudo -E bash setup-infisical.sh --no-interaction
```

## 📂 File Structure

- **`setup-infisical.sh`**: The automated installer script. Handles Docker setup, `.env` generation, Compose startup, Nginx configuration, and Certbot SSL generation.
- **`docker-compose.yml`**: A local reference copy of the Docker Compose stack (the setup script generates its own version directly on the target machine).
- **`.env.example`**: A local reference copy of the required environment variables.

## 💾 Data Persistence

The deployment sets up persistent storage within your designated install directory (default: `/opt/infisical`):
- `/opt/infisical/data/pg_data`: PostgreSQL persistent data.
- `/opt/infisical/data/redis_data`: Redis persistent data.

## 🔐 Credentials & Secrets

After the setup script finishes, all generated passwords, encryption keys, and authorization secrets are safely stored in:
`/opt/infisical/credentials.txt`

> **Note**: Keep `credentials.txt` and `.env` secure. Do not commit them to version control.

## 🔧 Managing the Deployment

To view logs:
```bash
cd /opt/infisical
docker compose logs -f
```

To restart the application:
```bash
cd /opt/infisical
docker compose restart
```

To update to a newer version:
```bash
cd /opt/infisical
docker compose pull
docker compose up -d
```

## 📧 Updating SMTP Credentials

If you need to configure or update your email/SMTP credentials, you can use the included `update-smtp.sh` script.

To use it, run:
```bash
cd /opt/infisical
sudo bash update-smtp.sh
```

This script will:
1. Prompt you for your new SMTP details (Host, Port, User, Password, etc.).
2. Test the connection against the provided SMTP server to ensure the credentials work.
3. Automatically update your `/opt/infisical/.env` file.
4. Restart the Infisical backend to apply the changes.
