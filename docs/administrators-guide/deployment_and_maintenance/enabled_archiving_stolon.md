# PostgreSQL WAL Archiving Setup (Stolon Cluster)

## Initial Situation

archive_mode was disabled.

---

## Steps Performed

### 1. Create Archive Directory

Manually created a folder in `/pgdata/archives` on all three servers.  
This is where archived WAL files will be stored.

### 2. Create Cluster Config Patch

Created a patch file for the cluster configuration.

```bash
[postgres@nl010vn9006 ~]$ cat /tmp/seb2.json
{
  "pgParameters":
   {
   "archive_mode": "on",
   "archive_command": "rsync -a %p /pgdata/archives/"
   }
}
```

### 3. Patch the Configuration

Applied the configuration using stolonctl.

```bash
/usr/local/bin/stolonctl update -f /tmp/seb2.json -p
```

### 4. Verify Configuration

```bash
[postgres@nl010vn9006 ~]$  /usr/local/bin/stolonctl clusterdata read | jq .cluster.spec.pgParameters
{
  "archive_command": "rsync -a %p /pgdata/archives/",
  "archive_mode": "on",
  "datestyle": "iso, mdy",
  "default_text_search_config": "pg_catalog.english",
  "dynamic_shared_memory_type": "posix",
  "effective_cache_size": "5736MB",
  "idle_in_transaction_session_timeout": "60min",
  "lc_messages": "en_US.UTF-8",
  "lc_monetary": "en_US.UTF-8",
  "lc_numeric": "en_US.UTF-8",
  "lc_time": "en_US.UTF-8",
  "log_connections": "on",
  "log_destination": "csvlog",
  "log_directory": "/var/log/postgres/postgres",
  "log_disconnections": "on",
  "log_error_verbosity": "verbose",
  "log_file_mode": "0600",
  "log_filename": "postgresql-%Y%m%d.log",
  "log_line_prefix": "%m [%p]: [%l-1] db=%d,user=%u,app=%a,client=%h ",
  "log_min_duration_statement": "5000",
  "log_min_error_statement": "error",
  "log_min_messages": "warning",
  "log_rotation_age": "1d",
  "log_rotation_size": "1GB",
  "log_statement": "ddl",
  "log_timezone": "Europe/Amsterdam",
  "log_truncate_on_rotation": "on",
  "logging_collector": "on",
  "max_connections": "100",
  "max_parallel_workers": "8",
  "max_parallel_workers_per_gather": "2",
  "max_wal_size": "3693MB",
  "max_worker_processes": "8",
  "min_wal_size": "1231MB",
  "shared_buffers": "1912MB",
  "ssl": "true",
  "ssl_ca_file": "/etc/pki/postgres/root.crt",
  "ssl_cert_file": "/etc/pki/postgres/server.crt",
  "ssl_key_file": "/etc/pki/postgres/server.key",
  "statement_timeout": "60min",
  "timezone": "Europe/Amsterdam",
  "wal_level": "replica",
  "work_mem": "29368kB"
}
```

### 5. Restart Stolon

Restarted Stolon (and with that PostgreSQL) on all servers.

### 6. Verify Configuration

Verified that the configuration was properly set after restart.

### 7. Verify WAL Archiving

Switched WAL files and verified that they appear in the archive directory.

```bash
[postgres@nl010vn9007 ~]$ ls /pgdata/archives/
0000000B0000001600000027 
0000000B0000001600000028  
0000000B000000160000002F  
0000000B0000001600000030
```

## Update in pgvillage Deployment

```bash
adminsmannem@Triodos.Corp@nl010vn9005 pgvillage]$ git diff

diff --git a/inventory/poc/group_vars/all/postgres.yml b/inventory/poc/group_vars/all/postgres.yml
index ecc628b..1c3dd22 100644
--- a/inventory/poc/group_vars/all/postgres.yml
+++ b/inventory/poc/group_vars/all/postgres.yml
@@ -10,6 +10,10 @@ postgresql_timeout_parameters:
  idle_in_transaction_session_timeout: "60min"
  statement_timeout: "60min"

+postgresql_archiving_parameters:
+  archive_mode: on
+  archive_command: rsync -a %p /pgdata/archives/
+
postgresql_log_parameters:
# Logging
log_destination: "csvlog"

diff --git a/inventory/poc/group_vars/all/stolon.yml b/inventory/poc/group_vars/all/stolon.yml
index 3815a50..be95908 100644
--- a/inventory/poc/group_vars/all/stolon.yml
+++ b/inventory/poc/group_vars/all/stolon.yml
@@ -14,7 +14,7 @@ stolon_pg_log_directory: "{{ postgresql_log_directory }}"
stolon_pg_port: "{{ postgresql_rw_port }}"
stolon_proxy_port: "{{ postgresql_proxy_port }}"

-stolon_extra_pg_parameters: "{{ postgresql_log_parameters | combine(postgresql_timeout_parameters) }}"

+stolon_extra_pg_parameters: "{{ postgresql_log_parameters | combine(postgresql_timeout_parameters) | combine(postgresql_archiving_parameters) }}"

stolon_wal_dir_mp: "{{ postgresql_wal_mountpoint }}"

[adminsmannem@Triodos.Corp@nl010vn9005 pgvillage]$
```

!!! Notes
- You should:
        
        - move archive to a separate filesystem (and update archive_command)
        - make sure that the archiving location is periodically cleaned
        or /pgdata will fill up and PostgreSQL will crash again.
