---
title: Pgroute66 - multiinstance
summary: A description of configuring pgroute66 to support forwarding to multiple cluster instances
authors:
  - Sebas Mannem
date: 2026-10-11
---

# pgroute66 - multi-instance

Pgroute66 allows for defining clusters of instances, and as of release v0.8.28, we have an option to have one instance of pgroute66 manage multiple clusters.
To define multiple clusters in pgroute66, you can configure `pgroute66_clusters` in your inventory (e.g. `inventories/vagrant/group_vars/all/pgroute66.yml`).

When properly defined, pgroute66 can be queried by haproxy with the scripts
- `checkpgprimary.sh` (to find the primary)
- `checkpgstandby.sh` (to find the standbys)

See [haproxy.md](haproxy.md) for more info on configuring the scripts in the backends.

## Settings

### Generic settings

The pgroute66 role uses the following settings:

| Variable                  | Description                                                                     |
|---------------------------|---------------------------------------------------------------------------------|
| `pgroute66_pgport`        | Default Postgres port (role default `5432`), used when a cluster does not set `pgport`. |
| `pgroute66_pgnodes_group` | Inventory group that holds the database hosts (`hacluster`).                     |
| `pgroute66_clusters`      | Dictionary with one entry per cluster; `pgport` is the Postgres port of that cluster. |
| `pgroute66_config`        | Configuration file contents of pgroute66, generated from the settings above.     |

### Overlays per cluster

You can set cluster specific values in `pgroute66_clusters`.

!!! example
    ```yaml
    pgroute66_clusters:
      cluster1:
        pgport: 5433
      cluster2:
        pgport: 5434
    ```

!!! note
    The keys must match the keys in [`stolon_clusters`](stolon.md) and the `<cluster>` prefix of the HAProxy backend names.
    `pgport` must match `stolon_clusters.<cluster>.sysconfig.stkeeper.pg_port`.

## Resulting config on servers

The Ansible role generates a yaml file with pgroute66 config with the following layout:

| Key         | Description                                                                      |
|-------------|----------------------------------------------------------------------------------|
| `groups`    | Generated: for every cluster in `pgroute66_clusters`, every host in `pgroute66_pgnodes_group` with `host`, `port` (the cluster's `pgport`) and `dbname` (`pgroute66_dbname`). |
| `loglevel`  | `{{ pgroute66_loglevel }}`                                                       |
| `verbosity` | `{{ pgroute66_verbosity }}`                                                      |
| `bind`      | `{{ pgroute66_bind }}`                                                           |
| `port`      | `{{ pgroute66_port }}`                                                           |

!!! example
    ```yaml
    groups:
      cluster1:
        db-1.local: {host: db-1.local, port: 5433, dbname: <pgroute66_dbname>}
        db-2.local: {host: db-2.local, port: 5433, dbname: <pgroute66_dbname>}
        db-3.local: {host: db-3.local, port: 5433, dbname: <pgroute66_dbname>}
      cluster2:
        db-1.local: {host: db-1.local, port: 5434, dbname: <pgroute66_dbname>}
        # ...
    ```
