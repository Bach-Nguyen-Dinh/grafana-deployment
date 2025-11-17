#!/bin/bash

echo "Stopping containers..."
docker-compose down

echo "Containers stopped."
echo ""
echo "To remove all data (volumes), run: docker-compose down -v"
