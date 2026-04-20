#!/bin/bash
# ---------------------------------------------------------
# RavactHub Master Installer (2024.06) - PIXEL-PERFECT VERSION
# ---------------------------------------------------------
set -e

# 1. Configuration
# ---------------------------
read -p "Enter Domain (e.g. ravact.com): " DOMAIN
read -p "Enter Mail Hostname (e.g. mail.ravact.com): " MAIL_HOST
read -p "Branding Name [RavactHub]: " BRAND_NAME
BRAND_NAME=${BRAND_NAME:-RavactHub}

SECRET_KEY=$(tr -dc 'a-z0-9' < /dev/urandom | head -c 32)
API_TOKEN=$(tr -dc 'A-Z0-9' < /dev/urandom | head -c 32)
SRS_SECRET=$(tr -dc 'a-z0-9' < /dev/urandom | head -c 32)
LOGO_URL="https://ravact.com/logo.png"
BRAND_COLOR="#3b82f6"

echo "🚀 Setting up PIXEL-PERFECT RavactHub for $DOMAIN..."

# 2. Directory Structure
# ---------------------------
mkdir -p /opt/mailu/data
mkdir -p /opt/mailu/data/redis
sudo chown 999:999 /opt/mailu/data/redis
mkdir -p /opt/mailu/dkim
mkdir -p /opt/mailu/overrides/templates/ui /opt/mailu/overrides/templates/sso /opt/mailu/overrides/static
# Webmail PHP Overrides (Memory & Max Filesize)
printf 'upload_max_filesize = 50M\npost_max_size = 50M\nmemory_limit = 512M\nmax_execution_time = 300\n' > /opt/mailu/overrides/webmail_php.ini
cd /opt/mailu

# 3. Environment Setup
# ---------------------------
cat > .env <<EOV
DOMAIN=$DOMAIN
HOSTNAMES=$MAIL_HOST
POSTMASTER=admin@$DOMAIN
WEBMAIL=none
ADMIN=true
ANTIVIRUS=none
ANTISPAM=rspamd
WEBDAV=none
API=true
SECRET_KEY=$SECRET_KEY
TZ=Asia/Colombo
MAIL_VERSION=2024.06
MESSAGE_SIZE_LIMIT=75000000
WEB_ADMIN=/admin
WEB_API=/api
API_TOKEN=$API_TOKEN
BRANDING_NAME=$BRAND_NAME
BRANDING_TEXT="$BRAND_NAME"
BRANDING_LOGO_URL="$LOGO_URL"
BRANDING_COLOR="$BRAND_COLOR"
EXTERNAL_URL=https://$MAIL_HOST
AUTH_REQUIRE_TOKENS=False

# Forwarding - SRS
SRS_SENDER_DOMAIN=$DOMAIN
SRS_SECRET=$SRS_SECRET
EOV

# 4. Generate UI Overrides
# ---------------------------

