# AAA Postgres_exporter Dashboard — Student Import Guide

This is the **corrected** version of the public Grafana dashboard. Do **not** import the original from grafana.com — use the JSON file in this folder instead.

## What was fixed (vs original dashboard ID `0000000390`)

| Issue | Original (broken) | Fixed version |
|-------|-------------------|---------------|
| Host variable | `label_values(node_disk_reads_completed, instance)` | `label_values(node_uname_info, instance)` |
| Database variable | `label_values(datname)` — invalid | `label_values(pg_stat_database_numbackends, datname)` |
| Instance variable | `${DS_PROMETHEUS}` not resolved | Portable `${DS_PROMETHEUS}` + correct query |
| CPU metrics | `node_cpu` | `node_cpu_seconds_total` |
| Disk metrics | `node_disk_reads_completed` | `node_disk_reads_completed_total` |
| Disk time metrics | `node_disk_*_time_ms` | `node_disk_*_time_seconds_total` |
| Memory metrics | `node_memory_MemTotal` | `node_memory_MemTotal_bytes` |
| Filesystem metrics | `node_filesystem_free` | `node_filesystem_free_bytes` |
| Default selections | Empty — panels show no data | Sensible defaults + "All" for DB/mode |

## Prerequisites (must be working before import)

1. **Prometheus** scraping these targets:
   - `YOUR_DB_HOST:9100` — node_exporter
   - `YOUR_DB_HOST:9187` — postgres_exporter (`pg_up` must equal `1`)

2. **Grafana** with a Prometheus datasource configured

3. **postgres_exporter** connected to PostgreSQL (user `exporter` with `pg_monitor` role)

## Import steps

### Option A — Grafana UI (recommended for students)

1. Open Grafana → **Dashboards** → **New** → **Import**
2. Click **Upload dashboard JSON file**
3. Select: `aaa-postgres-exporter-fixed.json`
4. When prompted, choose your **Prometheus** datasource from the dropdown
5. Click **Import**

### Option B — Grafana API

```bash
curl -u admin:YOUR_PASSWORD \
  -X POST -H "Content-Type: application/json" \
  -d @aaa-postgres-exporter-fixed-import.json \
  http://YOUR_GRAFANA:3000/api/dashboards/db
```

## After import — set your environment values

The dashboard variables must match **your** server IPs. Open the dashboard and set:

| Variable | What to select | Example (lab environment) |
|----------|----------------|---------------------------|
| **Host** | node_exporter instance | `192.168.1.107:9100` |
| **Instance** | postgres_exporter instance | `192.168.1.107:9187` |
| **Database** | All or specific DB | `All` |
| **Mode** | Lock modes | `All` |
| **Device** | Disk device | `vda` (or All) |

### Bookmarkable URL (replace IPs with yours)

```
http://GRAFANA_HOST:3000/d/<NEW_UID>/aaa-postgres-exporter-fixed?orgId=1&from=now-5m&to=now&var-host=192.168.1.107:9100&var-instance=192.168.1.107:9187&var-datname=All&var-mode=All&var-device=All
```

> After import, Grafana assigns a new UID. Copy it from the browser URL bar.

## Verify it works

```bash
# postgres_exporter must report pg_up 1
curl -s http://YOUR_DB_HOST:9187/metrics | grep '^pg_up'

# Prometheus must have pg metrics
curl -s 'http://YOUR_PROMETHEUS:9090/api/v1/query?query=pg_up'
```

In Grafana, panels **Current CPU**, **Current fetch data**, and **Lock tables** should show data within 30 seconds.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| All variables empty | Check Prometheus datasource; run variable queries in Explore |
| Host dropdown empty | Confirm node_exporter running on `:9100` |
| Instance dropdown empty | Confirm postgres_exporter on `:9187` and `pg_up=1` |
| PG panels empty, host panels OK | Create `exporter` DB user with `GRANT pg_monitor` |
| CPU/RAM panels empty | Host variable must match node_exporter `instance` label exactly |

## Files in this pack

| File | Purpose |
|------|---------|
| `aaa-postgres-exporter-fixed.json` | Import via Grafana UI |
| `aaa-postgres-exporter-fixed-import.json` | Import via API |
| `README-STUDENT-IMPORT.md` | This guide |
| `CHANGELOG.md` | Detailed list of query changes |

## Do not import the original

```
❌  Grafana.com ID 0000000390  (original — broken with node_exporter 1.x)
✅  aaa-postgres-exporter-fixed.json  (use this file)
```