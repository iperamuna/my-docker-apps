# Grafana & Prometheus Monitoring Stack

This directory contains the automated installation scripts and configuration templates for deploying a **Grafana** and **Prometheus** monitoring stack on your servers.

## Features
- **Grafana Enterprise**: Analytics & visualization platform for all your metrics.
- **Prometheus**: Time-series database to collect and store the metrics.
- **Node Exporter**: Deployed automatically to monitor the host machine's hardware and OS metrics.
- **Automated Reverse Proxy**: Integrates with Nginx and Let's Encrypt (Certbot) to secure your dashboard automatically via HTTPS.

## Installation Methods

### 1. Interactive Installation
The easiest way to install. Simply run the script and answers the prompts regarding your preferred domain name, passwords, and whether to generate SSL certificates.

```bash
sudo bash setup-grafana.sh
```

### 2. Automated (Non-Interactive) Installation
You can bypass all the prompts by passing environment variables and running with the `--no-interaction` flag. This is ideal if you are calling this script from an Ansible playbook or CI/CD pipeline.

```bash
# Example
GRAFANA_DOMAIN=monitor.yourdomain.com \
GRAFANA_ADMIN_USER=admin \
GRAFANA_ADMIN_PASS=supersecret \
SETUP_NGINX=true SETUP_SSL=true ADMIN_EMAIL=admin@yourdomain.com \
sudo bash setup-grafana.sh --no-interaction
```

## Post-Installation
After the script finishes, your dashboard will be available at your specified domain. Look at the generated `credentials.txt` inside your install directory (default: `/opt/grafana`) to retrieve your login details.

To add the local Prometheus database to Grafana:
1. Login to Grafana.
2. Go to Data Sources -> Add data source.
3. Select **Prometheus**.
4. Set the URL to `http://prometheus:9090` (this connects over the internal docker network).
5. Click Save & Test.
