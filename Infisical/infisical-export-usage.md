# Infisical Export Script

A safe Infisical dotenv export helper for macOS/Linux.

This script:

- Exports secrets from Infisical
- Merges them into an existing `.env`
- Updates only matching keys
- Preserves unrelated values
- Can configure `INFISICAL_API_URL`
- Automatically detects `zsh` or `bash`
- Safe for CI/CD by hiding values by default

---

# Features

## Safe `.env` Updates

Instead of replacing the entire `.env`:

- Existing keys are updated
- Missing keys are added
- Other keys remain untouched

---

## Automatic Shell Detection

Supports:

- zsh
- bash

Automatically updates:

- `~/.zshrc`
- `~/.bashrc`

---

## Self-Hosted Infisical Support

Can automatically configure:

```bash
INFISICAL_API_URL
```

Example:

```bash
./infisical-export.sh \
  --api-url=https://infisical.example.com
```

---

# Requirements

- macOS or Linux
- Infisical CLI
- zsh or bash

---

# Install Infisical CLI

Using Homebrew:

```bash
brew install infisical/get-cli/infisical
```

Verify:

```bash
infisical --version
```

Login:

```bash
infisical login
```

---

# Make Executable

```bash
chmod +x infisical-export.sh
```

---

# Usage

## Configure API URL Only

```bash
./infisical-export.sh \
  --api-url=https://infisical.example.com
```

This will:

- Detect shell
- Update shell config
- Replace existing value
- Verify configuration

---

## Export Secrets

```bash
./infisical-export.sh \
  --env=prod \
  --target=.env
```

---

## Export With Self-Hosted API

```bash
./infisical-export.sh \
  --api-url=https://infisical.example.com \
  --env=prod \
  --target=.env
```

---

## Show Secret Values

```bash
./infisical-export.sh \
  --env=prod \
  --target=.env \
  --show-values
```

---

# Parameters

| Parameter | Required | Description |
|---|---|---|
| `--env` | No* | Infisical environment |
| `--target` | No* | Target dotenv file |
| `--api-url` | No | Self-hosted Infisical URL |
| `--show-values` | No | Show old/new secret values |
| `--help` | No | Show help |

\* `--env` and `--target` are required only when exporting secrets.

---

# Example Output

## Safe Mode

```text
========================================
Infisical Export Summary
========================================

Added Keys   : 2
Updated Keys : 5

Detailed values hidden
Use --show-values to display old/new values
```

---

## Verbose Mode

```text
-------------
Updated
-------------

KEY=DB_PASSWORD
OLD=old-password
NEW=new-password
```

---

# CI/CD Example

## GitHub Actions

```yaml
- name: Export Secrets
  run: |
    chmod +x infisical-export.sh
    ./infisical-export.sh --env=prod --target=.env
```

---

# Recommended .gitignore

```gitignore
.env
.env.*
```

---

# Security Recommendations

- Avoid `--show-values` in CI/CD
- Never commit `.env`
- Rotate secrets periodically
- Use separate environments

---

# Behavior Notes

The script:

- Does NOT delete old keys
- Does NOT overwrite unrelated variables
- Creates missing target files
- Replaces existing `INFISICAL_API_URL`

---

# Help

```bash
./infisical-export.sh --help
```