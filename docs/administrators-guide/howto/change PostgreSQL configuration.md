---
title: How to change configuration
summary: A description of changing PostgreSQL configuration in a PgVillage cluster
authors:
  - Snehal Kapure
  - Sebas Mannem
date: 2026-04-04
---

# Introduction

This document decribes how to change configuration at day 2 (running and maintaining).

## Example usecase

Imagine you have deploy'ed your PostgreSQL cluster, and need to change your configuration.
As an example, `archive_mode` was disabled, and you want to enable it.

In this example use-case, we change the configuration option for `archive_mode` to true, but basically this document applies to all document changes.

## Steps to perform

### 0. Verify current configuration


```bash
[postgres@db1 ~]$  /usr/local/bin/stolonctl clusterdata read | jq .cluster.spec
```

!!!! note
     You can use this as input for a patch, and change as you wish.


### 1. Create Cluster Config Patch

Created a patch file for the cluster configuration.

```bash
[postgres@db1 ~]$ cat /tmp/archive_mode_patch.json
{
  "pgParameters":
   {
   "archive_mode": "on",
   }
}
```

!!!! note
     You could use the output of the command for step 0 as input.
     Do make sure you only keep your changes and remove anything that is not changed.
     Storing this patch (e.a. in git) allows for tracking all changes that you have applied.

### 2. Patch

Apply the configuration using stolonctl.

```bash
/usr/local/bin/stolonctl update -f /tmp/archive_mode_patch.json -p
```

### 3. Verify stolon configuration

```bash
[postgres@db1 ~]$  /usr/local/bin/stolonctl clusterdata read | jq .cluster.spec.pgParameters[archive_mode]
"archive_mode": "on",
```

### 4. Restart Stolon

For some configuration PostgreSQL rerquires to be restarted.
Stolon does not automatically restart, as this might create downtime.
Therefore you should restart stolon on all systems when you are ready to apply changes that require a restart.

```bash
# On all servers, issue:
[postgres@db1 ~]$  systemctl restart stolon-keeper
```

### 5. Verify PostgreSQL Configuration

```bash
# On all servers, issue:
[postgres@db1 ~]$ psql
show archive_command;
```

## 6. Update pgvillage Deployment

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
+

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
