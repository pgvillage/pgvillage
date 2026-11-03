---
title: Bring your own machines
summary: Running PgVillage on machines you provide (physical, VMs on KVM or VMware, cloud VMs), and what you need to prepare
authors:
  - Sebas Mannem
date: 2026-11-01
---

# Bring your own machines

Bring your own (BYO) means that you provide the machines, and PgVillage deploys on them: physical servers, VMs on KVM,
VMware or Proxmox, or VMs in a cloud. PgVillage doesn't create them, unlike on [Azure](azure/index.md),
[Lima](lima.md) or [Vagrant](vagrant/index.md). This is how you run PgVillage in production.

The deploy itself is the same as everywhere: the standard inventory, the inventory of your OS, and an inventory with
your hosts. [Getting started](index.md#tldr) has the commands.

## Checklist

Prepare these before the first deploy:

- [ ] **Hosts**: 3 database hosts, 1 backup host and a control node, on a [supported OS](index.md#supported-platforms),
      all the same OS family and architecture. See [Hosts](index.md#hosts) and [The backup host](#the-backup-host).
- [ ] **Disks**: a data and a wal disk per cluster on the database hosts, see [Disks](#disks). PgVillage doesn't
      create file systems or mount disks.
- [ ] **Names**: every host resolves the names of the others (DNS or `/etc/hosts`). The certificates and the wal-g
      endpoint use them.
- [ ] **Access**: ssh with a key from the control node, and sudo (when sudo asks for a password, run
      `ansible-playbook` with `--ask-become-pass`). See
      [Ansible config](../deployment_and_maintenance/ansible_cfg.md) when the user on the hosts differs from yours.
- [ ] **Network**: the hosts reach each other on all ports (PgVillage configures firewalld on the hosts, but not a
      firewall between them), and reach the package repositories and Ansible Galaxy. Your clients reach the database
      hosts (or the VIP) on the ports in [The standard inventory](index.md#the-standard-inventory).
- [ ] **Interface**: with more than one network interface, choose the one to use, see
      [More than one network interface](index.md#more-than-one-network-interface).
- [ ] **VIP** (optional): a free address in the network of the router hosts, see [Router](index.md#router). keepalived
      uses multicast VRRP, so your network must pass it between the router hosts.
- [ ] **Certificates** (optional): chainsmith creates a CA and the certificates. To use certificates signed by your own
      CA, see [Bring your own - Server Certificates](../deployment_and_maintenance/byo-server-certs.md) and
      [Bring your own - Client Certificates](../deployment_and_maintenance/byo-client-certs.md).
- [ ] **Backups**: storage for the backups, see [The backup host](#the-backup-host).

## Disks

The standard inventory has two clusters (`cluster1` and `cluster2`), and we advise separate data and wal storage for
every cluster: 4 disks per database host, mounted on

| Cluster    | Data                            | Wal                                    |
|------------|---------------------------------|----------------------------------------|
| `cluster1` | `/data/postgres/data/cluster1`  | `/data/postgres/wal/stolon/cluster1`   |
| `cluster2` | `/data/postgres/data/cluster2`  | `/data/postgres/wal/stolon/cluster2`   |

`/data/postgres/data` and `/data/postgres/wal` are `postgresql_data_mountpoint` and `postgresql_wal_mountpoint`. With
more or fewer clusters, it is a data and a wal disk per cluster.

!!! note
    For performance, these are best 4 separate disks (separate SCSI devices). They can also be separate partitions,
    LVM logical volumes, etc.: what matters most is that a full wal disk of one cluster doesn't fill the data of that
    cluster, or the storage of the other cluster.

!!! warning
    The standard inventory doesn't fully support a wal disk per cluster yet. The stolon keeper removes and recreates
    the wal directory of a cluster (`/data/postgres/wal/stolon/cluster1`), so it can't be a mount point itself, and
    stolon sizes `min_wal_size` and `max_wal_size` from the free space on `/data/postgres/wal/stolon`, which both
    clusters share. Until that is fixed, use one wal disk on `/data/postgres/wal` for both clusters.

## The backup host

The backup host runs RustFS, an S3 server, and stores the backups in `/var/lib/rustfs`: give it a disk that fits them.

!!! note
    The backup host is a simple solution for when there is no other storage for the backups. Depending on Enterprise
    Storage capabilities (an S3 bucket in your own storage or in a cloud, an NFS share, ...), the backup host might not
    be required: wal-g then writes the backups there.

## Your inventory

Create a folder in `inventories/` with your hosts, and put everything that is specific to your machines there (the
interface, the VIP, overrides of the standard values). The name of the folder is the name of the cluster. Keep it in
your own repository (e.g. a fork, or a separate repository next to this one), so updates of PgVillage don't touch it.

`inventories/kvm` is an example: three database VMs and a backup VM on KVM, with Rocky Linux. See [KVM](kvm.md).

## After the deploy

- Run the deploy again after every change; a second run should change nothing.
- Check the clusters, see [Deploy and check](index.md#deploy-and-check).
- For changes and updates, see [Modifying an existing deployment](../deployment_and_maintenance/modify_existing.md)
  and [Patching](../deployment_and_maintenance/patching_procedure.md).
