# Introduction

For backup and restore, we use Wal-G and [MinIO](../../../../../../../../pages/xwiki/Infrastructuur/Team%3A+DBA/Werkinstrukties/Postgres/Bouwsteen/Minio/WebHome.html).

WAL-G is an open-source project maintained by the community at [https://github.com/wal-g/wal-g/](https://github.com/wal-g/wal-g/).

Binnen acme wordt een rpm gebruikt welke beschikbaar wordt gesteld middels

- [https://github.com/MannemSolutions/rpmbuilder/releases](https://github.com/MannemSolutions/rpmbuilder/releases)
- [https://repo.mannemsolutions.nl/yum/pgvillage/](https://repo.mannemsolutions.nl/yum/pgvillage/)

At the time of this writing, an adapted RPM is being used, which is based on:

- The latest version of [https://github.com/wal-g/wal-g/tags](https://github.com/wal-g/wal-g/tags)
- This change: [https://github.com/wal-g/wal-g/pull/1269](https://github.com/wal-g/wal-g/pull/1269) (for restoring delta backups of Stolon managed databases)

The intention is to get this pull request merged so that separate builds are no longer needed.

# # Requirements

For making wal-g, the following components are needed:

- the `wal-g` binary (deployed to `/usr/local/bin/` via an rpm)
- scripts (deployed by Ansible to `/opt/wal-g/scripts/`)
  - `archive_restore.sh` (for catch-up when a standby lags behind the master, and during recovery)
  - `archive.sh` (to send WAL files to MinIO using wal-g)
  - `backup_locked.sh` (wrapper script with etcdctl lock to ensure backup.sh runs on only one server at a time)
  - `backup.sh` (creates a backup if there isn't already a recent one)
  - `delete.sh` (cleans up old backups)
  - `log_cleanup.sh` (maintenance of log files from wal-g scripts)
  - `maintenance.sh` (wrapper script for log_cleanup.sh and delete.sh)
  - `restore.sh` (for restoring a wal-g backup, see [Point in time restore](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Onderhoud/Point+in+time+Restore/WebHome.html) for more information)
- cron scheduling (`/etc/cron.d/wal-g` is created and maintained by Ansible)
- The wal-g config file (`/etc/default/wal-g` is created and maintained by Ansible)
  - Contains configuration regarding retention, number of deltas, how long backups are skipped after the last backup, etc.)
- A properly functioning MinIO and its configuration
  - MinIO runs on the backup server
  - The configuration for accessing it is included in `/etc/default/wal-g`
  - The root certificate is included in `~postgres/.wal-g/certs/`, allowing wal-g to verify the MinIO TLS certificate

# Use

Essentially, everything is automated using Ansible, Bash scripts, and cron.

You can even perform a Point-in-Time Restore using this procedure: [Point in time restore](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Onderhoud/Point+in+time+Restore/WebHome.html).

However, if desired, wal-g can also be invoked as a command-line tool.

That works as follows:

## Wal must be configured for use.
```markdown

```

Dit doen we door de environment variables te sourcen middels het volgende commando:

# Read the configuration from /etc/default/wal-g

```markdown
# Skip lines with a #
```

```markdown
# Export them as variables for subcommands
```

eval"$(sed '/#/d;s/^/export /' /etc/default/wal-g)"

## Then wal-g can be called directly.

A few examples:

### Checking which backups are available

# List of All Backups:

---

```markdown
[postgres@acme-dvppg1db-server2 ~] $ /usr/local/bin/wal-g-pg backup-list
```

name                                                     modified             wal\_segment\_backup\_start

```
base_000000010000000C0000000E                                                                                         2022-10-11T14:54:12Z 000000010000000C0000000E
```

```
base_000000010000000E00000069_D_000000010000000C0000000E 2022-10-12T07:08:48Z 000000010000000E00000069
```

```markdown
base_000000010000000E0000006B                                         2022-10-12T07:29:37Z 000000010000000E0000006B
```

```markdown
base_000000010000000E0000006N_D_000000010000000E0000006B 2022-10-12T18:02:06Z 000000010000000E0000006N
```

```
base_000000010000001000000046_D_000000010000000E0000006E 2022-10-13T18:02:17Z 000000010000001000000046
```

### Backups can be deleted.

for example all backups, or (in the above example) the backups up to base\_000000010000000E0000006B:

# Remove all backups (only report)

```markdown
/usr/local/bin/wal-g-pg delete everything
```

```markdown
# Delete all backups up to base_000000010000000E0000006B (only report)
```

```
/usr/local/bin/wal-g-pg delete before base_000000010000000E0000006B
```

Zonder de optie --confirm geeft wal-g alleen een rapport, met --confirm verwijderd hij ze ook echt:

\# Delete all backups (report and actually remove)

```
/usr/local/bin/wal-g-pg delete everything --confirm
```

```markdown
# Delete all backups up to base_000000010000000E0000006B (report and actually remove)
```

```markdown
/delete wal-g-pg postgres delete before base_000000010000000E0000006B --confirm
```

### Help

Deze opties zijn beschikbaar

```markdown
[postgres@acme-dvppg1db-server2 ~]$ /usr/local/bin/wal-g-pg
```

PostgreSQL backup tool

Usage:

```markdown
wal-g [command]
```

```
Available Commands:
```

```markdown
backup-fetch Fetches a backup from storage
```

```markdown
list-backup   Prints available backups
```

```markdown
backup-mark   Marks a backup as permanent or impermanent
```

```markdown
backup-push   Creates a backup and uploads it to storage
```

# catchup-fetch

Fetches an incremental backup from storage

# Catch-up List

Prints available incremental backups.
- - -

```markdown
catchup-push: Creates an incremental backup from LSN
```

```markdown
Completion: Generate shell completion code for the specified shell.
```

```markdown
duplicate    duplicate specific or all backups
```

```markdown
Delete        Clears old backups and WALs
```

flags  
Display the list of available global flags for all wal-g commands

```
help         Help about any command
```

pgbackrest  
Interact with pgBackRest backups (beta)

st            (DANGEROUS) Storage tools

```markdown
wal-fetch Fetches a WAL file from storage
```

```
wal-push    Uploads a WAL file to storage
```

wal-receive   Receive WAL stream with postgres Streaming Replication Protocol and push to storage

```
wal-restore   Restores WAL segments from storage.
```

```
wal-show     Show information about storage WAL segments, grouped by timelines.
```

```markdown
wal-verify Verify WAL storage folder. Available checks: integrity, timeline.
```

Flags:

```
--config string   config file (default is $HOME/.walg.json)
```

```
-h, --help          help for wal-g
```

```markdown
--turbo        Ignore all kinds of throttling defined in config
```

- `-v`, `--version`        version voor `wal-g`

To obtain a complete list of all global flags, execute: `wal-g flags`

Gebruik `wal-g [command] --help` voor meer informatie over een opdracht.

### Help op een commando

for example the delete command:

```
[postgres@acme-dvppg1db-server2 ~]$
/usr/local/bin/wal-g-pg delete --help
```

Clears old backups and WALs

Usage:

```markdown
wal-g delete [command]
```

```markdown
Available Commands:
```

before

everything

garbage

retain

target

Flags:

```markdown
--confirm             Confirms backup deletion
```

```
-h, --help  help for delete
```

```markdown
--use-sentinel-time Use backup creation time from sentinel for backups ordering.
```

Global Flags:

```
--config string    config file (default is $HOME/.walg.json)
```

```markdown
--turbo     Ignore all kinds of throttling defined in config
```

To get the complete list of all global flags, run: `wal-g flags`

Use "wal-g delete \[command\] --help"for more information about a command.

