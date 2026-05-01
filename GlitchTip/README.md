# GlitchTip — Open Source Error Tracking

Automated Docker-based deployment of [GlitchTip](https://glitchtip.com) with Nginx reverse proxy, Let's Encrypt SSL, and custom configuration management.

- **URL:** https://gt.siyalude.io
- **Server:** `iperamuna` (SSH alias)
- **Install Directory:** `/opt/glitchtip`

---

## 🚀 Fresh Deployment

### 1. Sync the GlitchTip directory
```bash
rsync -avz ./GlitchTip/ iperamuna:/opt/glitchtip/
```

### 2. Run the setup script
```bash
ssh iperamuna "sudo bash /opt/glitchtip/setup-glitchtip.sh"
```

The script will:
- Install Docker, Nginx, Certbot (if missing)
- Generate `.env` with random secrets
- Start GlitchTip stack (Web, Postgres 16, Valkey 9)
- Configure host Nginx as a reverse proxy with SSL

### 3. Create the Admin User
To access the dashboard or the admin panel, you need to create an initial superuser:
```bash
ssh -t iperamuna "sudo bash /opt/glitchtip/create-admin.sh"
```

---

## ⚙️ Configuration Management

A custom utility script is provided to modify common settings without manually editing `.env` files.

```bash
ssh iperamuna "cd /opt/glitchtip && sudo bash change-config.sh"
```

**Available Options:**
- Toggle **Uptime Monitoring**
- Toggle **Log Ingestion**
- Toggle **Django Admin** access at `/admin/`
- Update **From Email** address
- Update **SMTP URL** using an interactive builder (supports TLS/SSL)
- **Test SMTP Settings** by sending a real test email from the container

---

## 🛠️ Operations

### View logs
```bash
ssh iperamuna "cd /opt/glitchtip && docker compose logs -f"
```

### Restart all services
```bash
ssh iperamuna "cd /opt/glitchtip && docker compose restart"
```

### Check container health
```bash
ssh iperamuna "cd /opt/glitchtip && docker compose ps"
```

### Manual Environment Edits
```bash
ssh iperamuna "nano /opt/glitchtip/.env && cd /opt/glitchtip && docker compose up -d"
```

---

## 📁 Files

| File | Purpose |
|---|---|
| `setup-glitchtip.sh` | Automated installer script |
| `create-admin.sh` | Create initial superuser/admin |
| `change-config.sh` | Configuration modifier utility |
| `docker-compose.yml` | GlitchTip stack definition |
| `.env.example` | Reference environment variables |
