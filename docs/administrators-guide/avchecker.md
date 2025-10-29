# Avchecker

**Avchecker** is a tool that monitors the availability of **PostgreSQL**.

---

## How It Works

1. It’s a **Python script**.
2. It connects to a database.
3. It creates (if necessary) a table with one row.
4. Then it endlessly repeats:
   - Reads back the last value.
   - Writes a new value.
   - Checks if the time difference between the previous and new value is longer than **7.5 seconds** (adjustable).
   - If the difference exceeds this threshold, it reports to **stdout**.

---

## Architecture Overview

Avchecker runs on all database servers as a service and monitors different connection endpoints:

- **stolon** → Direct connection to the master.
- **proxy** → Connection to the master through stolon-proxy.
- **router** → Connection via HAProxy on port **5432**.

---

## Requirements and Dependencies

Avchecker runs as a service with multiple instances per database server.

### Components

#### 1. Service Files
- Location: `/etc/systemd/system/avchecker@.service` *(Ansible managed)*
- Instances:
  - `avchecker@stolon.service`
  - `avchecker@proxy.service`
  - `avchecker@routerro.service`
  - `avchecker@routerrw.service`

---

#### 2. Script
- Path: `/opt/avchecker/avchecker.py` *(Ansible managed)*
- Python version: `3.6.8`

---

#### 3. Linux User
- User: `avchecker` *(Ansible managed)*
- Authentication: Client certificates *(Ansible managed)*

---

#### 4. Table
- **Database:** `postgres`

  ```sql
  CREATE TABLE public.avchecker (last timestamptz);
  ```
 *(Managed by Python script)*

---

#### 5. Configuration Files

  - `/etc/default/avchecker_proxy`(configuration for connections via stolon-proxy)
  - `/etc/default/avchecker_stolon`(configurations for direct connections to the master)
  - `/etc/default/avchecker_routerro`(configurations for connections via haproxy port 5433)
  - `/etc/default/avchecker_routerrw`(configurations for connections via haproxy port 5432)

  ---

#### 6. Connections:

  - Each database server creates a connection for every Avchecker instance.  
  - A cluster with 4 nodes and a router results in **16 total connections**, of which **12 connect to the master database**.

  ---

#### 7. Endpoints

- **stolon:** direct connection to the master database on one of the nodes.  
- **proxy:** direct connection to stolon-proxy, which forwards to the master database.  
- **routerrw:**
  - connection to HAProxy on port 5432  
  - from HAProxy to stolon-proxy on the master  
  - from stolon-proxy to the master  
- **routerro:**
  - connection to HAProxy on port 5433  
  - from HAProxy to one of the standby instances  

---

## Usage

The purpose of **Avchecker** is to monitor the **connectivity** and **availability** of the PostgreSQL service across different endpoints.

---
## Example Scenarios

- If the router does not function properly or behaves inconsistently:
  - `avchecker@proxy` and `avchecker@stolon` do not provide notifications.
  - `avchecker@routerro` and `avchecker@routerrw` do provide notifications.

- If the application experiences issues but `avchecker@routerro` and `avchecker@routerrw` do not:
  - The problem is most likely in the application, routing, or firewalling up to the router VIP.

  ---

This makes Avchecker an excellent diagnostic tool to determine at which level a connectivity issue exists.

Avchecker runs continuously as a systemd service and reports any issues in the systemd journal.

There is a small difference between the `routerro` service and the other services.

---
## Commands

Status control works best via `journalctl` commands.

```bash
[root@acme-dvppg1db-server2 ~]# journalctl -efu avchecker@routerro | head
```
Example logs:
```text
-- Logs begin at Sun 2022-10-16 02:26:36 CEST. --

Oct 16 00:38:06 acme-dvppg1db-server2 avchecker.py[629825]: cannot execute UPDATE in a read-only transaction

Oct 16 03:38:06 acme-dvppg1db-server2 avchecker.py[629825]: cannot execute UPDATE in a read-only transaction

Oct 16 03:38:06 acme-dvppg1db-server2 avchecker.py[629825]: cannot execute UPDATE in a read-only transaction

Oct 16 03:06:38 acme-dvppg1db-server2 avchecker.py[629825]: cannot execute UPDATE in a read-only transaction

Oct 16 02:38:06 acme-dvppg1db-server2 avchecker.py[629825]: cannot execute UPDATE in a read-only transaction

Oct 16 02:52:16 acme-dvppg1db-server2 avchecker.py[629825]: cannot execute UPDATE in a read-only transaction

Oct 1602:52:16 acme-dvppg1db-server2 avchecker.py[629825]: cannot execute UPDATE in a read-only transaction

Oct 16 05:02:16 acme-dvppg1db-server2 avchecker.py[629825]: cannot execute UPDATE in a read-only transaction

Oct 1602:52:16 acme-dvppg1db-server2 avchecker.py[629825]: cannot execute UPDATE in a read-only transaction
```
---

