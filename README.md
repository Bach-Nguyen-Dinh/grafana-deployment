# grafana-deployment

A Grafana + InfluxDB monitoring dashboard system using Docker Compose with automated provisioning.

## Overview

This deployment provides a complete monitoring infrastructure with:
- **InfluxDB 1.6.4**: Time-series database for storing system metrics
- **Grafana 12.1.0**: Visualization platform with automated dashboard provisioning
- Automatic datasource and dashboard configuration
- Browser-based kiosk mode for displays

## Prerequisites

- Docker and Docker Compose installed
- sudo access (required for Docker operations)
- `curl` (for health checks)
- `jq` (optional, for better JSON parsing)

## Quick Start

```bash
sudo bash -E start.sh
```

The `-E` flag preserves environment variables, allowing the script to properly detect your user account for opening the browser.

## What Happens on Start

The `start.sh` script will:
1. Verify Docker is running
2. Start InfluxDB and Grafana containers
3. Wait for services to become healthy
4. Extract dashboard information from JSON files
5. Display access URLs and credentials
6. Automatically open the dashboard in your browser (kiosk mode)

## Services

### Grafana
- **URL**: http://localhost:3000
- **Username**: `admin`
- **Password**: `admin`
- **Features**:
  - Auto-provisioned InfluxDB datasource
  - Auto-loaded dashboards from `grafana/dashboards/`
  - Kiosk mode enabled (1-second refresh)

### InfluxDB
- **URL**: http://localhost:8086
- **Database**: `system_metrics`
- **Admin credentials**: `admin` / `admin123`
- **Grafana user**: `grafana` / `grafana123`

## Directory Structure

```
grafana-deployment/
├── docker-compose.yml              # Container orchestration
├── start.sh                        # Startup script with health checks
├── stop.sh                         # Shutdown script
├── grafana/
│   ├── grafana.ini                 # Grafana configuration
│   ├── dashboards/                 # Dashboard JSON files (place dashboards here)
│   │   └── dashboard.json
│   └── provisioning/
│       ├── datasources/
│       │   └── influxdb.yml        # InfluxDB datasource config (UID: DS_INFLUXDB)
│       └── dashboards/
│           └── dashboard.yml       # Dashboard provisioning config
└── README.md
```

## Managing Dashboards

### Adding a Dashboard

1. Place your dashboard JSON file in `grafana/dashboards/`
2. Ensure datasource references use `"uid": "DS_INFLUXDB"` (not `"uid": "${DS_INFLUXDB}"`)
3. Restart Grafana: `docker compose restart grafana`
4. Dashboard will be auto-loaded within 10 seconds

### Exporting a Dashboard

From Grafana UI:
1. Go to Dashboard → Share → Export
2. Save JSON to `grafana/dashboards/`
3. If datasource shows as `${DS_INFLUXDB}`, replace with direct UID:
   ```bash
   sed -i 's/"uid": "${DS_INFLUXDB}"/"uid": "DS_INFLUXDB"/g' grafana/dashboards/your-dashboard.json
   ```

## Common Commands

### Start Services
```bash
sudo bash -E start.sh
```

### Stop Services
```bash
sudo bash -E stop.sh
```

### Remove All Data (including volumes)
```bash
sudo docker compose down -v
```

### View Logs
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f grafana
docker compose logs -f influxdb
```

### Restart a Service
```bash
docker compose restart grafana
docker compose restart influxdb
```

### Check Service Status
```bash
docker compose ps
```

## Database Operations

### Check InfluxDB Status
```bash
curl -s http://localhost:8086/ping
# HTTP 204 = healthy
```

### Access InfluxDB CLI
```bash
docker exec -it influxdb influx -database system_metrics -username admin -password admin123
```

### Query Databases
```bash
docker exec -it influxdb influx -execute "SHOW DATABASES"
```

## Troubleshooting

### Dashboard Shows "Datasource not found"

This occurs when dashboard JSON uses template variable syntax. Fix with:
```bash
sed -i 's/"uid": "${DS_INFLUXDB}"/"uid": "DS_INFLUXDB"/g' grafana/dashboards/dashboard.json
docker compose restart grafana
```

### Services Won't Start

Check Docker is running:
```bash
sudo systemctl status docker
```

View service logs:
```bash
docker compose logs influxdb
docker compose logs grafana
```

### Permission Issues

Always use `sudo bash -E` to preserve environment variables:
```bash
sudo bash -E start.sh
```

### Dashboard Not Loading

1. Verify file exists: `ls -la grafana/dashboards/`
2. Check provisioning logs: `docker compose logs grafana | grep provisioning`
3. Wait 10 seconds for auto-reload or restart: `docker compose restart grafana`

## Network Architecture

Services communicate via `grafana-network` bridge network. Grafana references InfluxDB using the service name `influxdb:8086` (not `localhost:8086`).

## Configuration Files

### Datasource (grafana/provisioning/datasources/influxdb.yml)
- Defines InfluxDB connection with UID `DS_INFLUXDB`
- Pre-configured credentials for `grafana` user
- Set as default datasource

### Dashboard Provisioning (grafana/provisioning/dashboards/dashboard.yml)
- Scans `grafana/dashboards/` directory
- Auto-reloads every 10 seconds
- Allows UI edits to dashboards

### Grafana Config (grafana/grafana.ini)
- Kiosk mode settings
- Anonymous access configuration
- Refresh intervals

## Data Persistence

Data is stored in Docker volumes:
- `influxdb-data`: Database storage
- `grafana-data`: Grafana settings and dashboards

To completely reset:
```bash
sudo docker compose down -v
sudo bash -E start.sh
```

## Security Notes

**Default credentials are for development only.** For production:
1. Change all passwords in `docker-compose.yml`
2. Update datasource credentials in `grafana/provisioning/datasources/influxdb.yml`
3. Disable anonymous access in `grafana/grafana.ini`
4. Use environment variables for secrets
5. Enable HTTPS/TLS
