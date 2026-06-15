# Changelog — AAA Postgres_exporter Dashboard Fix

**Base dashboard:** Grafana community dashboard UID `0000000390`  
**Fixed version:** `aaa-postgres-exporter-fixed.json`  
**Target stack:** node_exporter 1.8.x + postgres_exporter 0.18.x + Prometheus + Grafana 10+

---

## Template variable changes

### `host`
```diff
- label_values(node_disk_reads_completed, instance)
+ label_values(node_uname_info, instance)
```
**Reason:** `node_disk_reads_completed` renamed to `node_disk_reads_completed_total` in node_exporter 0.16+.

### `device`
```diff
- label_values(node_disk_reads_completed{instance="$host", device!~"dm-.+"}, device)
+ label_values(node_disk_reads_completed_total{instance="$host", device!~"dm-.+"}, device)
```

### `instance`
```diff
- label_values({job=~"postgresql|postgresql01|postgresql02|postgresql03"}, instance)
+ label_values(pg_up{job="postgresql"}, instance)
```
**Reason:** Simpler, works with single postgres_exporter job named `postgresql`.

### `datname`
```diff
- label_values(datname)
+ label_values(pg_stat_database_numbackends, datname)
```
**Reason:** `label_values()` requires a metric name as first argument.

### `mode`
```diff
- label_values({mode=~"accessexclusivelock|..."}, mode)
+ label_values(pg_locks_count, mode)
```
**Reason:** Uses actual metric that carries the `mode` label.

### Datasource (all variables)
```diff
- ${DS_PROMETHEUS}  (unresolved after import)
+ ${DS_PROMETHEUS}  (with __inputs block — prompts on import)
```

### Defaults added
| Variable | Default |
|----------|---------|
| host | (student sets to their `:9100` instance) |
| instance | (student sets to their `:9187` instance) |
| datname | All (`$__all` / `.*`) |
| mode | All (`$__all` / `.*`) |

---

## Panel query metric renames

| Old metric | New metric |
|------------|------------|
| `node_cpu` | `node_cpu_seconds_total` |
| `node_disk_reads_completed` | `node_disk_reads_completed_total` |
| `node_disk_writes_completed` | `node_disk_writes_completed_total` |
| `node_disk_read_time_ms` | `node_disk_read_time_seconds_total` |
| `node_disk_write_time_ms` | `node_disk_write_time_seconds_total` |
| `node_disk_io_time_ms` | `node_disk_io_time_seconds_total` |
| `node_memory_MemTotal` | `node_memory_MemTotal_bytes` |
| `node_memory_MemFree` | `node_memory_MemFree_bytes` |
| `node_memory_Buffers` | `node_memory_Buffers_bytes` |
| `node_memory_Cached` | `node_memory_Cached_bytes` |
| `node_filesystem_free` | `node_filesystem_free_bytes` |
| `node_filesystem_size` | `node_filesystem_size_bytes` |

PostgreSQL panel queries (`pg_stat_*`, `pg_locks_count`, `pg_stat_activity_count`) were **unchanged** — they work when `pg_up=1`.

---

## Panels affected by node_exporter renames

- Current IOwait
- Current CPU
- RAM used
- RAM cached
- Disk IO Utilization
- Disk Use
- Disk Latency (read)
- Disk Latency (write)

## Panels that only need postgres_exporter (unchanged queries)

- Current fetch / insert / update data
- Fetch / Insert / Update / Delete / Return data
- Active / Idle sessions
- Lock tables