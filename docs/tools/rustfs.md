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

## Upgrading from the minio role

Deployments of PgVillage v2.0.1 and older ran the `pgvillage.minio` role on the backup host, as the `minio` user. On
the upgrade, the `pgvillage.rustfs` role takes over, with the same data (`/var/lib/minio`), so the existing backups
stay. The first step of `functional-all.yml`, `rustfs_user`, renames the `minio` user to `rustfs` first, with the same
uid and gid. Remove all `minio_*` variables from your inventories before you deploy: the rustfs role fails when any are
set.

See [Upgrading from v2.0.1 to v2.1.0](../operate/upgrading/upgrade_v2.1.0.md) for the steps, what the deploy does, and
how to keep running as `minio`.

## The rustfs user

RustFS runs as the `rustfs` user on the backup host (`rustfs_user`). On deployments that ran it as `minio` (v2.0.1 and
older), the step `rustfs_user` renames that user: see
[Upgrading from v2.0.1 to v2.1.0](../operate/upgrading/upgrade_v2.1.0.md#on-the-backup-host-the-rustfs-user).

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
