---
title: HAProxy - multiinstance
summary: A description of configuring HAProxy to proxy ports for multiple PostgreSQL HA clusters
authors:
  - Sebas Mannem
date: 2026-10-11
---

# HAProxy - multi-instance

When deploying multiple HA clusters (e.g. stolon or Patroni), HAProxy needs to forward traffic for all options for all instances.
The standard inventory (`inventories/standard/group_vars/all/haproxy.yml`) generates them: for every cluster in
[`stolon_clusters`](stolon.md) a read-write, a read-only and a stolon proxy route (`haproxy_routes`), each with a
frontend on the router and a backend with the database hosts (`hacluster`) as servers. Adding a cluster to
`stolon_clusters` adds its routes, and the firewall opens their ports (`firewall_ports_router`, see
[firewall](firewall.md)). The platform inventory only adds the router hosts (the `router` and `haproxy` groups) and the
keepalived VIP.

The frontend port is `port_prefix * 10000 + <Postgres port>`:

| Cluster    | Postgres | read-write (`rw`) | read-only (`ro`) | stolon proxy (`proxy`) |
|------------|----------|-------------------|------------------|------------------------|
| `cluster1` | 5433     | 35433             | 45433            | 55433                  |
| `cluster2` | 5434     | 35434             | 45434            | 55434                  |

To change the routes, override `haproxy_routes`; to set everything by hand, override `haproxy_config`,
`haproxy_frontends` and `haproxy_backends` as described below.

## `haproxy_routes`

| Key           | Description |
|---------------|-------------|
| `name`        | Route name in the frontend and backend names (`ReadWrite`, `ReadOnly`, `Proxy`). |
| `port_prefix` | Frontend port: `port_prefix * 10000 + <Postgres port>` (3, 4 and 5). |
| `backend`     | `pg`: the Postgres port of the keepers, `proxy`: the stolon proxy port. |
| `check`       | pgroute66 check script that decides which servers get traffic. |

## Generic settings

| Variable                 | Description                                                        |
|--------------------------|--------------------------------------------------------------------|
| `haproxy_timeout_client` | Client timeout of the frontends and server timeout of the backends (`10800s`). |
| `haproxy_checkport`      | Check port set on the backend servers (`9201`). With `external-check` it is not used to decide health (see note below). |

## `haproxy_config`

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

## `haproxy_frontends`

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

## `haproxy_backends`

List of backends, named `<cluster>-<Route>-backend`.

The backend `name` determines the cluster: the check scripts use `HAPROXY_PROXY_NAME` (the backend name) and strip
everything after the first dash to get the cluster name they query pgroute66 for. Therefore:

- the backend name must start with `<cluster>-`, where `<cluster>` is a key in [`pgroute66_clusters`](pgroute66.md),
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
    Therefore `checkport` does not need to be opened in the [firewall](firewall.md) of the database hosts.

    Do not replace the external check with a plain TCP check on the Postgres port (e.g. `5432`): a TCP check only
    proves Postgres accepts connections, so standbys would pass too and read-write traffic could be sent to a standby.
    In a multiinstance setup, nothing listens on `5432` anyway (instances use e.g. `5433` and `5434`).

## Adding an instance

Add the cluster to `stolon_clusters`: HAProxy gets its frontends and backends, pgroute66 its group, and the firewall
the frontend ports. The frontend ports follow from the Postgres port of the new cluster.
