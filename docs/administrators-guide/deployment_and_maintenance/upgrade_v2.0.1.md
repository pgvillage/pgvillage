---
title: Upgrading from v2.0.0 to v2.0.1
summary: How to upgrade a PgVillage v2.0.0 deployment on Ubuntu to v2.0.1, and the PgVillage packages from apt/latest to apt v0.0.5, in two steps
authors:
  - Sebas Mannem
date: 2026-11-06
---

# Upgrading from v2.0.0 to v2.0.1

PgVillage v2.0.1 has the same playbooks as v2.0.0, but newer roles (`requirements.yml`) and new inventories
(`inventories/standard` and the OS layers). On Ubuntu and Debian it also moves to the new PgVillage apt repositories:

|                        | v2.0.0                                           | v2.0.1                                         |
|------------------------|--------------------------------------------------|------------------------------------------------|
| apt repository         | `repo.mannemsolutions.nl/apt/latest` (role default) | `repo.mannemsolutions.nl/apt/v0.0.5` (`inventories/ubuntu`) |
| Packages               | converted from rpm (`0v0.19.7-2`, ...)           | built as deb (`0.19.8-1`, ...)                 |
| Binaries               | `/usr/local/bin`                                 | `/usr/bin`                                     |
| Backups (backup host)  | minio                                            | RustFS                                         |

The roles of v2.0.1 expect the binaries in `/usr/bin`. Upgrade in two steps, so that the roles and the packages don't
change in the same run:

