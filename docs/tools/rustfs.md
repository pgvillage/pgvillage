---
title: RustFS
summary: A description of RustFS, the Object Storage backend which can be used to convert a server into an S3 endpoint for backups
authors:
  - Sebas Mannem
  - Snehal Kapure
date: 2026-11-01
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

RustFS replaces MinIO, which PgVillage used before: the PgVillage package repositories (apt `v0.0.4`, yum and zypp
`v0.3.8`) ship RustFS, not MinIO. See [Migrating from MinIO](#migrating-from-minio).

## Requirements

RustFS and its client `rc` run on a separate backup server (the `backup` group), deployed by the
[pgvillage.rustfs](https://github.com/pgvillage/ansible-role-rustfs) role.

### Server

- The `rustfs` package (from the PgVillage repository) installs `/usr/bin/rustfs`.
- The service `/etc/systemd/system/rustfs.service` and its configuration `/etc/default/rustfs` are maintained by Ansible.
- It runs as the `rustfs` user.
- TLS certificates: chainsmith places them in `/etc/pki/rustfs`, and the role copies them to `/etc/rustfs/tls`.
  WAL-G trusts the root certificate of chainsmith.
- Runs on port 443 (`rustfs_server_addr`). The console is disabled (`rustfs_server_console_enable`).
- Stores data in `/var/lib/rustfs` (`rustfs_server_datadirs`).

### Client (rc)

- The `rustfs-cli` package installs `/usr/bin/rc`.
- Ansible uses it to create the buckets (`rustfs_buckets`), one per cluster (see
  [multi-instance](../administrators-guide/deployment_and_maintenance/multiinstance/rustfs.md)).
- It is configured for the `rustfs` user (`~rustfs/.config/rc`), with the alias `rustfs`.
- It trusts the server chain that chainsmith places for the `rustfs` user (`~rustfs/.config/rc/certs/root.crt`).

## Usage

Everything is deployed and maintained through Ansible. To look into the buckets, use `rc` on the backup server as the
`rustfs` user:

```bash
sudo -iu rustfs
RC_CONFIG_DIR=~/.config/rc rc ls rustfs/cluster1/basebackups_005/
```

## Migrating from MinIO

!!! warning
    Migrating an existing MinIO backup server to RustFS is not tested yet.

The `pgvillage.rustfs` role refuses to run when variables of the old `pgvillage.minio` role (`minio_*`) are set, and
says what replaces them. It also fails when MinIO is still installed, as both use the same ports. To replace MinIO by
RustFS and keep the existing backups, set:

```yaml
rustfs_remove_minio: true          # stop and remove MinIO; its user, data and certificates are kept
rustfs_user: minio                 # MinIO's user, which owns the data
rustfs_server_datadirs:
  - /var/lib/minio                 # MinIO's data directories
```

This is one-way: MinIO can't take over RustFS data.
