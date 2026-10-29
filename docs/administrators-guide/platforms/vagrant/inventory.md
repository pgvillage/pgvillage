---
title: Vagrant - inventory
summary: What the vagrant inventory changes on top of the standard inventory, and why
authors:
  - Sebas Mannem
date: 2026-10-30
---

# Vagrant - inventory

`inventories/vagrant` only has what differs from `inventories/standard`. Use both, standard first:

```bash
ansible-playbook -i inventories/standard -i inventories/vagrant functional-all.yml
```

A file in `inventories/vagrant/group_vars/<group>/` overrides the variables with the same name in
`inventories/standard/group_vars/<group>/`. Everything not listed here (the clusters and their ports, wal-g, minio
buckets, PgBouncer, avchecker, firewall, etcd, nagios, etc.) comes from standard.

## Hosts

`hosts` defines the vagrant boxes, and puts stolon, etcd and the router on the database hosts:

| Group         | Hosts                                      |
|---------------|--------------------------------------------|
| `hacluster`   | `db-1.local`, `db-2.local`, `db-3.local`   |
| `stolon`      | `hacluster`                                |
| `etcd_master` | `hacluster`                                |
| `router`      | `hacluster`                                |
| `haproxy`     | `hacluster` (used by the nagios play)      |
| `backup`      | `minio.local`                              |
| `localhosts`  | `localhost` (the Ansible host)             |

Ansible logs in as `vagrant` (`ansible_user`).

`localhost` must be defined here, not in standard: its `inventory_dir` sets `cluster_name`, which is `vagrant`.

## Network

The boxes have a NAT interface (for internet access) and a private network on `enp0s9` (172.30.1.0/24). Everything
PgVillage runs on the private network:

| File                     | Variable                                                    | Value |
|--------------------------|-------------------------------------------------------------|-------|
| `group_vars/all/etcd.yml`   | `etcd_iface_cluster`                                     | `enp0s9` |
| `group_vars/all/stolon.yml` | `stolon_pg_listen_address`, `stolon_proxy_listen_address` | `{{ ansible_facts.enp0s9.ipv4.address }}` |
| `group_vars/all/keepalived.yml` | `keepalived_interface`, `keepalived_vip`             | `enp0s9`, `172.30.1.30` |

## Ubuntu

The boxes run Ubuntu; standard is for EL.

| File                              | Variable                | Value |
|-----------------------------------|-------------------------|-------|
| `group_vars/all/packages.yml`     | `linux_packages`        | Ubuntu package names (`postgresql-17` instead of `postgresql17-server`, etc.), plus `acl`, and the router packages |
| `group_vars/all/packages.yml`     | `linux_public_repos`    | apt repositories: PgVillage (`repo.mannemsolutions.nl/apt`) and pgdg |
| `group_vars/all/packages.yml`     | `linux_users`, `linux_groups` | system users and groups per host group, including the router users |
| `group_vars/all/postgres.yml`     | `postgresql_bindir`     | `/usr/lib/postgresql/<version>/bin` |
| `group_vars/hacluster/pgbouncer.yml` | `pgbouncer_install_dir` | `/usr/sbin` |

## Certificates

Chainsmith creates certificates for the database hosts and the minio host, and stores them in
`/etc/pki/<owner>` instead of the data mountpoint:

| File                                  | Variable                                    | Value |
|---------------------------------------|---------------------------------------------|-------|
| `group_vars/all/chainsmith.yml`       | `server_cert_path`                          | `/etc/pki/{{ server_cert_owner }}` |
| `group_vars/all/chainsmith.yml`       | `chainsmith_nodes`, `chainsmith_ips`, `chainsmith_servers` | `hacluster` and `backup` hosts |
| `group_vars/all/chainsmith.yml`       | `chainsmith_server_cert_path`               | `{{ server_cert_path }}` |
| `group_vars/all/chainsmith.yml`       | `chainsmith_node_group`, `chainsmith_users` | client certificates for the users on `hacluster`, `router` and `backup` |
| `group_vars/all/stolon.yml`           | `stolon_pg_certdir`                         | `{{ server_cert_path }}` |
| `group_vars/hacluster/chainsmith.yml` | `server_cert_owner`                         | `postgres` |
| `group_vars/backup/minio.yml`         | `server_cert_owner`                         | `minio` |
| `group_vars/backup/chainsmith.yml`    | `chainsmith_client_*`, `chainsmith_server_cert_owner` | certificate files for minio (`~/.mcli/certs`) |

## Router

HAProxy, keepalived and pgroute66 run on the database hosts (`router` = `hacluster`), with keepalived managing the VIP
`172.30.1.30`. See [HAProxy](../../deployment_and_maintenance/multiinstance/haproxy.md) and
[pgroute66](../../deployment_and_maintenance/multiinstance/pgroute66.md).

| File                              | What |
|-----------------------------------|------|
| `group_vars/all/haproxy.yml`      | Frontends and backends for `cluster1`: read-write (35433), stolon proxy (35434) and read-only (35435) |
| `group_vars/all/keepalived.yml`   | VIP and interface |
| `group_vars/all/pgroute66.yml`    | pgroute66 groups for `cluster1` (5433) and `cluster2` (5434) |

!!! note
    HAProxy only has frontends for `cluster1`. Add frontends and backends for `cluster2` in `haproxy.yml` (and open
    the ports in the firewall) if you need them.

## Other operating systems

For EL boxes (e.g. Rocky Linux), use the standard values instead of the Ubuntu overrides:

- Remove `group_vars/all/postgres.yml` and `group_vars/hacluster/pgbouncer.yml`.
- In `group_vars/all/packages.yml`, remove `linux_public_repos`, and use the EL package names of
  `inventories/standard/group_vars/all/packages.yml` in `linux_packages` (keep the `backup`, `router` and `localhosts`
  entries).

For openSUSE, see [EL vs SUSE](../azure/el-vs-suse.md) for the package and path changes.

## Known issues

- `uninstall_linux_packages` comes from standard and has the EL package names, so `uninstall.yml` doesn't remove the
  Ubuntu packages.
- The HAProxy ports (35433-35435) are not in `firewall_ports` (standard only opens the PostgreSQL, PgBouncer, stolon
  proxy and etcd ports). `firewall_ports` is set for `hacluster`, so opening them means overriding the whole
  `firewall_ports` in `group_vars/hacluster/firewall.yml`.
