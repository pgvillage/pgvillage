---
title: libvirt
summary: Running a PgVillage demo environment on a Linux machine with libvirt (QEMU/KVM) and cloud-init, using the standard and libvirt inventories
authors:
  - Robert Griffioen
date: 2026-11-26
---

# libvirt

Run a PgVillage demo environment on a Linux machine with libvirt (QEMU/KVM). You deploy from a management VM, as at a
customer. The VMs come from the cloud image of a distribution and are set up with cloud-init. Everything you need is in
this repository:

- `platforms/libvirt/`: the scripts that create the VMs (`up.sh`, `create-demo.sh`) and prepare the management VM
  (`bootstrap.sh`), and a
  [README](https://github.com/pgvillage/pgvillage/blob/main/platforms/libvirt/README.md) with the details.
- `inventories/standard`: the standard PgVillage config, shared by all platforms.
- `inventories/os/<os>`: the OS of the VMs, e.g. `inventories/os/el` for Rocky Linux.
- `inventories/platform/libvirt`: the hosts and the VIP. The cluster name is `libvirt`.

Tested with Rocky Linux 9 (`Rocky-9-GenericCloud-Base`, x86_64), 2026-11-26.

## What gets deployed

| VM            | Name on the network      | Groups                                         | Runs |
|---------------|--------------------------|------------------------------------------------|------|
| `pgv-ansible` | `pgv-ansible.pgv.internal` | `localhosts` (as `localhost`)                | Ansible, chainsmith; you deploy from here |
| `pgv-db-1`    | `pgv-db-1.pgv.internal`  | `hacluster`, `stolon`, `etcd_master`, `router` | etcd, and per cluster: stolon, PostgreSQL, PgBouncer, wal-g, avchecker; plus HAProxy, keepalived and pgroute66 |
| `pgv-db-2`    | `pgv-db-2.pgv.internal`  | same                                           | same |
| `pgv-db-3`    | `pgv-db-3.pgv.internal`  | same                                           | same |
| `pgv-backup`  | `pgv-backup.pgv.internal` | `backup`                                      | RustFS, with a bucket per cluster |
| VIP           | `192.168.130.10`         |                                                | keepalived VIP for HAProxy |

Each VM gets 2 vCPUs, 2 GiB of memory and a 20 GiB disk (thin): 10 GiB of memory for the whole environment.

## Getting started

You need libvirt with `virsh` and `virt-install`, a libvirt network with NAT, DHCP and DNS for the domain
`pgv.internal` (192.168.130.0/24, with `192.168.130.10` outside the DHCP range), a storage pool for the disks, the
cloud image, and an ssh key. The README lists them, with the variables to use other names.

1. Create the VMs:
   ```bash
   PGV_LIBVIRT_IMAGE=~/images/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2 platforms/libvirt/create-demo.sh
   ```
   The management VM gets an ssh key that the other VMs accept, and clones PgVillage and installs Ansible on its first
   boot. The database VMs get the data and wal directories.
2. Wait for the management VM, log in and deploy:
   ```bash
   ssh <user>@pgv-ansible.pgv.internal cloud-init status --wait
   ssh <user>@pgv-ansible.pgv.internal
   cd ~/git/pgvillage
   ansible-playbook -i inventories/standard -i inventories/os/el -i inventories/platform/libvirt functional-all.yml
   ```
3. Check it, e.g. with the checks of the end-to-end test:
   ```bash
   ansible-playbook -i inventories/standard -i inventories/os/el -i inventories/platform/libvirt tests/e2e/verify.yml
   ```

Remove a VM with `virsh destroy <vm>; virsh undefine <vm> --remove-all-storage`.

## What was needed for libvirt

Compared to [Lima](lima.md):

- **The fqdn** comes from the network's DNS: DHCP registers `<vm>.pgv.internal`. No `/etc/hosts` entry, and not
  cloud-init's `manage_etc_hosts`, which maps the fqdn to `127.0.0.1`.
- **No unicast VRRP:** the libvirt bridge passes multicast, so keepalived works with its defaults.
- **A video card** (`--video vga`): without one, Rocky Linux 9 resets right after GRUB.
- **No swap:** the VMs have 2 GiB of memory, enough for dnf.
- **A recreated VM gets a new address**, and the DNS can give the old one for a few minutes.
