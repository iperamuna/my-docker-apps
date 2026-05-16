# Tutorial: Deploying Docker Apps via Komodo UI

This guide explains how to deploy a Docker application using Komodo while ensuring all files (compose, .env, and data) are neatly organized in a specific directory like `/opt/my-app`.

---

## 1. Prerequisites
*   A running **Komodo Core** (e.g., `komodo.ravact.com`).
*   A target server with the **Periphery Agent** installed (using the `setup-periphery-agent.sh` script).

---

## 2. Create the Stack
1.  Log in to your Komodo Dashboard.
2.  Go to **Stacks** on the left menu.
3.  Click **Add Stack**.
4.  **Name**: Enter your application name (e.g., `uptime-kuma`).
5.  **Server**: Select the server where you want to deploy.

---

## 3. Configure Deployment Paths
To keep your server clean, we want all files to live in `/opt/{app-name}`.

1.  Go to the **Settings** or **General** tab of the Stack.
2.  **Base Directory**: Set this to `/opt/uptime-kuma`.
3.  **Env File Path**: Set this to `.env`. This tells Komodo to write your variables to a physical file on disk.

> [!TIP]
> Setting the **Base Directory** ensures that when you use relative paths in your Compose file (like `./data`), they will resolve to `/opt/uptime-kuma/data`.

---

## 4. Setup Environment Variables
1.  Go to the **Environment** tab.
2.  Add your variables (e.g., `DB_PASSWORD`, `PORT`, etc.).
3.  Komodo will automatically generate the `.env` file in your Base Directory during deployment.

---

## 5. Write the Docker Compose
1.  Go to the **Compose** tab.
2.  Paste your `docker-compose.yml` content.
3.  **Crucial**: Use relative paths for volumes to ensure they stay inside your `/opt` folder.

**Example:**
```yaml
services:
  uptime-kuma:
    image: louislam/uptime-kuma:1
    container_name: uptime-kuma
    ports:
      - 3001:3001
    volumes:
      - ./data:/app/data  # Resolves to /opt/uptime-kuma/data
    restart: always
```

---

## 6. Deploy and Monitor
1.  Click **Save** to store your configuration.
2.  Click **Deploy**.
3.  **Watch the Logs**: The Periphery Agent will pull the images and start the containers.
4.  **Verify on Server**: If you SSH into your server, you will now see:
    ```bash
    ls -la /opt/uptime-kuma
    # Output:
    # docker-compose.yml
    # .env
    # data/
    ```

---

## Troubleshooting
*   **Permission Denied**: The Periphery Agent usually runs as root and can create folders in `/opt`. If it fails, ensure the service has appropriate permissions.
*   **Connection Error**: Ensure the target server's port `8120` is reachable from the Komodo Core server.
