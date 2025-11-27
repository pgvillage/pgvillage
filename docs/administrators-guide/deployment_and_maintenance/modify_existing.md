---
title: Modifying an existing deployment
summary: A description of how to modify an existing deployment
authors:
  - Sebas Mannem
  - Snehal Kapure
date: 2025-11-11
---

<!-- TDOD: This documentation should go and be replaced by docs on how to do this with a new run of Ansible -->

# Modifying an existing deployment

As part of creating a new cluster, database users and databases must also be created.

The ambition is to manage this automatically based on PGFA.

For now, we perform this manually.

## Dependencies

- Ansible setup according to [Ansible documentation](ansible.md)
- A properly stored database request form in teams:
  - Acme-IV-BI-Ops > General > Files > Database Request Forms >
- A running PostgreSQL cluster. Optionally, you can:
  - request servers according to [From database request to server request](inventory.md)
  - deploy via [link label] from servers to running database
    - This procedure is part of that procedure, so it should be good after this.

## Work Instruction

### 1. Create user and database using ps

Create users using the psql tool:

```bash
me@gurus-dbabh-server1 ~> ssh gurus-pgsdb-server1.int.corp.com

[me@gurus-pgsdb-server1 ~] $ sudo -iu postgres

#### Cluster Information

Master Keeper: gurus_pgssdb_l10

gurus_pgsdb_server1 (master)
├─gurus_pg_s_db_server2
└─gurus_pg_s_db_server3

[postgres@gurus-pgsdb-server1 ~]$ psql service=master

psql (14.5)

SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)

Type "help" for help.

postgres=# CREATE USER new_user;

CREATE ROLE

create_new_db=# \password create_new_user

Enter new password for user "new_user":

Enter it again:

postgres=# CREATE DATABASE new_db OWNER new_user;

CREATE DATABASE

REVOKE CONNECT ON DATABASE new_db FROM PUBLIC;

REVOKE

new_db=GRANT CONNECT ON DATABASE new_db TO new_user;

GRANT

new_db=#
```

### 2. Adjustments to hba.conf

Execute everything on the gurus-dbabh-server1:

```bash

#### Create a feature branch

ENV=poc
git checkout -b feature/changed*hba*$ENV dev

#### Adjust pg_hba configuration

Adjust the HBA configuration in `environments/$ENV/group_vars/all/generic.yml`
Adjust the HBA configuration as needed.

Be aware that for traffic via stolon-proxy, an accompanying SELinux rule must also be created.

#### Apply the updated configuration

ENV=poc
exportANSIBLE_VAULT_PASSWORD_FILE=~/git/ansible-postgres/bin/gpgvault
ansible-playbook -i environments/$ENV functional-all.yml --tags stolon

#### Create a Merge Request

ENV=poc
git add environments/$ENV
git commit -m "HBA adjustments $ENV"
git push
#glab, or follow the link in the output of the `git push` command
glab mr create

---

#### Check if everything has been rolled out properly:

me@gurus-dbabh-server1~> ssh gurus-pgsdb-server1.int.corp.com
[me@gurus-pgsdb-server1~] $ sudo -i postgres

===ClusterInfo===

#### MasterKeeper: gurus_pgssdb_server1

---

==Keepers/DBtree==

gurus_pgsdb_server1 (master)
├─gurus_pgsdb_server2
└─gurus_pgsdb_server3

[postgres@gurus-pgsdb-server1~] $ psql service=master
```

### `psql (14.5)`

```bash
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)

Type "help" for help.

postgres=# select \* from pg_hba_file_rules;

 line_number |   type    |   database   |  user_name  |    address     |    netmask     | auth_method |          options           | error
-------------+-----------+--------------+-------------+----------------+----------------+-------------+-----------------------------+-------
 1           | local     | postgres     | postgres    |                |                | peer        |                             |
 2           | local     | replication  | postgres    |                |                | peer        |                             |
 3           | hostssl   | all          | postgres    | 10.0.5.67      | 255.255.255.255| cert        | clientcert=verify-full      |
 4           | hostssl   | replication  | postgres    | 10.0.5.67      | 255.255.255.255| cert        | clientcert=verify-full      |
 5           | hostssl   | all          | postgres    | 10.0.5.68      | 255.255.255.255| cert        | clientcert=verify-full      |
 6           | hostssl   | replication  | postgres    | 10.0.5.68      | 255.255.255.255| cert        | clientcert=verify-full      |
 7           | local     | all          | all         |                |                | peer        |                             |
 8           | hostssl   | postgres     | avchecker   | samenet        |                | cert        | clientcert=verify-full      |
 9           | hostssl   | all          | all         | samenet        |                | cert        | clientcert=verify-full      |
(9 rows)

# postgres=#
```

If everything looks good, the status of the Merge Request can be changed to **Ready**.

### 3. Nieuwe client certificaten

If necessary, these can be created according to the [procedure for new client certificates](byo-client-certs.md).
