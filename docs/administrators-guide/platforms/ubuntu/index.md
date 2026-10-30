---
title: Ubuntu
summary: Deploying PgVillage on Ubuntu with the ubuntu inventory on top of the standard inventory
authors:
  - Sebas Mannem
date: 2026-10-30
---

# Ubuntu

`inventories/standard` has no OS specifics. For Ubuntu hosts, add `inventories/ubuntu` between standard and the
platform inventory, so the Ubuntu values override standard and the platform overrides both (for Enterprise Linux,
use [`inventories/el`](../el/index.md), for SUSE [`inventories/suse`](../suse/index.md)):

```bash
ansible-playbook -i inventories/standard -i inventories/ubuntu -i inventories/<platform> functional-all.yml
```

For example, the [vagrant](../vagrant/index.md) boxes run Ubuntu by default:

```bash
ansible-playbook -i inventories/standard -i inventories/ubuntu -i inventories/vagrant functional-all.yml
```

`inventories/ubuntu` has no hosts (its `hosts` file only lists the groups); they come from the platform inventory.

## What it changes

| File                                 | Variable                   | Ubuntu                                   | EL (`inventories/el`) |
|--------------------------------------|----------------------------|------------------------------------------|---------------|
| `group_vars/all/packages.yml`        | `linux_public_repos`       | apt repositories: PgVillage pinned to `repo.mannemsolutions.nl/apt/v0.3.2` (role default: `latest`), and pgdg | role default for dnf |
| `group_vars/all/postgres.yml`        | `postgresql_bindir`        | `/usr/lib/postgresql/<version>/bin`       | `/usr/pgsql-<version>/bin/` |
| `group_vars/all/uninstall.yml`       | `uninstall_linux_packages` | `postgresql-17`, `stolon`, `wal-g-pg`, `etcd` | EL package names |
| `group_vars/all/uninstall.yml`       | `uninstall_os_file_list`   | `/etc/postgresql/<version>`, `/var/lib/postgresql/<version>` (the default cluster of the deb package) | `/usr/pgsql-<version>`, `/var/lib/pgsql-<version>`, ... |
| `group_vars/hacluster/pgbouncer.yml` | `pgbouncer_install_dir`    | `/usr/sbin`                               | role default |

Packages, users and groups are not set in the inventory: the `pgvillage.linux` role picks them for apt:

- **Packages**: `stolon`, `wal-g-pg`, `etcd`, `acl` and `postgresql-17` on `hacluster`; `minio` and `acl` on `backup`;
  `keepalived`, `haproxy`, `pgroute66` on `router`; `chainsmith` on `localhosts`.
- **Users and groups**: `postgres`, `pgbouncer`, `avchecker`, `pgquartz`, `pgfga`, `pgroute66` on `hacluster`;
  `minio` on `backup`; `haproxy`, `keepalived`, `pgroute66` on `router`.

To change them, set `linux_packages`, `linux_users` or `linux_groups`. They are dictionaries per host group, and a
later inventory replaces them as a whole, so list all groups.

## Nagios

The nagios role doesn't work on Ubuntu. It is disabled in `inventories/standard` (`nagios_enabled: false`, for
multi-instance), so there is nothing to change for Ubuntu.
