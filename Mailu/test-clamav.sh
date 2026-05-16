#!/bin/bash
# ---------------------------------------------------------
# Mailu ClamAV Diagnostics Script
# ---------------------------------------------------------

MAILU_DIR="/opt/mailu"
COMPOSE_FILE="$MAILU_DIR/docker-compose.yml"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🛡️ Mailu ClamAV Diagnostics Tool${NC}"
echo "--------------------------------"

# 1. Check if antivirus is enabled in config
echo -n "Checking configuration... "
if ! grep -q "antivirus:" "$COMPOSE_FILE" 2>/dev/null; then
    echo -e "${RED}Not configured${NC}"
    echo "❌ Antivirus is not enabled in docker-compose.yml"
    echo "Use manage-mailu-features.sh to enable it first."
    exit 1
fi
echo -e "${GREEN}OK${NC}"

# 2. Check if container is running
echo -n "Checking container status... "
cd "$MAILU_DIR" || exit 1
AV_CONTAINER=$(docker compose ps -q antivirus 2>/dev/null)

if [ -z "$AV_CONTAINER" ]; then
    echo -e "${RED}Not running${NC}"
    echo "❌ Antivirus container is not running."
    echo "Try running: docker compose up -d antivirus"
    exit 1
fi
echo -e "${GREEN}Running (ID: ${AV_CONTAINER:0:8})${NC}"

# 3. Check if ClamAV daemon is responding
echo -n "Checking ClamAV daemon... "
if docker exec "$AV_CONTAINER" clamd --version >/dev/null 2>&1; then
    VERSION=$(docker exec "$AV_CONTAINER" clamd --version)
    echo -e "${GREEN}OK ($VERSION)${NC}"
else
    echo -e "${YELLOW}Warning (Could not get version)${NC}"
fi

# 4. Perform EICAR test
echo "Running EICAR test..."
# Standard EICAR test string
EICAR='X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'

# Write the test file inside the container's tmp directory
docker exec "$AV_CONTAINER" sh -c "echo -n '$EICAR' > /tmp/eicar.com"

# Scan the file using clamdscan (uses the daemon, much faster and tests the active service)
SCAN_RESULT=$(docker exec "$AV_CONTAINER" clamdscan /tmp/eicar.com 2>&1)

# Clean up
docker exec "$AV_CONTAINER" rm -f /tmp/eicar.com

if echo "$SCAN_RESULT" | grep -q "FOUND"; then
    echo -e "${GREEN}✅ SUCCESS: ClamAV detected the test virus!${NC}"
    # Print the specific detection string (usually Win.Test.EICAR_HDB-1 or similar)
    DETECTION=$(echo "$SCAN_RESULT" | grep "FOUND" | awk '{print $2}')
    echo "Detection signature: $DETECTION"
else
    echo -e "${RED}❌ FAILED: ClamAV did not detect the test virus.${NC}"
    echo "This might happen if the signatures are still downloading/loading."
    echo ""
    echo "Raw scan output:"
    echo "$SCAN_RESULT"
    echo ""
    echo "You can check the logs for errors:"
    echo "docker compose -f $COMPOSE_FILE logs --tail=50 antivirus"
fi

echo "--------------------------------"
