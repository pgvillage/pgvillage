---
title: Upgrading from v2.0.0 to v2.0.1
summary: How to upgrade a PgVillage v2.0.0 deployment on Ubuntu to v2.0.1, and the PgVillage packages from the old apt repository (v0.3.2) to the new one (apt/latest, v0.0.5 and newer)
authors:
  - Sebas Mannem
date: 2026-11-07
---

# Upgrading from v2.0.0 to v2.0.1

PgVillage v2.0.1 has the same playbooks as v2.0.0, but newer roles (`requirements.yml`) and new inventories
(`inventories/standard` and the OS layers). On Ubuntu and Debian it also moves to the new PgVillage apt packages:

|                        | v2.0.0                                                | v2.0.1                                                  |
|------------------------|-------------------------------------------------------|---------------------------------------------------------|
| apt repository         | `repo.mannemsolutions.nl/apt/latest` (role default)   | `repo.pgvillage.org/apt/latest` (`inventories/standard`) |
| Packages in it         | apt v0.3.2: converted from rpm (`0v0.19.7-2`, ...)    | apt v0.0.5 and newer: built as deb (`0.19.8-1`, ...)    |
| Binaries               | `/usr/local/bin`                                      | `/usr/bin`                                              |
| Backups (backup host)  | minio                                                 | RustFS                                                  |

Both use `apt/latest` (`repo.pgvillage.org` and `repo.mannemsolutions.nl` serve the same repository), but `apt/latest`
moved from v0.3.2 to v0.0.5. The roles of v2.0.0 expect the binaries in
`/usr/local/bin`, those of v2.0.1 in `/usr/bin`. Upgrade in three steps, so that the roles and the packages don't change
in the same run:

