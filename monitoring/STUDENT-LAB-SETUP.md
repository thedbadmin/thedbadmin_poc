# Student Lab Setup — Database Node + Monitoring Node

Step-by-step manual setup (no Vagrant).  
Two servers:

| Node | Role | Lab IP (example) |
|------|------|------------------|
| **Database node** | PostgreSQL + exporters | `192.168.1.107` |
| **Monitoring node** | Prometheus + Grafana | `192.168.1.42` |

Replace IPs with your own if different.

---

# PART 1 — DATABASE NODE

Run all steps below on the **database server** as `root` (unless noted).

---

## Step 1 — Confirm PostgreSQL is running

```bash
systemctl status postgresql-16    # or your PostgreSQL service name
sudo -u postgres psql -c "SELECT version();"
```

---

## Step 2 — Create PostgreSQL user for postgres_exporter

```bash
sudo -u postgres psql <<'SQL'
CREATE USER exporter WITH PASSWORD 'oracle';
GRANT pg_monitor TO exporter;
SQL
```

---

## Step 3 — Install node_exporter (port 9100)

```bash
VER=1.8.2
curl -fsSL -o /tmp/node_exporter.tar.gz \
  "https://github.com/prometheus/node_exporter/releases/download/v${VER}/node_exporter-${VER}.linux-amd64.tar.gz"
tar xzf /tmp/node_exporter.tar.gz -C /tmp
cp /tmp/node_exporter-${VER}.linux-amd64/node_exporter /usr/local/bin/
chmod +x /usr/local/bin/node_exporter

cat > /etc/systemd/system/node_exporter.service <<'EOF'
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=nobody
ExecStart=/usr/local/bin/node_exporter --web.listen-address=:9100
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now node_exporter
```

Verify:

```bash
curl -s http://localhost:9100/metrics | head -3
```

---

## Step 4 — Install postgres_exporter (port 9187)

```bash
VER=0.15.0
curl -fsSL -o /tmp/postgres_exporter.tar.gz \
  "https://github.com/prometheus-community/postgres_exporter/releases/download/v${VER}/postgres_exporter-${VER}.linux-amd64.tar.gz"
tar xzf /tmp/postgres_exporter.tar.gz -C /tmp
cp /tmp/postgres_exporter-${VER}.linux-amd64/postgres_exporter /usr/local/bin/
chmod +x /usr/local/bin/postgres_exporter

cat > /etc/systemd/system/postgres_exporter.service <<'EOF'
[Unit]
Description=PostgreSQL Exporter
After=network.target postgresql-16.service

[Service]
User=postgres
Environment=DATA_SOURCE_NAME=postgresql://exporter:oracle@localhost:5432/postgres?sslmode=disable
ExecStart=/usr/local/bin/postgres_exporter --web.listen-address=:9187
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now postgres_exporter
```

Verify (`pg_up` must be `1`):

```bash
curl -s http://localhost:9187/metrics | grep '^pg_up'
```

---

## Step 5 — Install pgbackrest_exporter (port 9854)

**Prerequisite:** pgBackRest installed, `/etc/pgbackrest.conf` ready, stanza created, at least one backup done.

```bash
sudo -u postgres pgbackrest stanza-create --stanza=prod01
sudo -u postgres pgbackrest backup --stanza=prod01 --type=full
sudo -u postgres pgbackrest info --stanza=prod01
```

Install exporter:

```bash
VER=0.23.0
curl -fsSL -o /tmp/pgbackrest_exporter.tar.gz \
  "https://github.com/woblerr/pgbackrest_exporter/releases/download/v${VER}/pgbackrest_exporter-${VER}-linux-x86_64.tar.gz"
tar xzf /tmp/pgbackrest_exporter.tar.gz -C /tmp
cp /tmp/pgbackrest_exporter-${VER}-linux-x86_64/pgbackrest_exporter /usr/local/bin/
chown postgres:postgres /usr/local/bin/pgbackrest_exporter
chmod +x /usr/local/bin/pgbackrest_exporter

cat > /etc/systemd/system/pgbackrest_exporter.service <<'EOF'
[Unit]
Description=Prometheus pgBackRest Exporter
After=network.target postgresql-16.service

[Service]
User=postgres
Group=postgres
ExecStart=/usr/local/bin/pgbackrest_exporter \
  --web.listen-address=:9854 \
  --backrest.config=/etc/pgbackrest.conf \
  --collect.interval=60
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now pgbackrest_exporter
```

