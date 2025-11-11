---
title: Connectivity
summary: A description of how to check connectivity to and between PgVillage nodes
authors:
  - Sebas Mannem
  - Snehal Kapure
date: 2025-11-11
---

# Introduction

Om PostgreSQL connectie issues goed te kunnen analyseren is het belangrijk om te begrijpen hoe connecties worden gerouteerd en welke dingen onderweg mis kunnen gaan.

Deze documentatie beschrijft de paden die een connectie afleggen en geeft hints welke dingen onderzocht kunnen worden om issues te analyseren en op te lossen.

## ```markdown

Postgres Read-Write Connections via the Router

```

### How to recognize?

RW connecties via de router worden geiniteerd door de client met de VIP als endpoint en poort 5432 als destination port.

A few examples are:

# A `pg_service` File with the Following Service:

\[myapp\]

user=usr

```

password=pwd

```

`host=acme-dvppg1pr-v01p.acme.corp.com`

```

port=5432

````

```markdown
sslmode=verify-full
````

```
dbname=myappdb
```

```markdown
# Then a connection with service=myapp
```

```markdown
# a libpq connection string like:
```

```markdown
'user=usr password=pwd host=acme-dvppg1pr-v01p.acme.corp.com port=5432 sslmode=verify-full dbname=myappdb'
```

```markdown
# a JDBC connection URL as:
```

```
postgresql://usr:pwd@acme-dvppg1pr-v01p.acme.corp.com:5432/myappdb
```

RW Router connections can be recognized by:

-

- The port is 5032.
- Hostname contains pr-v01.

### Paths

The connections follow these paths:

1. Starts at application level and then (OpenShift?, ) routing, network firewall, etc., all the way to the gateway.
2. To the Virtual IP on port 5432

   - The VirtualIP is linked by KeepaliveD.
     - Is KeepaliveD OK?
     - Is the VIP attached to one server?
     - Does the network address of the VIP match the network of the interface it's connected to?
   - Is the firewall active?
     - What are the firewall rules? `sudo iptables -L`?
     - Are the app servers included for port 5432?

3. Arrives at HAProxy

   - Is HAProxy running?
   - What does the haproxy stat command say?
     - Is there an active PostgresReadWrite-backend? There should be one...
     - Does it match expectations? See [HAProxy](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/HAProxy/WebHome.html) documentation...
   - Is PgRoute66 running?
   - Does the logging match expectations? Run with debugging if necessary. See [PgRoute66](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/PgRoute66/WebHome.html) documentation...
   - Are the PgRoute66 certificates OK? `sudo openssl x509 -text -noout -in ~pgroute66/.postgresql/postgresql.crt`
     - Check that `validity - Not After` has not expired
     - Check that `X509v3 Key Usage: Digital Signature, Key Encipherment, Data Encipherment` is set
     - Ensure the subject ends with `CN = pgroute66`

4. HAProxy routes to the Postgres primary port 25432

   - Is the firewall active?
   - What are the firewall rules? `sudo iptables -L`
   - Are the router nodes included for port 25432?

5. Port 25432 is stolon-proxy:

   - Is stolon-proxy running on the primary node?
   - What does the avchecker service say
     - Problem with avchecker@stolon is an issue with Postgres on the primary node
     - Problem with avchecker@proxy is an issue with stolon-proxy
     - Problem with avchecker@routerrw is an issue with the router
   - Does local connection work via stolon-proxy? `sudo -iupostgres bash -c 'psql service=proxy'`

6. Stolon-proxy routes to the primary Postgres
   - Is there a primary?
     - Log in on one of the database servers and switch to user postgres. Check the output of stolonctl status which identifies the primary
     - Log in on the primary, become postgres (sudo -iu postgres) and check the status with `psql -c 'select pg_is_in_recovery()'` (f is expected)
   - Is the user allowed from the pg_hba config?
     - Note that the source IP of the traffic are the proxy nodes!!!
   - What does logging on the primary say? Are there login errors?

## ```

PostgreSQL RO (Read Only) connections via the router

````

### How to recognize?

Routed connections through the router are initiated by the client with the VIP as the endpoint and port 5433 as the destination port.

A few examples are:

-
-

