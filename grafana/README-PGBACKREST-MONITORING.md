# pgBackRest Backup Monitoring — thedbadmin.com

Monitor pgBackRest backups in Grafana using **pgbackrest_exporter** + Prometheus.

## Dashboard

| Item | Value |
|------|-------|
| Name | `thedbadmin.com_backrest_mon_deshboard` |
| Grafana URL | http://192.168.1.42:3000/d/thedbadmin-backrest-mon/thedbadmin-com-backrest-mon-deshboard |
| Dashboard file | `thedbadmin.com_backrest_mon_deshboard.json` |
| Origin | **Original thedbadmin.com build** — not imported from Grafana.com or any third-party dashboard |

## Architecture

```
PostgreSQL VM (192.168.1.107)
  ├── pgBackRest 2.58  (stanza: prod01)
  └── pgbackrest_exporter :9854
           │
           ▼
Monitoring VM (192.168.1.42)
  ├── Prometheus :9090  (job: pgbackrest)
  └── Grafana :3000     (dashboard)
```

## Step 1 — Install pgbackrest_exporter (Database VM)

```bash
VER=0.23.0
curl -fsSL -o /tmp/pgbackrest_exporter.tar.gz \
  https://github.com/woblerr/pgbackrest_exporter/releases/download/v${VER}/pgbackrest_exporter-${VER}-linux-x86_64.tar.gz
tar xzf /tmp/pgbackrest_exporter.tar.gz -C /tmp
cp /tmp/pgbackrest_exporter-${VER}-linux-x86_64/pgbackrest_exporter /usr/local/bin/
chown postgres:postgres /usr/local/bin/pgbackrest_exporter
chmod +x /usr/local/bin/pgbackrest_exporter

cp pgbackrest_exporter.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now pgbackrest_exporter
```

Verify:

```bash
curl -s http://localhost:9854/metrics | grep pgbackrest_stanza_status
# pgbackrest_stanza_status{stanza="prod01"} 0   ← 0 = ok
```

## Step 2 — Add Prometheus scrape job (Monitoring VM)

Add to `prometheus/prometheus.yml`:

```yaml
  - job_name: 'pgbackrest'
    static_configs:
      - targets:
          - '192.168.1.107:9854'    # database VM bridged IP
        labels:
          stanza: 'prod01'
          instance_name: 'postgres-server'
```

Restart Prometheus:

```bash
docker compose -f /root/monitoring/docker-compose.yml restart prometheus
```

Verify target: http://192.168.1.42:9090/targets → `pgbackrest` should be **UP**

## Step 3 — Deploy the original Grafana dashboard

This dashboard was written from scratch for this lab. Do **not** use community dashboard ID 17709 or any other third-party JSON.

**Option A — file provisioning (recommended for the lab):**

```bash
cp grafana/dashboards/thedbadmin.com_backrest_mon_deshboard.json \
   /root/monitoring/grafana/provisioning/dashboards/json/
docker compose -f /root/monitoring/docker-compose.yml restart grafana
```

**Option B — manual import:**

1. Grafana → **Import** → upload `thedbadmin.com_backrest_mon_deshboard.json`
2. Select Prometheus datasource
3. Set variable **stanza** = `prod01`

## Key panels

| Panel | Metric | Meaning |
|-------|--------|---------|
| Stanza status | `pgbackrest_stanza_status` | 0=ok, 1+=problem |
| Since last full | `pgbackrest_backup_since_last_completion_seconds` | Age of last full backup |
| Backups CNT | `pgbackrest_backup_info` | Total backup count |
| Backups with errors | `pgbackrest_backup_error_status` | Checksum errors |
| WAL archive status | `pgbackrest_wal_archive_status` | WAL archiving health |

## Alerts (recommended)

| Alert | PromQL | Threshold |
|-------|--------|-----------|
| Stanza not OK | `pgbackrest_stanza_status != 0` | any |
| No full backup 24h | `pgbackrest_backup_since_last_completion_seconds{backup_type="full"} > 86400` | 24 hours |
| Exporter down | `pgbackrest_exporter_status != 1` | any |
| Backup has errors | `pgbackrest_backup_error_status > 0` | any |

## Prerequisites on database VM

- pgBackRest installed and stanza created (`pgbackrest stanza-create`)
- `/etc/pgbackrest.conf` configured
- Backups running (`pgbackrest backup --stanza=prod01 --type=full`)

Example stanza config:

```ini
[global]
repo1-path=/backup/pgbackrest
backup-user=postgres
retention-full=7
retention-diff=7

[prod01]
pg1-path=/opt/pgsql/16/data
pg1-user=postgres
```

## Files in this folder

| File | Purpose |
|------|---------|
| `thedbadmin.com_backrest_mon_deshboard.json` | Original Grafana dashboard (thedbadmin.com) |
| `pgbackrest_exporter.service` | systemd unit for database VM |
| `prometheus-scrape-snippet.yml` | Full live prometheus.yml from lab |
| `README-PGBACKREST-MONITORING.md` | This guide |