# Branded CSS
cat > overrides/static/branding.css <<EOC
/* 1. Logo Area Branding */
.brand-link { background-color: $BRAND_COLOR !important; color: #fff !important; }
.brand-image { content: url("$LOGO_URL"); max-height: 33px; width: auto; opacity: 1 !important; }

/* 2. Footer Branding */
.main-footer { display: flex; justify-content: flex-end; align-items: center; font-size: 0; padding: 10px 20px; background: transparent; border-top: 1px solid rgba(0,0,0,0.05); min-height: 50px !important; z-index: 1000; position: relative; }
.main-footer::after { content: "Powered By $BRAND_NAME (v. 2024.06)"; font-size: 0.72rem; color: #999; opacity: 0.6; font-weight: 300; letter-spacing: 0.3px; }
.main-footer strong, .main-footer .fa-pull-right, .main-footer a, .main-footer i { display: none !important; }
EOC

# Sidebar UI (Logged In)
cat > overrides/templates/ui/sidebar.html <<EOS
<div class="sidebar">
  <nav class="mt-2">
    <ul class="nav nav-pills nav-sidebar flex-column">
      <li class="nav-item">
        <a href="/" class="nav-link"><i class="nav-icon fas fa-home"></i><p>Back to Mail Hub</p></a>
      </li>
      <li class="nav-header text-uppercase text-primary">{% trans %}My account{% endtrans %}</li>
      <li class="nav-item"><a href="{{ url_for('.user_settings') }}" class="nav-link"><i class="nav-icon fas fa-cog"></i><p>{% trans %}Settings{% endtrans %}</p></a></li>
      <li class="nav-item"><a href="{{ url_for('.password') }}" class="nav-link"><i class="nav-icon fas fa-lock"></i><p>{% trans %}Update password{% endtrans %}</p></a></li>
      {%- if current_user.manager_of or current_user.global_admin %}
      <li class="nav-header text-uppercase text-primary">{% trans %}Administration{% endtrans %}</li>
      <li class="nav-item"><a href="{{ url_for('.domain_list') }}" class="nav-link"><i class="nav-icon fas fa-envelope"></i><p>{% trans %}Mail domains{% endtrans %}</p></a></li>
      {%- endif %}
      <li class="nav-header text-uppercase text-primary">Navigation</li>
      <li class="nav-item"><a href="/webmail/" class="nav-link"><i class="nav-icon far fa-address-book"></i><p>Roundcube</p></a></li>
      <li class="nav-item"><a href="/snappymail/" class="nav-link"><i class="nav-icon fas fa-bolt"></i><p>SnappyMail</p></a></li>
      <li class="nav-item" style="margin-top: 10px;"><a href="{{ url_for('sso.logout') }}" class="nav-link"><i class="nav-icon fas fa-sign-out-alt"></i><p>{% trans %}Sign out{% endtrans %}</p></a></li>
    </ul>
  </nav>
</div>
EOS

# Sidebar SSO (Guest)
cat > overrides/templates/sso/sidebar_sso.html <<EOS
<div class="sidebar">
  <nav class="mt-2">
    <ul class="nav nav-pills nav-sidebar flex-column">
      <li class="nav-header text-uppercase text-primary">Navigation</li>
      <li class="nav-item"><a href="/" class="nav-link"><i class="nav-icon fas fa-home"></i><p>Back to Mail Hub</p></a></li>
      <li class="nav-item"><a href="{{ url_for('sso.login') }}" class="nav-link"><i class="nav-icon fas fa-sign-in-alt"></i><p>{% trans %}Sign in{% endtrans %}</p></a></li>
      {%- if signup_domains %}<li class="nav-item"><a href="{{ url_for('ui.user_signup') }}" class="nav-link"><i class="nav-icon fa fa-user-plus"></i><p>{% trans %}Sign up{% endtrans %}</p></a></li>{%- endif %}
    </ul>
  </nav>
</div>
EOS

# Base Templates (Correct Imports & Layout)
for T in ui/base.html sso/base_sso.html; do
  IMPORTS='{%- import "macros.html" as macros %} {%- import "bootstrap/utils.html" as utils %}'
  [[ "$T" == "ui/base.html" ]] && IMPORTS='{%- import "utils.html" as utils -%}'
  
  cat > overrides/templates/$T <<EOB
$IMPORTS
<!DOCTYPE html><html><head><meta charset="utf-8"><title>{{ config['SITENAME'] }}</title><meta name="viewport" content="width=device-width, initial-scale=1"><link rel="stylesheet" href="{{ url_for('static', filename='vendor.css') }}"><link rel="stylesheet" href="{{ url_for('static', filename='app.css') }}"><link rel="stylesheet" href="{{ url_for('static', filename='branding.css') }}"></head>
<body class="hold-transition sidebar-mini"><div class="wrapper">
<aside class="main-sidebar sidebar-dark-primary elevation-4">
  <a href="/" class="brand-link"><img src="$LOGO_URL" class="brand-image img-circle elevation-3"><span class="brand-text font-weight-light">$BRAND_NAME</span></a>
  <div class="sidebar">{% include "$(basename $T | sed 's/base/sidebar/')" %}</div>
</aside>
<div class="content-wrapper">
  <section class="content-header">
    <div class="container-fluid">
      <div class="row mb-2">
        <div class="col-sm-6"><h1>{% block title %}{% endblock %}</h1></div>
        <div class="col-sm-6">{% block main_action %}{% endblock %}</div>
      </div>
    </div>
  </section>
  <div class="content">
    {{ utils.flashed_messages(container=False, default_category='success') }}
    <div class="container-fluid" style="padding-top:20px;">{% block content %}{% endblock %}</div>
  </div>
</div>
<footer class="main-footer"></footer>
</div><script src="{{ url_for('static', filename='vendor.js') }}"></script><script src="{{ url_for('static', filename='app.js') }}"></script></body></html>
EOB
done

# Client Setup Overrides (Adds Security Tips)
cat > overrides/templates/ui/client.html <<EOS
{%- extends "base.html" %}

{%- block title %}
{% trans %}Client setup{% endtrans %}
{%- endblock %}

{%- block subtitle %}
{% trans %}configure your email client{% endtrans %}
{%- endblock %}

{%- block content %}
<div class="alert alert-info" style="margin-top: 15px;">
  <h5><i class="icon fas fa-shield-alt"></i> Advanced Security: Authentication Tokens</h5>
  While you can use your regular email password below, we highly recommend generating an <b>Authentication Token</b> (App Password).<br>
  Go to <a href="/admin/token/list">Settings -> Authentication tokens</a> to create a unique password specifically for your phone or email app. If your device is ever lost, you can instantly revoke its access without changing your main password.
</div>

{%- call macros.table(title=_("Incoming mail"), datatable=False) %}
  <tbody>
    <tr><th>{% trans %}Mail protocol{% endtrans %}</th><td>IMAP</td></tr>
    <tr><th>{% trans %}TCP port{% endtrans %}</th><td>{{ "143" if config["TLS_FLAVOR"] == "notls" else "993 (TLS)" }}</td></tr>
    <tr><th>{% trans %}Server name{% endtrans %}</th><td><pre class="pre-config border bg-light">{{ config["HOSTNAME"] }}</pre></td></tr>
    <tr><th>{% trans %}Username{% endtrans %}</th><td><pre class="pre-config border bg-light">{{ current_user if current_user.is_authenticated else "******" }}</pre></td></tr>
    <tr><th>{% trans %}Password{% endtrans %}</th><td><pre class="pre-config border bg-light">*******</pre></td></tr>
  </tbody>
{%- endcall %}

{%- call macros.table(title=_("Outgoing mail"), datatable=False) %}
  <tbody>
    <tr><th>{% trans %}Mail protocol{% endtrans %}</th><td>SMTP</td></tr>
    <tr><th>{% trans %}TCP port{% endtrans %}</th><td>{{ "25" if config["TLS_FLAVOR"] == "notls" else "465 (TLS)" }}</td></tr>
    <tr><th>{% trans %}Server name{% endtrans %}</th><td><pre class="pre-config border bg-light">{{ config["HOSTNAME"] }}</pre></td></tr>
    <tr><th>{% trans %}Username{% endtrans %}</th><td><pre class="pre-config border bg-light">{{ current_user if current_user.is_authenticated else "******" }}</pre></td></tr>
    <tr><th>{% trans %}Password{% endtrans %}</th><td><pre class="pre-config border bg-light">*******</pre></td></tr>
  </tbody>
{%- endcall %}
<blockquote class="mt-4">
  {% trans %}If you use an Apple device,{% endtrans %}
  <a href="/apple.mobileconfig">{% trans %}click here to auto-configure it.{% endtrans %}</a>
</blockquote>
{%- endblock %}
EOS

# Pixel-Perfect Hub Landing Page
cat > overrides/index.html <<EOH
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>$BRAND_NAME | Mail Hub</title><style>body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;background:#0b0d17;color:white;margin:0;display:flex;justify-content:center;align-items:center;min-height:100vh;overflow:hidden}.bg-glow{position:fixed;top:0;left:0;width:100%;height:100%;background:radial-gradient(circle at center,#1a1e35 0%,#0b0d17 100%);z-index:-1}.hub-container{text-align:center;max-width:800px;width:100%}.hero h1{font-size:2.8rem;font-weight:700;margin-bottom:50px;color:#f8f9fa}.services{display:flex;justify-content:center;gap:30px;margin-bottom:60px;flex-wrap:wrap}.card{background:#1a1c26;border-radius:24px;padding:40px 30px;width:260px;box-shadow:0 20px 50px rgba(0,0,0,0.5);transition:.3s ease;display:flex;flex-direction:column;align-items:center}.card:hover{transform:translateY(-5px);background:#1f212d}.icon{font-size:50px;margin-bottom:25px}.card h2{font-size:1.6rem;margin:0 0 8px 0;font-weight:700;color:#fff}.card p{font-size:.9rem;color:#94a3b8;margin-bottom:30px}.btn{display:block;width:100%;padding:12px 0;background:linear-gradient(to right,#7b3fe4,#445ae2);color:white;text-decoration:none;border-radius:12px;font-weight:600;font-size:1rem;transition:opacity .2s}.btn:hover{opacity:0.9}.footer{display:flex;justify-content:center;gap:30px;color:#64748b;font-size:.9rem;margin-top:20px}.footer a{color:#64748b;text-decoration:none}.footer a:hover{color:#94a3b8}</style></head>
<body><div class="bg-glow"></div><div class="hub-container"><div class="hero"><h1>Welcome to your Mail Hub</h1></div><div class="services"><div class="card"><div class="icon">📬</div><h2>Roundcube</h2><p>Reliable & Classic</p><a href="/webmail/" class="btn">Launch</a></div><div class="card"><div class="icon">⚡</div><h2>SnappyMail</h2><p>Fast & Modern</p><a href="/snappymail/" class="btn">Launch</a></div></div><div class="footer"><a href="/sso/login">Admin Portal</a><a href="https://$MAIL_HOST/api">API Reference</a></div></div></body></html>
EOH

# 5. Routing Config
# ---------------------------
cat > overrides/root.conf <<EON
location = / { root /var/www; rewrite ^ /index.html break; }
EON

cat > overrides/snappymail.conf <<EON
location /snappymail/ {
    auth_request /internal/auth/user;
    auth_request_set \$user \$upstream_http_x_user;
    auth_request_set \$token \$upstream_http_x_user_token;

    include /etc/nginx/proxy.conf;
    proxy_set_header X-Remote-User \$user;
    proxy_set_header X-Remote-User-Token \$token;

    proxy_pass http://snappymail/;
    proxy_redirect /webmail/ /snappymail/;

    error_page 403 @sso_login;
}
EON

# 6. Docker Compose Configuration
# ---------------------------
cat > docker-compose.yml <<EOD
version: '2.2'

services:
  front:
    image: ghcr.io/mailu/nginx:2024.06
    restart: always
    env_file: .env
    logging:
      driver: json-file
    ports:
      - "25:25"
      - "465:465"
      - "587:587"
      - "110:110"
      - "995:995"
      - "143:143"
      - "993:993"
      - "127.0.0.1:8090:80"
    volumes:
      - ./certs:/certs:ro
      - ./overrides:/overrides:ro
      - ./overrides/index.html:/var/www/index.html:ro
      - ./dkim:/dkim:ro
    depends_on:
      - admin
      - imap
      - smtp

  admin:
    image: ghcr.io/mailu/admin:2024.06
    restart: always
    env_file: .env
    volumes:
      - ./data:/data
      - ./dkim:/dkim
      - ./overrides/static/branding.css:/app/mailu/static/branding.css:ro
      - ./overrides/templates/ui/sidebar.html:/app/mailu/ui/templates/sidebar.html:ro
      - ./overrides/templates/ui/base.html:/app/mailu/ui/templates/base.html:ro
      - ./overrides/templates/ui/client.html:/app/mailu/ui/templates/client.html:ro
      - ./overrides/templates/sso/sidebar_sso.html:/app/mailu/sso/templates/sidebar_sso.html:ro
      - ./overrides/templates/sso/base_sso.html:/app/mailu/sso/templates/base_sso.html:ro
    depends_on:
      - redis

  redis:
    image: redis:7-alpine
    restart: always
    volumes:
      - ./data/redis:/data

  imap:
    image: ghcr.io/mailu/dovecot:2024.06
    restart: always
    env_file: .env
    volumes:
      - ./data:/data
      - ./dkim:/dkim
    depends_on:
      - redis

  smtp:
    image: ghcr.io/mailu/postfix:2024.06
    restart: always
    env_file: .env
    volumes:
      - ./data:/data
      - ./dkim:/dkim
    depends_on:
      - redis

  antispam:
    image: ghcr.io/mailu/rspamd:2024.06
    restart: always
    env_file: .env
    volumes:
      - ./data:/data
      - ./dkim:/dkim
    depends_on:
      - redis

  webmail:
    image: ghcr.io/mailu/webmail:2024.06
    restart: always
    env_file: .env
    volumes:
      - ./data:/data
      - ./dkim:/dkim
      - ./overrides/webmail_php.ini:/etc/php83/conf.d/99_max_size.ini:ro
    depends_on:
      - imap
      - smtp

  snappymail:
    image: ghcr.io/mailu/webmail:2024.06
    restart: always
    env_file: .env
    environment:
      - WEBMAIL=snappymail
      - WEB_WEBMAIL=/snappymail
    volumes:
      - ./data:/data
      - ./dkim:/dkim
      - ./overrides/webmail_php.ini:/etc/php83/conf.d/99_max_size.ini:ro
    depends_on:
      - imap
      - smtp

networks:
  default:
    driver: bridge
    ipam:
      config:
        - subnet: 172.16.240.0/24
EOD

docker compose up -d --force-recreate
echo "✅ PIXEL-PERFECT RavactHub Deployment complete!"
