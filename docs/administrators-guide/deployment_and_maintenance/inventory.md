---
title: Ansible inventory
summary: A description of the Ansible inventory, how it works, and hoe it is implemented in PgVillage
authors:
  - Sebas Mannem
  - Snehal Kapure
date: 2025-11-11
---

# Inventory

Once the new servers are available, they can be deployed as new database, backup, and (optionally) routing servers.

This is done using Ansible. This description can be used to load the inventory with the correct information and run Ansible to create a running database cluster.

---

## Requirements

- 3 (or more) database servers, 1 backup server (and optionally router servers)
- A control node (management server, where you run Ansible) with ssh access and sudo on all servers, see
  [Bring your own machines](../platforms/byo.md#checklist) and [Ansible](ansible.md)

---

## Instruction Manual

<!-- This docs should be replaced by checks before running first time -->

### 1. Verify that the delivered servers meet the requirements

Go through the [checklist](../platforms/byo.md#checklist). In short:

#### Network
- **All servers** reach each other on all ports. PgVillage configures firewalld on the servers, but not a firewall
  between them. The ports per cluster are in [The standard inventory](../platforms/index.md#the-standard-inventory).
- **Control node (where you run Ansible)**: Should be able to connect to all other servers using ssh (port 22)

---

#### Downloading sources
the following sources should be available either directly, or through a proxy (e.a. Satellite)
- [pgvillage](https://github.com/pgvillage/pgvillage) (either https, or ssh, or zip if no other option is available)
- [ansible galaxy for all ansible roles](https://galaxy.ansible.com/)
- [Our package repos](https://repo.pgvillage.org/)
- [PostgreSQL repos](https://download.postgresql.org/)
- os specific repos (e.a. centos, epel, CRB, or ubuntu repos, or Suse repos)

For more info, check [our linux role](https://raw.githubusercontent.com/pgvillage/ansible-role-linux/refs/heads/main/defaults/main.yml) (see `_linux_public_repos`).

---

#### Storage
- **Database servers:**  
  `/data/postgres/data` and `/data/postgres/wal` must exist and have sufficient space (see [Disks](../platforms/byo.md#disks)).
- **Backup server:**  
  `/var/lib/rustfs` must have sufficient space for the backups.

---

#### CPU and Memory
- **Database server:**  See server request form.
- **Backup server:** 1 CPU, 4 GB RAM is sufficient.
- **Router servers:** 1 CPU, 4 GB RAM is sufficient.

---

### 2. Ensure the inventory has been created and filled out correctly

PgVillage ships its inventories in `inventories/`. You run Ansible with several of them, in this order (later values
win):

1. `inventories/standard`: the standard PgVillage config, shared by all platforms (no hosts)
2. an OS layer: `inventories/el`, `inventories/ubuntu` or `inventories/suse` (no hosts)
3. a platform inventory with the hosts and the platform specifics, e.g. your own `inventories/<cluster>`

```bash
ansible-playbook -i inventories/standard -i inventories/el -i inventories/<cluster> functional-all.yml
```

See [Getting started](../platforms/index.md) for the layers and a minimal inventory for your own machines.

Examples of platform inventories:

- `inventories/vagrant`: the vagrant demo environment, with a router (see [Vagrant](../platforms/vagrant/index.md))
- `inventories/lima`: VMs on a Mac with lima (see [Lima](../platforms/lima.md))
- `inventories/azure`: Azure, with a dynamic inventory (see [Azure](../platforms/azure/index.md))

Change a setting in your own inventory by adding a file with the same name to `inventories/<cluster>/group_vars/all/`
(e.g. `generic.yml`), instead of changing `inventories/standard`. The files below are the ones in `inventories/standard`
that hold the setting.

Let's move on to the following:

#### Multihomed

When running multi-homed, you should set the correct interface to bind all processes to.
See [More than one network interface](../platforms/index.md#more-than-one-network-interface).
Set the following parameters as to your likings:

- `inventories/<cluster>/group_vars/all/stolon.yml`, look for:
  - stolon_pg_listen_address and set it to something like: "{{ ansible_facts['eth1']['ipv4']['address'] }}"
- `inventories/<cluster>/group_vars/all/etcd.yml`, look for:
  - etcd_iface_cluster and set it to your interface name (e.a. eth1)

!!! note
    This might also be set if you are using another interface name, such as enp0s9

---

#### PostgreSQL Version
  - `group_vars/all/generic.yml`: `postgresql_version`
  - `group_vars/all/packages.yml`: `linux_rh_subscription.pool_ids` (RHEL with subscriptions, see the
    `pgvillage.linux` role)

---

#### Router Configuration
 - `group_vars/all/generic.yml`:
    - `postgresql_vip_fqdn`
    - `postgresql_vip_ip`
    - `postgresql_subnet`
 - See [Router](../platforms/index.md#router) and [HAProxy](multiinstance/haproxy.md)

---

#### Foreign Data Wrapper
  - `group_vars/all/stolon.yml`:
    - `stolon_keeper_extra_env_vars`
    - `stolon_package_names`

---

#### PgQuartz Configuration
  - `group_vars/all/pgquartz.yml`:
    - `pgquartz_definitions`
    - `pgquartz_jobs`

---

#### PostGIS
  - `group_vars/all/packages.yml`: `linux_packages`

---

#### pg_hba Configuration
  - `group_vars/all/generic.yml`: `stolon_pg_hba`
  - The first required pg_hba entries are:

    ```
    local all all ident
    hostssl postgres avchecker samenet cert
    ```
---

The remaining lines must follow the Host Based Access table from the database request form.

---

### Creating a New Inventory

1. Create a new branch:

```bash
NEW_ENV=[ENV]_[OMGEVING]
git checkout -b feature/$NEW_ENV main
```

2. Create the inventory, e.g. by copying an existing one (the folder name is the cluster name)

```bash
mkdir -p inventories/$NEW_ENV/group_vars/all
```

3. Modify required files:

- `inventories/$NEW_ENV/hosts` - fill in correct hostnames (see [Hosts](../platforms/index.md#hosts))
- `inventories/$NEW_ENV/group_vars/all/generic.yml` - configure pg_hba
---

<!-- This should be replaced on running PgVillage with certs signed by the orgs internal CA -->
<!-- We might add an option to generate CSR's instead of generating a chain -->

4. Create the client certificates according to the work instruction [generate new certificates](byo-server-certs.md)


5. Commit and Push the New Environment
Create a new commit, push and make a merge request (create it as a draft MR)

```bash
NEW_ENV=[ENV]_[OMGEVING]
git add inventories/$NEW_ENV
git commit -m "New environment $NEW_ENV"
git push
#glab, or follow the link in the output of the `git push` command
glab mr create

```

6. Execute Ansible Deployment
  - check the output and resolve any issues according to the [Ansible documentation](ansible.md)

**Check the result:**

- Ensure that Postgres is working and check the PostgreSQL version:

```bash
psql --version

ssh gurus-dbtdb-server3.int.corp.com

Last login: Thu Oct 2015 10:06 from 10.0.6.100

[me@gurus-dbtdb-server3~]$ sudo iu postgres

#### ClusterInfo

MasterKeeper: gurus_dbtdb_server2

#### Keepers/DBtree

gurus_dbtdb_server2 (master)
│── gurus_dbtdb_server3
└── gurus_dbtdb_server1

[postgres@gurus-dbtdb-server3~]$ psql service=proxy

psql(14.5)

SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)

Type "help" for help.

postgres=#
```
- Check the status of [avchecker](../../tools/avchecker.md)
- Create users as per [Extra database en/of user aanmaken](modify_existing.md)

If everything is okay after the rollout, mark the Merge Request as Ready and ensure that the Merge Request gets merged.