### Proxy Service Example

```bash
[root@acme-dvppg1db-server2 ~]# journalctl -efu avchecker@proxy

#Logs begin at Sun 2022-10-16 02:26:36 CEST.

Oct 16 20:25:28 acme-dvppg1db-server2 avchecker.py[629455]: 0:00:08.314879

[root@acme-dvppg1db-server2 ~]# journalctl -efu avchecker@stolon

-- Logs begin at Sun 2022-10-16 02:26:36 CEST. 

[root@acme-dvppg1db-server2 ~]# journalctl -efu avchecker@routerrw

-- Logs begin at Sun 2022-10-16 02:26:36 CEST.
```

At the first router, we observe a large number of notifications. 

This is expected behavior because updates fail on a standby instance — which is logical for `routerro`.

It was decided to include these notifications in the output since they confirm that we are working against a standby instance.

The downside is that there are more messages per second on stdout, causing the logs to fill up quickly. Hence the use of `| head 20`.

Systemd handles this efficiently and is not significantly impacted.

As an alternative, it can be decided, for example, to give a notification every n times and skip the rest.

This feature is (for now) not implemented.

For the proxy service, you see a notification:

```
Oct 16 20:25:28 acme-dvppg1db-server2 avchecker.py[629455]: 0:00:08.314879
```

This indicates that **stolon-proxy** took **8.31 seconds** to reconnect and rewrite data.  
Possible causes:

- The stolon-proxy was restarted
- The query took longer than expected due to locking or load delays.

All other services show no notifications.

---

## Controls

If it’s important to check availability, do the following steps.

- Log in to one of the database servers (preferably not the master)
- Check the output of `journalctl` for all available services

### Everything

Run the following commands:

```bash
cat /var/log/syslog | grep 'avchecker\|proxy'
journalctl -efu avchecker@stolon
journalctl -efu avchecker@routerrw
```

#### Verify the Following


- The services have **few interruptions**
  - Only `routerro` should have many and recent rules, typically showing `cannot execute UPDATE in a read-only transaction`.  
  - All other interruptions are points to look at  
- Interruptions from different services don't coincide  
  - If interruptions for all avchecker@ services coincide, there was likely an issue that the application also experienced  
  - An interruption for a single service probably indicates longer transaction times (postgres was busy) and is likely not noticed by the application  
- The endpoint used by the application works properly  
  - Systems with a router config are probably routerw and routerro  
  - Systems without a router are likely stolon (direct to master)  
- The routerro service has recent rules  
  - and only gives notifications for `cannot execute UPDATE in a read-oavchecker@routerronly transaction`  
  - if there are no recent rules, it could be that the  service is down or that the entire environment has been down for a long time. First check the avcheker@stolon service and all related controls.

!!! note

    For a quick end-to-end check of PostgreSQL with a router, check the `@routerrw` and `@routerro` services.
---

See at @routerrw and @routerro what to look out for…

### @stolon

```bash
journalctl -efu avchecker@stolon
```

If you encounter issues with `avchecker@stolon`, investigate and resolve them before proceeding

Check whether there is a master available, if it can be reached from the current server, and ensure that the client certificates are functioning correctly (for example, they have not expired):

```bash
[postgres@acme-dvppg1db-server1 ~]$ psql service=master
```

PostgreSQL (12.11)
-

```bash
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)

Type "help" for help.

postgres=# \q

[postgres@acme-dvppg1db-server1 ~]$
```

Connecting with `service=master` does the following:

