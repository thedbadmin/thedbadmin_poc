# thedbadmin.com_backrest_mon_deshboard — Original Dashboard

**100% original thedbadmin.com work** — panels, PromQL queries, layout, and transforms were written from scratch for this lab.

- No code copied from Grafana.com dashboard 17709 or any other public dashboard
- No `gnetId` / community import lineage
- Uses only standard `pgbackrest_exporter` metric names (public API, not copied dashboard JSON)

## Import

Grafana → **Dashboards → Import** → upload `thedbadmin.com_backrest_mon_deshboard.json`

## Panels

### Overview
| Panel | Metric | Meaning |
|-------|--------|---------|
| Stanza Status | `pgbackrest_stanza_status` | 0 = OK |
| Exporter Status | `pgbackrest_exporter_status` | 1 = collecting data |
| WAL Archive | `pgbackrest_wal_archive_status` | 1 = WAL archiving OK |
| Backup In Progress | `pgbackrest_stanza_backup_lock_status` | 1 = backup running |
| Backups With Errors | `pgbackrest_backup_error_status` | Checksum errors |
| Total Backups | `pgbackrest_backup_info` | Backup count |

### Backup Freshness
- Since Last FULL / INCR / DIFF (`pgbackrest_backup_since_last_completion_seconds`)

### Trends
- Backup age over time
- Repository size by backup type
- Backup duration history
- Database size per backup

### Inventory
- Table of all backups with label, type, duration, repo size

## Variable
- **Stanza** — defaults to `prod01`

## Live URL
http://192.168.1.42:3000/d/thedbadmin-backrest-mon/thedbadmin-com-backrest-mon-deshboard