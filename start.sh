#!/bin/bash

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if Docker is running
echo -e "${YELLOW}Checking Docker...${NC}"
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Docker is not running. Please start Docker and try again.${NC}"
    exit 1
fi

echo -e "${GREEN}Docker is running.${NC}"

# Start containers with built-in health checks
echo -e "${YELLOW}Starting containers...${NC}"
echo -e "${YELLOW}Docker Compose will wait for health checks to pass...${NC}"
docker compose up -d --wait

# Check if services started successfully
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to start services. Check logs with: docker compose logs${NC}"
    exit 1
fi

echo -e "${GREEN}All services are healthy and ready!${NC}"

# Wait a moment for dashboard provisioning to complete
echo -e "${YELLOW}Waiting for dashboard provisioning...${NC}"
sleep 5

# Extract dashboard info from JSON file
DASHBOARD_DIR="./grafana/dashboards"
DASHBOARD_JSON=$(find "$DASHBOARD_DIR" -name "*.json" -type f | head -1)

if [ -z "$DASHBOARD_JSON" ]; then
    echo -e "${RED}Warning: No dashboard JSON found in $DASHBOARD_DIR${NC}"
    DASHBOARD_URL="http://localhost:3000"
else
    # Extract UID and title from JSON
    if command -v jq > /dev/null 2>&1; then
        DASHBOARD_UID=$(jq -r '.uid // empty' "$DASHBOARD_JSON")
        DASHBOARD_TITLE=$(jq -r '.title // empty' "$DASHBOARD_JSON")
    else
        # Fallback to grep/sed if jq not available
        DASHBOARD_UID=$(grep -m 1 '"uid"' "$DASHBOARD_JSON" | grep -v 'grafana\|DS_INFLUXDB' | sed 's/.*"uid": *"\([^"]*\)".*/\1/' | head -1)
        DASHBOARD_TITLE=$(grep -m 1 '"title"' "$DASHBOARD_JSON" | sed 's/.*"title": *"\([^"]*\)".*/\1/')
    fi

    if [ -n "$DASHBOARD_UID" ]; then
        # Convert title to URL-friendly slug (lowercase, spaces to dashes, remove special chars)
        DASHBOARD_SLUG=$(echo "$DASHBOARD_TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g' | sed 's/[^a-z0-9-]//g')
        # Use environment variable to enable kiosk mode (default: off)
        if [ "${KIOSK_MODE:-false}" = "true" ]; then
            DASHBOARD_URL="http://localhost:3000/d/$DASHBOARD_UID/$DASHBOARD_SLUG?orgId=1&from=now-5m&to=now&timezone=browser&refresh=1s&kiosk=1"
        else
            DASHBOARD_URL="http://localhost:3000/d/$DASHBOARD_UID/$DASHBOARD_SLUG?orgId=1&from=now-5m&to=now&timezone=browser&refresh=1s"
        fi
    else
        echo -e "${YELLOW}Warning: Could not extract dashboard UID from $DASHBOARD_JSON${NC}"
        if [ "${KIOSK_MODE:-false}" = "true" ]; then
            DASHBOARD_URL="http://localhost:3000?orgId=1&from=now-5m&to=now&timezone=browser&refresh=1s&kiosk=1"
        else
            DASHBOARD_URL="http://localhost:3000?orgId=1&from=now-5m&to=now&timezone=browser&refresh=1s"
        fi
    fi
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Grafana: http://localhost:3000"
echo -e "Username: admin"
echo -e "Password: admin"
echo -e ""
if [ -n "$DASHBOARD_TITLE" ]; then
    echo -e "Dashboard: $DASHBOARD_TITLE"
fi
echo -e "URL: ${DASHBOARD_URL}"
echo -e ""
echo -e "InfluxDB: http://localhost:8086"
echo -e "Database: system_metrics"
echo -e "${GREEN}========================================${NC}"

# Open browser (handle root user properly)
# Function to open browser with better compatibility
open_browser() {
    local url="$1"

    # Try different browsers in order of preference
    if command -v google-chrome > /dev/null 2>&1; then
        google-chrome --new-window "$url" > /dev/null 2>&1 &
        return 0
    elif command -v chromium-browser > /dev/null 2>&1; then
        chromium-browser --new-window "$url" > /dev/null 2>&1 &
        return 0
    elif command -v firefox > /dev/null 2>&1; then
        # Firefox specific: use new-window to avoid profile locking issues
        firefox --new-window "$url" > /dev/null 2>&1 &
        return 0
    elif command -v xdg-open > /dev/null 2>&1; then
        xdg-open "$url" > /dev/null 2>&1 &
        return 0
    elif command -v open > /dev/null 2>&1; then
        open "$url" > /dev/null 2>&1 &
        return 0
    fi

    return 1
}

if [ "$EUID" -eq 0 ] && [ -n "$SUDO_USER" ]; then
    echo -e "${YELLOW}Opening dashboard in browser as user $SUDO_USER...${NC}"
    if ! sudo -u "$SUDO_USER" DISPLAY="${DISPLAY:-:0}" bash -c "$(declare -f open_browser); open_browser '$DASHBOARD_URL'"; then
        echo -e "${YELLOW}Could not automatically open browser. Please open manually:${NC}"
        echo -e "${DASHBOARD_URL}"
    fi
elif [ "$EUID" -eq 0 ]; then
    echo -e "${YELLOW}Running as root. Please open the dashboard manually:${NC}"
    echo -e "${DASHBOARD_URL}"
else
    echo -e "${YELLOW}Opening dashboard in browser...${NC}"
    if ! open_browser "$DASHBOARD_URL"; then
        echo -e "${YELLOW}Could not automatically open browser. Please open manually:${NC}"
        echo -e "${DASHBOARD_URL}"
    fi
fi