```markdown
# A pg_service file with the following service:
````

[myapp]

user=usr

password=pwd

`host=acme-dvppg1pr-v01p.acme.corp.com`

```
port=5433
```

```markdown
sslmode=verify-full
```

dbname=myappdb

```markdown
# Then a connection with service=myapp
```

```markdown
# A libpq connection string like:
```

```markdown
'user=usr password=pwd host=acme-dvppg1pr-v01p.acme.corp.com port=5433 sslmode=verify-full dbname=myappdb'
```

\# een jdbc connectie url als:

```
postgres://usr:pwd@acme-dvppg1pr-v01p.acme.corp.com:5433/myappdb
```

RO Router connections are recognizable by:

- Port is 5433
- Hostname contains pr-v01

### Paths

The connections follow these paths:

1. Begins at the application and then routing, network firewall, etc., up to the gateway.

   - Towards the Virtual IP on port 5433
     - The VirtualIP is attached by KeepaliveD.
       - Is KeepaliveD OK?
       - Is the VIP attached to one server?
       - Does the network address of the VIP match the network of the interface it's connected to?
   - Is the firewall active?
     - What are the firewall rules? `sudo iptables -L`?
     - Are the application servers included for port 5433?

2. Arrives at HAProxy

   - Is HAProxy running?
   - What does the haproxy stat command show?
     - Is there an active PostgresReadOnly-backend? There should be one...
     - Does it match expectations? See [HAProxy](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/HAProxy/WebHome.html) documentation...
   - Is PgRoute66 running?
   - Does the logging match expectations? Run with debugging temporarily if necessary. See [PgRoute66](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/PgRoute66/WebHome.html) documentation...
   - Are the PgRoute66 certificates OK? `sudo openssl x509 -text -noout -in ~pgroute66/.postgresql/postgresql.crt`
     - Check that `validity - Not After` has not expired
     - Ensure that `X509v3 Key Usage: Digital Signature, Key Encipherment, Data Encipherment` is set
     - Verify that the subject ends with `CN = pgroute66`

3. HAProxy routes to the Postgres standbys (not primary) on port 5432
   - Is the firewall active?
     - What are the firewall rules? `sudo iptables -L`
     - Are the router nodes included for port 5432?
   - Is the user allowed from the pg_hba config?
     - Note that the source IP of the traffic is from the proxy nodes!!!
   - What does the logging on the standby servers say? Are there login errors? Are there one or more standbys?
   - Log in to one of the database servers as user postgres. Check the output of stolonctl status for which are the standbys
   - Log into the standbys, become postgres (sudo -iu postgres) and check the status with `psql -c 'select pg_is_in_recovery()'` (it is expected)

## ```markdown

Stolon Proxy PostgreSQL Read-Write Connections

````

### How to recognize

Stolon-proxy read-write connections are initiated by the client with the database servers as the endpoint and port 25432 as the destination port.

A few examples are:

