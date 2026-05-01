# Ravact Infrastructure

This repository contains the deployment configurations, scripts, and documentation for the complete **Ravact / Siyalude IO** self-hosted infrastructure. Every system runs as a Docker container, reverse-proxied through host Nginx, and secured with automatic Let's Encrypt TLS via Certbot.

All provisioning is done through idempotent `setup-*.sh` scripts that can be re-run safely at any time to re-provision, update, or repair a service.

---

## 📋 Table of Contents

- [Deployed Applications](#-deployed-applications)
- [Infrastructure Design](#-infrastructure-design)
- [SSH Access](#-ssh-access)
- [Services](#-services)
  - [Mailu — Mail Server](#-mailu--mail-server)
  - [Listmonk — Newsletter](#-listmonk--newsletter)
- [ ] [AppFlowy — Workspace](#-appflowy--workspace)
- [ ] [GlitchTip — Error Tracking](#-glitchtip--error-tracking)
- [ ] [Komodo — Server Automation](#-komodo--server-automation)
  - [Grafana / Prometheus — Monitoring](#-grafana--prometheus--monitoring)
  - [Uptime Kuma — Status Page](#-uptime-kuma--status-page)
- [Managing Services](#-managing-services)
- [Networking & Ports](#-networking--ports)

---

## 🚀 Deployed Applications

| Application | Live URL | Description | Directory |
|---|---|---|---|
| **Mailu** | [mail.ravact.com](https://mail.ravact.com) | Full mail server stack (IMAP/SMTP/POP3, Webmail, Spam, AV) | [./Mailu](./Mailu) |
| **Listmonk** | [newsletter.ravact.com](https://newsletter.ravact.com) | High-performance mass newsletter & transactional email | [./Listmonk](./Listmonk) |
| **AppFlowy** | [af.siyalude.io](https://af.siyalude.io) | Self-hosted team workspace & knowledge base | [./AppFlowy](./AppFlowy) |
| **GlitchTip** | [gt.siyalude.io](https://gt.siyalude.io) | Open source error tracking & uptime monitoring | [./GlitchTip](./GlitchTip) |
| **Komodo Core** | [komodo.ravact.com](https://komodo.ravact.com) | Advanced server automation & deployment dashboard | [./Komodo](./Komodo) |
| **Grafana / Prometheus** | [monitor.ravact.com](https://monitor.ravact.com) | Hardware & container metrics visualization | [./Grafana](./Grafana) |
| **Uptime Kuma** | [uptime.siyalude.io](https://uptime.siyalude.io) | Application status monitoring & alerting | [./Uptime-kuma](./Uptime-kuma) |

---

## 🏗️ Infrastructure Design

All services share a common design philosophy:

| Principle | Implementation |
|---|---|
| **Port Isolation** | Services bind only to `127.0.0.1:<port>` — never exposed directly to the internet |
| **Reverse Proxy** | Host Nginx handles all external traffic on ports `80`/`443`, routing to internal Docker ports |
| **Auto-SSL** | Certbot provisions and auto-renews Let's Encrypt certificates per subdomain |
| **Internal Routing** | Services communicate over Docker subnets (e.g., Listmonk → Mailu SMTP on `front:25` with no TLS overhead) |
| **Idempotent Scripts** | All `setup-*.sh` scripts are safe to re-run; they re-configure without data loss |
| **SSH Automation** | All remote operations use the `iperamuna` SSH alias; scripts are uploaded via `scp` and executed non-interactively |

---

## 🔐 SSH Access

All servers are accessed via the `iperamuna` SSH alias configured in `~/.ssh/config`.

```bash
# Generic pattern for running a setup script remotely
scp ./ServiceDir/setup-service.sh iperamuna:/tmp/
ssh iperamuna "sudo bash /tmp/setup-service.sh"
```

---

## 🛠️ Services

### 📧 Mailu — Mail Server

**Directory:** [`./Mailu`](./Mailu)
**URLs:** [mail.ravact.com](https://mail.ravact.com) _(Admin: `/admin`, Webmail: `/webmail`, SnappyMail: `/snappymail`)_
**Install Path (server):** `/opt/mailu`

Mailu provides the complete mail stack: Postfix (SMTP), Dovecot (IMAP/POP3), Rspamd (antispam), ClamAV (antivirus), Roundcube, and SnappyMail webmail — all orchestrated via Docker Compose.

#### Deploy / Re-provision
```bash
scp Mailu/setup-mailu.sh iperamuna:/tmp/
ssh iperamuna "sudo bash /tmp/setup-mailu.sh"
```
The script prompts for `DOMAIN` and `MAIL_HOST`, then generates the `.env`, all UI overrides, the `docker-compose.yml`, and brings the stack up.

#### Key Files

| File | Purpose |
|---|---|
| `setup-mailu.sh` | Master installer — generates env, UI templates, compose file, and starts containers |
| `create-admin.sh` | Creates an initial admin user via the Mailu API |
| `rotate-api-token.sh` | Rotates the Mailu API token and updates `.env` |
| `backup-mailu.sh` | Archives `/opt/mailu/data` and DKIM keys to a dated tarball |
| `verify-dns.sh` | Validates MX, SPF, DKIM, and DMARC DNS records for configured domains |
| `enable-mass-email-sending.sh` | Configures sending limits & relay settings for bulk outbound mail |
| `manage-mailu-features.sh` | Toggles Mailu features (antivirus, antispam, webdav, etc.) via API |
| `domains.json` | Declarative domain list for bulk import |
| `mailu_setup_guide.md` | Full manual setup guide |
| `mailu_api_guide.md` | Mailu REST API usage patterns |
| `mailu_overrides_guide.md` | How UI template overrides work |

#### Ports Exposed (on host)
| Port | Protocol | Service |
|---|---|---|
| `25` | TCP | SMTP (inbound MX) |
| `465` | TCP | SMTPS (submission, implicit TLS) |
| `587` | TCP | Submission (STARTTLS) |
| `110` | TCP | POP3 |
| `995` | TCP | POP3S |
| `143` | TCP | IMAP |
| `993` | TCP | IMAPS |
| `127.0.0.1:8090` | HTTP | Admin/Webmail UI (proxied by Nginx → mail.ravact.com) |

> **Note:** The Docker Compose file for Mailu is **generated by `setup-mailu.sh`** directly on the server at `/opt/mailu/docker-compose.yml`. There is no separate compose file checked into this repository — the script is the single source of truth.

---

### 📰 Listmonk — Newsletter

**Directory:** [`./Listmonk`](./Listmonk)
**URL:** [newsletter.ravact.com](https://newsletter.ravact.com)
**Install Path (server):** `/opt/listmonk`

Listmonk is a high-performance, self-hosted newsletter and mailing list manager backed by PostgreSQL. It uses Mailu's SMTP (`front:25`) for outbound delivery over the internal Docker network — no external SMTP relay needed.

#### Deploy / Re-provision
```bash
scp Listmonk/setup-listmonk.sh iperamuna:/tmp/
ssh iperamuna "sudo bash /tmp/setup-listmonk.sh"
```

#### Key Files

| File | Purpose |
|---|---|
| `setup-listmonk.sh` | Full installer: Docker Compose, Nginx config, SSL |
| `docker-compose.yml` | Listmonk + PostgreSQL compose definition |
| `config.toml.example` | Reference Listmonk configuration template |
| `.env.example` | Environment variable reference |

---

### 📝 AppFlowy — Workspace

**Directory:** [`./AppFlowy`](./AppFlowy)
**URLs:** [af.siyalude.io](https://af.siyalude.io) | Admin Console: [af.siyalude.io/console](https://af.siyalude.io/console)
**Install Path (server):** `/opt/appflowy`

AppFlowy Cloud is a self-hosted, open-source Notion alternative. The deployment includes the full AppFlowy Cloud stack (GoTrue auth, AppFlowy backend, MinIO storage, Redis, PostgreSQL) managed via Docker Compose, with Nginx reverse proxy and Resend SMTP for email.

#### Deploy / Re-provision
```bash
scp AppFlowy/setup-appflowy.sh iperamuna:/tmp/
ssh iperamuna "sudo bash /tmp/setup-appflowy.sh"
```

#### Credentials

| Account | Email | Password |
|---|---|---|
| Admin Console | `admin@siyalude.io` | `CDrzUD7Gu0aMKm3V` |

> ⚠️ Admin Console accounts **cannot** log into the Desktop/Web App. Create separate regular user accounts for day-to-day use.

#### Connecting the Desktop App
1. Open AppFlowy Desktop → **Settings** → **Cloud Settings**
2. Set **Cloud server** to **AppFlowy Cloud Self-hosted**
3. Enter URL: `https://af.siyalude.io`
4. Restart and log in with a regular user account

#### Key Files

| File | Purpose |
|---|---|
| `setup-appflowy.sh` | Automated full installer |
| `docker-compose.yml` | Local copy of the server's compose file |
| `.env.example` | Reference environment variables |
| `fix_admin_pwd.sql` | SQL snippet to reset admin password if needed |

#### Common Issues

**Login loop (redirected back to `/login`)**
The GoTrue UUID and `af_user.uuid` can get out of sync. See [`AppFlowy/README.md`](./AppFlowy/README.md#-troubleshooting) for the full diagnosis and fix procedure.

**Admin Console shows "Cannot read properties of undefined"**
The admin account needs the `supabase_admin` role. See the README for the fix SQL.

---

### 🐞 GlitchTip — Error Tracking

**Directory:** [`./GlitchTip`](./GlitchTip)
**URL:** [gt.siyalude.io](https://gt.siyalude.io)
**Install Path (server):** `/opt/glitchtip`

GlitchTip is an open-source, Sentry-compatible error tracking platform. It includes integrated uptime monitoring and log ingestion.

#### Deploy / Re-provision
```bash
rsync -avz ./GlitchTip/ iperamuna:/opt/glitchtip/
ssh iperamuna "sudo bash /opt/glitchtip/setup-glitchtip.sh"
```

#### Key Files

| File | Purpose |
|---|---|
| `setup-glitchtip.sh` | Automated installer: Docker, Nginx, SSL |
| `change-config.sh` | Configuration modifier for Uptime/Logs/SMTP |
| `docker-compose.yml` | GlitchTip + Postgres + Valkey definition |
| `.env.example` | Reference environment variables |

---

### ⚙️ Komodo — Server Automation

**Directory:** [`./Komodo`](./Komodo)
**URL:** [komodo.ravact.com](https://komodo.ravact.com)
**Install Path (server):** `/opt/komodo`

Komodo Core is an advanced server automation and deployment management dashboard. It provides a UI for managing Docker stacks, running deployments, and monitoring resource usage across connected servers.

#### Deploy / Re-provision
```bash
scp Komodo/setup-komodo.sh iperamuna:/tmp/
ssh iperamuna "sudo bash /tmp/setup-komodo.sh"
```

#### Key Files

| File | Purpose |
|---|---|
| `setup-komodo.sh` | Full installer including Docker Compose and Nginx |
| `docker-compose.yml` | Komodo Core compose definition |
| `komodo-nginx.conf` | Nginx vhost config template |
| `GUIDE.md` | Operational notes and usage guide |
| `credentials.txt` | Stored access credentials (do not commit secrets publicly) |
| `komodo-notifier/` | Notification integration configs |

---

### 📊 Grafana / Prometheus — Monitoring

**Directory:** [`./Grafana`](./Grafana)
**URL:** [monitor.ravact.com](https://monitor.ravact.com)
**Install Path (server):** `/opt/grafana`

Grafana + Prometheus + cAdvisor provide real-time hardware and container metrics. The cAdvisor integration enables per-container CPU, RAM, network, and disk I/O tracking visible in Grafana.

#### Deploy / Re-provision
```bash
scp Grafana/setup-grafana.sh iperamuna:/tmp/
ssh iperamuna "sudo bash /tmp/setup-grafana.sh"
```

#### Dashboard

Import the **Docker & system monitoring** dashboard using **ID `14282`** from Grafana.com to get pre-built panels for all running containers.

#### Key Files

| File | Purpose |
|---|---|
| `setup-grafana.sh` | Full installer: Prometheus, Grafana, cAdvisor, Node Exporter, Nginx, SSL |
| `.env.example` | Environment variable reference |

---

### 🟢 Uptime Kuma — Status Page

**Directory:** [`./Uptime-kuma`](./Uptime-kuma)
**URL:** [uptime.siyalude.io](https://uptime.siyalude.io)
**Install Path (server):** `/opt/uptime-kuma`

Uptime Kuma monitors the availability and response times of all services, with configurable alerting via email, Slack, Telegram, and more.

#### Deploy / Re-provision
```bash
scp Uptime-kuma/setup-uptime-kuma.sh iperamuna:/tmp/
ssh iperamuna "sudo bash /tmp/setup-uptime-kuma.sh"
```

#### Key Files

| File | Purpose |
|---|---|
| `setup-uptime-kuma.sh` | Full installer with Docker and Nginx |
| `.env.example` | Environment variable reference |

---

## 📄 Managing Services

Every service directory follows the same pattern:

```
ServiceDir/
├── setup-service.sh     # Idempotent installer — run to deploy or re-provision
├── docker-compose.yml   # Compose definition (where applicable)
├── .env.example         # Safe credential template — copy to .env and fill in secrets
└── README.md            # Service-specific documentation
```

### Common Operations

```bash
# View live logs for a service
ssh iperamuna "cd /opt/<service> && docker compose logs -f"

# Restart all containers in a stack
ssh iperamuna "cd /opt/<service> && docker compose restart"

# Pull latest images and redeploy
ssh iperamuna "cd /opt/<service> && docker compose pull && docker compose up -d"

# Check container status
ssh iperamuna "cd /opt/<service> && docker compose ps"

# Stop a service
ssh iperamuna "cd /opt/<service> && docker compose down"
```

---

## 🌐 Networking & Ports

| Service | Internal Port | External Binding | Public Domain |
|---|---|---|---|
| Mailu (web UI) | `8090` | `127.0.0.1:8090` → Nginx | `mail.ravact.com` |
| Mailu SMTP | `25`, `465`, `587` | Direct (host) | — |
| Mailu IMAP/POP3 | `143`, `993`, `110`, `995` | Direct (host) | — |
| Listmonk | `9000` | `127.0.0.1:9000` → Nginx | `newsletter.ravact.com` |
| AppFlowy | `80` (nginx container) | `127.0.0.1:…` → Nginx | `af.siyalude.io` |
| GlitchTip | `8000` | `127.0.0.1:8000` → Nginx | `gt.siyalude.io` |
| Komodo | `9120` | `127.0.0.1:9120` → Nginx | `komodo.ravact.com` |
| Grafana | `3000` | `127.0.0.1:3000` → Nginx | `monitor.ravact.com` |
| Uptime Kuma | `3001` | `127.0.0.1:3001` → Nginx | `uptime.siyalude.io` |

> All internal ports are bound exclusively to `127.0.0.1` — the firewall only needs to permit ports `80`, `443`, `25`, `465`, `587`, `143`, `993`, `110`, and `995`.
