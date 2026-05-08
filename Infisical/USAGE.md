# Infisical Usage Guide

This guide covers how to install the Infisical CLI locally or on your servers, and how to effectively integrate it with a Laravel application to maximize both security and performance.

---

## 🛠️ Installing the Infisical CLI

The Infisical CLI is the primary tool used to fetch, manage, and inject secrets into your applications. For full documentation and other platforms, see the [Official CLI Overview](https://infisical.com/docs/cli/overview).

### macOS
If you are on macOS, the easiest way to install the CLI is via Homebrew:
```bash
brew install infisical/get-cli/infisical
```

*To update later, run:* `brew update && brew upgrade infisical`

### Ubuntu / Debian
If you are installing this on your `iperamuna` server or any Ubuntu/Debian-based CI/CD runner:
```bash
curl -1sLf 'https://artifacts-cli.infisical.com/setup.deb.sh' | sudo -E bash
sudo apt-get update && sudo apt-get install -y infisical
```

---

## 🔗 Connecting to Your Self-Hosted Instance

Since you are running a self-hosted instance of Infisical, you must configure the CLI to talk to your custom domain instead of the default Infisical Cloud.

### 1. Set the API URL
Set the `INFISICAL_API_URL` environment variable to point to your self-hosted instance.

**For your local machine:**
Add this to your `~/.bashrc` or `~/.zshrc`:
```bash
export INFISICAL_API_URL="https://infisical.siyalude.io"
```

**For your Ubuntu server (via SSH):**
To make it persistent across SSH sessions on the server, append it to your profile and reload it:
```bash
echo 'export INFISICAL_API_URL="https://infisical.siyalude.io"' >> ~/.bashrc
source ~/.bashrc
```
*(Alternatively, you can append `--domain="https://infisical.siyalude.io"` to every CLI command, but the environment variable is much easier).*

### 2. Log In
Authenticate the CLI with your instance.

**On your local machine:**
```bash
infisical login
```
This will open your local web browser to authenticate.

**On your Ubuntu server (via SSH):**
Because you cannot open a web browser over an SSH connection, use the **interactive** flag (`-i`). This allows you to securely type your email and password directly into the terminal:
```bash
infisical login -i
```

**For automated CI/CD servers:**
Use Machine Identities instead of a personal user account:
```bash
infisical login --method=universal-auth --client-id="<client-id>" --client-secret="<client-secret>"
```

### 3. Initialize Your Codebase
Navigate to the root directory of your Laravel application (or any codebase) and initialize it. This links your local directory to a specific project workspace in your Infisical dashboard.
```bash
cd /path/to/your/laravel/project
infisical init
```
This command generates a small `.infisical.json` file in your directory to track the connection. You should commit this file to version control.

---

## 🚀 Laravel Integration Workflow

Integrating Infisical with Laravel using the native `.env` system provides the best blend of **centralized management**, **transit security**, and **peak runtime performance**. 

Below is the highly recommended workflow for deploying a Laravel application using Infisical.

### Step 1: Export Secrets from Infisical
During your build process or deployment script (e.g., in GitHub Actions or a bash script on your server), use the Infisical CLI to securely pull your production secrets into a standard `.env` file.

```bash
# Export the production environment secrets to .env
infisical export --env=prod --format=dotenv > .env
```

### Step 2: Encrypt the `.env` (Optional but recommended for CI/CD)
If you are building your Laravel artifact in a CI pipeline and shipping it to your server, you should avoid transferring a plaintext `.env` over the wire. Instead, encrypt it natively with Laravel:

```bash
php artisan env:encrypt --key="base64:YOUR_ENCRYPTION_KEY"
```
*(You can then safely delete the raw `.env` file from the CI runner, leaving only the secure `.env.encrypted` file to be uploaded to your server).*

### Step 3: Decrypt on the Server
Once your code lands on your production server, decrypt the `.env` file using the identical key:

```bash
php artisan env:decrypt --key="base64:YOUR_ENCRYPTION_KEY"
```

### Step 4: Cache the Configuration (Critical for Performance)
Finally, run the Laravel config cache command:

```bash
php artisan config:cache
```

**Why this is important:** 
By running `config:cache`, Laravel reads the decrypted `.env` file exactly **once** and compiles all of your configuration into a high-speed PHP array (`bootstrap/cache/config.php`). 

From that moment on, the `.env` file is completely ignored. This prevents PHP from making slow disk reads to parse environment variables on every single web request, giving your application a massive performance boost while keeping your secrets perfectly secure!
