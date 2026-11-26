# libvirt

Run PgVillage on VMs on a Linux machine with libvirt, QEMU and KVM: a demo or development environment, set up the same
way as at a customer (you deploy from a management VM). The VMs come from a distribution's cloud image and are set up
with cloud-init.

| File             | What |
|------------------|------|
| `up.sh`          | Creates VMs from a cloud image: a disk on top of the image, a login user with your ssh key and passwordless sudo, the hostname. Generic: any VM name, settings via `PGV_LIBVIRT_*` variables (see the script). |
| `create-demo.sh` | Creates the five VMs of a demo environment with `up.sh` (see below). |
| `bootstrap.sh`   | Prepares the management VM: clones PgVillage, installs Ansible and the roles. `create-demo.sh` runs it on the first boot. |

Tested with Rocky Linux 9 (`Rocky-9-GenericCloud-Base`), 2026-11-25.

## What you need

- libvirt with QEMU/KVM, `virsh` and `virt-install`.
- A libvirt network with NAT, DHCP and DNS for a domain, e.g. `pgv.internal`: DHCP registers `<vm>.pgv.internal`
  in the network's DNS, and PgVillage uses those names (certificates, endpoints). Pass its bridge with
  `PGV_LIBVIRT_BRIDGE` (default `virbr-pgv`) and its domain with `PGV_LIBVIRT_DOMAIN`. Keep a part of the range out of DHCP
  for the VIP.
- A storage pool for the VM disks (`PGV_LIBVIRT_POOL`, default `vms`).
- The cloud image (qcow2) of the distribution (`PGV_LIBVIRT_IMAGE`). An installer ISO doesn't work: it doesn't run
  cloud-init.
- An ssh key pair; the public key goes into the VMs (`PGV_LIBVIRT_SSH_KEY`).

## A demo environment

```bash
PGV_LIBVIRT_IMAGE=~/images/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2 platforms/libvirt/create-demo.sh
```

| VM            | Groups in the inventory          | Gets from cloud-init |
|---------------|----------------------------------|----------------------|
| `pgv-ansible` | (management VM: `localhost`)     | its own ssh key, which all VMs accept; `bootstrap.sh`: PgVillage in `~/git/pgvillage` (`PGV_LIBVIRT_REPO`, `PGV_LIBVIRT_BRANCH`), Ansible in `~/venv` |
| `pgv-backup`  | `backup`                         | |
| `pgv-db-1..3` | `hacluster`, `router`, `haproxy` | `/data/postgres/data` and `/data/postgres/wal` (the mountpoints of `inventories/standard`) |

Each VM gets 2 vCPUs, 2 GiB memory and a 20 GiB disk (thin: only what is used takes space). The management VM's
setup runs on its first boot and takes a few minutes. Wait for it, then log in and deploy:

```bash
ssh <user>@pgv-ansible.pgv.internal cloud-init status --wait
ssh <user>@pgv-ansible.pgv.internal
cd ~/git/pgvillage
ansible-playbook -i inventories/standard -i inventories/os/<os> -i inventories/platform/libvirt functional-all.yml
```

`<os>` is the OS inventory that matches the image: `el` for Rocky Linux, `debian` for Debian and Ubuntu.

### The inventory

`inventories/platform/libvirt` has the VMs of `create-demo.sh` and goes on top of `inventories/standard` and the OS
inventory. Its folder name is the cluster name (`cluster_name` in standard): `libvirt`.

- `hosts`: the VMs by their names (`pgv-db-1.pgv.internal`, ...), no `ansible_host`: the addresses come from DHCP, and
  standard takes them from the facts. The router (haproxy, keepalived, pgroute66) runs on the database VMs.
- `group_vars/all/keepalived.yml`: the VIP, `192.168.130.10` on `eth0`, outside the DHCP range of the network.
  The libvirt bridge passes multicast, so VRRP needs no unicast peers.
- `group_vars/all/rustfs.yml`: fixed S3 keys of the backup host. Demo only: everyone who has this repository knows them.

For another network, change the domain in `hosts` and the VIP.

## Removing VMs

```bash
virsh destroy <vm>; virsh undefine <vm> --remove-all-storage
```

`create-demo.sh` makes a new key for the management VM on every run, and `up.sh` skips VMs that exist: remove all demo
VMs before you run it again.

## Pitfalls

- **No password:** the login user has no password (locked) and root neither: ssh with your key only, no console login.
- **`PGV_LIBVIRT_SSH_KEY` is the public key** (`.pub`). `up.sh` stops on a file with other lines, such as a private
  key: that would end up in the VMs' cloud-init data, and no login would work.
- **No video card = reboot loop** (Rocky 9, SeaBIOS): `up.sh` adds `--video vga`.
- **cloud-init runs on the first boot only**, and virt-install removes its seed after that boot. If the first boot
  fails, recreate the VM instead of rebooting it.
- **Not `manage_etc_hosts`:** it maps the fqdn to `127.0.0.1`, and other hosts would get that address for etcd and
  stolon. Without it, the fqdn resolves through the network's DNS.
- **A recreated VM gets a new address** (new MAC), and the DNS can give the old one for a few minutes ("No route to
  host"). Wait and try again.
