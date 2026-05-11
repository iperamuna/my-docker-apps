#!/bin/zsh

# -----------------------------------
# Infisical Export Helper
# -----------------------------------

set -e

SHOW_OUTPUT=false

ENVIRONMENT=""
TARGET_FILE=""
API_URL=""

# -----------------------------------
# Parse Arguments
# -----------------------------------

for arg in "$@"
do
  case $arg in

    --env=*)
      ENVIRONMENT="${arg#*=}"
      shift
      ;;

    --target=*)
      TARGET_FILE="${arg#*=}"
      shift
      ;;

    --api-url=*)
      API_URL="${arg#*=}"
      shift
      ;;

    --show-values)
      SHOW_OUTPUT=true
      shift
      ;;

    --help)
      echo "Usage:"
      echo ""
      echo "  Configure API URL only:"
      echo "    ./infisical-export.sh --api-url=https://example.com"
      echo ""
      echo "  Export secrets:"
      echo "    ./infisical-export.sh --env=prod --target=.env"
      echo ""
      echo "  Export with API URL setup:"
      echo "    ./infisical-export.sh \\"
      echo "      --api-url=https://example.com \\"
      echo "      --env=prod \\"
      echo "      --target=.env"
      echo ""
      echo "  Show secret values:"
      echo "    ./infisical-export.sh --env=prod --target=.env --show-values"
      echo ""
      exit 0
      ;;

    *)
      echo "Unknown argument: $arg"
      exit 1
      ;;

  esac
done

# -----------------------------------
# Configure INFISICAL_API_URL
# -----------------------------------

if [ -n "$API_URL" ]; then

  CURRENT_SHELL=$(basename "$SHELL")

  if [ "$CURRENT_SHELL" = "zsh" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
  elif [ "$CURRENT_SHELL" = "bash" ]; then
    SHELL_CONFIG="$HOME/.bashrc"
  else
    echo "Unsupported shell: $CURRENT_SHELL"
    exit 1
  fi

  echo ""
  echo "========================================"
  echo "Configuring INFISICAL_API_URL"
  echo "========================================"
  echo "Shell       : $CURRENT_SHELL"
  echo "Config File : $SHELL_CONFIG"
  echo ""

  # Remove existing entry if present
  if grep -q "^export INFISICAL_API_URL=" "$SHELL_CONFIG"; then
    sed -i '' '/^export INFISICAL_API_URL=/d' "$SHELL_CONFIG"
    echo "Existing INFISICAL_API_URL removed"
  fi

  # Add new entry
  echo "export INFISICAL_API_URL=\"$API_URL\"" >> "$SHELL_CONFIG"

  echo "New INFISICAL_API_URL added"

  # Load into current shell
  export INFISICAL_API_URL="$API_URL"

  echo ""
  echo "Verification"
  echo "-------------"

  CURRENT_VALUE=$(printenv INFISICAL_API_URL)

  if [ "$CURRENT_VALUE" = "$API_URL" ]; then
    echo "SUCCESS"
    echo "INFISICAL_API_URL=$CURRENT_VALUE"
  else
    echo "FAILED"
    echo "Expected : $API_URL"
    echo "Actual   : $CURRENT_VALUE"
    exit 1
  fi

  echo ""
fi

# -----------------------------------
# If only API URL setup requested
# -----------------------------------

if [ -z "$ENVIRONMENT" ] && [ -z "$TARGET_FILE" ]; then
  echo "No export operation requested"
  exit 0
fi

# -----------------------------------
# Validate Export Inputs
# -----------------------------------

if [ -z "$ENVIRONMENT" ]; then
  echo "Error: --env is required"
  exit 1
fi

if [ -z "$TARGET_FILE" ]; then
  echo "Error: --target is required"
  exit 1
fi

# -----------------------------------
# Ensure Target Exists
# -----------------------------------

if [ ! -f "$TARGET_FILE" ]; then
  touch "$TARGET_FILE"
fi

TEMP_FILE=$(mktemp)

echo ""
echo "========================================"
echo "Exporting Secrets"
echo "========================================"
echo "Environment : $ENVIRONMENT"
echo "Target File : $TARGET_FILE"
echo ""

# -----------------------------------
# Export From Infisical
# -----------------------------------

infisical export --env="$ENVIRONMENT" --format=dotenv > "$TEMP_FILE"

ADDED_KEYS=()
UPDATED_KEYS=()

# -----------------------------------
# Merge Secrets
# -----------------------------------

while IFS= read -r line || [ -n "$line" ]
do

  # Skip empty lines
  [[ -z "$line" ]] && continue

  # Skip comments
  [[ "$line" =~ ^# ]] && continue

  KEY="${line%%=*}"
  NEW_VALUE="${line#*=}"

  if grep -q "^${KEY}=" "$TARGET_FILE"; then

    OLD_LINE=$(grep "^${KEY}=" "$TARGET_FILE" | head -n 1)
    OLD_VALUE="${OLD_LINE#*=}"

    if [ "$OLD_VALUE" != "$NEW_VALUE" ]; then

      sed -i '' "s|^${KEY}=.*|${line}|" "$TARGET_FILE"

      UPDATED_KEYS+=(
        "KEY=${KEY}
OLD=${OLD_VALUE}
NEW=${NEW_VALUE}"
      )

    fi

  else

    echo "$line" >> "$TARGET_FILE"

    ADDED_KEYS+=(
      "KEY=${KEY}
VALUE=${NEW_VALUE}"
    )

  fi

done < "$TEMP_FILE"

rm -f "$TEMP_FILE"

# -----------------------------------
# Summary
# -----------------------------------

echo ""
echo "========================================"
echo "Infisical Export Summary"
echo "========================================"
echo ""

echo "Added Keys   : ${#ADDED_KEYS[@]}"
echo "Updated Keys : ${#UPDATED_KEYS[@]}"
echo ""

if [ "$SHOW_OUTPUT" = true ]; then

  if [ ${#ADDED_KEYS[@]} -gt 0 ]; then

    echo "-------------"
    echo "Added"
    echo "-------------"

    for item in "${ADDED_KEYS[@]}"
    do
      echo "$item"
      echo ""
    done
  fi

  if [ ${#UPDATED_KEYS[@]} -gt 0 ]; then

    echo "-------------"
    echo "Updated"
    echo "-------------"

    for item in "${UPDATED_KEYS[@]}"
    do
      echo "$item"
      echo ""
    done
  fi

else

  echo "Detailed values hidden"
  echo "Use --show-values to display old/new values"

fi

echo ""
echo "Done."