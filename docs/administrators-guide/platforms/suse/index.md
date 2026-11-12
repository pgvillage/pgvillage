---
title: SUSE
summary: Deploying PgVillage on openSUSE / SUSE with the suse inventory on top of the standard inventory
authors:
  - Sebas Mannem
date: 2026-10-30
---

# SUSE

`inventories/standard` has no OS specifics. For openSUSE or SUSE hosts, add `inventories/suse` between standard and
the platform inventory:

```bash
ansible-playbook -i inventories/standard -i inventories/suse -i inventories/<platform> functional-all.yml
```

For example, on Azure with an openSUSE Leap image (see [Azure - EL vs SUSE](../azure/el-vs-suse.md)):

```bash
ansible-playbook -i inventories/standard -i inventories/suse -i inventories/azure functional-all.yml
```

`inventories/suse` has no hosts (its `hosts` file only lists the groups); they come from the platform inventory.

!!! note
    Out of the box, SUSE runs on x86_64 only. download.postgresql.org (PGDG) builds PostgreSQL for SUSE only on x86_64
    (at the time of writing leap-16.0 for openSUSE, and sles15/16 for SUSE). The PgVillage packages exist for
    leap 16 on x86_64 and aarch64, so on ARM64 (e.g. Apple silicon) you need PostgreSQL packages from another source:
    openSUSE's own repository has them for aarch64, and other builds (or your own) work too. A setup for SUSE on ARM64
    with those packages is planned. If you need other architectures or specific SUSE builds, please reach out to us.

## What it changes

| File                           | Variable                   | SUSE |
|--------------------------------|----------------------------|------|
| `group_vars/all/packages.yml`  | `linux_packages`           | `stolon`, `wal-g-pg`, `etcd`, `glibc-locale`, `glibc-locale-base`, `openssl`, `postgresql17`, `-server`, `-contrib` on `hacluster`; `rustfs`, `rustfs-cli` on `backup`; `keepalived`, `haproxy`, `pgroute66` on `router`; `chainsmith` on `localhosts` |
| `group_vars/all/postgres.yml`  | `postgresql_bindir`        | `/usr/pgsql-<version>/bin/` (PGDG rpm's) |
| `group_vars/all/uninstall.yml` | `uninstall_linux_packages` | `postgresql17`, `-server`, `-contrib`, `-libs`, `stolon`, `wal-g-pg`, `etcd` |
| `group_vars/all/uninstall.yml` | `uninstall_os_file_list`   | `/usr/pgsql-<version>`, `/var/lib/pgsql-<version>`, `/etc/systemd/system/postgresql-<version>.service` |

`linux_packages` overrides the `pgvillage.linux` role default for zypper, which also installs
`postgresql17-plpython3` (not available for openSUSE) and `postgresql17-devel`. It is one dictionary, and a later
inventory replaces it as a whole, so it lists all groups.

Repositories, users and groups are not set in the inventory: the `pgvillage.linux` role picks them for zypper
(PgVillage `repo.pgvillage.org/zypp/<channel>`, with `linux_pgvillage_channel: latest` from `inventories/standard`,
and PGDG per PostgreSQL version, common and extras).

## openSUSE PostgreSQL packages

`postgresql_bindir` is the path of the PGDG rpm's. If you use the openSUSE PostgreSQL packages instead, set it to
`/usr/lib/postgresql<version>/bin` (in `inventories/suse` or the platform inventory), and change the `/usr/pgsql-*`
and `/var/lib/pgsql-*` entries in `uninstall_os_file_list` accordingly.
