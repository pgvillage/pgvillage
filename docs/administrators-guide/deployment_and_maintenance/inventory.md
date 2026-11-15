---
title: Inventory explained
summary: How the PgVillage inventories are layered (standard, OS, platform, yours), what each inventory in inventories/ is for, and how to make your own
---

# Inventory explained

PgVillage is configured with Ansible inventories. You don't write one from scratch: you combine the inventories in
`inventories/` with a small inventory of your own, which only has your hosts and what differs for you.
[Getting started](../platforms/index.md) has the short version; this page explains it in full.

## The layers

`ansible-playbook` gets several inventories (`-i`), in this order:

```bash
ansible-playbook -i inventories/standard -i inventories/os/<os> -i <your inventory> functional-all.yml
```

A variable can be set in several places. From weak to strong:

1. **Role defaults**: `defaults/main.yml` of each role (see the role repositories, e.g.
   [ansible-role-stolon](https://github.com/pgvillage/ansible-role-stolon/blob/main/defaults/main.yml)).
2. **Standard** (`inventories/standard`): the PgVillage config, shared by everyone.
3. **OS** (`inventories/os/<os>`): package names, repositories and paths of the OS.
4. **Platform** (`inventories/platform/<platform>`): the hosts and what is specific to a platform. When you bring your
   own machines, your own inventory takes this place.
5. **Yours**: your own inventory, last, so it wins.

Ansible merges the inventories into one, and a later inventory overrides the variables of an earlier one. There is one
exception: a variable in `group_vars/<group>` (e.g. `group_vars/hacluster`) beats the same variable in
`group_vars/all`, whatever the layer. So when a shared layer sets a variable for a group, your `group_vars/all` doesn't
override it: set it in `group_vars/<group>` of your inventory instead. See
[Variables that are set per group](#variables-that-are-set-per-group).

A variable is the whole value: when you set a dictionary or a list (e.g. `stolon_pg_hba`), yours replaces the one of
the earlier layer; it is not merged.

## The groups

The hosts are in these groups (see [Custom group names](group-names.md) to use other names):

- `hacluster`: the database hosts (3 or more). They run PostgreSQL with stolon, PgBouncer, wal-g, avchecker and
  PgQuartz. In the standard architecture they also run etcd: `stolon` and `etcd_master` are subgroups of `hacluster`.
- `backup`: the backup host (0 or 1). It runs RustFS, an S3 server, for the backups of wal-g.
- `router` (and `haproxy`): optional, the hosts that run HAProxy, keepalived (the VIP) and pgroute66. They can be the
  database hosts.
- `localhosts`: `localhost`, the control node, where Ansible and chainsmith (the certificates) run. It is in your
  inventory, not in standard: the cluster name is the name of the folder of the inventory that has `localhost`
  (`cluster_name: "{{ inventory_dir | basename }}"`).

## The steps

`functional-all.yml` runs the roles as steps, in order, each on the hosts of its groups: linux, chainsmith, firewall,
etcd, the backup server, wal-g, stolon, avchecker, the router (haproxy, keepalived, pgroute66), pgbouncer, nagios and
pgquartz. The inventory can change the steps (`pgvillage_roles`): disable one, change its groups, or add your own. See
[Roles in functional-all.yml](roles.md).

## The inventories in `inventories/`

### Standard

- `inventories/standard`: an opinionated, multi-instance PgVillage setup, used by every deployment. PostgreSQL 17,
  two stolon clusters (`cluster1` and `cluster2`) side by side on the same hosts, etcd and stolon on the database hosts,
  RustFS on the backup host with a bucket per cluster, certificates from chainsmith, firewalld, avchecker, PgQuartz
  and nagios. It has no hosts (its `hosts` file only has the groups) and no OS specifics. See
  [The standard inventory](../platforms/index.md#the-standard-inventory) and its
  [README](https://github.com/pgvillage/pgvillage/blob/main/inventories/standard/README.md).

### Platform

The platform inventories have hosts. Use them as they are to try PgVillage, or as an example for your own inventory.

- `inventories/platform/azure`: VMs on Azure, created by the playbooks in `playbooks/azure`. See
  [Azure](#azure) below and the [Azure docs](../platforms/azure/index.md).
- `inventories/platform/lima`: VMs on your Mac with Lima: the hosts and a VIP. See [Lima](../platforms/lima.md).
- `inventories/platform/vagrant`: boxes on your laptop with Vagrant and VirtualBox: the hosts, a second network
  interface, and the router on the database hosts. See [Vagrant](../platforms/vagrant/index.md) and
  [The vagrant inventory](../platforms/vagrant/inventory.md), which explains every setting.

### OS

Pick the one that matches your hosts. They have no hosts.

- `inventories/os/suse`: openSUSE and SUSE. See [SUSE](../platforms/suse/index.md).
- `inventories/os/el`: Enterprise Linux (Rocky Linux, RHEL, ...). See [EL](../platforms/el/index.md).
- `inventories/os/debian`: Debian (including Ubuntu). See
  [Debian (including Ubuntu)](../platforms/ubuntu/index.md).

### Azure

`inventories/platform/azure` is a dynamic inventory: `azure_rm.yml` (the `azure.azcollection.azure_rm` plugin) finds
the VMs in the resource groups of the cluster, and puts the database hosts of the scale set in the group `_postgres`,
which `hosts` maps to `hacluster`. `host_vars/localhost` makes `localhost` the control node (a local connection, and no
certificates of its own). The azure role writes some files into the inventory itself (`group_vars/_postgres`: the
storage account key for wal-g and the ssh proxy through the bastion). See [Azure integration](../platforms/azure/azure.md).

## Variables that are set per group

These shared layers set a variable in `group_vars/<group>`, not in `group_vars/all`. Your `group_vars/all` can't
override them; set them in the same `group_vars/<group>` folder of your inventory:

- `inventories/standard/group_vars/hacluster/chainsmith.yml`: `chainsmith_server_cert_path` (the server certificates
  of the database hosts are on the data mount point).
- `inventories/standard/group_vars/backup/chainsmith.yml`: `chainsmith_client_cert_sub_folder`,
  `chainsmith_client_cert_filename`, `chainsmith_client_pkey_filename`, `chainsmith_client_root_filename` and
  `chainsmith_server_cert_owner` (the certificates of RustFS and its client).
- `inventories/os/debian/group_vars/hacluster/pgbouncer.yml`: `pgbouncer_install_dir` (Debian and Ubuntu install
  pgbouncer in `/usr/sbin`).

## Make your own inventory

1. Copy a platform inventory that looks like your setup, or start from the `hosts` file in
   [Getting started](../platforms/index.md#tldr). The name of the folder is the cluster name.
2. Keep it in your own Git repository (or a fork of this one), next to a checkout of PgVillage, so you can update
   PgVillage without conflicts. Don't change `inventories/standard` or the OS inventories: put your changes in yours.
3. Put only what differs in it: your hosts in `hosts`, and a file in `group_vars/all/` (or `group_vars/<group>/`) for
   each change. The name of the file doesn't matter to Ansible; using the name of the file in standard that sets the
   variable (e.g. `generic.yml`, `stolon.yml`) keeps it easy to find.
4. Deploy with the standard and OS inventories in front of it:
   ```bash
   ansible-playbook -i inventories/standard -i inventories/os/el -i ~/git/my-inventories/mycluster functional-all.yml
   ```

The variables of each role are documented in `defaults/main.yml` of the role. Some examples:

- **A VIP for the router**: put the router hosts in `router` and `haproxy` (or the database hosts, with
  `children: hacluster:`) and set the VIP, see [Router](../platforms/index.md#router):
  ```yaml
  # group_vars/all/keepalived.yml
  keepalived_vip: 10.0.0.100
  ```
- **Another PostgreSQL version**:
  ```yaml
  # group_vars/all/generic.yml
  postgresql_version: 16
  ```
- **pg_hba**: `stolon_pg_hba` is the whole list, so repeat the entries of standard that you need (the first two are
  required by avchecker and the nagios checks) and add yours:
  ```yaml
  # group_vars/all/generic.yml
  stolon_pg_hba:
    - local all all ident
    - hostssl postgres avchecker samenet cert
    - hostssl all all samenet cert
    - hostssl myapp myapp 10.1.0.0/16 scram-sha-256
  ```
- **Another cluster** on the same hosts: add it to `stolon_clusters`, with its own ports and bucket. See
  [Multi-instance](multi-instance.md).
- **More than one network interface** (e.g. `eth1`): set the interface that etcd, stolon and keepalived use, see
  [More than one network interface](../platforms/index.md#more-than-one-network-interface).
- **A foreign data wrapper** (e.g. `oracle_fdw`): install the client packages on the database hosts with
  `linux_packages` (a dictionary per group; it replaces the one of standard, so keep its value and add yours), and give
  PostgreSQL the environment it needs with `stolon_keeper_extra_env_vars`:
  ```yaml
  # group_vars/all/stolon.yml
  stolon_keeper_extra_env_vars:
    ORACLE_HOME: /usr/lib/oracle/21/client64
    LD_LIBRARY_PATH: /usr/lib/oracle/21/client64/lib
  ```
