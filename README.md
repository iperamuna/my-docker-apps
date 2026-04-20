# Ravact Infrastructure

This repository contains the deployment configurations, scripts, and documentation for the complete Ravact/Siyalude IO infrastructure. All systems are deployed as Docker containers dynamically proxied behind Nginx and secured via Certbot Let's Encrypt.

## 🚀 Deployed Applications

| Application | Domain / Live URL | Description | Directory |
|-------------|-------------------|-------------|-----------|
| **Grafana / Prometheus** | [monitor.ravact.com](https://monitor.ravact.com) | Hardware & Container Metrics Visualization | [./Graphana](./Graphana) |
| **Uptime Kuma** | [uptime.siyalude.io](https://uptime.siyalude.io) | Application Status Monitoring & Alerts | [./Uptime-kuma](./Uptime-kuma) |
| **Listmonk** | [newsletter.ravact.com](https://newsletter.ravact.com) | High-performance Mass Newsletter Management | [./Listmonk](./Listmonk) |
| **Komodo Core** | [komodo.ravact.com](https://komodo.ravact.com) | Advanced Server Automation Dashboard | [./Komodo](./Komodo) |
| **Mailu** | _(Internal / SMTP)_<br>[mail.ravact.com](https://mail.ravact.com) | Complete Mailserver Stack (IMAP/POP3, Spam, AV) | [./Mailu](./Mailu) |

---

## 🛠️ Infrastructure Overview

All services rely on identical design principles for high availability:
- **Port Isolation**: Services run on internal ports (e.g. `3000`, `3001`, `9000`) and are bound to `127.0.0.1`.
- **Reverse Proxy**: Nginx exclusively handles the ingress external traffic on port `80/443`, routing internal ports seamlessly.
- **Auto-SSL**: Deployment scripts implement `certbot` for automatic setup and renewal.
- **Internal Routing**: For efficiency, internal services communicate directly over Docker subnets (e.g., Listmonk connecting to Mailu's SMTP on `front:25` with no TLS handshake overhead).

## 📄 Managing Services

Inside each application directory, you will likely find:
1. `docker-compose.yml`: For managing container lifecycles (`docker compose up -d`).
2. `setup-*.sh`: Fully idempotent automation scripts. You can run these `sudo bash setup-app.sh` repeatedly to re-provision Nginx/Docker environments.
3. `.env.example`: Safe credential templates.

To make global changes to the production server natively, we deploy all these via SSH over the `iperamuna` host using secure non-interactive automation flags.

> **Note on Monitoring:** The Grafana deployment natively incorporates `cAdvisor`. You can track live CPU / RAM statistics for any of these individual Docker containers by using Dashboard ID `14282`.
