---
title: RustFS
summary: A description of RustFS, the Object Storage backend which can be used to convert a server into an S3 endpoint for backups
authors:
  - Sebas Mannem
  - Snehal Kapure
date: 2026-11-15
---

# RustFS

The standard building block makes backups using WAL-G and WAL-G stores the backups in Cloud Storage (buckets).

When there is no Cloud Storage available, PgVillage deploys [RustFS](https://rustfs.com), an S3 compatible object
storage server, on the backup server, so that WAL-G can store the backups there. That way they are:

- Stored outside the database server.
- On a backup medium shared by all cluster nodes.
- On a file system that can be included in a VM backup (e.g. CommVault).

!!! note
    Using native Object storage from your Cloud provider, backup solution or storage solution is preferred over a VM
    with RustFS. This solution is only meant to provide an option when no other Object Storage solution is available.

RustFS replaces MinIO, which PgVillage used before: the PgVillage package repositories ship RustFS, not MinIO. Up to
PgVillage v2.0.1 the `pgvillage.minio` role deployed it (MinIO, or RustFS with `minio_use_rustfs`); now the
[pgvillage.rustfs](https://github.com/pgvillage/ansible-role-rustfs) role does. See
[Migrating from the minio role](#migrating-from-the-minio-role).

## Requirements

RustFS and its client `rc` run on a separate backup server (the `backup` group).

### Server

- The `rustfs` package (from the PgVillage repository) installs `/usr/bin/rustfs`. The linux role installs it.
- The service `/etc/systemd/system/rustfs.service` and its configuration `/etc/default/rustfs` are maintained by Ansible.
- It runs as the `rustfs` user (`rustfs_user`, the role default), which the linux role creates, and stores its data in
  `/var/lib/minio` (`rustfs_server_datadirs`): the data directory of the minio role, so deployments that ran it keep
  their backups. New deployments get the same.
- TLS certificates: chainsmith places them in `/etc/pki/rustfs`, and the role copies them to `/etc/rustfs/tls`.
  WAL-G trusts the root certificate of chainsmith.
- Runs on port 443 (`rustfs_server_addr`). The console is disabled (`rustfs_server_console_enable`).

### Client (rc)

- The `rustfs-cli` package installs `/usr/bin/rc`.
- Ansible uses it to create the buckets (`rustfs_buckets`), one per cluster (see [Multi-instance](#multi-instance)).
- It is configured for the `rustfs` user (`~rustfs/.config/rc`), with the alias `rustfs`.
- It trusts the root certificate that chainsmith places for the `rustfs` user (`~rustfs/.mcli/certs/CAs/root.crt`, where
  the minio role had it: moving it would make chainsmith issue new certificates for all hosts).

The settings are in `inventories/standard/group_vars/all/rustfs.yml` and `group_vars/backup/chainsmith.yml`.

## Usage

Everything is deployed and maintained through Ansible. To look into the buckets, use `rc` on the backup server as the
`rustfs` user:

```bash
sudo -u rustfs RC_CONFIG_DIR=~rustfs/.config/rc rc ls rustfs/cluster1/basebackups_005/
```

To list the backups of a cluster, on a database host:

```bash
sudo -iu postgres /opt/wal-g/scripts/list-backups.sh cluster1
```

## Migrating from the minio role

Deployments of PgVillage v2.0.1 and older ran the `pgvillage.minio` role on the backup host, as the `minio` user:

- with MinIO itself: deployments upgraded from v2.0.0 on Ubuntu, which keep MinIO with `minio_use_rustfs: false`
  (see [Upgrading from v2.0.0 to v2.0.1](../operate/upgrading/upgrade_v2.0.1.md));
- or with RustFS (`minio_use_rustfs: true`, the default in `inventories/standard`): new v2.0.1 deployments, and EL and
  SUSE.

The `pgvillage.rustfs` role takes both over, with the same data (`/var/lib/minio`), so the existing backups stay. In
`functional-all.yml` the step `rustfs` replaces the step `minio`. The `minio` user is renamed to `rustfs` first (see
[The rustfs user](#the-rustfs-user)).

### Before you deploy

Remove all `minio_*` variables from your inventories, including `minio_use_rustfs: false` of the upgrade to v2.0.1.
The rustfs role fails on the backup host when any are set, and says what replaces each of them, e.g.:

| minio role               | rustfs role |
|--------------------------|-------------|
| `minio_access_key`       | `rustfs_access_key` |
| `minio_secret_key`       | `rustfs_secret_key` |
| `minio_buckets`          | `rustfs_buckets` |
| `minio_server_addr`      | `rustfs_server_addr` |
| `minio_server_datadirs`  | `rustfs_server_datadirs` |
| `minio_user`             | `rustfs_user` |
| `minio_use_rustfs`       | nothing |

`inventories/standard` sets the `rustfs_*` variables in `group_vars/all/rustfs.yml`; set yours (e.g. the keys, with
ansible-vault) in your own inventory. Also:

- Moved the data of MinIO (`minio_server_datadirs`)? Set `rustfs_server_datadirs` to the same directories.
- Changed the step `minio` with `pgvillage_roles` (see [Steps](../reference/steps.md))? Make that change to the step
  `rustfs`. `--tags minio` still runs it.

### Deploy

Deploy as usual (`functional-all.yml`). On the backup host:

1. the step `rustfs_user` renames the `minio` user to `rustfs` (see [The rustfs user](#the-rustfs-user)).
2. the rustfs role stops and removes MinIO, if it runs (`rustfs_remove_minio: true` in `inventories/standard`): the
   `minio` service, its unit file, `/etc/default/minio`, and the `minio` and `mcli` packages. The data and the
   certificates stay, and chainsmith doesn't reissue the certificates.
3. it installs and configures RustFS (`/etc/default/rustfs`, `/etc/systemd/system/rustfs.service`, replacing those of
   the minio role), with the certificates in `/etc/rustfs/tls`, and (re)starts it on `/var/lib/minio`.
4. it configures `rc` (`~rustfs/.config/rc`) and creates the buckets that don't exist yet.

The switch is one-way: MinIO can't take over the data of RustFS.

WAL-G can't reach the backup host while RustFS (re)starts: `archive.sh` fails and PostgreSQL retries it, so the WAL
waits in `pg_wal` until RustFS is up again. Don't run a backup during the switch.

After the deploy, check that the backups are there, per cluster on a database host:

```bash
sudo -iu postgres /opt/wal-g/scripts/list-backups.sh cluster1
```

The configuration of the minio role in the home directory of `rustfs` stays on the backup host; remove it when
everything works: `~rustfs/.minio` (the certificates the minio role gave RustFS or MinIO) and `~rustfs/.mcli/config.json`
(keep `~rustfs/.mcli/certs`: `rc` uses the CA in it).

## The rustfs user

RustFS runs as the `rustfs` user on the backup host (`rustfs_user`). PgVillage v2.0.1 and older ran it (or MinIO) as
`minio`. On those deployments, the first step of `functional-all.yml`, `rustfs_user` (`tasks/rustfs_user.yml`),
renames the user before the linux role and chainsmith run (the linux role would otherwise create a new `rustfs` user,
and chainsmith would issue new certificates for all hosts):

- RustFS (or MinIO) stops;
- the `minio` group and user are renamed to `rustfs`, with the same gid and uid: the data (`/var/lib/minio`, or your
  `rustfs_server_datadirs`) keeps its owner and stays where it is;
- the home dir moves from `/home/minio` to `/home/rustfs`, with the certificates and the client config in it (`.minio`,
  `.mcli`, `.config/rc`);
- the server certificates of chainsmith move from `/etc/pki/minio` to `/etc/pki/rustfs`;
- the systemd unit (`User=`, `Group=`) and the paths in `/etc/default/rustfs` (or `/etc/default/minio`) and the client
  config point to `rustfs`, and RustFS (or MinIO) starts again.

Backups and WAL archiving to the backup host stop for the seconds that takes. Later runs, and new deployments, skip it.
`rollout_new_certs.yml` runs it too, before the rustfs role.

If both a `minio` and a `rustfs` user exist on the backup host, the deploy stops: remove the `rustfs` user (and group)
when it owns nothing (e.g. created by a deploy of the linux role without the rename), and deploy again.

To keep running as `minio`, set `rustfs_user: minio`, `chainsmith_server_cert_owner: minio` (backup hosts),
`minio` instead of `rustfs` for `backup` in `linux_users`, `linux_groups` and `chainsmith_users`, `/etc/pki/minio` as
the `source` of the server files in `rustfs_cert_files`, and disable the step
(`pgvillage_roles: {rustfs_user: {enabled: false}}`, see [Steps](../reference/steps.md)).

## Multi-instance

How to configure this for several clusters on the same hosts. See [Multi-instance](../deploy/multi-instance.md)
for the feature, and the [defaults](https://github.com/pgvillage/ansible-role-rustfs/blob/main/defaults/main.yml) of the role for all its variables.

When deploying multiple HA clusters (e.g. stolon or Patroni), you should separate the backups for each cluster to another bucket.
To configure RustFS with multiple buckets, edit the RustFS config (e.g. `inventories/standard/group_vars/all/rustfs.yml`) and define a bucket per cluster.
Then configure `s3_prefix` of every cluster in [`walg_clusters`](wal-g.md#multi-instance) to use the bucket meant for it.

### `rustfs_buckets`

With multi-instance every Postgres instance gets its own bucket, named after the instance:

```yaml
rustfs_buckets:
  - cluster1
  - cluster2
```
