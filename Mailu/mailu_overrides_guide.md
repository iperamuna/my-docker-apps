# Mailu UI Overrides & Branding Guide

This guide explains how we customized the Mailu Admin and Login interfaces using **Volume Mount Overrides**. This method ensures your changes are persistent across container restarts and Mailu updates.

## 🛠️ The Override Architecture
Instead of modifying the files inside the Docker containers directly, we use the `overrides/` directory in `/opt/mailu/`. These files are mapped to the internal container paths via `docker-compose.yml`.

### 📂 File Structure
```bash
/opt/mailu/
├── overrides/
│   ├── index.html            # The custom Mail Hub landing page
│   ├── static/
│   │   └── branding.css      # The CSS that handles the footer branding
│   └── templates/
│       ├── ui/
│       │   ├── base.html     # Global layout for the Admin Panel
│       │   └── sidebar.html  # Custom internal sidebar with your links
│       └── sso/
│           ├── base_sso.html # Global layout for the Login Page
│           └── sidebar_sso.html # Custom sidebar for the Login Page
```

## 🎨 How to update Branding
To change your branding name (e.g., from "RavactHub" to "NewBrand"):
1. Open `/opt/mailu/.env`.
2. Update the `BRANDING_NAME` variable.
3. Restart the admin container: `docker restart mailu-admin-1`.

## 🌐 How to update the Mail Hub
To change the links or design of your landing page:
### 1. The Hub Landing Page (`/overrides/index.html`)
The Hub is a custom landing page that routes users to Roundcube, SnappyMail, or the Admin Portal. It uses a high-end "Perfection" design with glassmorphism and gradient buttons.

**Key Design Features:**
- **Icons**: Emoji-based (📬 for Roundcube, ⚡ for SnappyMail).
- **Buttons**: Linear gradient (`#7b3fe4` to `#445ae2`).
- **Admin Link**: Specifically routes to `/sso/login` to bypass standard redirection loops.

**HTML Structure:**
```html
<div class="card">
    <div class="icon">📬</div>
    <h2>Roundcube</h2>
    <p>Reliable & Classic</p>
    <a href="/webmail/" class="btn">Launch</a>
</div>
```

### 2. Global Branding CSS (`/overrides/static/branding.css`)
This file controls the appearance of the sidebar logo and the custom footer across all panels.

```css
/* Sidebar Logo Injection */
.brand-image { content: url("https://ravact.com/logo.png"); opacity: 1 !important; }

/* Custom Footer Branding */
.main-footer::after { 
    content: "Powered By RavactHub (v. 2024.06)";
    font-size: 0.72rem; 
    color: #999;
}
```

## 🗄️ Template Reference
The templates are written in **Jinja2**. 
- To add a new tool to the sidebar, edit `overrides/templates/ui/sidebar.html`.
- To change the footer look globally, edit `overrides/static/branding.css`.

## 🔄 Persistence
Since these files live on your host VPS and are mounted as volumes, they will **NEVER** be overwritten by a `docker compose pull` or `docker compose up`. Your branding is permanent!
