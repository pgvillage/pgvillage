---
title: Connectivity
summary: A description of how to check connectivity to and between PgVillage nodes
authors:
  - Sebas Mannem
  - Snehal Kapure
date: 2025-11-11
---

# Connectivity

To properly analyze PostgreSQL connectivity issues, it is important to understand how connections are routed and where things can fail along the path.

This documentation describes the connection paths and provides guidance on what to investigate when troubleshooting connectivity problems.

## Postgres Read-Write Connections via the Router

### How to recognize

Read-write connections through the router are initiated by the client using the VIP as the endpoint and port **5432** as the destination port.

Examples:

```bash
# A pg_service file:
[myapp]
user=usr
password=pwd
host=acme-dvppg1pr-v01p.acme.corp.com
port=5432
sslmode=verify-full
dbname=myappdb

# Then a connection with service=myapp

# libpq connection string:
'user=usr password=pwd host=acme-dvppg1pr-v01p.acme.corp.com port=5432 sslmode=verify-full dbname=myappdb'

# JDBC connection URL as:
postgresql://usr:pwd@acme-dvppg1pr-v01p.acme.corp.com:5432/myappdb
```

RW router connections can be recognized by:

- Port is **5432**
- Hostname contains **pr-v01**

### Paths

The connections follow these paths:

1. Starts at application level and then (OpenShift?) routing, network firewall, etc., all the way to the gateway.

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
     - Does it match expectations? See [HAProxy](../../tools/haproxy.md) documentation...
   - Is PgRoute66 running?
   - Does the logging match expectations? Run with debugging if necessary. See [PgRoute66](../../tools/pgroute66.md) documentation...
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
   - What does the avchecker service say?
     - Problem with avchecker@stolon is an issue with Postgres on the primary node
     - Problem with avchecker@proxy is an issue with stolon-proxy
     - Problem with avchecker@routerrw is an issue with the router
   - Does local connection work via stolon-proxy? `sudo -iu postgres bash -c 'psql service=proxy'`

6. Stolon-proxy routes to the primary Postgres
   - Is there a primary?
     - Log in to one of the database servers and switch to user postgres. Check the output of stolonctl status which identifies the primary
     - Log in to the primary, become postgres (sudo -iu postgres) and check the status with `psql -c 'select pg_is_in_recovery()'` (f is expected)
   - Is the user allowed from the pg_hba config?
     - Note that the source IP of the traffic are the proxy nodes!!!
   - What does logging on the primary say? Are there login errors?

---

## PostgreSQL Read-Only (RO) Connections via the Router

### How to recognize

Routed connections through the router are initiated by the client with the VIP as the endpoint and port **5433** as the destination port.

Examples:
```bash
# A pg_service file with the following service:
[myapp]
user=usr
password=pwd
host=acme-dvppg1pr-v01p.acme.corp.com
port=5433
sslmode=verify-full
dbname=myappdb

# Then a connection with service=myapp

# libpq connection string:
'user=usr password=pwd host=acme-dvppg1pr-v01p.acme.corp.com port=5433 sslmode=verify-full dbname=myappdb'

# JDBC connection URL:
postgres://usr:pwd@acme-dvppg1pr-v01p.acme.corp.com:5433/myappdb
```

RO connections can be recognized by:

- Port is **5433**
- Hostname contains **pr-v01**

---

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
     - Does it match expectations? See [HAProxy](../tools/haproxy.md) documentation...
   - Is PgRoute66 running?
   - Does the logging match expectations? Run with debugging temporarily if necessary. See [PgRoute66](../tools/pgroute66.md) documentation...
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

---

## Stolon Proxy PostgreSQL Read-Write Connections

### How to recognize

Stolon-proxy read-write connections are initiated by the client with the database servers as the endpoint and port **25432** as the destination port.

Examples:

```bash
# A `pg_service` file with the following service:
[myapp]
user=usr
password=pwd
host=acme-dvppg1db-server1.acme.corp.com, acme-dvppg1db-server2.acme.corp.com, acme-dvppg1db-server3.acme.corp.com
port=25432
sslmode=verify-full
dbname=myappdb

# and then a connection with service=myapp

# libpq connection string:
'user=usr password=pwd host=acme-dvppg1db-server1.acme.corp.com,acme-dvppg1db-server2.acme.corp.com,acme-dvppg1db-server3.acme.corp.com port=25432 sslmode=verify-full dbname=myappdb'

# JDBC connection URL:
postgres://usr:pwd@acme-dvppg1db-server1.acme.corp.com,acme-dvppg1db-server2.acme.corp.com,acme-dvppg1db-server3.acme.corp.com:25432/myappdb
```

RW router connections can be recognized by:

- Port is **25432**
- Hostnames contain **db-l0**

---

### Paths

The connections follow these paths:

1. Starts with the application, followed by (OpenShift?) routing, network firewall, etc., up to the gateway.
2. To the Database server on port 25432
   - Is the firewall active?
   - What are the firewall rules? `sudo iptables -L`?
   - Are the app servers included for port 25432?
3. Port 25432 is stolon-proxy:
   - Is stolon-proxy running?
   - What does the avchecker service say?
     - Issue with avchecker@stolon is an issue with Postgres on the primary node
     - Issue with avchecker@proxy is an issue with stolon-proxy
   - Does local connection work via stolon-proxy? `sudo -iu postgres bash -c 'psql service=proxy'`
