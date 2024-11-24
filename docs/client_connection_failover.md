## Belongs to Component

---

Postgres

## # Introduction

In the Postgres environment, clusters are provided that consist of 3 or more database clusters and a backup server. In some environments, currently the two DVP clusters and the POC environment, there are also two proxy servers with a VIP address.

In environments with a VIP address, accessing the database is straightforward. By using the VIP, you always connect to the primary database.

In environments without VIP and proxy servers, there are usually three database servers where it is not known which one is the primary; this can also change, for example, during patching. To connect to the primary database, there are a few options.
```

## Requirements and dependencies

The database(s) can be accessed in various ways, each with its own specifics; we describe the following:

- psql on Linux  
- PGAdmin on Windows  
- DBeaver on Windows

## Performance

Using `psql` on Windows allows you to utilize the 'service file' (`.pg_service.conf` in `$HOME`) for configuration, including connection details. Below is an example of how to connect to either a primary or slave server without knowing which one it is. In the 'service file', this can be specified as follows:

```
[master]
```

```
host=gurus-pgsdb-server1.int.corp.com, gurus-pgsdb-server2.int.corp.com, gurus-pgsdb-server3.int.corp.com
```

`port=5432`

```markdown
target_session_attrs=read-write
```

```markdown
sslmode=verify-full
```

\[standby\]

```
host=gurus-pgsdb-server1.int.corp.com, gurus-pgsdb-server2.int.corp.com, gurus-pgsdb-server3.int.corp.com
```

port=5432

`target_session_attrs=read-only`

---

This way, the connection can be made with `service=master` to the primary database and with `server=standby` to any standby database:

## psql op Linux

The situation:

```
gurus_pgsdb_server1 (master)
```

├─gurus\_pgsdb\_server2

# gurus_pgsdb_server3

$ hostname --fqdn

`scc-pgsdb-server2.int.corp.com`

```markdown
$ **psql service=master**
```

psql (14.5)

```markdown
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
```

Type "help" for help.

```markdown
postgres=# select pg_is_in_recovery();
```

```markdown
pg_is_in_recovery
```

\-\-\-----------------

f

(1 row)

```
postgres=# exit;
```

```
Database is not recovering and is therefore the primary!
```

```markdown
$ **psql service=primary**
```

psql (14.5)

SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)

Enter "help" for assistance.

The indication of standby and master comes from the 'service file' and can be filled or expanded according to your own understanding.

```markdown
SELECT pg_is_in_recovery();
```

```markdown
`pg_is_in_recovery`
```

\-\-\-----------------

t

(1 row)

```markdown
postgres=# exit;
```

Now we see that the database is in `recovery_mode`, which means it's a standby/slave database.

## PGAdmin for Windows

For PGAdmin, it also applies that this can make use of the aforementioned 'service file'; it works identically to what has been described above. If PGAdmin is used on Windows, then the peculiarity is the name and location of the 'service file', namely:

```markdown

```

**\%APPDATA%\postgresql\.pg\_service.conf** (where \%APPDATA\% refers to the Application Data subdirectory in the user's profile), where on Linux this file is: **~/.pg\_service.conf**

In de windows van PGAdmin kan dit verder eenvoudig worden ingevuld.

The 'service file' contains the following:

`[aermaster]`

`port=5432`

```markdown
target_session_attrs=read-write
```

So if we make the connection this way, it ends up on the master!

![1672243206877-313.png](../../../../../../../../../attachment/xwiki/Infrastructuur/Team%3A+DBA/Algemene+Restore+Server+voor+DBA-Linux/Postgres/Bouwsteen/Onderhoud/Connect+to+primary+or+slave/WebHome/1672243206877-313.png)

## Dbeaver

For DBeaver on Windows, it works a bit differently; here, the JDBC URL is used, which needs to be entered in the DBeaver window, somewhat depending on the version.

An example is: `jdbc:postgresql://node1,node2,node3/accounting?targetServerType=primary`

Hiermee wordt weer bereikt dat de connectie wordt gemaakt naar de master database waar read/write acties mogelijk zijn.

```
![1672242748155-292.png](../../../../../../../../../attachment/xwiki/Infrastructuur/Team%3A%20DBA/Algemene%20Restore%20Server%20voor%20DBA-Linux/Postgres/Bouwsteen/Onderhoud/Connect%20to%20primary%20or%20slave/WebHome/1672242748155-292.png)
```

NB: Screenprint is a newer version than what's present on the management server; this is version 22.3.0.

Als de connect niet ' goed' wordt gemaakt, bv connected aan readonly (slave) omgeving kan de volgende 'foutmelding' worden getoond als er een poging wordt gedaan om iets weg te schrijven:

```markdown
Caused by: liquibase.exception.DatabaseException: ERROR: cannot execute CREATE TABLE in a read-only transaction [Failed SQL: (0)]
```

This will then be displayed, an error message, but clearly explainable!

