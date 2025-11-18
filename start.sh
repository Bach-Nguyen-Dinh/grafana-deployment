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

# Start containers
echo -e "${YELLOW}Starting containers...${NC}"
docker compose up -d

# Wait for services to be ready
echo -e "${YELLOW}Waiting for services to start...${NC}"
sleep 10

# Check if InfluxDB is ready
MAX_RETRIES=30
RETRY_COUNT=0
echo -e "${YELLOW}Checking InfluxDB...${NC}"
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s http://localhost:8086/ping > /dev/null 2>&1; then
        echo -e "${GREEN}InfluxDB is ready!${NC}"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo -e "${YELLOW}Waiting for InfluxDB... ($RETRY_COUNT/$MAX_RETRIES)${NC}"
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${RED}InfluxDB failed to start. Check logs with: docker compose logs influxdb${NC}"
    exit 1
fi

# Check if Grafana is ready
RETRY_COUNT=0
echo -e "${YELLOW}Checking Grafana...${NC}"
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s http://localhost:3000/api/health > /dev/null 2>&1; then
        echo -e "${GREEN}Grafana is ready!${NC}"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo -e "${YELLOW}Waiting for Grafana... ($RETRY_COUNT/$MAX_RETRIES)${NC}"
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${RED}Grafana failed to start. Check logs with: docker compose logs grafana${NC}"
    exit 1
fi

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
        DASHBOARD_URL="http://localhost:3000/d/$DASHBOARD_UID/$DASHBOARD_SLUG"
    else
        echo -e "${YELLOW}Warning: Could not extract dashboard UID from $DASHBOARD_JSON${NC}"
        DASHBOARD_URL="http://localhost:3000"
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
if [ "$EUID" -eq 0 ] && [ -n "$SUDO_USER" ]; then
    echo -e "${YELLOW}Opening dashboard in browser as user $SUDO_USER...${NC}"
    sudo -u "$SUDO_USER" DISPLAY=:0 xdg-open "$DASHBOARD_URL" 2>/dev/null || \
    sudo -u "$SUDO_USER" DISPLAY=:0 firefox "$DASHBOARD_URL" 2>/dev/null || \
    echo -e "${YELLOW}Please open the dashboard manually in your browser.${NC}"
elif [ "$EUID" -eq 0 ]; then
    echo -e "${YELLOW}Running as root. Please open the dashboard manually:${NC}"
    echo -e "${DASHBOARD_URL}"
elif command -v xdg-open > /dev/null; then
    echo -e "${YELLOW}Opening dashboard in browser...${NC}"
    xdg-open "$DASHBOARD_URL" 2>/dev/null
elif command -v open > /dev/null; then
    echo -e "${YELLOW}Opening dashboard in browser...${NC}"
    open "$DASHBOARD_URL"
else
    echo -e "${YELLOW}Please open the dashboard manually in your browser.${NC}"
fi