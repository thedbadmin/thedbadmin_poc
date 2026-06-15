#!/bin/bash
set -euo pipefail
echo "[monitoring] provisioning monitoring stack..."

INSTALL=/root/monitoring
SRC=/vagrant
if [ -f "$INSTALL/provision-monitoring.sh" ]; then
  SRC="$INSTALL"
fi

mkdir -p "$INSTALL/prometheus" \
         "$INSTALL/grafana/provisioning/dashboards/json" \
         "$INSTALL/grafana/provisioning/datasources"

if [ "$SRC" != "$INSTALL" ]; then
  cp "$SRC/docker-compose.yml" "$INSTALL/"
  cp "$SRC/lab.env" "$INSTALL/"
  cp "$SRC/prometheus/prometheus.yml" "$INSTALL/prometheus/prometheus.yml.template"
  cp -r "$SRC/grafana/provisioning/"* "$INSTALL/grafana/provisioning/"
  cp "$SRC/grafana/dashboards/"*.json "$INSTALL/grafana/provisioning/dashboards/json/" 2>/dev/null || true
else
  cp "$INSTALL/prometheus/prometheus.yml" "$INSTALL/prometheus/prometheus.yml.template"
  cp "$INSTALL/grafana/dashboards/"*.json "$INSTALL/grafana/provisioning/dashboards/json/" 2>/dev/null || true
fi

source "$INSTALL/lab.env"
sed -e "s/DB_HOST_PLACEHOLDER/${DB_HOST}/g" -e "s/DB_STANZA_PLACEHOLDER/${DB_STANZA}/g" \
  "$INSTALL/prometheus/prometheus.yml.template" > "$INSTALL/prometheus/prometheus.yml"

if ! command -v docker >/dev/null 2>&1; then
  dnf install -y docker docker-compose-plugin
  systemctl enable --now docker
fi

cd "$INSTALL"
export GRAFANA_ADMIN_PASSWORD
docker compose down 2>/dev/null || true
docker compose up -d

sleep 8
echo "[monitoring] docker status:"
docker compose ps
echo "[monitoring] prometheus targets:"
curl -sf http://localhost:9090/api/v1/targets | python3 -c "
import sys,json
for t in json.load(sys.stdin)['data']['activeTargets']:
    print(' ', t['labels'].get('job'), t['health'], t['scrapeUrl'])
"
echo "[monitoring] pgbackrest:"
curl -sf 'http://localhost:9090/api/v1/query?query=pgbackrest_stanza_status' | python3 -c "import sys,json; r=json.load(sys.stdin)['data']['result']; print(' OK' if r and r[0]['value'][1]=='0' else r)"
IP=$(ip -4 -br addr show eth1 | awk '{print $3}' | cut -d/ -f1)
echo "[monitoring] Grafana: http://${IP}:3000  Dashboard: /d/thedbadmin-backrest-mon/"
echo "[monitoring] done"
