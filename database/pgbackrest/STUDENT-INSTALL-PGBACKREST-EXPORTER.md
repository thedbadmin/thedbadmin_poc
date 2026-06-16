# Student Guide: Install pgbackrest_exporter

Simple steps to install **pgbackrest_exporter** on the **database VM** so Prometheus and Grafana can monitor pgBackRest backups.

All files you need are in this folder: `database/pgbackrest/`

| File | Use |
|------|-----|
| `pgbackrest_exporter.service` | Copy to `/etc/systemd/system/` |
| `pgbackrest.conf` | Example config → `/etc/pgbackrest.conf` |
| `daily_bkp.sh` | Example backup script |
| `provision.sh` | Full automated setup (Vagrant) |
| `prometheus-pgbackrest-scrape.yml` | Add to Prometheus on monitoring VM |
| `thedbadmin.com_backrest_mon_deshboard.json` | Import into Grafana |
| `README-DASHBOARD.md` | Dashboard panel reference |

---

## What you are installing

| Item | Value |
|------|-------|
| Tool | [pgbackrest_exporter](https://github.com/woblerr/pgbackrest_exporter) |
| Runs on | Database VM (`postgres-server`) |
| Port | **9854** |
| User | `postgres` |
| Config file | `/etc/pgbackrest.conf` |

The exporter reads pgBackRest backup info and exposes metrics like:

- `pgbackrest_stanza_status` — `0` means OK
- `pgbackrest_backup_info` — backup count
- `pgbackrest_backup_error_status` — backup errors

---

## Before you start (prerequisites)

1. **pgBackRest is installed** on the database VM
2. **`/etc/pgbackrest.conf` exists** and has your stanza (lab example: `prod01`)
3. **Stanza is created** and at least one backup exists:

```bash
sudo -u postgres pgbackrest stanza-create --stanza=prod01
sudo -u postgres pgbackrest backup --stanza=prod01 --type=full
sudo -u postgres pgbackrest info --stanza=prod01
```

4. **PostgreSQL is running**

---

## Lab quick install (Vagrant)

If you use the lab Vagrant setup, provisioning does everything for you:

```bash
cd /root/database
vagrant provision postgres_server
```

Files used from this repo:

- `database/pgbackrest/provision.sh`
- `database/pgbackrest/pgbackrest_exporter.service`

---

## Manual install (step by step)

Run these commands on the **database VM** as `root`.

### Step 1 — Download the exporter

```bash
VER=0.23.0
curl -fsSL -o /tmp/pgbackrest_exporter.tar.gz \
  "https://github.com/woblerr/pgbackrest_exporter/releases/download/v${VER}/pgbackrest_exporter-${VER}-linux-x86_64.tar.gz"

tar xzf /tmp/pgbackrest_exporter.tar.gz -C /tmp
cp /tmp/pgbackrest_exporter-${VER}-linux-x86_64/pgbackrest_exporter /usr/local/bin/
chown postgres:postgres /usr/local/bin/pgbackrest_exporter
chmod +x /usr/local/bin/pgbackrest_exporter
```

### Step 2 — Create the systemd service

Copy the service file from this folder:

```bash
cp pgbackrest_exporter.service /etc/systemd/system/
```

Or create `/etc/systemd/system/pgbackrest_exporter.service` with:

```ini
[Unit]
Description=Prometheus pgBackRest Exporter
After=network.target postgresql-16.service

[Service]
User=postgres
Group=postgres
Type=simple
ExecStart=/usr/local/bin/pgbackrest_exporter \
  --web.listen-address=:9854 \
  --backrest.config=/etc/pgbackrest.conf \
  --collect.interval=60
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### Step 3 — Start the service

```bash
systemctl daemon-reload
systemctl enable --now pgbackrest_exporter
systemctl status pgbackrest_exporter
```

### Step 4 — Open the firewall (if enabled)

```bash
firewall-cmd --permanent --add-port=9854/tcp
firewall-cmd --reload
```

---

## Verify it works

On the database VM:

```bash
# Service running?
systemctl is-active pgbackrest_exporter

# Metrics available?
curl -s http://localhost:9854/metrics | grep -E '^pgbackrest_stanza_status|^pgbackrest_exporter_status'
```

Expected output (example):

```
pgbackrest_stanza_status{stanza="prod01"} 0
pgbackrest_exporter_status 1
```

| Metric | Good value | Meaning |
|--------|------------|---------|
| `pgbackrest_stanza_status` | `0` | Stanza is healthy |
| `pgbackrest_exporter_status` | `1` | Exporter is collecting data |

---

## Connect Prometheus (monitoring VM)

On the **monitoring VM**, add the scrape job from `prometheus-pgbackrest-scrape.yml` into `prometheus/prometheus.yml`.

Change `192.168.1.107` to your database VM IP if different:

```yaml
  - job_name: 'pgbackrest'
    static_configs:
      - targets:
          - '192.168.1.107:9854'    # your database VM IP
        labels:
          stanza: 'prod01'
          instance_name: 'postgres-server'
```

Restart Prometheus:

```bash
cd /root/monitoring
docker compose restart prometheus
```

Check the target is **UP**:

- http://192.168.1.42:9090/targets

Quick test query:

```bash
curl -s 'http://192.168.1.42:9090/api/v1/query?query=pgbackrest_stanza_status'
```

---

## View in Grafana

1. Open Grafana: http://192.168.1.42:3000 (`admin` / `Admin@123`)
2. **Import** → upload `thedbadmin.com_backrest_mon_deshboard.json` from this folder
3. Set variable **Stanza** = `prod01`

Direct link:

http://192.168.1.42:3000/d/thedbadmin-backrest-mon/thedbadmin-com-backrest-mon-deshboard

---

## Troubleshooting

| Problem | What to check |
|---------|----------------|
| Service won't start | `journalctl -u pgbackrest_exporter -n 50` |
| No metrics on :9854 | Is pgBackRest configured? `sudo -u postgres pgbackrest info` |
| `stanza_status` not `0` | Run `sudo -u postgres pgbackrest check --stanza=prod01` |
| Prometheus target DOWN | Firewall, wrong IP, or exporter not running |
| Grafana empty | Prometheus scrape job missing or wrong stanza variable |

---

## Example pgBackRest config

Lab file: `pgbackrest.conf` (in this folder)

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

---

## Done checklist

- [ ] pgBackRest stanza exists and backups run
- [ ] `pgbackrest_exporter` installed in `/usr/local/bin/`
- [ ] systemd service enabled and active
- [ ] `curl localhost:9854/metrics` shows pgbackrest metrics
- [ ] Prometheus target `pgbackrest` is UP
- [ ] Grafana dashboard shows data for stanza `prod01`