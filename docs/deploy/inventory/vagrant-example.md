---
title: Vagrant - inventory
summary: What the vagrant inventory changes on top of the standard inventory, and why
authors:
  - Sebas Mannem
date: 2026-10-30
---

# Vagrant - inventory

`inventories/platform/vagrant` only has what is specific to the vagrant boxes. It goes on top of `inventories/standard` and an
OS inventory (Ubuntu by default, the OS of the boxes), in this order:

```bash
ansible-playbook -i inventories/standard -i inventories/os/debian -i inventories/platform/vagrant functional-all.yml
```

A file in `inventories/platform/vagrant/group_vars/<group>/` overrides the variables with the same name in the earlier
inventories. Everything not listed here comes from standard (the clusters and their ports, wal-g, minio buckets,
PgBouncer, avchecker, firewall, etcd, nagios, etc.) or from the OS inventory (packages, repositories, users, paths).

## Hosts

`hosts` defines the vagrant boxes, and puts the router on the database hosts (standard puts stolon and etcd there):

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
[Other operating systems](../../try-it/vagrant/index.md#other-operating-systems)):

```bash
ansible-playbook -i inventories/standard -i inventories/os/debian -i inventories/platform/vagrant functional-all.yml  # default
ansible-playbook -i inventories/standard -i inventories/os/el -i inventories/platform/vagrant functional-all.yml      # Rocky Linux
ansible-playbook -i inventories/standard -i inventories/os/suse -i inventories/platform/vagrant functional-all.yml    # openSUSE
```

See [Debian (including Ubuntu)](../os/debian.md), [EL](../os/el.md) and [SUSE](../os/suse.md).

## Data directories

The Vagrantfile creates `/data/postgres/data` and `/data/postgres/wal` on the database hosts: the
`postgresql_data_mountpoint` and `postgresql_wal_mountpoint` of standard. They are directories on the root disk, not
separate disks.

## Certificates

Chainsmith creates certificates for the database hosts and the minio host, as in standard: the server certificates of
the database hosts are on the data mountpoint (`/data/postgres/data/certs`).

## Router

HAProxy, keepalived and pgroute66 run on the database hosts (`router` = `hacluster`), with keepalived managing the VIP
`172.30.1.30`. Only the router hosts (`hosts`) and the VIP are vagrant specific; HAProxy (a read-write, read-only and
stolon proxy frontend for every cluster), pgroute66 and the firewall ports come from standard. See
[HAProxy](../../tools/haproxy.md#multi-instance) and
[pgroute66](../../tools/pgroute66.md#multi-instance).

| File                              | What |
|-----------------------------------|------|
| `hosts`                           | `router` and `haproxy` are the database hosts (`hacluster`) |
| `group_vars/all/keepalived.yml`   | VIP and interface |

The firewall: standard opens the ports of the groups a host is in (`firewall_ports_hacluster`,
`firewall_ports_backup` and `firewall_ports_router`, combined in `firewall_ports`), so the database hosts get both the
PostgreSQL and the HAProxy ports. The keepalived role allows VRRP in firewalld, so only one host has the VIP.

## Known issues

None at the moment. Tested on Ubuntu boxes (2026-10-31): a fresh `vagrant up` and deploy without failures, a second
deploy changes nothing, and PostgreSQL, stolon (both clusters), etcd, PgBouncer, RustFS, WAL archiving with wal-g,
HAProxy and keepalived (one VIP holder, failover) work.
