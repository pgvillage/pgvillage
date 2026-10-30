---
title: Vagrant - inventory
summary: What the vagrant inventory changes on top of the standard inventory, and why
authors:
  - Sebas Mannem
date: 2026-10-30
---

# Vagrant - inventory

`inventories/vagrant` only has what is specific to the vagrant boxes. It goes on top of `inventories/standard` and an
OS inventory (Ubuntu by default, the OS of the boxes), in this order:

```bash
ansible-playbook -i inventories/standard -i inventories/ubuntu -i inventories/vagrant functional-all.yml
```

A file in `inventories/vagrant/group_vars/<group>/` overrides the variables with the same name in the earlier
inventories. Everything not listed here comes from standard (the clusters and their ports, wal-g, minio buckets,
PgBouncer, avchecker, firewall, etcd, nagios, etc.) or from the OS inventory (packages, repositories, users, paths).

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

The boxes have a NAT interface (for internet access) and a private network (172.30.1.0/24). Everything PgVillage runs
on the private network. The name of that interface depends on the box (`enp0s9` on the Ubuntu box, `eth1` or
`enp0s8` on others), so `vagrant_iface` looks it up: the interface whose address is `ansible_host`.

| File                            | Variable                                                    | Value |
|---------------------------------|-------------------------------------------------------------|-------|
| `group_vars/all/network.yml`    | `vagrant_iface`                                             | the interface with `ansible_host` (from the facts) |
| `group_vars/all/etcd.yml`       | `etcd_iface_cluster`                                        | `{{ vagrant_iface }}` |
| `group_vars/all/stolon.yml`     | `stolon_pg_listen_address`, `stolon_proxy_listen_address`   | `{{ ansible_host }}` |
| `group_vars/all/keepalived.yml` | `keepalived_interface`, `keepalived_vip`                    | `{{ vagrant_iface }}`, `172.30.1.30` |

## Operating system

The inventory has no OS specifics: the package names, repositories, users and paths come from the OS inventory
between standard and vagrant. Use the one that matches the box (`PGV_OS`, see
[Other operating systems](index.md#other-operating-systems)):

```bash
ansible-playbook -i inventories/standard -i inventories/ubuntu -i inventories/vagrant functional-all.yml  # default
ansible-playbook -i inventories/standard -i inventories/el -i inventories/vagrant functional-all.yml      # Rocky Linux
ansible-playbook -i inventories/standard -i inventories/suse -i inventories/vagrant functional-all.yml    # openSUSE
```

See [Ubuntu](../ubuntu/index.md), [EL](../el/index.md) and [SUSE](../suse/index.md).

## Data directories

The Vagrantfile creates `/data/postgres/data` and `/data/postgres/wal` on the database hosts: the
`postgresql_data_mountpoint` and `postgresql_wal_mountpoint` of standard. They are directories on the root disk, not
separate disks.

## Certificates

Chainsmith creates certificates for the database hosts and the minio host (see standard). The only difference on
vagrant: the server certificates of the database hosts are in `/etc/pki/postgres` (the chainsmith role default)
instead of on the data mountpoint:

| File                                  | Variable                      | Value |
|---------------------------------------|-------------------------------|-------|
| `group_vars/hacluster/chainsmith.yml` | `chainsmith_server_cert_path` | `/etc/pki/postgres` |
| `group_vars/all/stolon.yml`           | `stolon_pg_certdir`           | `/etc/pki/postgres` |

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

## Known issues

- The HAProxy ports (35433-35435) are not in `firewall_ports` (standard only opens the PostgreSQL, PgBouncer, stolon
  proxy and etcd ports). `firewall_ports` is set for `hacluster`, so opening them means overriding the whole
  `firewall_ports` in `group_vars/hacluster/firewall.yml`.
