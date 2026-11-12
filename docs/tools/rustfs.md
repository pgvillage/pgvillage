---
title: RustFS
summary: A description of RustFS, the Object Storage backend which can be used to convert a server into an S3 endpoint for backups
authors:
  - Sebas Mannem
  - Snehal Kapure
date: 2026-11-11
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

- The `rustfs` package (from the PgVillage repository) installs `/usr/bin/rustfs`.
- The service `/etc/systemd/system/rustfs.service` and its configuration `/etc/default/rustfs` are maintained by Ansible.
- It runs as the `minio` user (`rustfs_user`), and stores its data in `/var/lib/minio` (`rustfs_server_datadirs`): the
  user and data directory of the minio role, so deployments that ran it keep their backups. New deployments get the
  same.
- TLS certificates: chainsmith places them in `/etc/pki/minio`, and the role copies them to `/etc/rustfs/tls`.
  WAL-G trusts the root certificate of chainsmith.
- Runs on port 443 (`rustfs_server_addr`). The console is disabled (`rustfs_server_console_enable`).

### Client (rc)

- The `rustfs-cli` package installs `/usr/bin/rc`.
- Ansible uses it to create the buckets (`rustfs_buckets`), one per cluster (see
  [multi-instance](../administrators-guide/deployment_and_maintenance/multiinstance/rustfs.md)).
- It is configured for the `minio` user (`~minio/.config/rc`), with the alias `rustfs`.
- It trusts the server chain that chainsmith places for the `minio` user (`~minio/.mcli/certs/CAs/root.crt`).

The certificates stay where chainsmith placed them for the minio role, so the move to the rustfs role doesn't reissue
them.

The settings are in `inventories/standard/group_vars/all/rustfs.yml` and `group_vars/backup/chainsmith.yml`.

## Usage

Everything is deployed and maintained through Ansible. To look into the buckets, use `rc` on the backup server as the
`minio` user:

```bash
sudo -u minio RC_CONFIG_DIR=~minio/.config/rc rc ls rustfs/cluster1/basebackups_005/
```

## Migrating from the minio role

Deployments of PgVillage v2.0.1 and older ran the `pgvillage.minio` role on the backup host:

- with MinIO itself: deployments upgraded from v2.0.0 on Ubuntu, which keep MinIO with `minio_use_rustfs: false`
  (see [Upgrading from v2.0.0 to v2.0.1](../administrators-guide/deployment_and_maintenance/upgrade_v2.0.1.md));
- or with RustFS (`minio_use_rustfs: true`, the default in `inventories/standard`): new v2.0.1 deployments, and EL and
  SUSE.

The `pgvillage.rustfs` role takes both over, with the same user (`minio`) and data (`/var/lib/minio`), so the
existing backups stay. In `functional-all.yml` the step `rustfs` replaces the step `minio`.

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
| `minio_use_rustfs`       | nothing |

`inventories/standard` sets the `rustfs_*` variables in `group_vars/all/rustfs.yml`; set yours (e.g. the keys, with
ansible-vault) in your own inventory. Also:

- Moved the data of MinIO (`minio_server_datadirs`)? Set `rustfs_server_datadirs` to the same directories.
- Changed the step `minio` with `pgvillage_roles` (see [Roles](../administrators-guide/deployment_and_maintenance/roles.md))?
  Make that change to the step `rustfs`.

### Deploy

Deploy as usual (`functional-all.yml`). On the backup host the rustfs role:

1. stops and removes MinIO, if it runs (`rustfs_remove_minio: true` in `inventories/standard`): the `minio` service,
   its unit file, `/etc/default/minio`, and the `minio` and `mcli` packages. The `minio` user, its data and
   certificates stay, and chainsmith doesn't reissue the certificates.
2. installs and configures RustFS (`/etc/default/rustfs`, `/etc/systemd/system/rustfs.service`), with the
   certificates in `/etc/rustfs/tls`, and starts it on `/var/lib/minio`.
3. configures `rc` (`~minio/.config/rc`) and creates the buckets that don't exist yet.

The switch is one-way: MinIO can't take over the data of RustFS.

WAL-G can't reach the backup host while RustFS (re)starts: `archive.sh` fails and PostgreSQL retries it, so the WAL
waits in `pg_wal` until RustFS is up again. Don't run a backup during the switch.

After the deploy, check that the backups are there, per cluster on a database host:

```bash
sudo -iu postgres /opt/wal-g/scripts/list-backups.sh cluster1
```

The configuration of MinIO in the home directory of `minio` stays on the backup host; remove it when everything works:
`~minio/.minio` and `~minio/.mcli/config.json` (keep `~minio/.mcli/certs`: `rc` uses the CA in it).