1. [v2.0.1 on apt/latest](#step-1-v201-on-aptlatest): the new roles, with the packages you have.
2. [apt v0.0.5](#step-2-apt-v005): the new packages.

This page is about Ubuntu (and Debian) deployments. On EL and SUSE the packages have always been in `/usr/bin`; there
you only bump the roles (and the repository version, `linux_pgvillage_channel`).

!!! warning
    Don't run v2.0.1 on a v2.0.0 deployment without the inventory changes of step 1. The new systemd units point to
    `/usr/bin`, and the role handlers restart stolon on all hosts: **all clusters go down** (`status=203/EXEC`), and WAL
    archiving stops (`archive.sh` exits with 127, the WAL piles up in `pg_wal`).

## What to expect

Tested on [lima](../platforms/lima.md) (Ubuntu 26.04, 3 database hosts, 2 clusters, TLS), with a client writing to
both clusters through HAProxy every second:

| Step   | Duration | Writes per cluster                                     |
|--------|----------|--------------------------------------------------------|
| Step 1 | 8 min    | one gap of 15-17 seconds (the primary moves to another host) |
| Step 2 | 5 min    | one gap of 11-17 seconds (the primary moves to another host) |

The roles restart the services one host at a time: per cluster first the keepers of the standbys, then the primary,
which they move to another host first (`stolonctl failkeeper`). etcd, pgroute66, HAProxy, keepalived and PgBouncer
restart one host at a time too. The two clusters have their gap at a different moment. Reads from the standbys go on.

On Ubuntu, `needrestart` restarts services after every apt run, on all hosts at once. The linux role of v2.0.1 tells
it to leave the PgVillage services alone (`/etc/needrestart/conf.d/pgvillage.conf`, see `linux_needrestart_exclude`
of the linux role): their roles restart them instead.

## Before you start

- Check that the clusters are healthy (`stolonctl status`) and that archiving works (`pg_stat_archiver`): you want a
  recent backup and WAL archive before you start.
- Plan the upgrade as a change with a short interruption of writes (see [What to expect](#what-to-expect)).
- Keep your inventory (hosts, cluster settings) as it is. The changes below go in your own inventory, e.g. in
  `group_vars/all/upgrade.yml`, on top of `inventories/standard` and `inventories/ubuntu` of v2.0.1.

## Step 1: v2.0.1 on apt/latest

Check out v2.0.1 and install its roles:

```bash
git checkout v2.0.1
ansible-galaxy role install --force -r requirements.yml
ansible-galaxy collection install -r requirements.yml
```

!!! note
    The `ansible.cfg` of v2.0.1 has `roles_path = ./roles:...`, so `ansible-galaxy` installs the roles in `./roles`,
    and they come before the v2.0.0 roles in `~/.ansible/roles`. Check the versions with `ansible-galaxy role list`.

Add to your inventory:

```yaml
---
# Upgrade step 1 (v2.0.1 on apt/latest): stay on the packages of apt/latest for now (inventories/ubuntu pins v0.0.5)
linux_public_repos:
  - name: PgVillage
    description: "PgVillage DEB Library - Ubuntu {{ ansible_facts.distribution_version }} - {{ ansible_facts.architecture }}"
    repo: >-
      [signed-by=/etc/apt/keyrings/pgvillage.asc arch={{ linux_architecture }}]
      https://repo.mannemsolutions.nl/apt/latest
      {{ ansible_facts.distribution_release }}
      main
    priority: 10
  - name: "pgdg{{ linux_pg_version }}"
    description: "PostgreSQL {{ linux_pg_version }} for Ubuntu {{ ansible_facts.distribution_version }} - {{ ansible_facts.architecture }}"
    repo: |
      [signed-by=/etc/apt/keyrings/postgresql.asc] https://apt.postgresql.org/pub/repos/apt {{ ansible_facts.distribution_release }}-pgdg main
    enabled: true
    priority: 20
# apt/latest ships minio, not RustFS (inventories/standard sets true); switching to RustFS is a migration of its own
minio_use_rustfs: false
# The packages of apt/latest install in /usr/local/bin; the v2.0.1 roles default to /usr/bin
stolon_bin_path: /usr/local/bin
etcd_install_dir: /usr/local/bin
pgroute66_deploydir: /usr/local/bin
pgfga_deploydir: /usr/local/bin
walg_bin: /usr/local/bin/wal-g-pg
pgquartz_bin: /usr/local/bin/pgquartz
```

| Variable                  | Why |
|---------------------------|-----|
| `linux_public_repos`      | `inventories/ubuntu` pins the PgVillage repository to v0.0.5. This is the same list, with apt/latest. |
| `minio_use_rustfs`        | `inventories/standard` replaces minio with RustFS, which apt/latest doesn't have (`No package matching 'rustfs' is available`). |
| `*_bin_path`, `*_install_dir`, `*_deploydir`, `*_bin` | The systemd units, the wal-g scripts (`archive.sh`) and the pgquartz jobs call these binaries. |

Then deploy as usual:

```bash
ansible-playbook -i inventories/standard -i inventories/ubuntu -i <your inventory> functional-all.yml
```

A second run should change nothing.

## Step 2: apt v0.0.5

Replace the additions of step 1 with:

```yaml
---
# Upgrade step 2 (apt v0.0.5): upgrade the PgVillage packages from apt/latest (/usr/local/bin) to those of v0.0.5
# (/usr/bin). Each role upgrades its own package and then restarts its services, one host at a time.
minio_use_rustfs: false
stolon_package_name_state: latest
etcd_package_version: latest
walg_package_state: latest
pgquartz_package_state: latest
pgroute66_package_state: latest
pgfga_package_state: latest
avchecker_package_state: latest
chainsmith_package_state: latest
```

- `linux_public_repos` and the binary paths go: `inventories/ubuntu` pins apt v0.0.5, whose packages install in
  `/usr/bin`, the role defaults.
- Upgrade the PgVillage packages with the states of their roles, not with `linux_package_state: latest`. That upgrades
  all packages of the hosts at the start of the run (in the test even the kernel): the services then run on binaries
  that are gone, before their roles have updated the units.

Deploy again (same command as in step 1), and check:

```bash
dpkg-query -W stolon etcd wal-g-pg pgroute66 pgquartz   # the versions of v0.0.5, e.g. stolon 0.19.8-1
command -v stolon-keeper wal-g-pg etcd                    # /usr/bin/...
```

After the upgrade:

- Remove the `*_state: latest` lines again, so later runs don't upgrade packages unplanned (or keep them, if that is
  how you want to patch).
- apt keeps the sources of apt/latest. Remove them on all hosts:
  `/etc/apt/sources.list.d/repo_mannemsolutions_nl_apt_latest.list` and
  `/etc/apt/sources.list.d/repo_pgvillage_org_apt_latest.list`.
- minio keeps running on the backup host. Moving the backups to RustFS is a separate step.
