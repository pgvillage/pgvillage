---
title: Getting started
summary: The simplest PgVillage setup on your own machines, with the standard inventory, an OS layer and your own hosts
authors:
  - Sebas Mannem
date: 2026-11-01
---

# Getting started

This page describes the simplest PgVillage setup: your own machines (physical, VMs on KVM, VMware, a cloud, ...),
the standard PgVillage config, and an inventory with only your hosts. For ready-made environments (Azure, Vagrant), see
[Running on specific platforms](#running-on-specific-platforms).

## TL;DR

You need 3 database hosts, 1 backup host and a control node (where you run Ansible), all running the same supported OS
(see [Supported platforms](#supported-platforms)), with internet access and a user with ssh access and sudo on all
hosts.

On the database hosts, create the data and wal directories (preferably separate disks):

```bash
sudo mkdir -p /data/postgres/data /data/postgres/wal
```

On the control node:

```bash
git clone https://github.com/pgvillage/pgvillage.git ~/git/pgvillage
cd ~/git/pgvillage
python3 -m venv ~/venv && . ~/venv/bin/activate
pip install ansible netaddr
ansible-galaxy role install --role-file requirements.yml
ansible-galaxy collection install --requirements-file requirements.yml

mkdir -p inventories/mycluster
cat > inventories/mycluster/hosts <<'EOF'
all:
  children:
    hacluster:
      hosts:
        db-1.example.com:
        db-2.example.com:
        db-3.example.com:
    backup:
      hosts:
        backup.example.com:
    localhosts:
      hosts:
        localhost:
          ansible_connection: local
          ansible_python_interpreter: "{{ansible_playbook_python}}"
EOF

# os/el, os/debian (also for Ubuntu) or os/suse: the OS of your hosts
ansible-playbook -i inventories/standard -i inventories/os/el -i inventories/mycluster functional-all.yml
```

That gives you two PostgreSQL clusters (`cluster1` and `cluster2`), each with a primary and two standbys managed by
stolon, PgBouncer, backups with wal-g to RustFS on the backup host, and certificates from chainsmith.

## Supported platforms

<table markdown="1">
<tr markdown="1">
<th></th>
<th colspan="2">Debian 12, 13<br>Ubuntu 22.04, 24.04, 26.04, 26.10<br>EL 8, 9, 10<br>Fedora 43, 44</th>
<th colspan="2">openSUSE Leap 16</th>
</tr>
<tr markdown="1">
<th></th>
<th>AMD</th>
<th>ARM</th>
<th>AMD</th>
<th>ARM*</th>
</tr>
<tr markdown="1">
<td markdown="1">[Azure](deploy/platforms/azure/index.md)</td>
<td>✅</td>
<td>✅</td>
<td>✅</td>
<td>⚠️*</td>
</tr>
<tr markdown="1">
<td markdown="1">[macOS](try-it/vagrant/macos.md) ([Vagrant](try-it/vagrant/index.md))</td>
<td>❌</td>
<td>✅</td>
<td>❌</td>
<td>⚠️*</td>
</tr>
<tr markdown="1">
<td markdown="1">[macOS](try-it/vagrant/macos.md) ([Lima](try-it/lima.md))</td>
<td>✅**</td>
<td>✅</td>
<td>✅**</td>
<td>⚠️*</td>
</tr>
<tr markdown="1">
<td markdown="1">Linux ([Vagrant](try-it/vagrant/index.md))</td>
<td>✅</td>
<td>✅</td>
<td>✅</td>
<td>⚠️*</td>
</tr>
<tr markdown="1">
<td markdown="1">[BYO](deploy/byo.md)</td>
<td>✅</td>
<td>✅</td>
<td>✅</td>
<td>⚠️*</td>
</tr>
</table>

\* PostgreSQL.org does not build ARM packages for openSUSE Leap 16.<br>
\** Lima can be used with AMD emulation, but it has a huge performance impact.

The versions are those in the [PgVillage repositories](https://repo.pgvillage.org/). See also
[ARM vs AMD](deploy/os/arm-vs-amd.md).

## The layers

PgVillage combines three inventories, in this order, so later values win:

| Layer | Inventory | What it has |
|-------|-----------|-------------|
| Standard | [`inventories/standard`](#the-standard-inventory) | The PgVillage config, shared by all platforms. No hosts, no OS specifics. |
| OS | `inventories/os/debian`, `inventories/os/el` or `inventories/os/suse` | Package names, repositories and paths of the OS. See [Debian (including Ubuntu)](deploy/os/debian.md), [EL](deploy/os/el.md) and [SUSE](deploy/os/suse.md). |
| Platform | e.g. `inventories/mycluster` | Your hosts, and what is specific to your machines (network interface, VIP, ...). |

To change a value, add a file to `group_vars/all/` (or `group_vars/<group>/`) of a later layer, preferably your own:
e.g. `inventories/mycluster/group_vars/all/generic.yml` with `postgresql_version: 16`. Don't change `standard`; that
keeps updates of this repository easy.

The cluster name is the name of your inventory folder (`mycluster`).

See [Inventory explained](deploy/inventory/index.md) for the full version: the order of the layers,
the groups, the variables that a layer sets per group, and how to make and keep your own inventory.

## The standard inventory

`inventories/standard` is an opinionated, multi-instance PgVillage setup:

- PostgreSQL 17 (`postgresql_version`), with its data in `/data/postgres/data` and its wal in `/data/postgres/wal`
  (`postgresql_data_mountpoint`, `postgresql_wal_mountpoint`). stolon sizes the wal settings from the wal disk.
- Two stolon clusters, `cluster1` and `cluster2`, that run side by side on the same database hosts:

  | Cluster    | PostgreSQL | stolon proxy | PgBouncer | Router (read-write / read-only / proxy) | Bucket     |
  |------------|------------|--------------|-----------|-----------------------------------------|------------|
  | `cluster1` | 5433       | 25433        | 6433      | 35433 / 45433 / 55433                   | `cluster1` |
  | `cluster2` | 5434       | 25434        | 6434      | 35434 / 45434 / 55434                   | `cluster2` |

  To add or remove a cluster, see [multi-instance](deploy/multi-instance.md).
- etcd and stolon (sentinel, keeper, proxy) on the database hosts (`etcd_master` and `stolon` are subgroups of
  `hacluster`).
- RustFS on the backup host, with a bucket per cluster; wal-g archives the WAL and makes the backups there.
- chainsmith (on the control node) creates a CA, server certificates for all hosts and client certificates for the
  internal users. Connections need TLS, and clients log in with a certificate (`stolon_pg_hba`).
- firewalld on all hosts, with the ports of the groups each host is in.
- avchecker, PgQuartz, pgfga and nagios checks per cluster.

See [`inventories/standard/README.md`](https://github.com/pgvillage/pgvillage/blob/main/inventories/standard/README.md)
and the files in `inventories/standard/group_vars`.

## Your machines

### Hosts

| Group        | Hosts | Runs |
|--------------|-------|------|
| `hacluster`  | 3 (or more) database hosts | etcd, and per cluster: stolon, PostgreSQL, PgBouncer, wal-g, avchecker, PgQuartz |
| `backup`     | 1 backup host | RustFS |
| `localhosts` | `localhost`, the control node | Ansible, chainsmith |
| `router`     | optional, see [Router](#router) | HAProxy, keepalived, pgroute66 |

The control node gets packages from the PgVillage repository too (chainsmith), so it runs the same OS family as the
hosts. `localhost` must be in your inventory, not in standard: the cluster name comes from its inventory folder.

Use names that the hosts can resolve (DNS or `/etc/hosts`): the certificates and the wal-g endpoint use them. When
Ansible should connect to an address, add `ansible_host: <ip>` to the host.

### Requirements

- **Storage**: `/data/postgres/data` and `/data/postgres/wal` on the database hosts; a separate data and wal disk per
  cluster is best (a full wal disk doesn't stop the data disk), see [Disks](deploy/byo.md#disks). The backup host stores the
  backups in `/var/lib/minio`.
- **Memory**: the two clusters together need at least 2 GB per database host; 1 GB is enough for the backup host.
- **Network**: the hosts reach each other on all ports (firewalld is configured by PgVillage), and reach the package
  repositories: the PgVillage repository (repo.pgvillage.org), download.postgresql.org (EL, SUSE), the OS
  repositories, and Ansible Galaxy from the control node.
- **Access**: ssh with a key from the control node, and sudo (with a password: run `ansible-playbook` with
  `--ask-become-pass`). When the user on the hosts differs from yours, see [Ansible config](deploy/control-node/ansible_cfg.md).

### More than one network interface

PgVillage listens on the interface of the default route. If your hosts have several interfaces (e.g. a NAT interface
and a private network), set the one to use in your inventory, e.g. in `group_vars/all/network.yml`:

```yaml
etcd_iface_cluster: eth1
stolon_pg_listen_address: "{{ ansible_facts.eth1.ipv4.address }}"
stolon_proxy_listen_address: "{{ ansible_facts.eth1.ipv4.address }}"
```

[Vagrant](deploy/inventory/vagrant-example.md#network) is an example.

### Router

The router (HAProxy, keepalived and pgroute66) gives every cluster a read-write, a read-only and a proxy port on a
virtual IP (VIP), which follows the primary. It is optional. To use it, add the hosts to `router` and `haproxy` (e.g.
the database hosts) and set the VIP, on a free address in their network:

```yaml
# hosts
    router:
      children:
        hacluster:
    haproxy:
      children:
        hacluster:
```

```yaml
# group_vars/all/keepalived.yml
keepalived_interface: eth0
keepalived_vip: 192.0.2.30
```

See [HAProxy](tools/haproxy.md#multi-instance) and
[pgroute66](tools/pgroute66.md#multi-instance).

## Deploy and check

Run the playbook again after every change; a second run should change nothing.

```bash
ansible-playbook -i inventories/standard -i inventories/os/el -i inventories/mycluster functional-all.yml
```

On a database host, check the clusters and the WAL archiving:

```bash
sudo -u postgres psql -h /tmp -p 5433 -c 'select pg_is_in_recovery()' -c 'select * from pg_stat_archiver'
```

## Running on specific platforms

- [Azure](deploy/platforms/azure/index.md): creates the Azure resources (VMs, load balancer, storage account) and deploys PgVillage on
  them.
- [Vagrant](try-it/vagrant/index.md): a demo environment on your laptop with VirtualBox.
- [Lima](try-it/lima.md): a demo environment on your Mac with Lima (no VirtualBox, no root permissions).
- [macOS](try-it/vagrant/macos.md): a demo environment on a Mac with Apple silicon, with Lima or Vagrant.
- [Bring your own machines](deploy/byo.md): what to prepare on your own machines (physical, VMs, cloud VMs).
- [ARM vs AMD](deploy/os/arm-vs-amd.md): running on ARM64 (aarch64) or AMD64 (x86_64).
