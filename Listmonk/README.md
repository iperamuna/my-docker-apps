# Listmonk Installer

Automated self-contained setup script for [Listmonk](https://listmonk.app/) on Ubuntu 22.04/24.04, pre-configured for **Mailu internal SMTP** (no SSL/TLS overhead).

## Files

| File | Purpose |
|---|---|
| `setup-listmonk.sh` | Main installer script |
| `docker-compose.yml` | Reference Compose file (script generates the real one on-server) |
| `config.toml.example` | Reference Listmonk config with SMTP options documented |
| `.env.example` | All configurable env variables with docs |

---

## Quick Start

### Interactive (Prompted)
```bash
scp -r ./Listmonk root@your-server:/tmp/listmonk-setup
ssh root@your-server
cd /tmp/listmonk-setup
chmod +x setup-listmonk.sh
sudo bash setup-listmonk.sh
```
The script will prompt for each setting with sensible defaults.

---

### Non-Interactive (Fully Automated)
```bash
# Pass everything via environment variables
LISTMONK_DOMAIN=newsletter.ravact.com \
LISTMONK_ADMIN_USER=admin \
LISTMONK_ADMIN_PASS=SuperSecure123 \
SMTP_HOST=front \
SMTP_PORT=25 \
SMTP_USER=listmonk@ravact.com \
SMTP_PASS=mailboxpassword \
SMTP_FROM="Ravact Newsletter <listmonk@ravact.com>" \
SMTP_TLS=false \
SMTP_STARTTLS=false \
JOIN_MAILU_NETWORK=true \
MAILU_NETWORK=mailu_default \
SETUP_NGINX=true \
SETUP_SSL=true \
ADMIN_EMAIL=admin@ravact.com \
sudo -E bash setup-listmonk.sh --no-interaction
```

---

## Mailu Internal SMTP — How It Works

Listmonk is added to the `mailu_default` Docker network. This allows it to reach Mailu's `front` container **directly at hostname `front` on port 25** — plain SMTP with **no TLS handshake**.

```
┌──────────────────────────────────────────────────────┐
│  Docker Host                                         │
│                                                      │
│  ┌──────────────┐   port 25 (plain)  ┌───────────┐  │
│  │ listmonk-app │──────────────────▶ │  front    │  │
│  │  (container) │   no SSL overhead  │  (Mailu)  │  │
│  └──────────────┘                    └───────────┘  │
│         │                                   │        │
│   mailu_default network (bridge)            │        │
│                                             ▼        │
│                                      External SMTP   │
└──────────────────────────────────────────────────────┘
```

**Why no TLS internally?**
- Traffic stays inside Docker's virtual bridge network (never leaves the host)
- TLS handshakes add latency and CPU overhead for bulk sends
- Mailu's `front` container already enforces auth via `SMTP_USER/PASS`

---

## Prerequisites on the Mailu side

1. **Create a Mailu mailbox** for `listmonk@yourdomain.com`
2. **Allow relay** from the Listmonk container's IP (or rely on authenticated SMTP)
3. Verify the Mailu Docker network name: `docker network ls | grep mailu`

---

## Post-Install Checklist

- [ ] Log into the Listmonk dashboard at `https://your-domain/`
- [ ] Go to **Settings → SMTP** and send a test email
- [ ] Create a **Sender** entry using your from address
- [ ] Add a **List** and import your first subscribers
- [ ] Set up your first **Campaign**
- [ ] Change the admin password from the default (if you didn't set one)

---

## Useful Commands

```bash
# View logs
docker compose -f /opt/listmonk/docker-compose.yml logs -f

# Restart
docker compose -f /opt/listmonk/docker-compose.yml restart

# Stop everything
docker compose -f /opt/listmonk/docker-compose.yml down

# Database backup
docker exec listmonk-db pg_dump -U listmonk listmonk > listmonk-backup-$(date +%F).sql
```
