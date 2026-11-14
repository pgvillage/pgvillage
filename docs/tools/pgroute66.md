---
title: PgRoute66
summary: A description of PgRoute66 which can be used to control where HAProxy outes traffic
authors:
  - Sebas Mannem
  - Snehal Kapure
date: 2025-11-11
---

# PgRoute66

The PostgreSQL building block can optionally be executed with a PostgreSQL router.

The router consists of a HA setup with 2 servers, each having a Virtual IP address and running [HAProxy](haproxy.md) and PgRoute66 on both nodes.

HAProxy is used to route TCP traffic to the correct PostgreSQL server(s), and PgRoute66 is used to control HAProxy.
[HAProxy](haproxy.md).

Pgroute66 is an open-source project and is maintained by the community.

- [rpmbuilder Releases on GitHub](https://github.com/pgvillage-build/rpmbuilder)
- [pgvillage Repository](https://github.com/pgvillage/pgvillage/releases)

## Requirements

For the PostgreSQL router setup, the following components are required for PgRoute66 to function correctly:

- The binary is deployed via the **depgroute66** RPM (from Satellite).
- The PgRoute66 configuration file is located at:  
  `/etc/pgroute66/config.yaml`  
  and is deployed and managed through **Ansible**.
- The PgRoute66 service file can be found at:  
  `/etc/systemd/system/pgroute66.service`  
  and is also deployed and managed through **Ansible**.
- PgRoute66 runs under the **pgroute66** Linux user, which is deployed and managed through **Ansible**.
- PgRoute66 uses **mTLS** for PostgreSQL connections through:
  - a client certificate and key (deployed and managed through Ansible)
  - a root certificate to verify the server certificate (deployed and managed through Ansible)
  - all three located in `~pgroute66/.postgresql/`

---

## Use

PgRoute66 runs as a service and does not require any manual actions.

For troubleshooting, check the service logs:

---

```bash
[me@gurus-pgspr-server2 ~] $ sudo journalctl -efu pgroute66.service

-- Logs begin at Thu 2022-10-13 02:09:58 CEST.
Oct 13 22:29:19 gurus-pgspr-server2 pgroute66[1608249]: [GIN] 2022/10/13 - 22:29:19 | 200 | 1.780668ms | 127.0.0.1 | GET "/v1/standbys"
Oct 13 22:29:19 gurus-pgspr-server2 pgroute66[1608249]: [GIN] 2022/10/13 - 22:29:19 | 200 | 1.951384ms | 127.0.0.1 | GET "/v1/primary"
Oct 13 22:29:21 gurus-pgspr-server2 pgroute66[1608249]: [GIN] 2022/10/13 - 22:29:21 | 200 | 1.812061ms | 127.0.0.1 | GET "/v1/primary"
Oct 13 22:29:19 gurus-pgspr-server2 pgroute66[1608249]: [GIN] 2022/10/13 - 22:29:19 | 200 | 1.986874ms | 127.0.0.1 | GET "/v1/standbys"
Oct 13 22:29:20 gurus-pgspr-server2 pgroute66[1608249]: [GIN]2022/10/13 - 22:29:20 | 200 | 1.917752ms |   127.0.0.1 | GET "/v1/standbys"
Oct 13 22:29:20 gurus-pgspr-server2 pgroute66[1608249]: [GIN]2022/10/13 - 22:29:20 | 200 | 1.69516ms |     127.0.0.1 | GET "/v1/primary"
Oct 13 22:29:21 gurus-pgspr-server2 pgroute66[1608249]: [GIN]2022/10/13 - 22:29:21 | 200 | 1.957809ms |   127.0.0.1 | GET "/v1/standbys"
Oct 13 22:29:21 gurus-pgspr-server2 pgroute66[1608249]: [GIN]2022/10/13 - 22:29:21 | 200 | 1.812061ms |   127.0.0.1 | GET  "/v1/primary"
Oct 13 22:29:21 gurus-pgspr-server2 pgroute66[1608249]: [GIN]2022/10/13 - 22:29:21 | 200 | 1.606772ms |  127.0.0.1 | GET "/v1/standbys"
```

If necessary, the logging can also be temporarily increased by raising the log level to debug in the config file:

```bash
[me@gurus-pgspr-server2 ~]$ vim /etc/pgroute66/config.yaml

[me@gurus-pgspr-server2 ~]$ grep loglevel /etc/pgroute66/config.yaml

loglevel: develop

[me@gurus-pgspr-server2 ~]$ systemctl restart pgroute66.service
```

!!! note

    HAProxy and PgRoute66 are loosely coupled, and a successful restart of the pgroute66 has no impact on the availability of the service.

---

## Multi-instance

How to configure this for several clusters on the same hosts. See [Multi-instance](../administrators-guide/deployment_and_maintenance/multi-instance.md)
for the feature, and the [defaults](https://github.com/pgvillage/ansible-role-pgroute66/blob/main/defaults/main.yml) of the role for all its variables.

Pgroute66 allows for defining clusters of instances, and as of release v0.8.28, we have an option to have one instance of pgroute66 manage multiple clusters.
To define multiple clusters in pgroute66, you can configure `pgroute66_clusters` in your inventory. `inventories/standard/group_vars/all/pgroute66.yml` builds it from `stolon_clusters` (every cluster with its Postgres port), so a new cluster in `stolon_clusters` is added automatically.

When properly defined, pgroute66 can be queried by haproxy with the scripts
- `checkpgprimary.sh` (to find the primary)
- `checkpgstandby.sh` (to find the standbys)

See [haproxy.md](haproxy.md#multi-instance) for more info on configuring the scripts in the backends.

### Settings

#### Generic settings

The pgroute66 role uses the following settings:

| Variable                  | Description                                                                     |
|---------------------------|---------------------------------------------------------------------------------|
| `pgroute66_pgport`        | Default Postgres port (role default `5432`), used when a cluster does not set `pgport`. |
| `pgroute66_pgnodes_group` | Inventory group that holds the database hosts (`hacluster`).                     |
| `pgroute66_clusters`      | Dictionary with one entry per cluster; `pgport` is the Postgres port of that cluster. |
| `pgroute66_config`        | Configuration file contents of pgroute66, generated from the settings above.     |

#### Overlays per cluster

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
    The keys must match the keys in [`stolon_clusters`](stolon.md#multi-instance) and the `<cluster>` prefix of the HAProxy backend names.
    `pgport` must match `stolon_clusters.<cluster>.sysconfig.stkeeper.pg_port`.

### Resulting config on servers

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

## ToDo

PgRoute66 could be enhanced to detect the primary database based on Stolon configuration in etcd.

In that case, PgRoute66 can run on the database server along with it and HAProxy can be used without the `external-check` and `insecure-fork-wanted` options.
