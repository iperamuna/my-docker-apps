#!/bin/bash
# ==============================================================================
# Docker & System Resource Usage Monitor
# ==============================================================================

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
BLUE='\033[1;34m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
NC='\033[0m'

echo -e "${CYAN}=========================================================================${NC}"
echo -e "${CYAN}                  DOCKER & APP RESOURCE USAGE MONITOR                    ${NC}"
echo -e "${CYAN}=========================================================================${NC}"

if [[ $EUID -ne 0 ]]; then
   echo -e "⚠️  Note: Running without sudo. Some disk usage info might require sudo.\n"
fi

echo -e "${BLUE}▶ 🧠 Container RAM & CPU Usage${NC}"
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.CPUPerc}}" | awk 'NR==1 {print "\033[1;32m" $0 "\033[0m"} NR>1 {print $0}'

echo -e "\n${BLUE}▶ 💾 Container Disk Usage (Writable Layers)${NC}"
docker ps -a -s --format "table {{.Names}}\t{{.Size}}" | awk 'NR==1 {print "\033[1;32m" $0 "\033[0m"} NR>1 {print $0}'

echo -e "\n${BLUE}▶ 🗄️  Application Data Directories (/opt/)${NC}"
if [ -d "/opt" ]; then
    if command -v sudo &>/dev/null && [[ $EUID -ne 0 ]]; then
        sudo du -shc /opt/* 2>/dev/null | sort -h || echo "Could not read /opt folders."
    else
        du -shc /opt/* 2>/dev/null | sort -h || echo "Could not read /opt folders."
    fi
else
    echo "/opt directory not found."
fi

echo -e "\n${BLUE}▶ 🐳 Docker System Data Summary${NC}"
docker system df | awk 'NR==1 {print "\033[1;32m" $0 "\033[0m"} NR>1 {print $0}'

echo -e "\n${CYAN}=========================================================================${NC}"
