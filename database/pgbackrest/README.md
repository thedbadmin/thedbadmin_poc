# pgBackRest + pgbackrest_exporter — Student Files

All files for this lab are in **this folder** (`database/pgbackrest/`).

## Files

| File | Purpose |
|------|---------|
| **STUDENT-INSTALL-PGBACKREST-EXPORTER.md** | Start here — step-by-step install guide |
| `pgbackrest_exporter.service` | systemd unit for the exporter |
| `pgbackrest.conf` | Example pgBackRest config (stanza `prod01`) |
| `provision.sh` | Automated install (used by Vagrant) |
| `daily_bkp.sh` | Example backup cron script |
| `prometheus-pgbackrest-scrape.yml` | Prometheus scrape config for monitoring VM |
| `thedbadmin.com_backrest_mon_deshboard.json` | Original Grafana dashboard |
| `README-DASHBOARD.md` | Dashboard panel reference |

## Quick start

**Database VM:**
```bash
cd /root/database
vagrant provision postgres_server
```

**Manual install:** open `STUDENT-INSTALL-PGBACKREST-EXPORTER.md`

## Lab ports

| Service | Port |
|---------|------|
| pgbackrest_exporter | 9854 |
| postgres_exporter | 9187 |
| node_exporter | 9100 |
| Prometheus | 9090 |
| Grafana | 3000 |