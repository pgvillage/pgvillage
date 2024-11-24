# Introduction

Once the new servers are available, they can be deployed as new database, backup, and (optionally) routing servers.

Dit wordt gedaan middels Ansible. Deze beschrijving kan gebruikt worden om de inventory met de juiste informatie te laden

and running Ansible to create a running database cluster.

# Requirements

- 3 (or more) database servers, 1 backup server (and optionally 2 router servers)
  - Requested through a change request (see [from database request to server request](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Van+database+aanvraag+naar+server+aanvraag/WebHome.html) for more information).
  - Delivered by SHS
- Management server with the correct configuration: [ssh](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/ssh/WebHome.html) config, [ansible](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/ansible/WebHome.html) config

# Instruction Manual

1: Controleer dat de opgeleverde servers voldoen aan de aanvragen. Controleer o.a.:

- iptables
  - On the database servers, ports 5432, 25432, 2379, and 2380 must be open.
  - On the backup server, port 9091 must be open.
  - On the router servers (if applicable), ports 5432 and 5433 must be open.
- storage
  - On the database servers, `/data/postgres/data` and `/data/postgres/wal` must be available with sufficient space.
  - On the backup server, `/data/postgres/backup` must be available with sufficient space.
- CPU and memory
  - Database server: See server request form.
  - Backup server: 1 CPU and 4G is sufficient.
  - Router servers (if applicable): 1 CPU and 4 G is sufficient.

2: Make sure the inventory has been created and filled out correctly.

The inventory can (for example) be copied from an existing inventory and possibly even assembled itself.

Examples:

- `environments/poc` explains how it works in the POC environment: PG14, including router configuration.
- `environments/geo_a` relates to a solution with PG14 and PostGIS.
- `environments/vbe_a` pertains to a solution with PostgreSQL 12, router, foreign data wrapper, and pgQuartz jobs.

Let's move on to the following:

```markdown
- postgres version:
  - environments/[ENV]/group_vars/all/generic.yml: postgresql_version
  - environments/[ENV]/group_vars/all/packages.yml: linux_rhsm_poolids
    - see examples in "environments/vbe_t/group_vars/all/packages.yml" (PG12) and "environments/geo_a/group_vars/all/packages.yml" (PG14)
- router config:
  - environments/[ENV]/group_vars/all/generic.yml: postgresql_vip_fqdn, postgresql_vip_ip en postgresql_subnet
  - environments/[ENV]/group_vars/all/generic.yml: haproxy_rw_backends en haproxy_ro_backends
- Foreign data wrapper:
  - environments/[ENV]/group_vars/all/generic.yml: stolon_keeper_extra_env_vars en stolon_package_names
  - environments/[ENV]/group_vars/all/generic.yml: stolon_keeper_extra_env_vars
- PgQuartz:
  - environments/[ENV]/group_vars/all/generic.yml: pgquartz_definitions, pgquartz_jobs
- PostgIS:
  - environments/[ENV]/group_vars/hacluster/packages.yml: linux_packages.postgres
- pg_hba config
  - environments/[ENV]/group_vars/all/generic.yml: stolon_pg_hba
    - The first and second line must remain:
```

- `local all all` identify  
- `ident`

- hostssl postgres avchecker samenet cert  
  - The rest must be in accordance with the database request form (information at `Host Based Access` table)

For example, to create a new inventory based on `geo_a`:

- Create a new branch and merge request
- Copy from an existing inventory

```markdown
NEW_ENV=[ENV]_[OMGEVING]
```

```markdown
git checkout -b feature/$NEW_ENV dev
```

```markdown
rsync -av environments/geo_a environments/$NEW_ENV
```

```markdown
Adjust the following files as needed: `environments/$NEW_ENV/hosts` and `environments/$NEW_ENV/group_vars/all/generic.yml`
```

Adjust the environment as needed. At least configure the following files:

```markdown
- environments/[ENV]/hosts
  - fill in the correct hostnames
- environments/[ENV]/group_vars/all/generic.yml
  - pg_hba configuration
```

3: create the client certificates according to the work instruction [generate new certificates](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Onderhoud/Nieuwe+certificaten+genereren+en+uitrollen/WebHome.html)

```markdown
4: Create a new commit, push and make a merge request (create it as a draft MR)
```

```
NEW_ENV=[ENV]_[OMGEVING]
```

```markdown
git add environments/$NEW_ENV
```

```markdown
git commit -m "New environment $NEW_ENV"
```

git push

#glab, or follow the link in the output of the `git push` command

---

glab mr create

5: Execute Ansible, check the output and resolve any issues according to the [Ansible documentation](../../../../../../../../pages/xwiki/Infrastructuur/Team%3A+DBA/Werkinstrukties/Postgres/Bouwsteen/ansible/WebHome.html)

Check the result:
-

- Ensure that Postgres is working and check the PostgreSQL version:

```bash
psql --version
```

```markdown
ssh gurus-dbtdb-server3.int.corp.com
```

```markdown
Last login: Thu Oct 2015 10:06 from 10.0.6.100
```

```
[me@gurus-dbtdb-server3~]$ sudo iu postgres
```

### ClusterInfo

```markdown
MasterKeeper: gurus_dbtdb_server2
```

## Keepers/DBtree

```markdown
gurus_dbtdb_server2 (master)
```

```
│── gurus_dbtdb_server3
```

```
└─gurus_dbtdb_server1
```

```markdown
[postgres@gurus-dbtdb-server3~]$ psql service=proxy
```

psql(14.5)

```markdown
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
```

Type "help" for help.
```

postgres=#

- Check the status of [avchecker](../../../../../../../../pages/xwiki/Infrastructuur/Team%3A+DBA/Werkinstrukties/Postgres/Bouwsteen/AV+checker/WebHome.html)
- Create users as per [Extra database en/of user aanmaken](../../../../../../../../pages/xwiki/Infrastructuur/Team%3A+DBA/Werkinstrukties/Postgres/Bouwsteen/Bestaand+cluster+aanpassen/WebHome.html)

If everything is okay after the rollout, mark the Merge Request as Ready and ensure that the Merge Request gets merged.

