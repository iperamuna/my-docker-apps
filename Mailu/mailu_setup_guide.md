# Mailu Professional Setup Guide (2024.06)

This guide documents the high-end, branded Mailu infrastructure deployed for RavactHub.

### 3. Integrated Services
| Service | Role | Configuration |
| :--- | :--- | :--- |
| **SnappyMail** | Primary Webmail | Optimized proxy at `/snappymail/` with full Mailu SSO integration |
| **Roundcube** | Standard Webmail | Re-enabled via `WEBMAIL=roundcube` |
| **Apache Tika** | Attachment Indexing | Enables full-text search within PDF/Word attachments |
| **Fetchmail** | Account Fetching | Allows users to pull emails from external IMAP/POP3 accounts |

### 4. Branding Engine
All branding is centralized in `/opt/mailu/.env`. Update these variables to change the global look:
- `BRANDING_TEXT`: The text shown in the browser title and sidebar top.
- `BRANDING_LOGO_URL`: Full URL to your logo (used in sidebar and hub).
- `BRANDING_COLOR`: Preferred hex color (theme primary).
- **Hardened Security**: Oletools, Rspamd, and SSL/TLS mapping directly to Let's Encrypt.

## 🌐 Endpoints
- **Landing Hub**: [https://mail.ravact.com/](https://mail.ravact.com/)
- **Roundcube**: [https://mail.ravact.com/webmail/](https://mail.ravact.com/webmail/)
- **SnappyMail**: [https://mail.ravact.com/snappymail/](https://mail.ravact.com/snappymail/)
- **Admin Portal**: [https://mail.ravact.com/admin](https://mail.ravact.com/admin)
- **API Reference**: [https://mail.ravact.com/api](https://mail.ravact.com/api)

## 🎨 Branding Management
You can update your branding without editing code!
1. Open `/opt/mailu/.env`
2. Change `BRANDING_NAME=YourBrand`
3. Restart the admin container: `docker restart mailu-admin-1`

The sidebar links (Client Setup, Help, etc.) are automatically hidden for public users to maintain a clean appearance.

**Note on UI Overrides**: The layout injects custom templates (`base.html`, `sidebar.html`) for the pixel-perfect hub styling. If you manually tweak templates in `/opt/mailu/overrides/templates/ui/`, ensure you retain `{% block title %}` and `{% block main_action %}` inside `.content-header` so functional buttons (like "Add Domain") and layout titles continue to render properly.

## 📦 Backups & Maintenance
- **Backups**: Run `./backup-mailu.sh` to create a timestamped archive of settings and mail data.
- **Features**: Use `./manage-mailu-features.sh` to toggle ClamAV (AntiVirus) or Full-Text Search.
- **DNS Health**: Use `./verify-dns.sh` to check SPF, DKIM, and DMARC status.

## 🛠️ Outlook/Mobile Client Setup
You can connect your email client (Outlook, Apple Mail, Thunderbird, etc.) using your **standard email password**.

- **IMAP Root Path**: Set to `INBOX` (critical for folder syncing in Outlook for Mac).
- **Ports**: SSL/TLS (993/465) or STARTTLS (587).

### 🛡️ Advanced Security Tip: Authentication Tokens
While your regular password works perfectly, we highly recommend generating **Authentication Tokens** (App Passwords) for your mobile devices and email clients.

* **What it does**: Generates a dedicated, long, unique password strictly for a single specific device (e.g., "My iPhone").
* **Why it's better**: If your phone is lost or compromised, you can instantly revoke its email access with one click from the web portal, without needing to change your primary account password or update your other devices.
* **How to use**: Log into the Webmail/Admin panel, go to **Settings** -> **Authentication tokens**, generate a new token, and paste that token into your email app's password field instead of your main password.

## 1. Prerequisites & Host Setup
- **OS**: Clean Ubuntu 22.04 or 24.04 VPS.
- **Hostname**: Set your server's FQDN before starting:
  ```bash
  hostnamectl set-hostname mail.yourdomain.com
  ```

## 2. DNS Configuration (External Steps)
Set up these records at your DNS provider (e.g., Cloudflare).

> [!IMPORTANT]
> **Cloudflare Users**: For the `mail` A record, you MUST set the **Proxy Status** to **DNS Only** (Grey Cloud). Mailu handles its own SSL/TLS, and Cloudflare's proxy cannot handle SMTP traffic.

| Type | Name | Value | TTL |
| :--- | :--- | :--- | :--- |
| **A** | `mail` | `YOUR_SERVER_IP` (Proxy: OFF) | Auto |
| **MX** | `@` | `mail.yourdomain.com` (Priority 10) | Auto |
| **TXT** | `@` | `v=spf1 mx ~all` | Auto |
| **TXT** | `_dmarc` | `v=DMARC1; p=quarantine; rua=mailto:admin@yourdomain.com` | Auto |

> [!NOTE]
> **DNS Verification Status**: As of today, your configuration (`PTR`, `SPF`, `DMARC`, and `SMTP Banner`) is confirmed as **perfect**. The recommended DMARC value `p=quarantine` is now active and provides the best balance between security and deliverability.

### 🚨 Critical: The PTR Record (Reverse DNS)
You cannot set this in your DNS panel (Cloudflare). You **MUST** log in to your VPS Provider's Dashboard (Contabo, Hetzner, AWS, etc.) and find the "Reverse DNS" or "PTR" setting for your IP address.
- **IP**: `YOUR_SERVER_IP`
- **PTR Value**: `mail.yourdomain.com`
*Failure to do this will result in Gmail and Outlook rejecting 100% of your emails.*

## 3. Firewall Configuration
Ensure the following ports are open on your VPS firewall (UFW):

| Port | Protocol | Purpose |
| :--- | :--- | :--- |
| **25** | SMTP | Mail Exchange (Incoming) |
| **465** | SMTPS | **Secure Outgoing** (SSL/TLS) |
| **587** | MSA | **Secure Outgoing** (STARTTLS) |
| **993** | IMAPS | **Secure Incoming** (SSL/TLS) |
| **995** | POP3S | Secure POP3 |
| **80/443** | HTTP/S | Webmail & Admin |

```bash
ufw allow 25,80,443,465,587,110,143,993,995/tcp
ufw enable
```

## 4. Installation
1.  **Upload the script** from this folder: `setup-mailu.sh`.
2.  **Run the script**:
    ```bash
    chmod +x setup-mailu.sh
    ./setup-mailu.sh
    ```
    *The script will prompt for basic info (Domain) and **Advanced Settings**.*

### 🛠️ Advanced Settings Prompts
The script provides defaults for these, but you can customize them during installation:
- **Timezone**: Set to your local region (default: `Asia/Colombo`).
- **Enable API**: Allows programmatic control of Mailu (default: `true`).
- **Message Size**: Sets the maximum allowed raw email size (default: `75MB`). 
    *Note: This mathematically allows for actual ~50MB attachments after base64 encoding expansion overhead.*
- **Rate Limit**: Limits per-user sending to prevent spam abuse (default: `200/day`).
- **API Token**: A unique secret for authenticating with the `/api` endpoint.

## 5. Post-Setup Actions

### A. Create the Admin User
To create your first admin account, you can use the interactive helper script:
1.  **Upload the script**: `create-admin.sh` to your server.
2.  **Run it**:
    ```bash
    chmod +x create-admin.sh
    ./create-admin.sh
    ```
    *It will prompt you for the email and password, then create the user inside the container.*

### B. Generate & Publish DKIM Key (Persistent)
Your DKIM keys are now persisted in `/opt/mailu/dkim` on the host. 

1.  Log in to Mailu Admin: `https://mail.yourdomain.com/admin`
2.  Go to **Domains** -> Click **Edit** (pencil icon).
3.  Click **Regenerate DKIM Key**. 
    *Note: The default selector is now **dkim** (e.g. `dkim._domainkey.yourdomain.com`).*
4.  Copy the generated TXT record and add it to your DNS provider (e.g., Cloudflare).

## 6. Included Security Features
Your setup includes:
- **Rspamd (Antispam)**: Advanced filtering for all incoming mail.
- **SRS (Sender Rewriting Scheme)**: Automatically enabled in your `.env`. This rewrites the envelope sender for forwarded emails, ensuring they pass SPF checks on destination servers like Gmail or Outlook.
- **DKIM Persistence**: Keys are stored on the host filesystem at `/opt/mailu/dkim`, ensuring they survive container replacements.
- **Oletools**: Specifically scans Microsoft Office attachments for malicious macros.
- **SSL/TLS**: Automated certificates via Let's Encrypt for both Webmail and IMAP/SMTP.

## 7. Maintenance & Troubleshooting
- **Verify DNS Health**: `./verify-dns.sh`
- **Manage Features (ClamAV/FTS)**: 
  ```bash
  chmod +x manage-mailu-features.sh
  ./manage-mailu-features.sh
  ```
- **Rotate API Token**: `./rotate-api-token.sh`
- **Backup Entire System**:
  ```bash
  chmod +x backup-mailu.sh
  ./backup-mailu.sh
  ```
- **Enable Mass/Bulk Sending (MSS)**: `./enable-mass-email-sending.sh`
- **Restart**: `docker compose restart`
- **Spam Score**: Use [Mail-Tester.com](https://www.mail-tester.com) to verify your delivery.

---

## 8. Mass SMTP Sending (MSS) — Listmonk Integration

This section covers enabling Mailu as a high-volume SMTP relay for [Listmonk](https://listmonk.app/), the self-hosted newsletter platform.

> [!IMPORTANT]
> Run **`enable-mass-email-sending.sh`** from the root `Ravact/` directory on your server. It automates all steps below via the Mailu API.

### How It Works

```
┌──────────────────────────────────────────────────────────────────┐
│  Docker Host                                                     │
│                                                                  │
│  ┌──────────────┐   Port 25 (plain SMTP)   ┌─────────────────┐  │
│  │ listmonk-app │ ────────────────────────▶ │  mailu: front   │  │
│  │  (container) │   No TLS — RELAYNETS      │  (SMTP relay)   │  │
│  └──────────────┘   trusted subnet          └────────┬────────┘  │
│                                                      │           │
│                                 Authenticated SMTP   │           │
│                                 (TLS to recipient)   ▼           │
│                                              External Internet    │
└──────────────────────────────────────────────────────────────────┘
```

**Why no TLS for internal?**
- Traffic stays inside Docker's bridge network — never leaves the host
- TLS handshakes add latency and CPU for every email in a bulk campaign
- Mailu's `front` container enforces sender auth (`MSS_USER/PASS`) before relaying outbound
- `RELAYNETS` whitelists trusted container subnets at the transport level

### What `enable-mss-sending.sh` Does

| Step | Action |
|------|--------|
| 1 | Reads `DOMAIN`, `API_TOKEN` from `/opt/mailu/.env` |
| 2 | Auto-detects the Listmonk container's Docker subnet |
| 3 | Creates a dedicated `listmonk@yourdomain.com` mailbox via Mailu API |
| 4 | Adds the Listmonk subnet to `RELAYNETS` in `/opt/mailu/.env` |
| 5 | Optionally overrides the global send rate limit |
| 6 | Restarts Mailu `front` and `admin` containers |
| 7 | Prints a ready-to-paste `[[smtp]]` block for Listmonk's `config.toml` |

### Running the Script

**Interactive (recommended first time):**
```bash
chmod +x enable-mss-sending.sh
sudo bash enable-mss-sending.sh
```

**Non-interactive (CI / re-run):**
```bash
MSS_USER=listmonk \
MSS_PASS=YourSecurePassword \
RELAY_NETS="172.20.0.0/24" \
MSS_RATE_LIMIT="2000/day" \
sudo -E bash enable-mss-sending.sh --no-interaction
```

### Mailu `config.toml` SMTP Block (output by the script)

```toml
[[smtp]]
enabled          = true
host             = "front"          # Mailu container on shared Docker network
port             = 25               # Plain SMTP — no TLS handshake (RELAYNETS trusted)
auth_protocol    = "plain"
username         = "listmonk@yourdomain.com"
password         = "your_mss_password"
email_headers    = []
max_conns        = 10
max_msg_retries  = 2
idle_timeout     = "15s"
wait_timeout     = "5s"
tls_type         = "none"           # Internal relay — TLS disabled for performance
tls_skip_verify  = false
```

> [!NOTE]
> Listmonk must be joined to the `mailu_default` Docker network. The Listmonk installer (`Listmonk/setup-listmonk.sh`) handles this automatically when `JOIN_MAILU_NETWORK=true`.

### DNS Deliverability for Bulk Sending

> [!WARNING]
> Sending bulk email without proper DNS is a direct path to spam folders or blacklisting.

| Record | Purpose | Verification |
|--------|----------|-------------|
| **SPF** | Authorises your IP to send | `./verify-dns.sh` |
| **DKIM** | Cryptographic signature per email | Mailu Admin → Domains → Regenerate DKIM |
| **DMARC** | Policy for failed SPF/DKIM | `p=quarantine` minimum |
| **PTR** | Reverse DNS for your server IP | Set at VPS provider dashboard |

### Warm-Up Schedule (Avoid Blacklisting)

Start slowly when sending from a new IP or mailbox:

| Day | Max Emails/Day |
|-----|---------------|
| 1–2 | 100 |
| 3–5 | 300 |
| 6–10 | 1,000 |
| 11–20 | 5,000 |
| 21+ | Ramp to limit |

Use [Mail-Tester.com](https://www.mail-tester.com) and [MXToolbox](https://mxtoolbox.com/blacklists.aspx) to monitor reputation during warm-up.

### Post-Enable Checklist

- [ ] Listmonk's `config.toml` updated with the `[[smtp]]` block
- [ ] Listmonk restarted: `docker compose -f /opt/listmonk/docker-compose.yml restart`
- [ ] Test email sent from Listmonk dashboard → Settings → SMTP
- [ ] DKIM key regenerated and published in DNS
- [ ] DMARC record set to at least `p=quarantine`
- [ ] Warm-up schedule followed for new sending IP

---
*Created for Ravact Deployment*
