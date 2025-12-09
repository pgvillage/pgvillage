---
title: Point in time restore
summary: A description of how to restore a PgVillage deployment, or how to restore data to a specific point in time
authors:
  - Sebas Mannem
  - Snehal Kapure
date: 2025-11-11
---

# Point in time restore

1. In almost all cases, the reason for a point-in-time restore is not due to an error in the PostgreSQL architecture or by the DBA.

    Therefore, in almost all cases, a Point-in-Time Restore does not cause application downtime.

    Take the time to perform a proper Point-in-Time Restore.

2. In a Shared Cluster setup, it is important that a single database can be restored while the rest of the cluster remains operational.

    Actually, this is not a feature of the standard building block, but it can be executed.

    See chapter _Restore of Some Databases or Tables_ for more information.

## Restore to point in time

[WAL-g](../../tools/wal-g.md) supports performing a restore to Point in Time, 
but the procedure in combination with [stolon](../../tools/stolon.md) (High Availability Cluster Management) is complex.

Therefore, the process is fully automated in an **Ansible playbook**, which performs these steps:

- Stop the stolon-keeper on all nodes
- Remove the Postgres data and recreate the folders with the correct permissions
- Generate the stolon custom_config required to perform a Point In Time Restore using stolon and wal-g
- Load the `custom_config` into the etcd config of stolon
- Start stolon-keeper (one by one per node)
  - Stolon starts on the master and
    - Finds pitr as the init mode and executes the restore script.
      - The restore script runs wal-g backup-fetch to restore data to the last backup for the point in time
    - Starts Postgres afterwards, which performs recovery up to a specific point in time
      - Uses the restore_command to retrieve WAL-files using wal-g
      - Once Postgres is done with recovery (up to the point in time), PostgreSQL becomes available
  - PostgreSQL is again available for the application
  - Meanwhile, the standbys start, they clone from the master and become ReadOnly available

## Performance

Point-in-time restore is executed from the **management server**.

### 1. SSH to the management server

### 2. Ensure correct Ansible configuration:
  - [Ansible](ansible.md)

### 3. Perform PITR using Ansible (Examples)

```bash
cd ~/git/ansible-postgres
export ANSIBLE_VAULT_PASSWORD_FILE=$PWD/bin/gpgvault

# Restore to August 30, 2022 at 09:10:11 AM:
ansible-playbook -i environments/poc/ ./restore.yml -e 'restore_target="2022-08-30T09:10:11"'

# Restore to the label mylabel1:
ansible-playbook -i environments/poc/ ./restore.yml -e restore_target="mylabel1"

# Restore to transaction ID 50851
ansible-playbook -i environments/poc/ ./restore.yml -e restore_target="50851"
```
For a restore until the last moment, simply do not specify `-e restore_target=...`!

!!! Notes:

    The `RESTORETARGETINPUT` is written (appended) to `/etc/default/wal-g`. Even if the restore goes well, it will not be removed! **Check manually and adjust for starting restore.**

Also check for `backup` files in the data directory that are created after a restore on the master and make a backup after the restore!

### Restore some database or table

In a Shared Cluster setup, it's important that a single database is restored while the rest remains available.

This is not a standard feature of the building block, but it can be executed manually:

#### Steps

1. Prepare a standby node 
  - Make a standby available (stop stolon-keeper as root or with adm account and sudo)
  - Optionally free up or expand disk space there
  - Set PGRESTORE to a value other than PGDATA (etc. export `PGRESTORE=`)
  - Run the restore script with a restoration location, restore target, etc.:

2. Run the restore script
```bash
/opt/wal-g/scripts/restore.sh "/data/postgres/data/restore" "2022-08-30 09:10:11"
```
3. Start the restored instance manually

```bash
/usr/pgsql-12/bin/pg_ctl start -D "/data/postgres/data/restore"
````

!!! Note:

     This can be set up alongside an existing instance, as it starts on port 5433!!!


4. Copy the restored data to the master

- Restore a schema:

```bash
pg_dump [database] -n [myschema] | psql service=master
- Table (first truncate):
- pg_dump [database] -t "[myschema].[mytable]" | psql service=master
```
5. Stop and clean up the restore instance

```bash
/usr/pgsql-12/bin/pg_ctl stop -D "/data/postgres/data/restore"
rm -rf "/data/postgres/data/restore"  
```
6. Restart the Stolon Keeper 
Run as root or with the adm account using sudo.
