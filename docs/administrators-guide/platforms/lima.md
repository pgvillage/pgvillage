---
title: Lima
summary: Running a PgVillage demo environment on your Mac with Lima (vz, user-v2 network), using the standard and lima inventories
authors:
  - Sebas Mannem
date: 2026-11-01
---

# Lima

Run a PgVillage demo environment on your Mac with [Lima](https://lima-vm.io/), as an alternative to
[Vagrant](vagrant/index.md). The VMs use Apple's Virtualization framework (`vz`) and the Lima `user-v2` network, so you
need no VirtualBox, no boxes to build and no root permissions. Everything you need is in this repository:

- `lima/`: the VM template (`pgvillage.yaml`) and `up.sh`, which creates the VMs and prepares the Ansible VM.
- `inventories/standard`: the standard PgVillage config, shared by all platforms (multi-instance: `cluster1` and
  `cluster2`).
- `inventories/ubuntu` or `inventories/el`: the OS of the VMs (Ubuntu by default). See [Ubuntu](ubuntu/index.md) and
  [EL](el/index.md).
- `inventories/lima`: the hosts and the VIP. See [The lima inventory](#the-lima-inventory).

!!! warning
    The VIP needs the `keepalived_unicast_peers` of the keepalived role
    ([ansible-role-keepalived#17](https://github.com/pgvillage/ansible-role-keepalived/pull/17)), which is not in a
    release yet. With the keepalived release in `requirements.yml`, every router VM takes the VIP.

## What gets deployed

| VM            | Name on the network          | Groups                                         | Runs |
|---------------|------------------------------|------------------------------------------------|------|
| `pgv-ansible` | `lima-pgv-ansible.internal`  | `localhosts` (as `localhost`)                  | Ansible, chainsmith; you deploy from here |
| `pgv-db-1`    | `lima-pgv-db-1.internal`     | `hacluster`, `stolon`, `etcd_master`, `router` | etcd, and per cluster: stolon (sentinel, keeper, proxy), PostgreSQL, PgBouncer, wal-g, avchecker; plus HAProxy, keepalived and pgroute66 |
| `pgv-db-2`    | `lima-pgv-db-2.internal`     | same                                           | same |
| `pgv-db-3`    | `lima-pgv-db-3.internal`     | same                                           | same |
| `pgv-backup`  | `lima-pgv-backup.internal`   | `backup`                                       | RustFS, with a bucket per cluster |
| VIP           | `192.168.104.250`            |                                                | keepalived VIP for HAProxy |

The ports are the same as on [Vagrant](vagrant/index.md#what-gets-deployed). The database VMs get 2 CPUs and 2 GiB of
memory, the others 1 CPU and 1 GiB: 8 GiB for the whole environment. Every VM has a 20 GiB disk (sparse: it only takes
what is used).

## Getting started

1. Install Lima (2.0 or newer): `brew install lima`. No root permissions are needed, also not later on.
2. Create the VMs:
   ```bash
   lima/up.sh                 # Ubuntu 26.04
   PGV_OS=el lima/up.sh       # or Rocky Linux 9
   ```
   This creates and starts the five VMs, creates the data and wal directories on the database VMs, gives the Ansible
   VM an ssh key that the other VMs accept, and installs Ansible and the roles and collections from `requirements.yml`
   on the Ansible VM (with the same `bootstrap.sh` as vagrant). Running it again is safe: it starts VMs that are
   stopped and skips what is done.
3. Log in to the Ansible VM and deploy:
   ```bash
   limactl shell --workdir=/ pgv-ansible
   cd ~/git/pgvillage/
   ansible-playbook -i inventories/standard -i inventories/${PGV_OS} -i inventories/lima functional-all.yml
   ```
   `~/git/pgvillage` is this repository (a writable virtiofs mount), so you deploy what you have checked out.
4. Check it: e.g. connect to the read-write route of `cluster1` through the VIP, from a database VM:
   ```bash
   limactl shell --workdir=/ pgv-db-1 sudo -u postgres psql "host=192.168.104.250 port=35433 dbname=postgres sslmode=require"
   ```

Stop the VMs with `limactl stop <vm>` (`limactl list` shows them), and remove them with
`limactl delete -f pgv-ansible pgv-backup pgv-db-1 pgv-db-2 pgv-db-3`.

## How it works

### The VMs

`lima/pgvillage.yaml` is the template for all VMs. `up.sh` combines it with the image of the OS (the `_images/` Lima
templates: only the image, without Lima's default mount of your home directory) and sets the CPUs and memory per VM.

On every boot, a provisioning script in the template:

- creates and enables a 1 GiB swap file: the cloud images have no swap, and dnf runs out of memory (killed, `rc -9`)
  on the 1 GiB VMs when it loads the EPEL metadata;
- adds `<ip> lima-<vm>.internal lima-<vm>` to `/etc/hosts`, so the fqdn of the VM is its name on the network. The
  certificates (chainsmith) and the wal-g endpoint use the fqdn, and without this it would be `lima-<vm>`, which the
  other VMs can't resolve;
- disables the automatic apt runs (they hold the dpkg lock while the deploy installs packages);
- lets chrony step the clock after a suspend of your Mac (etcd and certificates don't like a clock in the past).

Only the Ansible VM mounts something: the repository on `~/git/pgvillage`.

Lima forwards the ports that a VM listens on to `localhost` on your Mac by default. The VMs listen on the same ports
(PostgreSQL, rpcbind, ...), which gives conflicts, so the template turns that off (`portForwards`).

### The network

The `user-v2` network connects the VMs (192.168.104.0/24) and gives them internet access through your Mac, without root
permissions (unlike Lima's `socket_vmnet` networks). Each VM has one interface, `eth0`, with an address from DHCP, and
the network resolves `lima-<vm>.internal` for every VM. The addresses depend on the order in which the VMs were created,
so the inventory uses the names, not the addresses.

`user-v2` does not pass multicast. keepalived sends VRRP as multicast by default, and then every router host becomes
master and takes the VIP. The lima inventory therefore sends VRRP as unicast to the other router hosts
(`keepalived_unicast_peers`). The VIP itself works: after a failover the other VMs follow the new holder (gratuitous
ARP).

The Lima network does not reach your Mac's own network, and your Mac can't reach the VMs' addresses directly. Use
`limactl shell`, or forward a port (`portForwards` in the template).

### The lima inventory

`inventories/lima` only has what is specific to these VMs. It goes on top of `inventories/standard` and an OS
inventory:

| File                            | What |
|---------------------------------|------|
| `hosts`                         | The VMs by their names. No `ansible_host`: standard takes the addresses from the facts where it needs them (the IP addresses in the certificates). The router (`router`, `haproxy`) runs on the database hosts. |
| `group_vars/all/keepalived.yml` | The VIP (`192.168.104.250`, at the end of the range, away from the DHCP addresses), on `eth0`, with unicast VRRP. |

The rest works with the standard defaults: each VM has only one interface, so etcd, stolon and PostgreSQL listen on the
right one without overrides (vagrant needs overrides for its second interface).

## What was needed for lima

What it took to get PgVillage running on Lima, compared to what was already there for vagrant:

- **keepalived**: unicast VRRP, as `user-v2` drops multicast. Added to the keepalived role
  (`keepalived_unicast_peers`, [ansible-role-keepalived#17](https://github.com/pgvillage/ansible-role-keepalived/pull/17)).
- **standard**: `chainsmith_ips` falls back to the address of the default route when a host has no `ansible_host`.
- **The fqdn**: the `/etc/hosts` entry on every boot (see [The VMs](#the-vms)).
- **Swap**: for dnf on the 1 GiB VMs (see [The VMs](#the-vms)).
- **No port forwarding** to your Mac (see [The VMs](#the-vms)).
- **The image**: `--set` can't change the base template of a VM, so `up.sh` passes a small template on stdin with the
  OS image and `pgvillage.yaml` as its bases.

Not needed, unlike vagrant: building boxes (Lima uses the cloud images of the distributions), guest additions,
`OPENSSL_armcap` (vz shows the real CPU features to the VM; the VirtualBox issue with SVE2 doesn't occur), static IP
configuration, and a shared ssh key in the repository.

## Lima compared to vagrant

Measured on a MacBook with Apple silicon (16 cores, 64 GB), on 2026-11-01, with the images or boxes already
downloaded:

| Step                                         | Lima, Rocky Linux 9 | Vagrant, Rocky Linux 9 | Lima, Ubuntu 26.04 |
|----------------------------------------------|---------------------|------------------------|--------------------|
| Create and start the VMs, bootstrap Ansible  | 342 s               | 614 s                  | 196 s              |
| First deploy                                 | 285 s               | 639 s                  | 297 s              |
| Second deploy (nothing to change)            | 120 s               | 222 s                  | 109 s              |

Both run the same inventories and roles; on Rocky Linux, the second deploy changes one task on both (a known issue in
the haproxy role).

Other differences:

- **Setup**: Lima needs only `brew install lima`. Vagrant needs VirtualBox, Vagrant and a box per OS that you build
  yourself (with the guest additions, see [Creating the boxes](vagrant/boxes.md)).
- **Images**: Lima uses the official cloud images of the distributions (a new Lima release brings newer ones), and
  caches them. Vagrant boxes are yours to rebuild when they get out of date.
- **Network**: vagrant has a private network with static addresses that your Mac can reach; Lima has DHCP addresses
  behind names, which your Mac can't reach directly, and no multicast.
- **Platforms**: Lima runs on macOS and Linux; vagrant with VirtualBox also on Windows and on x86_64 Macs.
- **SUSE**: not tried on Lima (Lima has openSUSE images; PGDG has no aarch64 packages for SUSE, see
  [SUSE](suse/index.md)).