```markdown
# A `pg_service` file with the following service:
````

\[myapp\]

user=usr

`password=pwd`

```
host=acme-dvppg1db-server1.acme.corp.com, acme-dvppg1db-server2.acme.corp.com, acme-dvppg1db-server3.acme.corp.com
```

port=25432

```markdown
sslmode=verify-full
```

dbname=myappdb

# and then a connection with service=myapp

```markdown
# A libpq connection string like:
```

```markdown
'user=usr password=pwd host=acme-dvppg1db-server1.acme.corp.com,acme-dvppg1db-server2.acme.corp.com,acme-dvppg1db-server3.acme.corp.com port=25432 sslmode=verify-full dbname=myappdb'
```

\# een jdbc connectie url als:

```markdown
postgres://usr:pwd@acme-dvppg1db-server1.acme.corp.com,acme-dvppg1db-server2.acme.corp.com,acme-dvppg1db-server3.acme.corp.com:25432/myappdb
```

RW Router connections are recognizable by:

- Port is 25432
- Hostname contains `db-l0`

### Paths

---

The connections follow the following paths:

1. Starts with the application, followed by (OpenShift?, ) routing, network firewall, etc., up to the gateway.
2. To the Database server on port 25432
   - Is the firewall active?
   - What are the firewall rules? \`sudo iptables -L\`?
   - Are the app servers included for port 25432?
3. Port 25432 is stolon-proxy:
   - Is stolon-proxy running?
   - What does the avchecker service say
     - Issue with avchecker@stolon is an issue with Postgres on the primary node
     - Issue with avchecker@proxy is an issue with stolon-proxy
   - Does local connection work via stolon-proxy? \`sudo -iupostgres bash -c 'psql service=proxy'\`
4. Stolon-proxy routes to the primary postgres
   - Is there a primary?
     - Log into one of the database servers as user postgres. Check the output of `stolonctl status` which shows the primary.
     - Log into the primary, becomes postgres (sudo -iu postgres) and check the status with \`psql -c 'select pg_is_in_recovery()'\` (f is expected)
   - Is the user allowed from the pg_hba config?
     - Note that the source IP of the traffic are the proxy nodes!!!
   - What does the logging on the primary say? Are there login errors?

## Direct PostgreSQL Read-Write Connections

### How to recognize

Directe RW connecties worden geiniteerd door de client met de DB servers als endpoint en poort 5432 als destination port.

A few examples are:

```markdown
# A `pg_service` file with the following service:
```

\[myapp\]

user=usr

```
password=pwd
```

```
host=acme-dvppg1db-server1.acme.corp.com, acme-dvppg1db-server2.acme.corp.com, acme-dvppg1db-server3.acme.corp.com
```

port=5432

```markdown
sslmode=verify-full
```

dbname=myappdb

target_session_attrs=read-write

```markdown
# and then a connection with service=myapp
```

```markdown
# A libpq connection string like:
```

```markdown
'user=usr password=pwd host=acme-dvppg1db-server1.acme.corp.com,acme-dvppg1db-server2.acme.corp.com,acme-dvppg1db-server3.acme.corp.com port=5432 sslmode=verify-full dbname=myappdb target_session_attrs=read-write'
```

\# een jdbc connectie url als:

```
postgres://usr:pwd@acme-dvppg1db-server1.acme.corp.com,acme-dvppg1db-server2.acme.corp.com,acme-dvppg1db-server3.acme.corp.com:5432/myappdb?targetServerType=master
```

Directe RW connections can be recognized by:

- Port is 5432
- LibPQ: `target_session_attrs` = read-write (of primary)
- JDBC: `targetServerType` = primary (of master, preferPrimary)
- Hostname contains db-l0

### Paths

The connections follow these paths:

1. Begins with the application and then (OpenShift?, ) routing, network firewall, etc., up to the gateway

   - Is OpenShift routing correctly configured?
   - Does the traffic indeed come from the intended IP address?
   - Is the firewall open for traffic from the AppServer IP to the database nodes?

2. To the Database server on port 5432

   - Is the firewall active?
   - What are the firewall rules? `sudo iptables -L`
   - Are the appserver IPs included for port 5432

3. On port 5432, PostgreSQL is running
   - Is there a primary?
     - Log in to one of the database servers as user postgres. Check the output of stolonctl status to determine which is the primary.
     - Log in to the primary as postgres (sudo -iu postgres) and check the status with `psql -c 'select pg_is_in_recovery()'` (f is expected)
   - Is the user allowed from the pg_hba config?
     - Note that the source IPs of the traffic are the app servers!!!
   - What does the logging on the primary say? Are there login errors?

## Direct PostgreSQL Connections

RO Connectors

### How to recognize

Direct RO connections are established by the client with the database hosts as endpoints and port 5432 as the destination port.

A few examples are:

```markdown
# A `pg_service` file with the following service:
```

```
[myapp]
```

user=usr

password=pwd

```markdown
host=acme-dvppg1db-server1.acme.corp.com, acme-dvppg1db-server2.acme.corp.com, acme-dvppg1db-server3.acme.corp.com, acme-dvppg1db-server4.acme.corp.com
```

```
port=5432
```

```markdown
sslmode=verify-full
```

```
dbname=myappdb
```

#with the v14+ driver

```markdown
target_session_attrs=read-only # or standby or prefer-standby
```

# and then a connection with service=myapp

\# a libpq connection string like:

```markdown
'user=usr password=pwd host=acme-dvppg1db-server1.acme.corp.com,acme-dvppg1db-server2.acme.corp.com,acme-dvppg1db-server3.acme.corp.com,acme-dvppg1db-server4.acme.corp.com port=5432 sslmode=verify-full dbname=myappdb target_session_attrs=read-only'
```

```markdown
# a JDBC connection URL as:
```

```markdown
postgres://usr:pwd@acme-dvppg1db-server1.acme.corp.com,acme-dvppg1db-server2.acme.corp.com,acme-dvppg1db-server3.acme.corp.com,acme-dvppg1db-server4.acme.corp.com:5432/myappdb?targetServerType=secondary
```

RO Router connections can be recognized by:

- port is 5432
- hostname contains db-l0
- libpq: `target_session_attrs=read-only` (or `standby`, `prefer-standby`)
- JDBC: `targetServerType=secondary` (or `slave`, `preferSlave`, `preferSecondary`)

### Paths

The connections follow the following paths:

```markdown
1. Start at the application level and then proceed to routing (OpenShift?), network firewall, etc., until reaching the gateway.
2. To the Database hostname on port 5432
   - Is the firewall active?
   - What are the firewall rules? `sudo iptables -L`
   - Are the app servers included for port 5432?
   - Is the user allowed from the pg_hba configuration?
     - Note that the source IP of the traffic is the app server IP!!!
   - What do the logs on the standby servers say? Are there login errors? Are there one or more standbys?
   - Log in to one of the database servers as user postgres. Check the output of `stolonctl status` which shows the standbys.
   - Log into the standby's as postgres (sudo -iu postgres) and check the status with `psql -c 'select pg_is_in_recovery()'` (it is expected).
```