4. Stolon-proxy routes to the primary postgres
   - Is there a primary?
     - Log into one of the database servers as user postgres. Check the output of `stolonctl status` which shows the primary.
     - Log into the primary, become postgres (sudo -iu postgres) and check the status with `psql -c 'select pg_is_in_recovery()'` (f is expected)
   - Is the user allowed from the pg_hba config?
     - Note that the source IP of the traffic are the proxy nodes!!!
   - What does the logging on the primary say? Are there login errors?

---

## Direct PostgreSQL Read-Write Connections

### How to recognize

Direct RW connections are initiated by the client targeting the DB servers directly on port **5432**.

Examples:

```bash
# A `pg_service` file with the following service:
[myapp]
user=usr
password=pwd
host=acme-dvppg1db-server1.acme.corp.com, acme-dvppg1db-server2.acme.corp.com, acme-dvppg1db-server3.acme.corp.com
port=5432
sslmode=verify-full
dbname=myappdb
target_session_attrs=read-write

# Then a connection with service=myapp

# A libpq connection string like:
'user=usr password=pwd host=acme-dvppg1db-server1.acme.corp.com,acme-dvppg1db-server2.acme.corp.com,acme-dvppg1db-server3.acme.corp.com port=5432 sslmode=verify-full dbname=myappdb target_session_attrs=read-write'

# JDBC connection URL:
postgres://usr:pwd@acme-dvppg1db-server1.acme.corp.com,acme-dvppg1db-server2.acme.corp.com,acme-dvppg1db-server3.acme.corp.com:5432/myappdb?targetServerType=master
```

Direct RW connections are recognizable by:

- Port **5432**
- libpq: `target_session_attrs=read-write`
- JDBC: `targetServerType=primary`
- Hostnames contain **db-l0**

---

### Paths

The connections follow these paths:

1. Begins with the application and then (OpenShift?,) routing, network firewall, etc., up to the gateway

   - Is OpenShift routing correctly configured?
   - Does the traffic indeed come from the intended IP address?
   - Is the firewall open for traffic from the AppServer IP to the database nodes?

2. To the Database server on port 5432

   - Is the firewall active?
   - What are the firewall rules? `sudo iptables -L`
   - Are the app server IPs included for port 5432?

3. On port 5432, PostgreSQL is running
   - Is there a primary?
     - Log in to one of the database servers as user postgres. Check the output of stolonctl status to determine which is the primary.
     - Log in to the primary as postgres (sudo -iu postgres) and check the status with `psql -c 'select pg_is_in_recovery()'` (f is expected)
   - Is the user allowed from the pg_hba config?
     - Note that the source IPs of the traffic are the app servers!!!
   - What does the logging on the primary say? Are there login errors?

## Direct PostgreSQL Connections (Read-Only)

### How to recognize

Direct RO connections are established by the client with the database hosts as endpoints and port **5432** as the destination port.

Examples:

```bash
# A `pg_service` file with the following service:
[myapp]
user=usr
password=pwd
host=acme-dvppg1db-server1.acme.corp.com, acme-dvppg1db-server2.acme.corp.com, acme-dvppg1db-server3.acme.corp.com, acme-dvppg1db-server4.acme.corp.com
port=5432
sslmode=verify-full
dbname=myappdb

# with the v14+ driver
target_session_attrs=read-only # or standby or prefer-standby

# Then a connection with service=myapp

# libpq connection string:
'user=usr password=pwd host=acme-dvppg1db-server1.acme.corp.com,acme-dvppg1db-server2.acme.corp.com,acme-dvppg1db-server3.acme.corp.com,acme-dvppg1db-server4.acme.corp.com port=5432 sslmode=verify-full dbname=myappdb target_session_attrs=read-only'

# JDBC connection URL as:
postgres://usr:pwd@acme-dvppg1db-server1.acme.corp.com,acme-dvppg1db-server2.acme.corp.com,acme-dvppg1db-server3.acme.corp.com,acme-dvppg1db-server4.acme.corp.com:5432/myappdb?targetServerType=secondary
```

RO connections can be recognized by:

- Port **5432**
- Hostnames contain **db-l0**
- libpq: `target_session_attrs=read-only` (or `standby`, `prefer-standby`)
- JDBC: `targetServerType=secondary` (or `slave`, `preferSlave`, `preferSecondary`)

---

### Paths

The connections follow these paths:

1. Start at the application level and then proceed to routing (OpenShift?), network firewall, etc., until reaching the gateway.
2. To the Database hostname on port 5432
   - Is the firewall active?
   - What are the firewall rules? `sudo iptables -L`
   - Are the app servers included for port 5432?
   - Is the user allowed from the pg_hba configuration?
     - Note that the source IP of the traffic is the app server IP!!!
   - What do the logs on the standby servers say? Are there login errors? Are there one or more standbys?
   - Log in to one of the database servers as user postgres. Check the output of `stolonctl status` which shows the standbys.
   - Log into the standbys as postgres (sudo -iu postgres) and check the status with `psql -c 'select pg_is_in_recovery()'` (it is expected).
