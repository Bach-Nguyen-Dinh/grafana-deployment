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

# Check if Grafana is ready
MAX_RETRIES=30
RETRY_COUNT=0
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
    echo -e "${RED}Grafana failed to start. Check logs with: docker-compose logs grafana${NC}"
    exit 1
fi

# Dashboard URL (using the UID from your dashboard JSON)
DASHBOARD_URL="http://localhost:3000/d/debfk50vlpszker/system-monito-and-control-topaz-wip"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Grafana: http://localhost:3000"
echo -e "Username: admin"
echo -e "Password: admin"
echo -e ""
echo -e "Dashboard: ${DASHBOARD_URL}"
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