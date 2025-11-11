---
title: PostgreSQL Service File
summary: A description of the PostgreSQL Service file, how it works, and how it is implemented in PgVillage
authors:
  - Sebas Mannem
  - Snehal Kapure
date: 2025-11-11
---

# Introduction

een pg_service file bevat alle informatie voor een client om te kunnen connecten naar PostgreSQL.

Deze documentatie geeft een template om aan de eindgebruiker op te kunnen leveren.

# Dependencies

```markdown
- [Server request](../../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Van+database+aanvraag+naar+server+aanvraag/WebHome.html)
- [Configure cluster](../../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Van+server+naar+draaiende+database/WebHome.html)
- [Client connection information](../../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Clients/WebHome.html)
- [Client certificates](../../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/mTLS/Client+certificaten/WebHome.html)
```

# Instruction

De pg_service file vor een bepaalde gebruiker zou het volgende kunnen bevatten:

\[en\]

```markdown
host={lijst van alle hosts, gescheiden door komma's}
```

`port=5432`

```markdown
{user}
```

```markdown
sslcert=/home/{user}/.postgresql/{user}.crt
```

```markdown
sslkey=/home/{user}/.postgresql/{user}.key
```

```markdown
sslrootcert=/home/{user}/.postgresql/postgresql.crt
```

```markdown
target_session_attrs = read-write
```

```markdown
sslmode=verify-full
```

```markdown
dbname={database naam}
```

\[proxy\]

```markdown
host={lijst van alle hosts, gescheiden door een komma}
```

port=25432

user={user}

```markdown
sslcert=/home/{user}/.postgresql/{user}.crt
```

```markdown
sslkey=/home/{user}/.postgresql/{user}.key
```

```markdown
sslrootcert=/home/{user}/.postgresql/postgresql.crt
```

```markdown
target_session_attrs=read-write
```

```
sslmode=verify-full
```

```markdown
dbname = {databasenaam}
```

If a router is also being used, add the following:

```markdown

```

\[vip_rw\]

`host={vip_fqdn}`

port=5432

user={user}

```markdown
sslcert=/home/{user}/.postgresql/{user}.crt
```

```markdown
sslkey=/home/{user}/.postgresql/{user}.key
```

```plaintext
sslrootcert=/home/{user}/.postgresql/postgresql.crt
```

```markdown
target_session_attrs=read-write
```

```markdown
sslmode=verify-full
```

```markdown
dbname={database naam}
```

```
[vip_ro]
```

`host={vip fqdn}`

port=5433

user={user}

```markdown
sslcert=/home/{user}/.postgresql/{user}.crt
```

```
sslkey=/home/{user}/.postgresql/{user}.key
```

```markdown
sslrootcert=/home/{user}/.postgresql/postgresql.crt
```

```markdown
target_session_attrs=read-write
```

```
sslmode=verify-full
```

```
dbname={database name}
```

The starting point is that:

- `{user}` is replaced by the PostgreSQL user.
  - This must match the PostgreSQL user
  - This must match the Common Name of the client certificate:

```
openssl x509 -text -noout -in /home/{user}/.postgresql/{user}.crt | sed -n '/Subject:/{s/.\*= //;p}'
- {vip fqdn} moet vervangen worden door het IP adres van de VIP
- {database name} moet vervangen worden door de naam van de Postgres Database
- {list of all hosts, separated by ,} moet vervangen worden door een lijst van de servers, e.a.
```

- `{vip fqdn}` must be replaced with the IP address of the VIP
- `{database name}` must be replaced with the name of the Postgres Database
- `{list of all hosts, separated by ,}` must be replaced with a list of the servers, etc.

```
gurus-pgsdb-server1.int.corp.com, gurus-pgsdb-server2.int.corp.com, gurus-pgsdb-server3.int.corp.com
```
