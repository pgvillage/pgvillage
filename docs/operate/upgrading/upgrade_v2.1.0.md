---
title: Upgrading from v2.0.1 to v2.1.0
summary: How to upgrade a PgVillage v2.0.1 deployment to v2.1.0, including the switch of the backup host from the minio role to the rustfs role and the rename of the minio user
authors:
  - Sebas Mannem
date: 2026-11-17
---

# Upgrading from v2.0.1 to v2.1.0

PgVillage v2.1.0 has newer roles (`requirements.yml`), and the backup host moves from the `pgvillage.minio` role to
the `pgvillage.rustfs` role: RustFS runs as the `rustfs` user instead of `minio`, on the same data. The upgrade is a
normal deploy with `functional-all.yml`, after a few changes to your own inventory.

!!! note "Upgrading from v2.0.0?"

    Upgrade to v2.0.1 first: [Upgrading from v2.0.0 to v2.0.1](upgrade_v2.0.1.md).

## Before you deploy

Make sure there is a recent backup of every cluster, and that WAL archiving works. Per cluster, on a database host:

```bash
sudo -iu postgres /opt/wal-g/scripts/list-backups.sh cluster1
```

### Remove the minio variables

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
- Changed the step `minio` with `pgvillage_roles` (see [Steps](../../reference/steps.md))? Make that change to the step
  `rustfs`. `--tags minio` still runs it.

### Internal role variables

Some internal variables of the roles (`_linux_packages`, `_linux_pg_packages`, `_stolon_package_names`,
`_avchecker_package_names`, `_pgfga_python_packages`, ...) moved from `defaults/main.yml` to `vars/main.yml`. Role
vars beat the inventory, so an inventory that sets one of them is now silently ignored. Set the public variable
instead (e.g. `linux_packages`, `stolon_package_names`, `avchecker_package_names`). Reading them, as
`inventories/standard/group_vars/all/packages.yml` does, still works.

### Chainsmith (nothing to change)

pgvillage.chainsmith v0.3.1 adds the optional groups `chainsmith_controller` (the host that generates the certificates)
and `chainsmith_nodes` (the hosts that receive them). Without them it does what it did: the first host in
`localhosts` generates, `hacluster` and `backup` receive. Define them only to run chainsmith on another host than
`localhost`, or to give the controller certificates too; see [Chainsmith](../../tools/chainsmith.md).

With `--limit` or `serial` that leaves the controller or a recipient out of the play, chainsmith now skips with a
warning instead of failing (or issuing a chain for only part of the hosts).

## What the first deploy does

Deploy as usual (`functional-all.yml`).

### On the backup host: the rustfs user

The first step, `rustfs_user` (`tasks/rustfs_user.yml`), renames the user before the linux role and chainsmith run
(the linux role would otherwise create a new `rustfs` user, and chainsmith would issue new certificates for all
hosts):

- RustFS (or MinIO) stops;
- the `minio` group and user are renamed to `rustfs`, with the same gid and uid: the data (`/var/lib/minio`, or your
  `rustfs_server_datadirs`) keeps its owner and stays where it is;
- the home dir moves from `/home/minio` to `/home/rustfs`, with the certificates and the client config in it (`.minio`,
  `.mcli`, `.config/rc`);
- the server certificates of chainsmith move from `/etc/pki/minio` to `/etc/pki/rustfs`;
- the systemd unit (`User=`, `Group=`) and the paths in `/etc/default/rustfs` (or `/etc/default/minio`) and the client
  config point to `rustfs`, and RustFS (or MinIO) starts again.

Later runs, and new deployments, skip it. `rollout_new_certs.yml` runs it too, before the rustfs role.

If both a `minio` and a `rustfs` user exist on the backup host, the deploy stops: remove the `rustfs` user (and group)
when it owns nothing (e.g. created by a deploy of the linux role without the rename), and deploy again.

### On the backup host: from the minio role to the rustfs role

Deployments of v2.0.1 ran the `pgvillage.minio` role, with RustFS (`minio_use_rustfs: true`, the default in
`inventories/standard`) or with MinIO itself (deployments upgraded from v2.0.0 on Ubuntu, with
`minio_use_rustfs: false`). The rustfs role takes both over, with the same data, so the existing backups stay. In
`functional-all.yml` the step `rustfs` replaces the step `minio`:

1. the rustfs role stops and removes MinIO, if it runs (`rustfs_remove_minio: true` in `inventories/standard`): the
   `minio` service, its unit file, `/etc/default/minio`, and the `minio` and `mcli` packages. The data and the
   certificates stay, and chainsmith doesn't reissue the certificates.
2. it installs and configures RustFS (`/etc/default/rustfs`, `/etc/systemd/system/rustfs.service`, replacing those of
   the minio role), with the certificates in `/etc/rustfs/tls`, and (re)starts it on `/var/lib/minio`.
3. it configures `rc` (`~rustfs/.config/rc`) and creates the buckets that don't exist yet.

The switch is one-way: MinIO can't take over the data of RustFS.

WAL-G can't reach the backup host while RustFS (re)starts: `archive.sh` fails and PostgreSQL retries it, so the WAL
waits in `pg_wal` until RustFS is up again. Don't run a backup during the switch.

### On the database hosts

- The stolon role applies the cluster spec again when the stored spec differs from the inventory. When a cluster
  created with v2.0.1 still has parameters pending a restart, it restarts the keepers of that cluster one host at a
  time, with a failover of the primary: a short gap in writes.
- Services whose binary was replaced (a newer package) restart, one host at a time where the role restarts rolling.
- The roles stop before they change anything when their binary isn't where the units point (the packages of v2.0.1
  are in `/usr/bin`, the defaults).

A second deploy changes nothing.

## After the deploy

Check that the backups are there, per cluster on a database host:

```bash
sudo -iu postgres /opt/wal-g/scripts/list-backups.sh cluster1
```

The configuration of the minio role in the home directory of `rustfs` stays on the backup host; remove it when
everything works: `~rustfs/.minio` (the certificates the minio role gave RustFS or MinIO, including a copy of the
private key) and `~rustfs/.mcli/config.json` (keep `~rustfs/.mcli/certs`: `rc` uses the CA in it).

## Keep running as minio

To keep running RustFS as `minio`, set `rustfs_user: minio`, `chainsmith_server_cert_owner: minio` (backup hosts),
`minio` instead of `rustfs` for `backup` in `linux_users`, `linux_groups` and `chainsmith_users`, `/etc/pki/minio` as
the `source` of the server files in `rustfs_cert_files`, and disable the step
(`pgvillage_roles: {rustfs_user: {enabled: false}}`, see [Steps](../../reference/steps.md)).
