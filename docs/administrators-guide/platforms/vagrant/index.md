---
title: Vagrant
summary: Running a PgVillage demo environment on your laptop with Vagrant, using the standard and vagrant inventories
authors:
  - Sebas Mannem
date: 2026-10-30
---

# Vagrant

Run a PgVillage demo environment on your laptop with [Vagrant](https://www.vagrantup.com/) and
[VirtualBox](https://www.virtualbox.org/). Everything you need is in this repository:

- `vagrant/`: the `Vagrantfile` and the scripts that prepare the boxes.
- `inventories/standard`: the standard PgVillage config, shared by all platforms. It is multi-instance: two stolon
  clusters (`cluster1` and `cluster2`) run side by side on the same hosts.
- `inventories/ubuntu`, `inventories/el` or `inventories/suse`: the OS of the boxes (Ubuntu by default). See
  [Ubuntu](../ubuntu/index.md), [EL](../el/index.md) and [SUSE](../suse/index.md).
- `inventories/vagrant`: everything specific to the vagrant boxes: the hosts, the network, certificates, and the router
  (HAProxy, keepalived and pgroute66). See [The vagrant inventory](inventory.md).

## What gets deployed

| Host           | IP            | Groups                                         | Runs |
|----------------|---------------|------------------------------------------------|------|
| `ansible.local`| 172.30.1.10   | `localhosts` (as `localhost`)                  | Ansible, chainsmith; you deploy from here |
| `db-1.local`   | 172.30.1.31   | `hacluster`, `stolon`, `etcd_master`, `router` | etcd, and per cluster: stolon (sentinel, keeper, proxy), PostgreSQL, PgBouncer, wal-g, avchecker; plus HAProxy, keepalived and pgroute66 |
| `db-2.local`   | 172.30.1.32   | same                                           | same |
| `db-3.local`   | 172.30.1.33   | same                                           | same |
| `minio.local`  | 172.30.1.20   | `backup`                                       | minio, with a bucket per cluster |
| VIP            | 172.30.1.30   |                                                | keepalived VIP for HAProxy |

The ports per cluster:

| Cluster    | PostgreSQL | stolon proxy | PgBouncer | HAProxy (rw / proxy / ro) |
|------------|------------|--------------|-----------|---------------------------|
| `cluster1` | 5433       | 25433        | 6433      | 35433 / 35434 / 35435     |
| `cluster2` | 5434       | 25434        | 6434      | -                         |

HAProxy only has frontends for `cluster1`, see [Router](inventory.md#router).

The database hosts get 2 GB of memory, the others 1 GB, all 2 CPUs: about 9 GB for the whole environment.

## Getting started

1. Install [VirtualBox](https://www.virtualbox.org/wiki/Downloads) and
   [Vagrant](https://developer.hashicorp.com/vagrant/install).
2. Create the box, once: see [Creating the boxes](boxes.md).
3. Start the boxes:
   ```bash
   cd vagrant
   vagrant up
   ```
   This creates the five boxes, gives them a static IP on the private network, seeds `/etc/hosts`, shares one ssh key
   between them, and creates the data and wal directories on the database hosts. On the Ansible host it installs
   Ansible and the roles and collections from `requirements.yml`.
4. Log in to the Ansible host and deploy:
   ```bash
   vagrant ssh ansible
   cd ~/git/pgvillage/
   ansible-playbook -i inventories/standard -i inventories/${PGV_OS} -i inventories/vagrant functional-all.yml
   ```
5. Be amazed.

`~/git/pgvillage` on the Ansible host is this repository on your laptop (a VirtualBox shared folder), so you deploy
what you have checked out, including your local changes. `PGV_OS` is set in `~/.bashrc` of the Ansible host (see
[Other operating systems](#other-operating-systems)).

## Check the deployment

```bash
vagrant ssh db-1
sudo -iu postgres psql -h /tmp -p 5433 -c 'select pg_is_in_recovery()'   # cluster1
sudo -iu postgres psql -h /tmp -p 5434 -c 'select pg_is_in_recovery()'   # cluster2
```

One host returns `f` (the primary of that cluster), the others `t` (standbys). The primaries of `cluster1` and
`cluster2` don't have to be on the same host.

## Other operating systems

The boxes run Ubuntu by default. `PGV_OS` picks another OS; it selects the box and is the name of the OS inventory
to deploy with:

| `PGV_OS`           | Box                   | OS inventory           |
|--------------------|-----------------------|------------------------|
| `ubuntu` (default) | `nibble/ubuntu-26.04` | `inventories/ubuntu`   |
| `el`               | `nibble/rocky-9`      | `inventories/el`       |
| `suse`             | `nibble/suse-16`      | `inventories/suse`     |

```bash
cd vagrant
PGV_OS=el vagrant up
```

Set it for every `vagrant` command on these boxes (`vagrant up`, `vagrant provision`, `vagrant destroy`), e.g. with
`export PGV_OS=el`. `PGV_BOX` overrides the box name, if you named your box differently.

The bootstrap writes `PGV_OS` to `~/.bashrc` of the Ansible host, so the deploy command in
[Getting started](#getting-started) uses the right OS inventory.

!!! note
    The PostgreSQL community has no aarch64 packages for SUSE: on Apple silicon, use `ubuntu` or `el`.

## The vagrant directory

| File                         | What |
|------------------------------|------|
| `Vagrantfile`                | The boxes: `ansible`, `minio` and `db-1` to `db-3`, all on the private network `172.30.1.0/24` |
| `scripts/init_vm.sh`         | All boxes: new ssh host keys, the shared ssh key, `/etc/hosts`, chrony steps the clock after a suspend |
| `scripts/set_ip.sh`          | All boxes: the static IP on the private network (with NetworkManager, netplan or wicked) |
| `scripts/bootstrap.sh`       | Ansible host: Ansible in `~/venv`, the roles and collections from `requirements.yml`, ssh to localhost |

`vagrant up` creates `vagrant/.ssh` (the shared ssh key) and `vagrant/.vagrant`; both are in `.gitignore`.

## Mac M1+ users

Apple silicon (M1, M2, M3, etc.) is no issue: you can create the boxes for both amd64 and aarch64, see
[Creating the boxes](boxes.md).

## DNS

There is no DNS: `scripts/init_vm.sh` seeds the hosts into `/etc/hosts` of every box.

## Starting over

```bash
cd vagrant
vagrant destroy -f
vagrant up
```

To keep the boxes and only remove PgVillage, run `uninstall.yml` with the same inventories as the deploy.