- Connects one-to-one to all nodes and
  - Performs a full SSL check (`sslmode=verify-full`)
  - Authenticates with client certificates (for user `postgres`)
  - Checks if it is a master instance
- Goes on to the next node if necessary

If this works then you already know a lot:

- The server operates with a server certificate that can be verified with the root certificate (~postgres/.postgresql/root.crt).
- Client certificates are functioning correctly, can be verified by the server, and have not expired.
  - NOTE: The entire chain expires simultaneously.
  - NOTE: There is certificate monitoring for this certificate!
- A master instance is available.

---
### @proxy

The next step is the stolon-proxy layer. Check it with

```bash
journalctl -efu avchecker@proxy
```

If you notice issues with `avchecker@proxy`, resolve them before investigating `stolon-rw`.

HAProxy connects through stolon-proxy, so issues with stOLON-PROXY also have consequences.

If `avchecker@stolon` works properly, the best explanation is that the stolon-proxy service did not start correctly (or at all).

Other issues may be related to firewalling (but the AvChecker also connects locally, and the stolon proxy connects to the master in the same way as the service=`stolon` check).

---

Eventueel kan stolon-proxy ook gecontroleerd worden met psql:

```bash
[postgres@acme-dvppg1db-server1 ~]$ psql service=proxy
```

PostgreSQL (12.11)

```bash
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
```

Type "help" for help.
-

```bash
postgres=# \q

[postgres@acme-dvppg1db-server1 ~]$
```

Connecting with `service=proxy` does the following:

- Connect locally to the stolon-proxy port  
  - Stolon-proxy forwards traffic to the master
- Performs full SSL verification (`sslmode=verify-full`)
- Authenticates with client certificates (for user `postgres`)

If this works out then you already know a lot:

- The server operates with a server certificate that can be verified using the root certificate (~postgres/.postgresql/root.crt).
- The client certificates are functioning properly, can be verified by the server, and have not expired.
  - NOTE: The entire chain expires simultaneously.
  - NOTE: There is certificate monitoring for this certificate!!!
- A master instance is available.
- The local stolon-proxy can successfully connect to it.

Read more information in the documentation of [stolon](stolon.md).

---

### @routerrw
 
Used when HAProxy + Keepalived + PgRoute66 are deployed.

If `@stolon` and `@proxy` are healthy but `@routerrw` fails:
- The issue lies in **router configuration** (HAProxy, Keepalived, or PgRoute66).

Refer to internal documentation for:
- [HAProxy](haproxy.md)
- [KeepaliveD](keepalived.md)
- [PgRoute66](pgroute66.md)
  
---

The `@routerrw` service can also be very well used for an end-to-end check.

The best tool for end-to-end control is the `@routerro` service, but it does not verify if the router also forwards to the primary database server.

Therefore, @routerro should also be checked along with @routerrw:

```bash
journalctl -efu avchecker@routerrw
```
Check the output, ensuring that there are not (or very few) lines reporting a timeout.

If you don't see any issues but find that insufficient, then check with the [HAProxy](haproxy.md) documentation the output of the `show stat` command.

---

### @routerro

When a router configuration (using [HAProxy](haproxy.md), [KeepaliveD](keepalived.md) and [PgRoute66](pgroute66.md)) is used, it is also monitored with the avchecker@routerrw service.

If there are issues with `@stolon` and `@proxy`, it's best to resolve these first.

---

If there are no issues from @stolon and @proxy, then the problem must be found in the router configuration.

This can best be investigated and resolved with the documentation of [keepalived](keepalived.md), [HAProxy](haproxy.md) and [pgRoute66](pgroute66.md).

The @routerro service can also be very well used for an end-to-end check.

The main advantage of the `@routerro` service is that it continuously outputs status and covers all components.

The result of this check immediately provides a lot of useful information.

```bash
journalctl -efu avchecker@routerro | head
```
Check the output, ensuring primarily that the router service provides recent rules (such as "cannot execute UPDATE in a read-only transaction") and nothing else.

This tells you that:

- The router is still working properly.
- At least one of the other services is still updating the table.
- Streaming replication is still functioning (the other service updates the master and the changes reach this standby).
- The VIP is still linked to the server with a healthy HAProxy and pgrouter66 (i.e., the primary router is still working well).
- Server and client certificates are still working properly.

