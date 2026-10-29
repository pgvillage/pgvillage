---
title: Vagrant
summary: Running a PgVillage demo environment on your laptop with Vagrant, using the standard and vagrant inventories
authors:
  - Sebas Mannem
date: 2026-10-30
---

# Vagrant

Run a PgVillage demo environment on your laptop with [Vagrant](https://www.vagrantup.com/).

The deployment uses three inventories, in this order, so later values win:

- `inventories/standard`: the standard PgVillage config, shared by all platforms. It is multi-instance: two stolon
  clusters (`cluster1` and `cluster2`) run side by side on the same hosts.
- `inventories/ubuntu`: Ubuntu packages, apt repositories, users and paths (the boxes run Ubuntu). See
  [Ubuntu](../ubuntu/index.md).
- `inventories/vagrant`: everything specific to the vagrant boxes: the hosts, the network interface, certificates,
  and the router (HAProxy, keepalived and pgroute66).

See [The vagrant inventory](inventory.md) for what it changes, and why.

!!! note
    The Vagrantfile, the box definitions and the bootstrap scripts are not in this repository yet. Until then, use
    [pgv_vagrant](https://github.com/pgvillage/pgv_vagrant) to create the boxes.

## What gets deployed

| Host          | IP            | Groups                                            | Runs |
|---------------|---------------|---------------------------------------------------|------|
| `db-1.local`  | 172.30.1.31   | `hacluster`, `stolon`, `etcd_master`, `router`    | etcd, and per cluster: stolon (sentinel, keeper, proxy), PostgreSQL, PgBouncer, wal-g, avchecker; plus HAProxy, keepalived and pgroute66 |
| `db-2.local`  | 172.30.1.32   | same                                              | same |
| `db-3.local`  | 172.30.1.33   | same                                              | same |
| `minio.local` | 172.30.1.20   | `backup`                                          | minio, with a bucket per cluster |
| VIP           | 172.30.1.30   |                                                   | keepalived VIP for HAProxy |

The ports per cluster:

| Cluster    | PostgreSQL | stolon proxy | PgBouncer | HAProxy (rw / proxy / ro) |
|------------|------------|--------------|-----------|---------------------------|
| `cluster1` | 5433       | 25433        | 6433      | 35433 / 35434 / 35435     |
| `cluster2` | 5434       | 25434        | 6434      | -                         |

HAProxy only has frontends for `cluster1`, see [Router](inventory.md#router).

## Getting started

1. Install Vagrant and VirtualBox.
2. Create the boxes (Ubuntu) and start them: `vagrant up`.
3. Log in to the Ansible host and deploy:
   ```bash
   vagrant ssh ansible
   cd ~/git/pgvillage/
   ansible-playbook -i inventories/standard -i inventories/ubuntu -i inventories/vagrant functional-all.yml
   ```
4. Be amazed.

## Check the deployment

```bash
vagrant ssh db-1
sudo -iu postgres psql -h /tmp -p 5433 -c 'select pg_is_in_recovery()'   # cluster1
sudo -iu postgres psql -h /tmp -p 5434 -c 'select pg_is_in_recovery()'   # cluster2
```

One host returns `f` (the primary of that cluster), the others `t` (standbys). The primaries of `cluster1` and
`cluster2` don't have to be on the same host.

## Mac M1+ users

Apple silicon (M1, M2, M3, etc.) is no issue: the boxes can be built for both amd64 and aarch64.

## Other operating systems

The boxes run Ubuntu, hence `inventories/ubuntu`. `inventories/standard` itself is for Enterprise Linux (EL), so for
EL boxes you leave out `inventories/ubuntu`. See [Other operating systems](inventory.md#other-operating-systems).

## DNS

There is no DNS: the hosts are seeded into `/etc/hosts` of every box.
