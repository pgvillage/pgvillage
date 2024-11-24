# Introduction

De PostgreSQL bouwsteen kan eventueel worden uitgevoerd met een PostgreSQL router.

The router consists of a HA setup with 2 servers, a Virtual IP address, and an HAProxy along with [PgRoute66](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/PgRoute66/WebHome.html) on both nodes.

HAProxy is used to route TCP traffic to the appropriate PostgreSQL server(s), and [PgRoute66](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/PgRoute66/WebHome.html) is used to direct HAProxy.

# Requirements

Op de PostgreSQL router setup zijn de volgende dingen nodig om HAProxy te laten functioneren:

- The binary is rolled out using the (standard) haproxy rpm (from Satellite)
- The haproxyconfig can be found in `/etc/haproxy/haproxy.cfg` and is rolled out and managed via Ansible
  - The haproxy config requires some hardcoded config in the Ansible inventory (namely `haproxy_rw_backends` and `haproxy_ro_backends` in `environments/{ENV}/group_vars/all/generic.yml`.
- HAProxy depends on a properly working [PgRoute66](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/PgRoute66/WebHome.html)
- The integration between HAProxy and [PgRoute66](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/PgRoute66/WebHome.html) depends on the following scripts:
  - `/usr/local/bin/checkpgprimary.sh` (Ansible managed)
  - `/usr/local/bin/checkpgstandby.sh` (Ansible managed)

# Troubleshooting

In principle, no management is required for HAProxy and [PgRoute66](../../../../../../../../pages/xwiki/Infrastructuur/Team%3A+DBA/Werkinstrukties/Postgres/Bouwsteen/PgRoute66/WebHome.html).

Voor troubleshooting kan het handig zijn om de connecties die HAProxy routeert inzichtelijk te maken middels het volgende commando:

```markdown
[me@acme-dvppg1pr-server2 ~]$ echo "show stat" | sudo nc -U /var/lib/haproxy/stats | cut -d "," -f 1,2,5,6,18,37 | column -s, -t
```

```markdown
# pxname               svname                                                                                           scur  smax status check_status
```

```
haproxy-stat                FRONTEND                               00     OPEN
```

```
PostgresReadWrite-frontend FRONTEND             5135 OPEN
```

```
PostgresReadOnly-frontend   FRONTEND                               48     OPEN
```

```markdown
PostgresReadWrite-backend   acme-dvppg1db-server1.acme.corp.com 00   DOWN   PROCERR
```

```
PostgresReadWrite-backend acme-dvppg1db-server2.acme.corp.com 539 UP PROCOK
```

PostgresReadWrite-backend acme-dvppg1db-server3.acme.corp.com 0101 DOWN PROCERR  
```

```
PostgresReadWrite-backend   acme-dvppg1db-server4.acme.corp.com 06   DOWN PROCERR
```

```
PostgresReadWrite-backend   BACKEND                               5135   UP
```

```
PostgresReadOnly-backend   acme-dvppg1db-server1.acme.corp.com 13     UP       PROCOK
```

```markdown
PostgresReadOnly-backend    acme-dvppg1db-server2.acme.corp.com  04   DOWN   PROCERR
```

```
PostgresReadOnly-backend   acme-dvppg1db-server3.acme.corp.com 24   UP   PROCOK
```

```markdown
PostgresReadOnly-backend acme-dvppg1db-server4.acme.corp.com 15 UP PROCOK
```

```markdown
PostgresReadOnly-backend    BACKEND                                48     UP
```

What you can conclude from this is that:

- The primary database server `acme-dvppg1db-server2.acme.corp.com` is (UP and PROCOK for PostgresReadWrite-backend)
- Standby databases `acme-dvppg1db-server1.acme.corp.com`, `acme-dvppg1db-server3.acme.corp.com`, and `acme-dvppg1db-server4.acme.corp.com` are (UP and PROCOK for PostgresReadOnly-backend)
- There is not much traffic
  - currently 5/4 connections for RW/RO
  - maximum 135/8 for RW/RO

# All Done

Momenteel wordt al het verkeer doorgestuurd naar alleen de primary node, naar stolon-proxy (25432).

- Technically, this is convenient (no dual hop to a standby and then on to the primary)
- During switchover/failover, this means that the traffic will always come out at the primary
- However, this makes stolon-proxy on the primary node into a Single Point of Failure

