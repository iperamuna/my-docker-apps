# Mailu API Quick-Start Guide

Your Mailu server API is now enabled and accessible. You can use it to automate user creation, domain management, and more.

## 1. Authentication
All API requests require the `X-API-Token` header.

- **Header Name**: `Authorization`
- **Your Token**: `6624E2F262D999D741EA76B6A3C5866A`

## 2. Base URLs
- **Swagger UI (Web)**: `https://mail.ravact.com/api`
- **JSON Spec**: `https://mail.ravact.com/api/v1/swagger.json`
- **REST Root**: `https://mail.ravact.com/api/v1`

## 3. Example Request (cURL)
To list all users on your domain:
```bash
curl -X GET "https://mail.ravact.com/api/v1/user" \
     -H "Authorization: 6624E2F262D999D741EA76B6A3C5866A"
```

## 4. Importing to Apidog
1.  Open **Apidog**.
2.  Click **Import**.
3.  Select the **[mailu_api_spec.json](./mailu_api_spec.json)** file from this folder.
4.  Apidog will automatically identify the endpoints (User, Domain, Alias, etc.).
5.  In the **Environment Settings**, add a global header:
    - `X-API-Token`: `6624E2F262D999D741EA76B6A3C5866A`

## 5. Core Endpoints
| Feature | Endpoint | Method |
| :--- | :--- | :--- |
| **Users** | `/user` | GET (List) / POST (Create) |
| **Specific User** | `/user/{email}` | GET / PATCH / DELETE |
| **Domains** | `/domain` | GET (List) / POST (Create) |
| **Aliases** | `/alias` | GET (List) / POST (Create) |

## 6. Rotating the Token
If your token is compromised, use the **[rotate-api-token.sh](./rotate-api-token.sh)** script:
1.  **Upload to server**: `rotate-api-token.sh`
2.  **Run it**:
    ```bash
    chmod +x rotate-api-token.sh
    ./rotate-api-token.sh
    ```
    *This will update the `.env`, restart the `admin` service, and print your new token.*

---
*Generated for Ravact Mailu Deployment*