Verify:

```bash
curl -s http://localhost:9854/metrics | grep -E '^pgbackrest_stanza_status|^pgbackrest_exporter_status'
```

Expected: `pgbackrest_stanza_status{stanza="prod01"} 0` and `pgbackrest_exporter_status 1`

---

## Step 6 — Open firewall ports (if firewall is on)

```bash
firewall-cmd --permanent --add-port=9100/tcp
firewall-cmd --permanent --add-port=9187/tcp
firewall-cmd --permanent --add-port=9854/tcp
firewall-cmd --reload
```

---

## Step 7 — Database node checklist

| Check | Command | Expected |
|-------|---------|----------|
| node_exporter | `curl -s localhost:9100/metrics \| head -1` | metrics output |
| postgres_exporter | `curl -s localhost:9187/metrics \| grep ^pg_up` | `pg_up 1` |
| pgbackrest_exporter | `curl -s localhost:9854/metrics \| grep stanza_status` | value `0` |

**Database node is ready.**

---

# PART 2 — MONITORING NODE

Run all steps below on the **monitoring server** as `root`.

---

## Step 1 — Install Docker

```bash
dnf install -y docker docker-compose-plugin
systemctl enable --now docker
docker --version
```

---

## Step 2 — Create monitoring folder

```bash
mkdir -p /root/monitoring/prometheus
cd /root/monitoring
```

Copy these files from the repo into `/root/monitoring/`:

- `docker-compose.yml`
- `lab.env`

---

## Step 3 — Create Prometheus config

Create `/root/monitoring/prometheus/prometheus.yml`  
Change `192.168.1.107` to your **database node IP**:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:

  - job_name: 'prometheus'
    static_configs:
      - targets:
          - 'prometheus:9090'

  - job_name: 'postgresql'
    static_configs:
      - targets:
          - '192.168.1.107:9187'

  - job_name: 'node_exporter'
    static_configs:
      - targets:
          - '192.168.1.107:9100'

  - job_name: 'pgbackrest'
    static_configs:
      - targets:
          - '192.168.1.107:9854'
        labels:
          stanza: 'prod01'
          instance_name: 'postgres-server'
```

---

## Step 4 — Start Prometheus and Grafana

```bash
cd /root/monitoring
export GRAFANA_ADMIN_PASSWORD=Admin@123
docker compose up -d
docker compose ps
```

Both containers `prometheus` and `grafana` should be **Up**.

---

## Step 5 — Verify Prometheus targets

Open in browser:

**http://192.168.1.42:9090/targets**

All jobs should be **UP**:

| Job | Target |
|-----|--------|
| postgresql | `192.168.1.107:9187` |
| node_exporter | `192.168.1.107:9100` |
| pgbackrest | `192.168.1.107:9854` |

Or from command line:

```bash
curl -s http://localhost:9090/api/v1/targets | grep -E '"health"|"job"'
```

---

## Step 6 — Login to Grafana

1. Open browser: **http://192.168.1.42:3000**
2. Login:
   - Username: `admin`
   - Password: `Admin@123`

---

## Step 7 — Add Prometheus datasource (first time only)

Skip this if Prometheus datasource already exists.

1. Left menu → **Connections** → **Data sources**
2. Click **Add data source**
3. Select **Prometheus**
4. Set URL: `http://prometheus:9090`
5. Click **Save & test** → should show green **Successfully queried**

---

## Step 8 — Import Dashboard 1: AAA Postgres Exporter

