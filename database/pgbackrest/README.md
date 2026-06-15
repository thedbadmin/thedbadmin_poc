# pgBackRest — Database VM (/root/database)

Runs on `postgres-server` VM. Includes backups + Prometheus exporter.

## Provision
```bash
cd /root/database
vagrant provision postgres_server
```

## Components
- pgBackRest stanza `prod01`
- Cron: Sunday full, Mon-Sat incremental
- pgbackrest_exporter on port **9854**
