---
title: Point in time restore
summary: How to restore a cluster of a PgVillage deployment to a point in time with the restore playbook
authors:
  - Sebas Mannem
  - Snehal Kapure
date: 2026-11-14
---

# Point in time restore

PgVillage backs up every cluster in `stolon_clusters` with [wal-g](../../tools/wal-g.md): full and delta backups
(cron, `backup_locked.sh`) and the WAL archive (`archive.sh`). The playbook `restore.yml` restores one cluster from
them, to a point in time:

- **Replace the cluster**: the cluster gets the data of the point in time on all its hosts. Its current data is removed:
  everything after the point in time is lost. Use it when the cluster as a whole must go back.
- **Restore next to the running cluster**: the point in time is restored into another folder on one host and started
  as a separate PostgreSQL instance, for inspection, or to copy some tables or databases back. The cluster keeps
  running and is not touched.

Most restores are about data (a table dropped or updated by mistake), not about a broken cluster. Then a restore next
to the running cluster, and copying the data back, gives the application no downtime. Take your time for it.

!!! warning "Always restore with restore.yml (or restore.sh), never with `wal-g backup-fetch`"

    Don't run `wal-g backup-fetch` (or `wal-g-pg backup-fetch`) by hand. On PgVillage a plain backup-fetch doesn't
    give a working instance: it hangs on delta backups (stolon's `postgresql.auto.conf` symlink), leaves `pg_wal` out,
    and sets no `restore_command`, so no WAL is replayed. And restoring into the data folder of a cluster without stolon
    knowing about it breaks the cluster. `restore.yml` and the `restore.sh` script of the walg role handle all this.

## Prerequisites

- Run it from the Ansible control node, with the inventory of the deployment (see [Ansible](ansible.md)).
- The walg role with stolon support in `restore.sh` (the playbook checks this and stops when it is missing).
- A backup of the cluster from before the point in time, and the WAL archive from that backup up to the point in time.
  List them on a database host:

    ```bash
    sudo -iu postgres /opt/wal-g/scripts/list-backups.sh cluster1
    ```

    `backup-list` shows the times in UTC.
- For a restore next to the cluster: room on the host for the data of the cluster, in a folder that doesn't exist yet
  or is empty.

## Choosing the point in time

Give at most one target:

| Variable              | Restores up to                                                    | Backup that is used                     |
|-----------------------|-------------------------------------------------------------------|-----------------------------------------|
| (none)                | the end of the WAL archive (latest)                               | the latest backup                       |
| `restore_target_time` | a time, e.g. `"2026-11-14 10:30:00+01:00"` (without a time zone: the time zone of the database host) | the latest backup before that time |
| `restore_target_xid`  | a transaction ID (`recovery_target_xid`)                          | the earliest backup                     |
| `restore_target_name` | a restore point (`pg_create_restore_point()`)                     | the earliest backup                     |

The target is included: the transaction at the target time, or with the target XID, is restored. Other variables:

- `restore_backup_name`: use this backup (a name from `list-backups.sh`) instead of the one in the table, e.g. a backup
  closer before the XID, so less WAL is replayed.
- `restore_target_timeline`: `recovery_target_timeline` (default `latest`). Needed after an earlier restore, for a
  point in time on the old timeline after the point where that restore branched off. E.g. a restore to 10:00 made
  timeline 2; to get 10:15 of before that restore, use `-e restore_target_timeline=1`. Without it PostgreSQL follows
  timeline 2, doesn't find the target, and the restore fails (the playbook waits until `restore_timeout`).
  `list-backups.sh` shows the timelines and where they branched off (`wal-show`).
- `restore_backup_after` (replace only, default `true`): make a full backup when the restore is done (see below).
- `restore_timeout` (default 7200): seconds to wait for the restore.

## Replace the cluster

```bash
# Up to 10:30 (Amsterdam time) on 14 November 2026
ansible-playbook -i inventories/<env> restore.yml -e restore_cluster=cluster1 -e restore_confirm=cluster1 \
  -e 'restore_target_time="2026-11-14 10:30:00+01:00"'

# Up to transaction 50851
ansible-playbook -i inventories/<env> restore.yml -e restore_cluster=cluster1 -e restore_confirm=cluster1 \
  -e restore_target_xid=50851

# Up to the end of the WAL archive
ansible-playbook -i inventories/<env> restore.yml -e restore_cluster=cluster1 -e restore_confirm=cluster1
```

`restore_confirm` must be the name of the cluster: without it the playbook stops before it changes anything.

### What happens

The playbook uses stolon's [point in time recovery](https://github.com/sorintlab/stolon/blob/master/doc/pitr.md):

1. It checks the variables, and lets `restore.sh` choose the backup (or checks `restore_backup_name`), before anything
   changes. The backup and the target are shown.
2. On the current primary it switches to a new WAL file and waits until it is archived, so a restore to latest includes
   the last transactions. (Writes after this are lost.)
3. It re-initializes the stolon cluster (`stolonctl init`) with the cluster spec of the inventory and `initMode: pitr`:
    - stolon chooses one of the keepers of the cluster. That keeper stops PostgreSQL, removes the data and wal folders
      and runs `restore.sh` to fetch the backup (full + deltas), with `pg_wal` on the wal folder;
    - it starts PostgreSQL with `restore_command = archive_restore.sh <cluster> %f %p` and the target, PostgreSQL
      replays the WAL up to the target and promotes: a new timeline;
    - it becomes the primary, and the other keepers clone it (`pg_basebackup`) and stream from it.

    From the init until the restore is done, the cluster is down (the proxies and haproxy have no primary).
    The keeper logs the restore: `journalctl -u stolon-keeper@<cluster>` on the host that restores.
4. It waits until stolon reports the cluster healthy, with all keepers, and checks on every host that the primary has
   all standbys streaming.
5. It makes a full backup (`backup_locked.sh` with `WALG_BACKUP_FORCE=1`). The restored cluster runs on a new
   timeline; the latest backups are from the old one, and a later restore must not build on them.

Run the deployment (`functional-all.yml`) once after the restore: it applies the settings that are not in the stolon
spec again, e.g. the lines of the pgbouncer role in `pg_hba.conf`.

The other clusters on the same hosts are not touched. Afterwards the stolon spec shows `initMode: pitr` and the
`pitrConfig`; that only matters for an init, and the next restore replaces it.

### How to check

```bash
sudo -iu postgres   # the login shows the keepers and databases of every cluster (stolonctl status)
psql service=cluster1-local -c "SELECT pg_is_in_recovery(), timeline_id FROM pg_control_checkpoint()"
psql service=cluster1-master -c "SELECT last_archived_wal, failed_count FROM pg_stat_archiver"
/opt/wal-g/scripts/list-backups.sh cluster1
```

Check the data the application needs, that the primary has its standbys (`pg_stat_replication`), that archiving
continues on the new timeline, and that the backup after the restore is in the list.

When a restore fails (e.g. the WAL up to the target is missing), the playbook stops waiting after `restore_timeout`.
Look at the keeper log on the host that restored, fix the cause and run the playbook again: it starts the restore anew.

## Restore next to the running cluster

```bash
ansible-playbook -i inventories/<env> restore.yml -e restore_cluster=cluster1 -e restore_dir=/data/postgres/data/restore \
  -e 'restore_target_time="2026-11-14 10:30:00+01:00"' [-e restore_host=<host>]
```

On `restore_host` (default: the first host of `hacluster`) `restore.sh` fetches the backup into `restore_dir`, sets the
recovery settings and starts the instance on port `PGPORT + 10000` (e.g. 15433 for cluster1 on 5433), with
`archive_command = '/bin/true'` (it doesn't archive into the backups of the cluster), its log in `<restore_dir>/log`,
and no synchronous standbys. The playbook waits until it is promoted. The cluster keeps running.

Copy the data back, e.g. a table:

```bash
sudo -iu postgres
pg_dump -h /tmp -p 15433 -d mydb -t myschema.mytable --data-only | psql service=cluster1-master dbname=mydb
```

or a schema (`-n myschema`), or compare with the running cluster. Stop and remove the instance when done:

```bash
sudo -iu postgres /usr/lib/postgresql/17/bin/pg_ctl stop -D /data/postgres/data/restore   # PGBIN of the host
sudo rm -rf /data/postgres/data/restore
```

## restore.sh

`restore.sh` (in `/opt/wal-g/scripts`, from the walg role) is what the playbook runs. It can also be run by hand on a
database host as `postgres`, for a restore next to the cluster:

```bash
/opt/wal-g/scripts/restore.sh <cluster> <restore folder> [<target: time, XID or restore point>]
/opt/wal-g/scripts/restore.sh cluster1 /data/postgres/data/restore "2026-11-14 10:30:00+01:00"
```

The cluster argument is required: it selects `/etc/default/wal-g-<cluster>`. Never give it the data folder of the
cluster while stolon runs it; to replace a cluster, use `restore.yml`.
