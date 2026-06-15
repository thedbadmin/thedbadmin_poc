#!/bin/bash
set -euo pipefail
echo "[pgbackrest] provisioning database VM..."

PGVER=0.23.0
SRC=/vagrant/pgbackrest

# --- pgBackRest package ---
if ! rpm -q pgbackrest >/dev/null 2>&1; then
  dnf install -y pgbackrest
fi

# --- config ---
install -d -m 0777 /backup/pgbackrest /backup/pgbackrest/log /backup/scripts /opt/scripts
cp "$SRC/pgbackrest.conf" /etc/pgbackrest.conf
chmod 644 /etc/pgbackrest.conf
cp "$SRC/daily_bkp.sh" /opt/scripts/daily_bkp.sh
cp "$SRC/daily_bkp.sh" /backup/scripts/daily_bkp.sh
chmod +x /opt/scripts/daily_bkp.sh /backup/scripts/daily_bkp.sh
chown postgres:postgres /opt/scripts/daily_bkp.sh

# --- stanza (idempotent) ---
if ! sudo -u postgres pgbackrest info --stanza=prod01 >/dev/null 2>&1; then
  sudo -u postgres pgbackrest stanza-create --stanza=prod01
fi

# --- cron for postgres user ---
CRON_FILE=/etc/cron.d/pgbackrest
cat > "$CRON_FILE" <<'CRON'
# pgBackRest backups - Sunday full, Mon-Sat incremental
0 1 * * 0 postgres /opt/scripts/daily_bkp.sh
0 1 * * 1-6 postgres /opt/scripts/daily_bkp.sh
CRON
chmod 644 "$CRON_FILE"

# --- pgbackrest_exporter ---
if [ ! -x /usr/local/bin/pgbackrest_exporter ]; then
  curl -fsSL -o /tmp/pgbackrest_exporter.tar.gz \
    "https://github.com/woblerr/pgbackrest_exporter/releases/download/v${PGVER}/pgbackrest_exporter-${PGVER}-linux-x86_64.tar.gz"
  tar xzf /tmp/pgbackrest_exporter.tar.gz -C /tmp
  cp "/tmp/pgbackrest_exporter-${PGVER}-linux-x86_64/pgbackrest_exporter" /usr/local/bin/
  chown postgres:postgres /usr/local/bin/pgbackrest_exporter
  chmod +x /usr/local/bin/pgbackrest_exporter
fi

cp "$SRC/pgbackrest_exporter.service" /etc/systemd/system/pgbackrest_exporter.service
systemctl daemon-reload
systemctl enable --now pgbackrest_exporter

# --- firewall ---
if command -v firewall-cmd >/dev/null 2>&1; then
  firewall-cmd --permanent --add-port=9854/tcp 2>/dev/null || true
  firewall-cmd --reload 2>/dev/null || true
fi

echo "[pgbackrest] verification"
systemctl is-active pgbackrest_exporter
sudo -u postgres pgbackrest info --stanza=prod01 | head -5
curl -sf http://localhost:9854/metrics | grep -E '^pgbackrest_stanza_status|^pgbackrest_exporter_status' | head -3
echo "[pgbackrest] done"
