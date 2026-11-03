---
title: Enterprise Linux
summary: Deploying PgVillage on Enterprise Linux (Rocky Linux, RHEL) with the el inventory on top of the standard inventory
authors:
  - Sebas Mannem
date: 2026-10-30
---

# Enterprise Linux

`inventories/standard` has no OS specifics. For Enterprise Linux (EL) hosts, such as Rocky Linux or RHEL, add
`inventories/el` between standard and the platform inventory:

```bash
ansible-playbook -i inventories/standard -i inventories/el -i inventories/<platform> functional-all.yml
```

For example, the default Azure image is Rocky Linux:

```bash
ansible-playbook -i inventories/standard -i inventories/el -i inventories/azure functional-all.yml
```

`inventories/el` has no hosts (its `hosts` file only lists the groups); they come from the platform inventory.

## What it changes

| File                           | Variable                   | EL |
|--------------------------------|----------------------------|----|
| `group_vars/all/postgres.yml`  | `postgresql_bindir`        | `/usr/pgsql-<version>/bin/` (PGDG rpm's) |
| `group_vars/all/uninstall.yml` | `uninstall_linux_packages` | `postgresql17`, `-server`, `-contrib`, `-devel`, `-plpython3`, `-libs`, `stolon`, `wal-g-pg`, `etcd` |
| `group_vars/all/uninstall.yml` | `uninstall_os_file_list`   | `/usr/pgsql-<version>`, `/var/lib/pgsql-<version>`, `/etc/systemd/system/postgresql-<version>.service` |

## Packages, repositories, users

These are not set in the inventory: the `pgvillage.linux` role picks them for dnf.

- **Packages**: `stolon`, `wal-g-pg`, `etcd`, `glibc-all-langpacks`, `langpacks-en` and the PostgreSQL packages
  (`postgresql17`, `-server`, `-contrib`, `-devel`, `-plpython3`) on `hacluster`; `minio` on `backup`; `keepalived`,
  `haproxy`, `pgroute66` on `router`; `chainsmith` on `localhosts`.
- **Repositories**: PgVillage (`repo.mannemsolutions.nl/yum`), PGDG (per PostgreSQL version, common and extras), EPEL.
- **Users and groups**: `postgres`, `pgbouncer`, `avchecker`, `pgquartz`, `pgfga`, `pgroute66` on `hacluster`;
  `minio` on `backup`; `haproxy`, `keepalived`, `pgroute66` on `router`.

To change them, set `linux_packages`, `linux_public_repos`, `linux_users` or `linux_groups` in `inventories/el` (or the
platform inventory). They are dictionaries per host group, and a later inventory replaces them as a whole.
