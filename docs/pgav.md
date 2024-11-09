# Pgav

## Introduction

Pgav is a tool which monitors availability of a PostgreSQL cluster.
Whenever the cluster is available for writes, everything is ok, once it is not available, it records duration and when timeout exxceeds it reports a message.
Pgav is transparent to switchovers / failovers, which means that during switchovers / failovers pgav will reconnect to the new primary and unless it takes longer then `timeout` it will not be reported.

The way it works:

- The binary connects to Postgres using Client Connection Failover to find the primary database server
- At first run, pgav creates a table to record last touchpoint
- During an (endless) repeat
  - If needed, pgav reconnects
  - Pgav checks duration since last touchpoint
  - Pgav checks duration since last touchpoint.
    If longer than `--timeout` pgav outputs a critical log message
  - Pgav waits for `--sleeptime` before going into next iteration

## Pgav in PgVillage

Pgav is installed (from rpm) on all database servers and runs as a systemd service.

Pgav uses the following components:

- rpm:
  - source: [github/mannemsolutions/pgav](https://github.com/mannemsolutions/pgav/releases/)
  - name: pgav-v{version}.{architecture}.rpm
  - binary: /usr/bin/pgav
- service:
  - managed by PgVillage
  - file: /etc/systemd/system/pgav@.service (ansible managed)
  - Services:
    - pgav@stolon.service
    - pgav@proxy.service
    - pgav@routerro.service
    - pgav@routerrw.service
- linux user (ansible managed):
  - name: pgav
  - authentication: client certificates (chainsmith/ansible managed)
- table:
  - database: postgres
  - definitie: create table public.pgavailability(last timezone); # Created by pgav
- configfiles:
  - /etc/default/pgav_proxy # configuration for service checking connections through stolon-proxy
  - /etc/default/pgav_stolon # configuration for service checking connections direct to primary
  - /etc/default/pgav_routerro # configuration for service checking connections through load balancer (e.a. haproxy) port 5433
  - /etc/default/pgav_routerrw # configuration for service checking connections through load balancer (e.a. haproxy) port 5432
- connections:
  - Every database server runs these services
  - So for cluster with 4 nodes, stolon-proxy and loadbalancer (e.a. haproxy) a total of 16 services are monitoring availability where 12 are monitoring connections to the primary database instance.
- endpoints
  - stolon: direct connection to primary (Client Connection Failover)
  - proxy: direct connection to stolon-proxy (local) which forwards to primary (rw) database server
  - routerrw
    - connect to loadbalancer (e.a. haproxy) on port 5432
    - loadbalancer to stolon-proxy on a database server
    - stolon-proxy to primary database server
  - routerro
    - connect to loadbalancer (e.a. haproxy) on port 5433
    - loadbalancer to a standby instance (round robin per connection)

# Usage (monitoring and historic analysis)

Pgav logs issues to systemd journal from where any monitoring solution can pick it up for further registration, trend analysis, alerting, etc.
Furthermore, admins can use this logging to analyse any issues experienced from the application.
If (for example) application experiences connectiivity issues, but pgav does not log any issues,
chances are that problems occur within route between application and database server, somewhere before the local database network.

Some examples of issues and how pgav would perceive them:

- If the router has issues, pgav@proxy would suffer, and pgav@stolon would worjk perfectly fine
- If all pgav@ services would work perfectly fine, but the application would still suffer, the issue lies besides PgVillage

## Commands

Checking pgav@ output can easilly be done with journalctl.

Some example commands:

\[root@vmsscluster1_4_fa73 ~\]\# journalctl -efu avchecker@routerro \| head

\-\- Logs begin at Sun 2022-10-16 02:26:36 CEST. --

Oct 1602:38:06 vmsscluster1_4_fa73 avchecker.py\[629825\]: cannot execute UPDATE in a read-only transaction

Oct 1602:38:06 vmsscluster1_4_fa73 avchecker.py\[629825\]: cannot execute UPDATE in a read-only transaction

Oct 1602:38:06 vmsscluster1_4_fa73 avchecker.py\[629825\]: cannot execute UPDATE in a read-only transaction

Oct 1602:38:06 vmsscluster1_4_fa73 avchecker.py\[629825\]: cannot execute UPDATE in a read-only transaction

Oct 1602:38:06 vmsscluster1_4_fa73 avchecker.py\[629825\]: cannot execute UPDATE in a read-only transaction

Oct 1602:52:16 vmsscluster1_4_fa73 avchecker.py\[629825\]: cannot execute UPDATE in a read-only transaction

Oct 1602:52:16 vmsscluster1_4_fa73 avchecker.py\[629825\]: cannot execute UPDATE in a read-only transaction

Oct 1602:52:16 vmsscluster1_4_fa73 avchecker.py\[629825\]: cannot execute UPDATE in a read-only transaction

Oct 1602:52:16 vmsscluster1_4_fa73 avchecker.py\[629825\]: cannot execute UPDATE in a read-only transaction

\[root@vmsscluster1_4_fa73 ~\]\# journalctl -efu avchecker@proxy

\-\- Logs begin at Sun 2022-10-16 02:26:36 CEST. --

Oct 1620:25:28 vmsscluster1_4_fa73 avchecker.py\[629455\]: 0:00:08.314879

^C

\[root@vmsscluster1_4_fa73 ~\]\# journalctl -efu avchecker@stolon

\-\- Logs begin at Sun 2022-10-16 02:26:36 CEST. --

^C

\[root@vmsscluster1_4_fa73 ~\]\# journalctl -efu avchecker@routerrw

\-\- Logs begin at Sun 2022-10-16 02:26:36 CEST. --

^C

## Checks

To check for issues, log in on any of gthe database servers and check output of the journalctl commands.

```

journalctl -efu pgav@proxy
journalctl -efu pgav@stolon
journalctl -efu pgav@routerrw
journalctl -efu pgav@routerro \| head
```
