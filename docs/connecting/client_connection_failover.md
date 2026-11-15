# Client Connection Failover

In the Postgres environment, clusters are provided that consist of 3 or more database servers and a backup server. In some environments, currently the two DVP clusters and the POC environment, there are also two proxy servers with a VIP address.

In environments with a VIP address, accessing the database is straightforward. By using the VIP, you always connect to the primary database.

In environments without VIP and proxy servers, there are usually three database servers where it is not known which one is the primary; this can also change, for example, during patching. To connect to the primary database, there are a few options.

## Requirements and dependencies

The database(s) can be accessed in various ways, each with its own specifics; we describe the following:

- psql on Linux  
- PGAdmin on Windows  
- DBeaver on Windows

## Using psql service files

Using `psql` on Windows allows you to utilize the 'service file' (`.pg_service.conf` in `$HOME`) for configuration, including connection details. Below is an example of how to connect to either a primary or slave server without knowing which one it is. In the 'service file', this can be specified as follows:

```bash
#[master]

host=gurus-pgsdb-server1.int.corp.com, gurus-pgsdb-server2.int.corp.com, gurus-pgsdb-server3.int.corp.com
port=5432
target_session_attrs=read-write
sslmode=verify-full

#[standby]

host=gurus-pgsdb-server1.int.corp.com, gurus-pgsdb-server2.int.corp.com, gurus-pgsdb-server3.int.corp.com
port=5432
target_session_attrs=read-only
```
---

This way, the connection can be made with `service=master` to the primary database and with `service=standby` to any standby database:

### psql on Linux

The situation:

```bash
gurus_pgsdb_server1 (master)

├─gurus_pgsdb_server2
├─gurus_pgsdb_server3

$ hostname --fqdn
gurus-pgsdb-server2.int.corp.com

$ psql service=master

psql (14.5)
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
Type "help" for help.

postgres=# select pg_is_in_recovery();
pg_is_in_recovery
-----------------
f
(1 row)

postgres=# exit;

## Database is not recovering and is therefore the primary!

$ psql service=standby

psql (14.5)
```

SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)

Enter "help" for assistance.

The indication of standby and master comes from the 'service file' and can be filled or expanded according to your own understanding.

```bash
SELECT pg_is_in_recovery();
`pg_is_in_recovery`
-----------------
t
(1 row)

postgres=# exit;
```

Now we see that the database is in `recovery_mode`, which means it's a standby/slave database.

## PGAdmin for Windows

For PGAdmin, it also applies that this can make use of the aforementioned 'service file'; it works identically to what has been described above. If PGAdmin is used on Windows, then the peculiarity is the name and location of the 'service file', namely:

**\%APPDATA%\postgresql\.pg\_service.conf** (where \%APPDATA\% refers to the Application Data subdirectory in the user's profile), where on Linux this file is: **~/.pg\_service.conf**

In the windows of PGAdmin, this can be easily filled in further.

The 'service file' contains the following:

```bash
# [aermaster]

port=5432
target_session_attrs=read-write
```

So if we make the connection this way, it ends up on the master!


## Dbeaver

For DBeaver on Windows, it works a bit differently; here, the JDBC URL is used, which needs to be entered in the DBeaver window, somewhat depending on the version.

An example is: `jdbc:postgresql://node1,node2,node3/accounting?targetServerType=primary`

This ensures that the connection is made to the master database where read/write actions are possible.

NB: Screenprint is a newer version than what's present on the management server; this is version 22.3.0.

If the connection is not made 'correctly', e.g., connected to a readonly (slave) environment, the following 'error message' may be shown when an attempt is made to write something:

```text
Caused by: liquibase.exception.DatabaseException: ERROR: cannot execute CREATE TABLE in a read-only transaction [Failed SQL: (0)]
```

This will then be displayed, an error message, but clearly explainable!

