---
title: HAProxy
summary: A description of HAProxy, to properly load balance and forward RW and RO connections
authors:
  - Sebas Mannem
  - Snehal Kapure
date: 2025-11-11
---

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
[me@gurus-pgspr-server2 ~]$ echo "show stat" | sudo nc -U /var/lib/haproxy/stats | cut -d "," -f 1,2,5,6,18,37 | column -s, -t

pxname                    svname                                 scur  smax  status   check_status
haproxy-stat              FRONTEND                              0     0     OPEN     -
PostgresReadWrite-frontend FRONTEND                              5     135   OPEN     -
PostgresReadOnly-frontend  FRONTEND                              4     8     OPEN     -
PostgresReadWrite-backend  gurus-pgsdb-server1.acme.corp.com   0     0     DOWN     PROCERR
PostgresReadWrite-backend  gurus-pgsdb-server2.acme.corp.com   5     39    UP       PROCOK
PostgresReadWrite-backend  gurus-pgsdb-server3.acme.corp.com   1     1     DOWN     PROCERR
PostgresReadWrite-backend  gurus-pgsdb-server4.acme.corp.com   0     6     DOWN     PROCERR
PostgresReadWrite-backend  BACKEND                              5     135   UP       -
PostgresReadOnly-backend   gurus-pgsdb-server1.acme.corp.com   1     3     UP       PROCOK
PostgresReadOnly-backend   gurus-pgsdb-server2.acme.corp.com   0     4     DOWN     PROCERR
PostgresReadOnly-backend   gurus-pgsdb-server3.acme.corp.com   2     4     UP       PROCOK
PostgresReadOnly-backend   gurus-pgsdb-server4.acme.corp.com   1     5     UP       PROCOK
PostgresReadOnly-backend   BACKEND                              4     8     UP       -
```

From this output, you can conclude that:

- The primary database server `gurus-pgsdb-server2.acme.corp.com` is (UP and PROCOK for PostgresReadWrite-backend)
- Standby databases `gurus-pgsdb-server1.acme.corp.com`, `gurus-pgsdb-server3.acme.corp.com`, and `gurus-pgsdb-server4.acme.corp.com` are (UP and PROCOK for PostgresReadOnly-backend)
- There is not much traffic
  - currently 5/4 connections for RW/RO
  - maximum 135/8 for RW/RO

## Multi-instance

How to configure this for several clusters on the same hosts. See [Multi-instance](../administrators-guide/deployment_and_maintenance/multi-instance.md)
for the feature, and the [defaults](https://github.com/pgvillage/ansible-role-haproxy/blob/main/defaults/main.yml) of the role for all its variables.

When deploying multiple HA clusters (e.g. stolon or Patroni), HAProxy needs to forward traffic for all options for all instances.
The standard inventory (`inventories/standard/group_vars/all/haproxy.yml`) generates them: for every cluster in
[`stolon_clusters`](stolon.md#multi-instance) a read-write, a read-only and a stolon proxy route (`haproxy_routes`), each with a
frontend on the router and a backend with the database hosts (`hacluster`) as servers. Adding a cluster to
`stolon_clusters` adds its routes, and the firewall opens their ports (`firewall_ports_router`, see
[firewall](firewall.md#multi-instance)). The platform inventory only adds the router hosts (the `router` and `haproxy` groups) and the
keepalived VIP.

The frontend port is `port_prefix * 10000 + <Postgres port>`:

| Cluster    | Postgres | read-write (`rw`) | read-only (`ro`) | stolon proxy (`proxy`) |
|------------|----------|-------------------|------------------|------------------------|
| `cluster1` | 5433     | 35433             | 45433            | 55433                  |
| `cluster2` | 5434     | 35434             | 45434            | 55434                  |

To change the routes, override `haproxy_routes`; to set everything by hand, override `haproxy_config`,
`haproxy_frontends` and `haproxy_backends` as described below.

### `haproxy_routes`

| Key           | Description |
|---------------|-------------|
| `name`        | Route name in the frontend and backend names (`ReadWrite`, `ReadOnly`, `Proxy`). |
| `port_prefix` | Frontend port: `port_prefix * 10000 + <Postgres port>` (3, 4 and 5). |
| `backend`     | `pg`: the Postgres port of the keepers, `proxy`: the stolon proxy port. |
| `check`       | pgroute66 check script that decides which servers get traffic. |

### Generic settings

| Variable                 | Description                                                        |
|--------------------------|--------------------------------------------------------------------|
| `haproxy_timeout_client` | Client timeout of the frontends and server timeout of the backends (`10800s`). |
| `haproxy_checkport`      | Check port set on the backend servers (`9201`). With `external-check` it is not used to decide health (see note below). |

### `haproxy_config`

Generated from `stolon_clusters` and `haproxy_routes`: per cluster and route, the backend port (on the database hosts)
and the frontend port (on the router), e.g.:

!!! example
    ```yaml
    haproxy_config:
      cluster1:
        rw:
          backend_port: "{{ stolon_clusters.cluster1.sysconfig.stkeeper.pg_port }}"
          frontend_port: 35433
        proxy:
          backend_port: "{{ stolon_clusters.cluster1.sysconfig.stproxy.port }}"
          frontend_port: 55433
        ro:
          backend_port: "{{ stolon_clusters.cluster1.sysconfig.stkeeper.pg_port }}"
          frontend_port: 45433
    ```

| Route       | Backend                      | Health check                           |
|-------------|------------------------------|----------------------------------------|
| `rw`        | Postgres port of the keeper  | `/opt/pgroute66/checkpgprimary.sh`      |
| `ro`        | Postgres port of the keeper  | `/opt/pgroute66/checkpgstandby.sh`      |
| `proxy`     | stolon proxy port            | `/opt/pgroute66/checkpgprimary.sh`      |

!!! note
    You can define other config and/or use other naming instead of rw, proxy and ro.

### `haproxy_frontends`

List of frontends. Each entry has `name`, `address`, `port`, `mode`, `backend` and `timeout_client`.

Frontend names follow the pattern `<cluster>-<Route>-frontend` (e.g. `cluster1-ReadWrite-frontend`) to keep them
aligned with the backends.

!!! example
    ```yaml
    haproxy_frontends:
      - name: "cluster1-ReadWrite-frontend"
        address: "*"
        port: "{{ haproxy_config.cluster1.rw.frontend_port }}"
        mode: "{{ haproxy_mode }}"
        backend: "cluster1-ReadWrite-backend"
        timeout_client: "{{ haproxy_timeout_client }}"
    ```

!!! note
    Define a separate frontend (and backend) for every route of every cluster in `haproxy_config`

### `haproxy_backends`

List of backends, named `<cluster>-<Route>-backend`.

The backend `name` determines the cluster: the check scripts use `HAPROXY_PROXY_NAME` (the backend name) and strip
everything after the first dash to get the cluster name they query pgroute66 for. Therefore:

- the backend name must start with `<cluster>-`, where `<cluster>` is a key in [`pgroute66_clusters`](pgroute66.md#multi-instance),
  and the cluster name itself must not contain a dash;
- the server `name` must equal the host name pgroute66 returns (the inventory hostname, e.g. `db-1.local`).

| Key              | Description                                                                 |
|------------------|-----------------------------------------------------------------------------|
| `name`           | Backend name, referenced by `backend` in the frontend.                      |
| `mode`           | HAProxy mode (`haproxy_mode`).                                      |
| `balance_method` | Balance algorithm (`leastconn`).                                            |
| `options`        | HAProxy options (`external-check`).                                         |
| `params`         | Extra parameters, e.g. `external-check command /opt/pgroute66/checkpgprimary.sh`. |
| `timeout_server` | Server timeout.                                                             |
| `servers`        | List of servers with `name`, `address`, `port` and `checkport`.             |

!!! example
    ```yaml
    haproxy_backends:
      - name: "cluster1-ReadWrite-backend"
        mode: "{{ haproxy_mode }}"
        balance_method: "leastconn"
        options:
          - "external-check"
        params:
          - "external-check command  /opt/pgroute66/checkpgprimary.sh"
        timeout_server: "{{ haproxy_timeout_client }}"
        servers:
          - name: "db-1.local"
            address: "172.30.1.31"
            port: "{{ haproxy_config.cluster1.rw.backend_port }}"
            checkport: "{{ haproxy_checkport }}"
          # db-2.local, db-3.local ...
    ```

!!! note
    With `external-check`, HAProxy does not run a TCP check against `checkport`. Health is decided by the check script,
    which asks pgroute66 whether the server (by `name`) is the primary or a standby of the cluster (by backend name).
    Therefore `checkport` does not need to be opened in the [firewall](firewall.md#multi-instance) of the database hosts.

    Do not replace the external check with a plain TCP check on the Postgres port (e.g. `5432`): a TCP check only
    proves Postgres accepts connections, so standbys would pass too and read-write traffic could be sent to a standby.
    In a multiinstance setup, nothing listens on `5432` anyway (instances use e.g. `5433` and `5434`).

### Adding an instance

Add the cluster to `stolon_clusters`: HAProxy gets its frontends and backends, pgroute66 its group, and the firewall
the frontend ports. The frontend ports follow from the Postgres port of the new cluster.

## All Done

Currently, all traffic is routed only to the primary node, via stolon-proxy on port 25432.

- Technically, this is convenient (no dual hop to a standby and then on to the primary)
- During switchover/failover, this means that the traffic will always come out at the primary
- However, this makes stolon-proxy on the primary node into a Single Point of Failure