**File:** `grafana/aaa-postgres-exporter-fixed-import.json`

### Navigation

1. Left menu → **Dashboards**
2. Click **New** → **Import**
3. Click **Upload dashboard JSON file**
4. Select: **`aaa-postgres-exporter-fixed-import.json`**
5. On the import screen:
   - Name: `AAA Postgres_exporter` (or keep default)
   - Folder: choose a folder (e.g. `PostgreSQL Monitoring`)
   - **Prometheus** dropdown → select your Prometheus datasource
6. Click **Import**

### After import — set variables (top of dashboard)

| Variable | Select |
|----------|--------|
| **Host** | `192.168.1.107:9100` |
| **Instance** | `192.168.1.107:9187` |
| **Database** | `All` |
| **Mode** | `All` |
| **Device** | `All` (or `vda`) |

Panels like **CPU**, **Memory**, and **pg_up** should show data within 30 seconds.

---

## Step 9 — Import Dashboard 2: pgBackRest Monitoring

**File:** `grafana/thedbadmin.com_backrest_mon_deshboard.json`  
(or `database/pgbackrest/thedbadmin.com_backrest_mon_deshboard.json`)

### Navigation

1. Left menu → **Dashboards**
2. Click **New** → **Import**
3. Click **Upload dashboard JSON file**
4. Select: **`thedbadmin.com_backrest_mon_deshboard.json`**
5. On the import screen:
   - Name: `thedbadmin.com_backrest_mon_deshboard`
   - Folder: same folder as above
   - **Prometheus** datasource → select Prometheus
6. Click **Import**

### After import — set variable

| Variable | Select |
|----------|--------|
| **Stanza** | `prod01` |

Check panels:

- **Stanza Status** → OK (green)
- **Total Backups** → shows count
- **Backup Inventory** → table with backup rows

---

## Step 10 — Open dashboards later (navigation)

**From Grafana home:**

1. Left menu → **Dashboards**
2. Browse your folder (e.g. **PostgreSQL Monitoring**)
3. Click dashboard name to open

**Direct URLs (after import):**

| Dashboard | URL |
|-----------|-----|
| AAA Postgres | `http://192.168.1.42:3000/d/<uid>/aaa-postgres-exporter-fixed` |
| pgBackRest | `http://192.168.1.42:3000/d/thedbadmin-backrest-mon/thedbadmin-com-backrest-mon-deshboard` |

> AAA Postgres UID may change after import — copy it from the browser address bar.

---

## Step 11 — Monitoring node checklist

| Check | URL / action | Expected |
|-------|----------------|----------|
| Prometheus | http://192.168.1.42:9090/targets | All targets UP |
| Grafana login | http://192.168.1.42:3000 | Login works |
| AAA dashboard | Import + set Host/Instance | Panels show data |
| pgBackRest dashboard | Import + set Stanza=prod01 | Stanza Status OK |

---

## Troubleshooting (quick)

| Problem | Fix |
|---------|-----|
| Prometheus target DOWN | Check exporter on database node + firewall |
| `pg_up` not 1 | Fix `exporter` user / password in postgres_exporter service |
| AAA dashboard empty | Set **Host** and **Instance** variables to exact `IP:port` |
| pgBackRest empty | Confirm stanza `prod01` exists and backups ran |
| Cannot import dashboard | Use JSON files from repo `grafana/` folder |

---

## Files you need from repo

| File | Node | Purpose |
|------|------|---------|
| `monitoring/docker-compose.yml` | Monitoring | Start Prometheus + Grafana |
| `monitoring/lab.env` | Monitoring | Grafana password |
| `monitoring/prometheus/prometheus.yml` | Monitoring | Template for scrape config |
| `grafana/aaa-postgres-exporter-fixed-import.json` | Monitoring | Import dashboard 1 |
| `grafana/thedbadmin.com_backrest_mon_deshboard.json` | Monitoring | Import dashboard 2 |
| `database/pgbackrest/pgbackrest.conf` | Database | pgBackRest example config |