---
title: Minio
summary: A description of Minio, the Object Storage backend which can be used to convert a server into an S3 endpoint for backups
authors:
  - Sebas Mannem
  - Snehal Kapure
date: 2025-11-11
---

# MinIO

The standard building block makes backups using WAL-G and WAL-G stores the backups in Cloud Storage (buckets).

Within Acme, however, there is no Cloud Storage available and therefore MinIO is deployed so that WAL-G can subsequently transport the backups to MinIO so that they:

!!! note
    Note that using native Object storage from your Cloud provider, backup solution or storage solution is preferred over a VM with Minio.
    This solution is only meant to provide an option whhen no other Object Storage solution is available.

---

- Stored outside the database server.
- All cluster nodes use a shared backup medium.
- The file system behind MinIO can be easily included in CommVault via VM Backup.

This means that MinIO can be replaced by a future Cloud Storage (bucket) system once it becomes available within Acme.

## Requirements

For MinIO, the following components are required:

- MinIO and mcli are both run on a separate backup server (e.g., gurus-backup-server1)

### Server:

- The binary is deployed to /usr/local/bin/ using the RPMs
  - Source for the minio RPM: [https://dl.min.io/server/minio/release/linux-amd64](https://dl.min.io/server/minio/release/linux-amd64)
- The service file `/etc/systemd/system/minio.service` is created and maintained by Ansible
- The configuration `/etc/default/minio` is deployed and maintained by Ansible
- TLS certificates (`/etc/pki/tls/minio/*`) are deployed and maintained by Ansible
  - The root certificate is made available to wal-g by Ansible
- Runs on port 9091 (default)
- Stores data in `/data/postgres/backup/`

### Client (mcli):

- Used by Ansible to create the bucket.
- Also configured by Ansible (under the `minio-server` user).
- The binary is deployed to `/usr/local/bin/` using the RPMs.
  - Source for the mcli RPM: [https://dl.min.io/client/mc/release/linux-amd64](https://dl.min.io/client/mc/release/linux-amd64)

---

## Usage

In principle, everything is deployed and maintained through Ansible.

If more insight is desired, two things can be done:

1: Ensure routing to the management console (SSH proxy, opening ports in the firewall, etc.).

You can then use a browser to connect to this port and browse through the bucket (MinIO).

2: (Advice) Use `mcli` on the backup server under the `minio-user` account.

```bash
me@gurus-ansible-server1 ~/g/ansible-postgres (tmp)> ssh gurus-backup-server1.acme.corp.com

#Last login: Thu Oct 13 21:12:47 2022 from 10.0.6.100

[me@gurus-backup-server1 ~] $ sudo -i uminio-user

[minio-user@gurus-backup-server1 ~]$ /usr/local/bin/mcli ls minio/backup/basebackups_005/

[2022-10-11 16:54:12 CEST] 404B STANDARD base_000000010000000C0000000E_backup_stop_sentinel.json

[2022-10-12 09:08:48 CEST]  530B STANDARD base_000000010000000E00000069_D_000000010000000C0000000E_backup_stop_sentinel.json

[2022-10-12 09:29:37 CEST] 404B STANDARD base_000000010000000E0000006B_backup_stop_sentinel.json

[2022-10-12 20:02:06 CEST]   528B STANDARD base_000000010000000E0000006E_D_000000010000000E0000006B_backup_stop_sentinel.json

[2022-10-13 20:02:17 CEST]   559B STANDARD base_000000010000001000000046_D_000000010000000E0000006E_backup_stop_sentinel.json

[2022-10-13 21:31:56 CEST]    0B base_000000010000000C0000000E/

[2022-10-13 21:31:56 CEST]     0B base_000000010000000E00000069_D_000000010000000C0000000E/

[2022-10-13 21:31:56 CEST]    0B base_000000010000000E0000006B/

[2022-10-13 19:31:56 UTC]    0B base_000000010000000E0000006E_D_000000010000000E0000006B/

[2022-10-13 19:31:56 UTC]     0B base_000000010000001000000046_D_000000010000000E0000006E/
```

## The rustfs user

RustFS (or MinIO, see [Upgrading from v2.0.0 to v2.0.1](../administrators-guide/deployment_and_maintenance/upgrade_v2.0.1.md))
runs as the `rustfs` user on the backup host (`minio_user` in `inventories/standard`). PgVillage v2.0.1 and older ran it
as `minio`. On those deployments, the first step of `functional-all.yml`, `rustfs_user` (`tasks/rustfs_user.yml`),
renames the user before the linux role and chainsmith run (the linux role would otherwise create a new `rustfs` user,
and chainsmith would issue new certificates for all hosts):

- RustFS (or MinIO) stops;
- the `minio` group and user are renamed to `rustfs`, with the same gid and uid: the data (`/var/lib/minio`, or your
  `minio_server_datadirs`) keeps its owner and stays where it is;
- the home dir moves from `/home/minio` to `/home/rustfs`, with the certificates and the client config in it (`.minio`,
  `.mcli`, `.config/rc`);
- the server certificates of chainsmith move from `/etc/pki/minio` to `/etc/pki/rustfs`;
- the systemd unit (`User=`, `Group=`) and the paths in `/etc/default/rustfs` (or `/etc/default/minio`) and the client
  config point to `rustfs`, and RustFS (or MinIO) starts again.

Backups and WAL archiving to the backup host stop for the seconds that takes. Later runs, and new deployments, skip it.
`rollout_new_certs.yml` runs it too, before the minio role.

If both a `minio` and a `rustfs` user exist on the backup host, the deploy stops: remove the `rustfs` user (and group)
when it owns nothing (e.g. created by a deploy of the linux role without the rename), and deploy again.

To keep running as `minio`, set `minio_user: minio`, `chainsmith_server_cert_owner: minio` (backup hosts),
`minio` instead of `rustfs` for `backup` in `linux_users`, `linux_groups` and `chainsmith_users`, `/etc/pki/minio` in
`minio_cert_files` and `minio_rustfs_cert_files`, and disable the step (`pgvillage_roles: {rustfs_user: {enabled: false}}`,
see [Roles](../administrators-guide/deployment_and_maintenance/roles.md)).

## Tips & tricks

When files are deleted, they are temporarily stored in a temporary folder for a certain period of time.

This temporary folder is cleaned up every 24 hours, removing all data that is 24 hours or older.

In theory, temporary data can therefore be cleaned up 47 hours later (if delays occur).

While the storage behind MinIO is typically sized sufficiently, if you need to free up space (e.g., by cleaning old backups), you can manually clean temporary data by restarting the MinIO service:

```bash
[me@gurus-backup-server1 ~]$ sudo systemctl restart minio.service
```

This only affects a backup and restore (they need to be restarted).

---

Recovery (wal-fetch) and archiving (wal-push) are simply replayed and are not impacted by a MinIO restart.
