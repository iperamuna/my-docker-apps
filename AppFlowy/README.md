# AppFlowy Cloud — Self-Hosted Deployment

Automated Docker-based deployment of [AppFlowy Cloud](https://github.com/AppFlowy-IO/AppFlowy-Cloud) with Nginx reverse proxy, Let's Encrypt SSL, and Resend SMTP integration.

- **URL:** https://af.siyalude.io
- **Admin Console:** https://af.siyalude.io/console
- **Server:** `iperamuna` (SSH alias)
- **Install Directory:** `/opt/appflowy`

---

## 🚀 Fresh Deployment

### 1. Transfer the setup script to the server
```bash
scp setup-appflowy.sh iperamuna:/tmp/
```

### 2. Run the setup script
```bash
ssh iperamuna "sudo bash /tmp/setup-appflowy.sh"
```

The script will:
- Install Docker, Nginx, Certbot
- Clone the AppFlowy Cloud repo
- Generate `.env` with random secrets + pre-configured Resend SMTP
- Start all Docker containers
- Configure host Nginx as a reverse proxy with SSL

---

## 🔑 Credentials

| Account | Email | Password |
|---|---|---|
| Admin Console | `admin@siyalude.io` | `CDrzUD7Gu0aMKm3V` |

> ⚠️ Admin Console accounts **cannot** log into the Desktop/Web App. Create separate regular user accounts for day-to-day use.

---

## 📧 SMTP (Resend)

Emails are sent via [Resend](https://resend.com) from `info@siyalude.io`.

| Variable | Value |
|---|---|
| Host | `smtp.resend.com` |
| Port | `465` (Implicit SSL/TLS) |
| Username | `resend` |
| Sender | `info@siyalude.io` |

---

## 🖥️ Connecting the Desktop App

1. Open AppFlowy Desktop.
2. Go to **Settings** → **Cloud Settings**.
3. Set **Cloud server** to **AppFlowy Cloud Self-hosted**.
4. Enter the URL: `https://af.siyalude.io`
5. Restart the application and log in with a **regular user account** (not the admin).

---

## 🛠️ Operations

### View logs
```bash
ssh iperamuna "cd /opt/appflowy && docker compose logs -f"
```

### Restart all services
```bash
ssh iperamuna "cd /opt/appflowy && docker compose restart"
```

### Check container health
```bash
ssh iperamuna "cd /opt/appflowy && docker compose ps"
```

### Edit environment variables
```bash
ssh iperamuna "nano /opt/appflowy/.env && cd /opt/appflowy && docker compose up -d"
```

---

## 🐛 Troubleshooting

### Login loop / redirected back to `/login`

The AppFlowy backend looks up users by their GoTrue UUID stored in `af_user.uuid`. This can get out of sync if a user is deleted from GoTrue and re-created (getting a new UUID), while the old `af_user` record persists with the old UUID.

**Diagnose:**
```bash
# Check appflowy_cloud logs for "Can't find the user profile for user"
ssh iperamuna "cd /opt/appflowy && docker compose logs appflowy_cloud | grep 'user profile'"

# Get the GoTrue UUID (from auth.users)
ssh iperamuna "docker exec appflowy-postgres-1 psql -U postgres -d postgres -c \"SELECT id, email FROM auth.users WHERE email = 'user@example.com';\""

# Get the AppFlowy UUID (from af_user)
ssh iperamuna "docker exec appflowy-postgres-1 psql -U postgres -d postgres -c \"SELECT uid, uuid, email FROM af_user WHERE email = 'user@example.com';\""
```

**Fix** (if UUIDs don't match):
```bash
# Replace <NEW_GOTRUE_UUID> with the UUID from auth.users
ssh iperamuna "docker exec appflowy-postgres-1 psql -U postgres -d postgres -c \"UPDATE af_user SET uuid = '<NEW_GOTRUE_UUID>' WHERE email = 'user@example.com';\""
```

---

### Admin Console shows "Cannot read properties of undefined"

The admin console requires the `admin@siyalude.io` account to have the `supabase_admin` role. Check and fix:

```bash
# Check current role
ssh iperamuna "docker exec appflowy-postgres-1 psql -U postgres -d postgres -c \"SELECT email, role, raw_app_meta_data FROM auth.users WHERE email = 'admin@siyalude.io';\""

# Fix: promote to supabase_admin
ssh iperamuna "docker exec appflowy-postgres-1 psql -U postgres -d postgres -c \"UPDATE auth.users SET role = 'supabase_admin', raw_app_meta_data = raw_app_meta_data || '{\\\"is_system_admin\\\": true}' WHERE email = 'admin@siyalude.io';\""
```

Log out and back into the console after running this.

---

### SMTP / email sending errors

Check GoTrue logs for SMTP errors:
```bash
ssh iperamuna "cd /opt/appflowy && docker compose logs gotrue | grep -iE 'smtp|email|error'"
```

Common causes:
- `Bad sender address syntax` → `GOTRUE_SMTP_ADMIN_EMAIL` is not set or invalid
- Connection refused → Wrong port or `APPFLOWY_MAILER_SMTP_TLS_KIND` not set to `wrapper`

---

## 📁 Files

| File | Purpose |
|---|---|
| `setup-appflowy.sh` | Automated installer script |
| `.env.example` | Reference environment variables |
| `docker-compose.yml` | Local copy of server's docker-compose |
| `fix_admin_pwd.sql` | SQL to reset admin password if needed |
