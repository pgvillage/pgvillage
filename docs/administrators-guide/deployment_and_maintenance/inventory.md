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

- 3 (or more) database servers, 1 backup server (and optionally 2 router servers)
  - Requested through a change request (see [from database request to server request]   (inventory.md) for more information).
  - Delivered by SHS
- Management server with the correct configuration: [ssh](../ssh.md) config, [ansible](ansible.md) config

---

## Instruction Manual

<!-- This docs should be replaced by checks before running first time -->

### 1. Verify that the delivered servers meet the requirements

#### iptables
- **Database servers:** Ports `5432`, `25432`, `2379`, and `2380` must be open.
- **Backup server:** Port `9091` must be open.
- **Router servers (if applicable):** Ports `5432` and `5433` must be open.

---

#### Storage
- **Database servers:**  
  `/data/postgres/data` and `/data/postgres/wal` must exist and have sufficient space.
- **Backup server:**  
  `/data/postgres/backup` must exist and have sufficient space.

---

#### CPU and Memory
- **Database server:**  See server request form.
- **Backup server:** 1 CPU, 4 GB RAM is sufficient.
- **Router servers:** 1 CPU, 4 GB RAM is sufficient.

---

### 2. Ensure the inventory has been created and filled out correctly

The inventory can (for example) be copied from an existing inventory and possibly even assembled itself.

Examples:

<!-- These should be replaced by example environments as shipped with pgvillage (e.a. pgv_azure and pgv_vagrant) -->

- `environments/poc` explains how it works in the POC environment: PG14, including router configuration.
- `environments/geo_a` relates to a solution with PG14 and PostGIS.
- `environments/vbe_a` pertains to a solution with PostgreSQL 12, router, foreign data wrapper, and pgQuartz jobs.

Let's move on to the following:

#### PostgreSQL Version
  - `environments/[ENV]/group_vars/all/generic.yml`: postgresql_version
  - `environments/[ENV]/group_vars/all/packages.yml`: linux_rhsm_poolids
    - see examples in `environments/vbe_t/group_vars/all/packages.yml` (PG12)             and `environments/ geo_a/group_vars/all/packages.yml` (PG14)

---

#### Router Configuration
 - `environments/[ENV]/group_vars/all/generic.yml`:
  - `postgresql_vip_fqdn`
  - `postgresql_vip_ip`
  - `postgresql_subnet`
  - `haproxy_rw_backends`
  - `haproxy_ro_backends`

---

#### Foreign Data Wrapper
  - `environments/[ENV]/group_vars/all/generic.yml`:
    - `stolon_keeper_extra_env_vars`
    - `stolon_package_names`

---

#### PgQuartz Configuration
  - `environments/[ENV]/group_vars/all/generic.yml`: 
    - `pgquartz_definitions`
    - `pgquartz_jobs`

---

#### PostGIS
  - `environments/[ENV]/group_vars/hacluster/packages.yml`: `linux_packages.postgres`

---

#### pg_hba Configuration
  - `environments/[ENV]/group_vars/all/generic.yml`: `stolon_pg_hba`
  - The first required pg_hba entries are:

    ```
    local all all ident
    hostssl postgres avchecker samenet cert
    ```
---

The remaining lines must follow the Host Based Access table from the database request form.

---

### Creating a New Inventory Based on geo_a

1. Create a new branch:

```bash
NEW_ENV=[ENV]_[OMGEVING]
git checkout -b feature/$NEW_ENV dev
```

2. Copy existing inventory

```bash
rsync -av environments/geo_a environments/$NEW_ENV
```

3. Modify required files:

- `environments/[ENV]/hosts` - fill in correct hostnames  
- `environments/[ENV]/group_vars/all/generic.yml` - configure pg_hba  
---

<!-- This should be replaced on running PgVillage with certs signed by the orgs internal CA -->
<!-- We might add an option to generate CSR's instead of generating a chain -->

4. Create the client certificates according to the work instruction [generate new certificates](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Onderhoud/Nieuwe+certificaten+genereren+en+uitrollen/WebHome.html)


5. Commit and Push the New Environment
Create a new commit, push and make a merge request (create it as a draft MR)

```bash
NEW_ENV=[ENV]_[OMGEVING]
git add environments/$NEW_ENV
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
- Check the status of [avchecker](../tools/avchecker.md)
- Create users as per [Extra database en/of user aanmaken](../../../../../../../../pages/xwiki/Infrastructuur/Team%3A+DBA/Werkinstrukties/Postgres/Bouwsteen/Bestaand+cluster+aanpassen/WebHome.html)

If everything is okay after the rollout, mark the Merge Request as Ready and ensure that the Merge Request gets merged.
