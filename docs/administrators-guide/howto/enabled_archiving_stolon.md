---
title: How to enable archiving to a local folder
summary: The steps to enabkling archiving to a local folder on a PgVillage cluster
authors:
  - Snehal Kapure
  - Sebas Mannem
date: 2026-04-04
---

# Introduction

In some cases people might want to use their existing backup tool to backup their PostgreSQL cluster.
This does require to run a backup agent and schedule a backup for every PgVillage DB node.
But this also requires to configure PostgreSQL to archive to a local folder.
This document decribes how to setup the local folder, and enable archiving in PoostgreSQL.
For setup of your backup tool, agent, schedule, etc. please refer to docs for your Backup vendor.

!!! note
    If this mountpoint floods, pg_wal will fill up and PostgreSQL will crash.
    Therefore, make sure that the archiving location is periodically cleaned
    and that you have enough space to cover for keeping archives during issues.

## Steps to perform

### 1. Create Archive Directory

!!! note
    You don't want to combine this location with your data space, so create a seperate mountpoint.
    You can combine this with the WAL location, but make sure this is a seperate folder.

Manually setup the location (a subfolder of `/pgwal`, a seperate NFS share, a seperate mountpoint with enough space to keep 3 days of WAL archives, whichever you prefer).

In this document we use `/pgwal/archives` as a basis.

### 2. Create and apply Cluster Config Patch

Create a patch file for the cluster configuration.

```bash
[postgres@db1 ~]$ cat /tmp/enable_archiving.json
{
  "pgParameters":
   {
   "archive_mode": "on",
   "archive_command": "rsync -a %p /pgwal/archives/"
   }
}
```

!!! note
    Refer to [changing PostgreSQL configuration](./change PostgreSQL\ configuration.md) for more information on changing PostgreSQL configration with stolon.

### 3. Patch the Configuration

Apply the configuration using stolonctl.

```bash
/usr/local/bin/stolonctl update -f /tmp/enable_archiving.json -p
```

### 4. Verify Configuration

```bash
[postgres@db1 ~]$  /usr/local/bin/stolonctl clusterdata read | jq .cluster.spec.pgParameters | grep archive_
  "archive_command": "rsync -a %p /pgwal/archives/",
  "archive_mode": "on",
```

### 5. Restart Stolon

Restarted Stolon (and with that PostgreSQL) on all servers.

### 6. Verify Configuration

```bash
[postgres@db1 ~]$ psql -c 'show archive_command;'
  rsync -a %p /pgwal/archives/
[postgres@db1 ~]$ psql -c 'show archive_mode;'
  true
```

### 7. Verify that WAL Archiving actually works

Switched WAL files and verified that they appear in the archive directory.

```bash
[postgres@nl010vn9007 ~]$ ls /pgwal/archives/
0000000B0000001600000027 
0000000B0000001600000028  
0000000B000000160000002F  
0000000B0000001600000030
```

# Background info


## Update pgvillage Deployment configuration

You probably also want to update your PgVillage deploment:

1. Add a hash called postgresql_archiving_parameters and add the archiving parameters to it:
   ```bash
   guru@ansible pgvillage]$ git diff
   
   diff --git a/inventory/poc/group_vars/all/postgres.yml b/inventory/poc/group_vars/all/postgres.yml
   index ecc628b..1c3dd22 100644
   --- a/inventory/poc/group_vars/all/postgres.yml
   +++ b/inventory/poc/group_vars/all/postgres.yml
   @@ -10,6 +10,10 @@ postgresql_timeout_parameters:
     idle_in_transaction_session_timeout: "60min"
     statement_timeout: "60min"
   
   +postgresql_archiving_parameters:
   +  archive_mode: on
   +  archive_command: rsync -a %p /pgwal/archives/
   +
   postgresql_log_parameters:
   # Logging
   log_destination: "csvlog"

2. Add the hash to your stolon_extra_pg_parameters config:
   Add a hash called postgresql_archiving_parameters and add the archiving parameters to it:
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
   
   [guru@ansible pgvillage]$
   ```
