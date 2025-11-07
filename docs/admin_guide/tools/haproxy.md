# HAProxy

The PostgreSQL component can optionally be deployed with a PostgreSQL router.

The router consists of a high-availability (HA) setup with two servers, a virtual IP address, and HAProxy together with [PgRoute66](pgroute66.md) running on both nodes.

HAProxy is used to route TCP traffic to the appropriate PostgreSQL server(s), and [PgRoute66](pgroute66.md) is used to direct HAProxy.

## Requirements

On the PostgreSQL router setup, the following components are required for HAProxy to function properly:

- The binary is rolled out using the (standard) haproxy rpm (from Satellite)
- The haproxyconfig can be found in `/etc/haproxy/haproxy.cfg` and is rolled out and managed via Ansible
  - The haproxy config requires some hardcoded config in the Ansible inventory:
    - `haproxy_rw_backends` 
    - `haproxy_ro_backends` 
    located in `environments/{ENV}/group_vars/all/generic.yml`
- HAProxy depends on a properly working [PgRoute66](pgroute66.md)
- The integration between HAProxy and [PgRoute66](pgroute66.md) depends on the following scripts:
  - `/usr/local/bin/checkpgprimary.sh` (Ansible managed)
  - `/usr/local/bin/checkpgstandby.sh` (Ansible managed)

## Troubleshooting

In principle, no management is required for HAProxy and [PgRoute66](pgroute66.md).

For troubleshooting, you can inspect active HAProxy connections using the following command:

```bash
[me@acme-dvppg1pr-server2 ~]$ echo "show stat" | sudo nc -U /var/lib/haproxy/stats | cut -d "," -f 1,2,5,6,18,37 | column -s, -t

pxname                    svname                                 scur  smax  status   check_status
haproxy-stat              FRONTEND                              0     0     OPEN     -
PostgresReadWrite-frontend FRONTEND                              5     135   OPEN     -
PostgresReadOnly-frontend  FRONTEND                              4     8     OPEN     -
PostgresReadWrite-backend  acme-dvppg1db-server1.acme.corp.com   0     0     DOWN     PROCERR
PostgresReadWrite-backend  acme-dvppg1db-server2.acme.corp.com   5     39    UP       PROCOK
PostgresReadWrite-backend  acme-dvppg1db-server3.acme.corp.com   1     1     DOWN     PROCERR
PostgresReadWrite-backend  acme-dvppg1db-server4.acme.corp.com   0     6     DOWN     PROCERR
PostgresReadWrite-backend  BACKEND                              5     135   UP       -
PostgresReadOnly-backend   acme-dvppg1db-server1.acme.corp.com   1     3     UP       PROCOK
PostgresReadOnly-backend   acme-dvppg1db-server2.acme.corp.com   0     4     DOWN     PROCERR
PostgresReadOnly-backend   acme-dvppg1db-server3.acme.corp.com   2     4     UP       PROCOK
PostgresReadOnly-backend   acme-dvppg1db-server4.acme.corp.com   1     5     UP       PROCOK
PostgresReadOnly-backend   BACKEND                              4     8     UP       -
```

From this output, you can conclude that:

- The primary database server `acme-dvppg1db-server2.acme.corp.com` is (UP and PROCOK for PostgresReadWrite-backend)
- Standby databases `acme-dvppg1db-server1.acme.corp.com`, `acme-dvppg1db-server3.acme.corp.com`, and `acme-dvppg1db-server4.acme.corp.com` are (UP and PROCOK for PostgresReadOnly-backend)
- There is not much traffic
  - currently 5/4 connections for RW/RO
  - maximum 135/8 for RW/RO

## All Done

Currently, all traffic is routed only to the primary node, via stolon-proxy on port 25432.

- Technically, this is convenient (no dual hop to a standby and then on to the primary)
- During switchover/failover, this means that the traffic will always come out at the primary
- However, this makes stolon-proxy on the primary node into a Single Point of Failure

