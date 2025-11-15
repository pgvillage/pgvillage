---
title: Wal-G
summary: A description of the Backup and recovery tool WAL-G, and how to use it
authors:
  - Sebas Mannem
  - Snehal Kapure
date: 2025-11-11
---

# WAL-G

For backup and restore, we use Wal-G and [MinIO](minio.md).

WAL-G is an open-source project maintained by the community.

- [rpmbuilder Releases on GitHub](https://github.com/pgvillage-build/rpmbuilder)
- [pgvillage Repository](https://github.com/pgvillage/pgvillage/releases)

At the time of this writing, an adapted RPM is being used, which is based on:

- The latest version of [https://github.com/wal-g/wal-g/tags](https://github.com/wal-g/wal-g/tags)
- This change: [https://github.com/wal-g/wal-g/pull/1269](https://github.com/wal-g/wal-g/pull/1269) (for restoring delta backups of Stolon managed databases)

The intention is to get this pull request merged so that separate builds are no longer needed.

## Requirements

For making wal-g, the following components are needed:

### 1. WAL-G Binary

- Installed via RPM to `/usr/local/bin/`

### 2. Scripts

Deployed by Ansible to `/opt/wal-g/scripts/`:

- `archive_restore.sh` – used for catch-up when a standby lags behind or during recovery
- `archive.sh` – sends WAL files to MinIO using WAL-G
- `backup_locked.sh` – wrapper script using `etcdctl lock` to ensure backups run on only one server
- `backup.sh` – creates a new backup if there isn’t a recent one
- `delete.sh` – cleans up old backups
- `log_cleanup.sh` – maintains WAL-G log files
- `maintenance.sh` – wrapper for `log_cleanup.sh` and `delete.sh`
- `restore.sh` – restores a WAL-G backup (see [Point in time restore](../../roles/walg/files/scripts/restore.sh) for more information)

### 3. Cron Scheduling

- Managed by Ansible
- Cron file: `/etc/cron.d/wal-g`

### 4. Configuration File

- File: `/etc/default/wal-g` (maintained by Ansible)
- Contains:
  - Retention policies
  - Number of delta backups
  - Backup skip intervals

### 5. MinIO Configuration

- MinIO runs on the **backup server**
- Access configuration is included in `/etc/default/wal-g`
- Root certificate located in `~postgres/.wal-g/certs/` (for TLS verification)

---

## Use

Essentially, everything is automated using Ansible, Bash scripts, and cron.

You can even perform a Point-in-Time Restore using this procedure: [Point in time restore](../../roles/walg/files/scripts/restore.sh).

However, if desired, wal-g can also be invoked as a command-line tool.

That works as follows:

### Configuring WAL-G for Use

We do this by sourcing the environment variables using the following command:

Read the configuration from `/etc/default/wal-g`

```bash
# Skip lines with a #
# Export them as variables for subcommands
eval "$(sed '/#/d;s/^/export /' /etc/default/wal-g)"
```

Then wal-g can be called directly.

A few examples:

**Checking which backups are available**

```bash
[postgres@acme-dvppg1db-server2 ~] $ /usr/local/bin/wal-g-pg backup-list
...
name                                                       modified             wal_segment_backup_start
base_000000010000000C0000000E                              2022-10-11T14:54:12Z 000000010000000C0000000E
base_000000010000000E00000069_D_000000010000000C0000000E   2022-10-12T07:08:48Z 000000010000000E00000069
base_000000010000000E0000006B                              2022-10-12T07:29:37Z 000000010000000E0000006B
base_000000010000000E0000006N_D_000000010000000E0000006B   2022-10-12T18:02:06Z 000000010000000E0000006N
base_000000010000001000000046_D_000000010000000E0000006E   2022-10-13T18:02:17Z 000000010000001000000046
```

### Backups can be deleted.

For example, you can delete all backups, or (as in the example above) the backups up to `base_000000010000000E0000006B`:

### Remove all backups (only report)

/usr/local/bin/wal-g-pg delete everything

Delete all backups up to base_000000010000000E0000006B (only report)

/usr/local/bin/wal-g-pg delete before `base_000000010000000E0000006B`

Without the `--confirm` option, WAL-G only provides a report.  
With `--confirm`, it actually performs the deletion.

### Delete all backups (report and actually remove)

/usr/local/bin/wal-g-pg delete everything --confirm

Delete all backups up to base_000000010000000E0000006B (report and actually remove)

/delete wal-g-pg postgres delete before base_000000010000000E0000006B --confirm

### Help

You can view available commands using:

```bash
[postgres@acme-dvppg1db-server2 ~]$ /usr/local/bin/wal-g-pg
PostgreSQL backup tool

Usage:

wal-g [command]

Available Commands:

backup-fetch	Fetch a backup from storage
backup-list	List available backups
backup-mark	Mark a backup as permanent or impermanent
backup-push	Create a backup and upload it to storage

# catchup-fetch

Fetches an incremental backup from storage

# Catch-up List

Prints available incremental backups.
catchup-push: Creates an incremental backup from LSN
Completion: Generate shell completion code for the specified shell.
duplicate: Duplicate specific or all backups
Delete: Clears old backups and WALs

# flags
Display the list of available global flags for all wal-g commands
help Help about any command

pgbackrest
Interact with pgBackRest backups (beta)
st (DANGEROUS) Storage tools

wal-fetch Fetches a WAL file from storage
wal-push    Uploads a WAL file to storage
wal-receive   Receive WAL stream with postgres Streaming Replication Protocol and push to storage
wal-restore   Restores WAL segments from storage.
wal-show     Show information about storage WAL segments, grouped by timelines.
wal-verify Verify WAL storage folder. Available checks: integrity, timeline.

# Flags:
--config string   config file (default is $HOME/.walg.json)
-h, --help          help for wal-g
--turbo        Ignore all kinds of throttling defined in config
- `-v`, `--version`        version voor `wal-g`

To obtain a complete list of all global flags, execute: `wal-g flags`

Use `wal-g [command] --help` for more information about a command.

### Help for the `delete` Command

[postgres@acme-dvppg1db-server2 ~]$ /usr/local/bin/wal-g-pg delete --help
Clears old backups and WALs

Usage:
wal-g delete [command]

Available Commands:
before
everything
garbage
retain
target

Flags:
--confirm             Confirms backup deletion
-h, --help  help for delete
--use-sentinel-time Use backup creation time from sentinel for backups ordering.

Global Flags:
--config string    config file (default is $HOME/.walg.json)
--turbo     Ignore all kinds of throttling defined in config
```

To get the complete list of all global flags, run: `wal-g flags`

Use "wal-g delete \[command\] --help"for more information about a command.
