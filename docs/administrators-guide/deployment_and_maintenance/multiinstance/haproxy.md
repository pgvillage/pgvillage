---
title: HAProxy - multiinstance
summary: A description of configuring HAProxy to proxy ports for multiple PostgreSQL HA clusters
authors:
  - Sebas Mannem
date: 2026-10-11
---

# HAProxy - multi-instance

When deploying multiple HA clusters (e.g. stolon or Patroni), HAProxy needs to forward traffic for all options for all instances.
You can configure them by editing the haproxy config (e.g. `inventories/vagrant/group_vars/all/haproxy.yml`) and define all front-ends and back-ends.
Best is to define a global config first and define front-ends and backends from that.

## Generic settings

| Variable                 | Description                                                        |
|--------------------------|--------------------------------------------------------------------|
| `haproxy_timeout_client` | Client timeout of the frontends and server timeout of the backends (`10800s`). |
| `haproxy_checkport`      | Check port set on the backend servers (`9201`). With `external-check` it is not used to decide health (see note below). |

## `haproxy_config`

Helper dictionary that maps each route type to a backend port (on the database hosts) and a frontend port (on the router):

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
        mode: "{{ haproxy_default_mode }}"
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
| `mode`           | HAProxy mode (`haproxy_default_mode`).                                      |
| `balance_method` | Balance algorithm (`leastconn`).                                            |
| `options`        | HAProxy options (`external-check`).                                         |
| `params`         | Extra parameters, e.g. `external-check command /opt/pgroute66/checkpgprimary.sh`. |
| `timeout_server` | Server timeout.                                                             |
| `servers`        | List of servers with `name`, `address`, `port` and `checkport`.             |

!!! example
    ```yaml
    haproxy_backends:
      - name: "cluster1-ReadWrite-backend"
        mode: "{{ haproxy_default_mode }}"
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

The current inventory only routes `cluster1`. For another instance, add frontends and backends named after
that cluster (e.g. `cluster2-ReadWrite-frontend` / `cluster2-ReadWrite-backend`) with unused frontend ports and the
backend ports of that instance from [`stolon_clusters`](stolon.md).
