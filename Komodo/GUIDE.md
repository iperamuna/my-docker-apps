# Komodo v2 Deployment Guide

This guide provides instructions on how to use the automated `setup-komodo.sh` script to deploy a full **Komodo v2** stack on an Ubuntu 24.04 server.

## Prerequisites

1.  **Server:** A clean Ubuntu 24.04 server (or one with Mailu already running).
2.  **DNS:** Point `komodo.ravact.com` to your server's public IP address (**84.46.255.169**).
3.  **Root Access:** You must have root or sudo privileges.

## One-Command Installation

To install Komodo, transfer the `setup-komodo.sh` script to your server and run it:

```bash
# 1. On your local machine, upload the script
scp setup-komodo.sh root@84.46.255.169:/root/

# 2. On the server, run the script
chmod +x setup-komodo.sh
sudo ./setup-komodo.sh
```

## What the Script Does

The script automates the following steps:
- **Docker Engine:** Installs official Docker and Docker Compose if not found.
- **Komodo Core:** Deploys the Dashboard and MongoDB database in `/opt/komodo`.
- **Periphery Agent:** Installs the agent as a `systemd` service on the host.
- **Nginx Proxy:** Sets up a reverse proxy configuration at `komodo.ravact.com`.

## Post-Installation Steps

### 1. Enable HTTPS
Run Certbot to secure your dashboard:
```bash
sudo certbot --nginx -d komodo.ravact.com
```

### 2. Initial Login
- **URL:** `https://komodo.ravact.com`
- **Username:** `admin`
- **Password:** `l1XQEY+rJ5jQOIXM` (from `credentials.txt`)

### 3. Adding Your Server (Monitor Containers)
To see your Mailu containers and server metrics:
1.  Navigate to **Servers** on the left menu.
2.  Click **Add Server**.
3.  **Name:** `iperamuna`
4.  **Address:** `https://84.46.255.169:8120`
5.  **Skip TLS Verification:** **CHECK THIS** (required for the default self-signed cert).
6.  Click **Add**.

Once added, click the server name and go to the **Containers** tab to see your running Docker instances.

## Troubleshooting
If you encounter a "502 Bad Gateway" or "Connection Refused":
- Ensure the Core can reach MongoDB.
- If you need to reset the database, run:
  ```bash
  cd /opt/komodo
  docker compose down
  rm -rf mongo-data
  docker compose up -d
  ```

## Support
For more details, refer to the [official Komodo documentation](https://komo.do/docs/).