0. [Pin apt v0.3.2](#step-0-pin-apt-v032) (still with v2.0.0): keep the packages you have.
1. [v2.0.1 on apt v0.3.2](#step-1-v201-on-apt-v032): the new roles, with the packages you have.
2. [apt/latest](#step-2-aptlatest): the new packages.

This page is about Ubuntu (and Debian) deployments. On EL and SUSE the packages have always been in `/usr/bin`; there
you only bump the roles (and the repository version, `linux_pgvillage_channel`).

!!! danger "Do step 0 now"
    A v2.0.0 deployment that still uses `apt/latest` gets the new packages as soon as they are installed or upgraded:
    on a new or rebuilt host, with `apt upgrade`, or with a `*_package_state: latest`. Their binaries are in `/usr/bin`,
    while the systemd units of v2.0.0 point to `/usr/local/bin`: the services fail at their next restart. Step 0
    prevents that, and you can do it any time before the upgrade itself.

!!! warning
    Don't run v2.0.1 on a v2.0.0 deployment without the inventory changes of step 1. The new systemd units point to
    `/usr/bin`, and the role handlers restart stolon on all hosts: **all clusters go down** (`status=203/EXEC`), and WAL
    archiving stops (`archive.sh` exits with 127, the WAL piles up in `pg_wal`).

## What to expect

Tested on [lima](../platforms/lima.md) (Ubuntu 26.04, 3 database hosts, 2 clusters, TLS), with a client writing to
both clusters through HAProxy every second:

| Step   | Duration | Writes per cluster                                     |
|--------|----------|--------------------------------------------------------|
| Step 0 | 2 min    | no interruption (only the apt sources change)          |
| Step 1 | 5-8 min  | two gaps: 13-18 seconds (the WAL moves to its subfolder, see below), then 10-17 seconds (the primary moves to another host) |
| Step 2 | 5-6 min  | one gap of 11-17 seconds (the primary moves to another host) |

The roles restart the services one host at a time: per cluster first the keepers of the standbys, then the primary,
which they move to another host first (`stolonctl failkeeper`). etcd, pgroute66, HAProxy, keepalived and PgBouncer
restart one host at a time too. The two clusters have their gap at a different moment. Reads from the standbys go on.

In step 1, v2.0.1 also moves the WAL of each cluster from `<stolon_wal_dir>/<cluster>` to the subfolder
`<stolon_wal_dir>/<cluster>/wal` (`tasks/stolon_wal_subfolder.yml`, before the stolon role), so the WAL of a cluster can
have its own disk, mounted on `<stolon_wal_dir>/<cluster>` (see [BYO](../platforms/byo.md)). For that, the keepers of a
cluster stop on all database hosts at the same time, for the seconds the move takes: no reads either. Once moved, later
runs skip it.

On Ubuntu, `needrestart` restarts services after every apt run, on all hosts at once. The linux role of v2.0.1 tells
it to leave the PgVillage services alone (`/etc/needrestart/conf.d/pgvillage.conf`, see `linux_needrestart_exclude`
of the linux role): their roles restart them instead.

## Before you start

- Check that the clusters are healthy (`stolonctl status`) and that archiving works (`pg_stat_archiver`): you want a
  recent backup and WAL archive before you start.
- Plan steps 1 and 2 as a change with a short interruption of writes (see [What to expect](#what-to-expect)).
- Keep your inventory (hosts, cluster settings) as it is. The changes below go in your own inventory, e.g. in
  `group_vars/all/upgrade.yml`: on top of your v2.0.0 inventory for step 0, and on top of `inventories/standard` and
  `inventories/ubuntu` of v2.0.1 for steps 1 and 2.
- In the commands below, `<inventories>` stands for the `-i` options of your deploy.

## Step 0: pin apt v0.3.2

Still with v2.0.0: point the PgVillage apt repository to v0.3.2, the version that `apt/latest` had until it moved. Add
to your inventory:

```yaml
---
# Upgrade step 0: pin the PgVillage apt repository to v0.3.2 (the packages of v2.0.0); apt/latest moved to v0.0.5
linux_public_repos:
  - name: PgVillage
    description: "PgVillage DEB Library - Ubuntu {{ ansible_facts.distribution_version }} - {{ ansible_facts.architecture }}"
    repo: >-
      [signed-by=/etc/apt/keyrings/pgvillage.asc arch={{ linux_architecture }}]
      https://repo.pgvillage.org/apt/v0.3.2
      {{ ansible_facts.distribution_release }}
      main
    priority: 10
  - name: "pgdg{{ linux_pg_version }}"
    description: "PostgreSQL {{ linux_pg_version }} for Ubuntu {{ ansible_facts.distribution_version }} - {{ ansible_facts.architecture }}"
    repo: |
      [signed-by=/etc/apt/keyrings/postgresql.asc] https://apt.postgresql.org/pub/repos/apt {{ ansible_facts.distribution_release }}-pgdg main
    enabled: true
    priority: 20
```

Deploy as usual (v2.0.0). This adds the v0.3.2 repository, but it doesn't remove the one of `apt/latest`
(`ansible.builtin.apt_repository` only adds): remove that one yourself, on all hosts:

```bash
ansible all <inventories> -b -m ansible.builtin.file \
  -a 'path=/etc/apt/sources.list.d/repo_mannemsolutions_nl_apt_latest.list state=absent'
ansible all <inventories> -b -m ansible.builtin.apt -a 'update_cache=true'
```

Check that the hosts only see v0.3.2 now:

```bash
ansible all <inventories> -m ansible.builtin.shell -a 'apt-cache policy stolon | grep -E "http|Candidate"'
# Candidate: 0v0.19.7-2, and only https://repo.pgvillage.org/apt/v0.3.2
```

If you pinned `https://repo.mannemsolutions.nl/apt/v0.3.2` instead: that is the same repository, keep it.

Keep these additions until step 2. Your v2.0.0 deployment now stays on the packages it has, also when `apt/latest`
moves.

## Step 1: v2.0.1 on apt v0.3.2

Check out v2.0.1 and install its roles:

```bash
git checkout v2.0.1
ansible-galaxy role install --force -r requirements.yml
ansible-galaxy collection install -r requirements.yml
```

!!! note
    The `ansible.cfg` of v2.0.1 has `roles_path = ./roles:...`, so `ansible-galaxy` installs the roles in `./roles`,
    and they come before the v2.0.0 roles in `~/.ansible/roles`. Check the versions with `ansible-galaxy role list`.

Keep the `linux_public_repos` of step 0, and add:

```yaml
# Upgrade step 1 (v2.0.1 on apt v0.3.2)
# apt v0.3.2 ships minio, not RustFS (inventories/standard sets true); switching to RustFS is a migration of its own
minio_use_rustfs: false
# The packages of apt v0.3.2 install in /usr/local/bin; the v2.0.1 roles default to /usr/bin
stolon_bin_path: /usr/local/bin
etcd_install_dir: /usr/local/bin
pgroute66_deploydir: /usr/local/bin
pgfga_deploydir: /usr/local/bin
walg_bin: /usr/local/bin/wal-g-pg
pgquartz_bin: /usr/local/bin/pgquartz
```

| Variable                  | Why |
|---------------------------|-----|
| `linux_public_repos`      | `inventories/standard` sets `linux_pgvillage_channel: latest` (`repo.pgvillage.org/apt/latest`), which has the new packages now. This list replaces the role default with v0.3.2. |
| `minio_use_rustfs`        | `inventories/standard` replaces minio with RustFS, which apt v0.3.2 doesn't have (`No package matching 'rustfs' is available`). |
| `*_bin_path`, `*_install_dir`, `*_deploydir`, `*_bin` | The systemd units, the wal-g scripts (`archive.sh`) and the pgquartz jobs call these binaries. |

Then deploy as usual:

```bash
ansible-playbook -i inventories/standard -i inventories/ubuntu -i <your inventory> functional-all.yml
```

A second run should change nothing. Check that `pg_wal` of each cluster points to the subfolder:

```bash
sudo ls -l /data/postgres/data/cluster1/postgres/pg_wal   # standard paths; -> <stolon_wal_dir>/cluster1/wal
```

## Step 2: apt/latest

Replace the additions of steps 0 and 1 with:

```yaml
---
# Upgrade step 2 (apt/latest): upgrade the PgVillage packages from apt v0.3.2 (/usr/local/bin) to those of apt/latest
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

- `linux_public_repos` and the binary paths go: `inventories/standard` uses `repo.pgvillage.org/apt/latest`, whose
  packages install in `/usr/bin`, the role defaults.
- Upgrade the PgVillage packages with the states of their roles, not with `linux_package_state: latest`. That upgrades
  all packages of the hosts at the start of the run (in the test even the kernel): the services then run on binaries
  that are gone, before their roles have updated the units.

Deploy again (same command as in step 1), and check:

```bash
dpkg-query -W stolon etcd wal-g-pg pgroute66 pgquartz   # the new versions, e.g. stolon 0.19.8-1
command -v stolon-keeper wal-g-pg etcd                    # /usr/bin/...
```

After the upgrade:

- Remove the `*_state: latest` lines again, so later runs don't upgrade packages unplanned (or keep them, if that is
  how you want to patch).
- Remove the source of apt v0.3.2 on all hosts (apt keeps it, like in step 0):

    ```bash
    ansible all <inventories> -b -m ansible.builtin.shell \
      -a 'rm -fv /etc/apt/sources.list.d/repo_*_apt_v0_3_2.list'
    ansible all <inventories> -b -m ansible.builtin.apt -a 'update_cache=true'
    ```

- minio keeps running on the backup host. Moving the backups to RustFS is a separate step, with the release after
  v2.0.1: see [Migrating from the minio role](../../tools/rustfs.md#migrating-from-the-minio-role).
