---
title: Modifying an existing deployment
summary: A description of how to modify an existing deployment
authors:
  - Sebas Mannem
  - Snehal Kapure
date: 2025-11-11
---

<!-- TDOD: This documentation should go and be replaced by docs on how to do this with a new run of Ansible -->

# Introduction

Als onderdeel van het aanmaken van een nieuw cluster moet ook database users en databases aangemaakt worden.

The ambition is to manage this automatically based on PGFA.

Voorlopig doen we dit met de hand.

# Dependencies

- Ansible setup according to [Ansible documentation](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/ansible/WebHome.html)
- A properly stored database request form in teams:
  - Acme-IV-BI-Ops > General > Files > Database Request Forms >
- A running PostgreSQL cluster. Optionally, you can:
  - request servers according to [From database request to server request](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Van+database+aanvraag+naar+server+aanvraag/WebHome.html)
  - deploy via [link label] from servers to running database
    - This procedure is part of that procedure, so it should be good after this.

# Werkinstructie

1: create user and database with `psql`

Maak de users aan met de psql tool:

```markdown
me@gurus-dbabh-server1 ~> ssh gurus-pgsdb-server1.int.corp.com
```

```
[me@gurus-pgsdb-server1 ~] $ sudo -iu postgres
```

## Cluster Information

---

```markdown
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

2: Adjustments to `hba.conf`

Execute everything on the gurus-dbabh-server1:

First, create a new feature (not for expanding on new database servers, only for adjusting existing clusters):

ENV=poc

```markdown
git checkout -b feature/changed*hba*$ENV dev
```

```markdown
Adjust the HBA configuration in `environments/$ENV/group_vars/all/generic.yml`
```

Adjust the HBA configuration as needed.

Be aware that for traffic via stolon-proxy, an accompanying SELinux rule must also be created.

Als de hba config naar behoren is aangepast kan deze worden toegepast middels:

ENV=poc

```markdown
exportANSIBLE_VAULT_PASSWORD_FILE=~/git/ansible-postgres/bin/gpgvault
```

```markdown
ansible-playbook -i environments/$ENV functional-all.yml --tags stolon
```

Then create a Merge Request (not for expanding on new database servers, only when adjusting existing clusters):

ENV=poc

```markdown
git add environments/$ENV
```

```markdown
git commit -m "HBA adjustments $ENV"
```

git push

#glab, or follow the link in the output of the `git push` command

glab mr create

Check if everything has been rolled out properly:

```markdown
me@gurus-dbabh-server1~> ssh gurus-pgsdb-server1.int.corp.com
```

```markdown
[me@gurus-pgsdb-server1~] $ sudo -i postgres
```

```markdown
===ClusterInfo===
```

# MasterKeeper: gurus_pgssdb_server1

---

==Keepers/DBtree==

---

```sql
gurus_pgsdb_server1 (master)
```

├─gurus_pgsdb_server2

└─gurus_pgsdb_server3

```
[postgres@gurus-pgsdb-server1~] $ psql service=master
```

## `psql (14.5)`

```
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
```

Type "help" for help.

```markdown
postgres=# select \* from pg_hba_file_rules;
```

```markdown
line_number | type | database | user_name | address | netmask | auth_method | options | error
```

-------------+---------+---------------+-------------+---------------+-----------------+-------------+--------------------------+-------

```
1| local | postgres | postgres |||| peer |
```

```
2 | local | replication | postgres ||| peer ||
```

```markdown
3 | hostssl | all | postgres | 10.0.5.67 | 255.255.255.255 | cert | clientcert=verify-full |
```

```markdown
4 | hostssl | {replication} | {postgres} | 10.0.5.67 | 255.255.255.255 | cert | {clientcert=verify-full} |
```

```markdown
5 | hostssl | {all} | postgres | 10.0.5.68 | 255.255.255.255 | cert | clientcert=verify-full |
```

```markdown
6|hostssl| {replication}| {postgres} |10.0.5.68|255.255.255.255|cert| {clientcert=verify-full} |
```

```markdown
7|local|{all} |{all}| ||peer||
```

```markdown
8 | hostssl | {postgres} | {avchecker} | samenet | cert | clientcert=verify-full |
```

```markdown
9 | hostssl | all | all | samenet | cert | clientcert=verify-full |
```

(9rows)

```
# postgres=#
```

If everything looks good, then the status of the Merge Request can be changed to Ready.

3: nieuwe client certificaten

If necessary, these can be created according to the [procedure for new client certificates](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Onderhoud/Nieuwe+certificaten+genereren+en+uitrollen/WebHome.html).
