---
title: Stolon - multiinstance
summary: A description of configuring stolon to deploy and manage multiple PostgreSQL clusters
authors:
  - Sebas Mannem
date: 2026-10-11
---

# Stolon - multi-instance

PostgreSQL can be deployed multi-instance, which means that multiple PostgreSQL processes are running separately next to each other.
To separate resources, one can run them as multiple systemd services and manage them with cgroups.
To separate disk space, one can specify data directories and WAL directories on separate filesystems.
There are other options, but this is the way the stolon role deploys multiple clusters on (virtual or physical) servers.

To configure stolon to deploy and maintain multiple clusters, edit the stolon config (e.g. `environments/cluster1/group_vars/all/stolon.yml`) and configure separate `stolon_clusters`.
There are 3 main chapters, and for all three the configuration can set defaults (used for all clusters),
which can be overridden by cluster specific values (in `stolon_clusters`):

- Defaults in `stolon_default_sysconfig` can be overridden in `stolon_clusters[clustername].sysconfig`
- Defaults in `stolon_default_custom_config` can be overridden in `stolon_clusters[clustername].custom_config`
- Defaults in `stolon_default_cgroups` can be overridden in `stolon_clusters[clustername].cgroups`

## `stolon_clusters`

Dictionary with one entry per stolon cluster (Postgres instance) running on the hosts in `stolon_host_group`.
The key is the cluster name. For every entry separate sentinel, keeper and proxy services are deployed.

## SYSCONFIG

Stolon primarily works with environment variables set by systemd when starting the services.
Defaults can be set in `stolon_default_sysconfig`, per cluster they can be overridden in `stolon_clusters[clustername].sysconfig`
The settings can be set for all 3 components of stolon (`keeper`, `proxy`, and `sentinel`).
You can set the following options:

### Keeper
Settings written to the sysconfig (environment) files of the stolon services of that instance.

| Key                           | Description                                                                     |
|-------------------------------|---------------------------------------------------------------------------------|
| `stkeeper.cluster_name`       | Stolon cluster name used by the keeper.                                         |
| `stkeeper.pg_port`            | Port Postgres listens on. Must be unique per host.                               |
| `stkeeper.data_dir`           | Keeper data directory for this instance.                                        |
| `stkeeper.pgdata_dir`         | PGDATA of the instance (usually `<data_dir>/postgres`).                          |
| `stkeeper.wal_dir`            | Keeper WAL directory for this instance.                                         |
| `stkeeper.pgwal_dir`          | Postgres WAL directory (pg_wal) for this instance.                              |

### Proxy
Settings written to the sysconfig (environment) files of the stolon services of that instance.

| Key                           | Description                                                                     |
|-------------------------------|---------------------------------------------------------------------------------|
| `stproxy.cluster_name`        | Stolon cluster name used by the proxy.                                          |
| `stproxy.port`                | Port the stolon proxy listens on. Must be unique per host.                       |

### Sentinel
Settings written to the sysconfig (environment) files of the stolon services of that instance.

| Key                           | Description                                                                     |
|-------------------------------|---------------------------------------------------------------------------------|
| `stsentinel.cluster_name`     | Stolon cluster name used by the sentinel.                                       |

## Stolon config

Stolon allows for setting cluster config in etcd, managed by stolon on a cluster wide level.

### PostgreSQL settings

PostgreSQL settings (`postgresql.conf`) can be defaulted in `stolon_default_custom_config.pgParameters`
and overruled per cluster in `stolon_clusters[clustername].custom_config.pgParameters`.

All PostgreSQL settings can be configured, but some are crucial to be properly set to a specific value for proper working of replication and other cluster options.
Stolon overrules them when required. Please see [postgresqlco.nf](https://postgresqlco.nf/) for all available settings

In our examples, we have set the following options:

| Key                                  | Description                                                        |
|--------------------------------------|--------------------------------------------------------------------|
| `pgParameters.log_directory`         | Postgres log directory, typically `{{ stolon_pg_log_directory }}/<name>`. |
| `pgParameters.archive_command`       | Instance aware wal-g archive command, e.g. `/opt/wal-g/scripts/archive.sh <name> %p`. |

### pgHBA

Stolon manages HBA rules, and allows administrators to set certain HBA rules.
The HBA rules can be added to `stolon_clusters[clustername].custom_config.pgHBA`.

### Example

!!! example
    ```yaml
    stolon_clusters:
      cluster1:
        custom_config:
          pgParameters:
            log_directory: "{{ stolon_pg_log_directory }}/cluster1"
    ```


## CGROUPS

systemd resource control settings applied to every stolon instance (keeper) by default.
Keys are systemd resource control directives (see `man systemd.resource-control`).

### Example

!!! example
    ```yaml
    stolon_default_cgroups:
      CPUQuota: 100%
      MemoryHigh: 8G
    ```

Use this to prevent one instance from starving the other instances on the same host.
You can set specific settings in `stolon_clusters[clustername].cgroups`.

## Example

!!! example
    ```yaml
    stolon_clusters:
      cluster1:
        cgroups:
          CPUQuota: 200%
        sysconfig:
          stsentinel:
            cluster_name: cluster1
          stkeeper:
            cluster_name: cluster1
            pg_port: 5433
            data_dir: "{{ postgresql_data_mountpoint }}/cluster1"
            pgdata_dir: "{{ postgresql_data_mountpoint }}/cluster1/postgres"
            wal_dir: "{{ stolon_wal_dir }}/cluster1"
            pgwal_dir: "{{ stolon_wal_dir }}/cluster1"
          stproxy:
            cluster_name: cluster1
            port: 25433
        custom_config:
          pgParameters:
            log_directory: "{{ stolon_pg_log_directory }}/cluster1"
          pgHBA:
            - "hostssl db1 user1 1.2.3.4/32 scram-sha-256"
      cluster2:
        sysconfig:
          stsentinel:
            cluster_name: cluster2
          stkeeper:
            cluster_name: cluster2
            pg_port: 5434
            data_dir: "{{ postgresql_data_mountpoint }}/cluster2"
            pgdata_dir: "{{ postgresql_data_mountpoint }}/cluster2/postgres"
            wal_dir: "{{ stolon_wal_dir }}/cluster2"
            pgwal_dir: "{{ stolon_wal_dir }}/cluster2"
          stproxy:
            cluster_name: cluster2
            port: 25434
        custom_config:
          pgParameters:
            log_directory: "{{ stolon_pg_log_directory }}/cluster2"
          pgHBA:
            - "hostssl db2 user2 5.6.7.8/32 scram-sha-256"
    ```

## Comments

- `pg_port` and `stproxy.port` must be unique per host and opened in [`firewall_ports`](firewall.md).
- `pgdata_dir` and `pg_port` must match the corresponding entry in [`walg_clusters`](walg.md).
- The cluster name should match a bucket in [`minio_buckets`](minio.md).
