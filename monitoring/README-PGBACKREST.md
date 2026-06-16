# pgBackRest Monitoring — Monitoring VM (/root/monitoring)

Prometheus scrapes pgbackrest_exporter from database VM.
Grafana dashboard: **thedbadmin.com_backrest_mon_deshboard** (original thedbadmin.com build — not copied from Grafana.com)

## Full student guide (both nodes, no Vagrant)
See **[STUDENT-LAB-SETUP.md](STUDENT-LAB-SETUP.md)** — database node + monitoring node steps and dashboard import navigation.

## Provision
```bash
cd /root/monitoring
vagrant provision postgres16_server
```

## URLs
- Grafana: http://192.168.1.42:3000 (admin / Admin@123)
- Prometheus: http://192.168.1.42:9090
- Dashboard: /d/thedbadmin-backrest-mon/
