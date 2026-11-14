---
title: Multi-instance
summary: Several PostgreSQL clusters on the same hosts, each with its own ports, disks, bucket, PgBouncer and routes
---

# Multi-instance

PgVillage can run several PostgreSQL clusters side by side on the same database hosts. Every cluster is a stolon
cluster of its own (sentinel, keeper and proxy services, a primary and standbys), with its own:

- **ports**: PostgreSQL, the stolon proxy, PgBouncer, and the routes of HAProxy on the router;
- **disks**: a data and a wal directory per cluster, preferably on their own disks (see [Disks](byo.md#disks));
- **backups**: its own wal-g configuration and cron job, and its own bucket on the backup host;
- **resources**: systemd resource control (cgroups) per keeper, so one cluster can't starve the others;
- **checks and jobs**: avchecker and PgQuartz per cluster.

etcd, the backup host, the router hosts and the certificates are shared by all clusters.

## The standard inventory

`inventories/standard` is multi-instance: it runs `cluster1` and `cluster2`.

| Cluster    | PostgreSQL | stolon proxy | PgBouncer | Router (read-write / read-only / proxy) | Bucket     |
|------------|------------|--------------|-----------|-----------------------------------------|------------|
| `cluster1` | 5433       | 25433        | 6433      | 35433 / 45433 / 55433                   | `cluster1` |
| `cluster2` | 5434       | 25434        | 6434      | 35434 / 45434 / 55434                   | `cluster2` |

The data of a cluster is in `<data mountpoint>/<cluster>`, its wal in `<wal mountpoint>/stolon/<cluster>/wal`.

`stolon_clusters` is the list of clusters. Standard derives the HAProxy routes, the pgroute66 groups and the PgQuartz
jobs from it, so they follow when you add a cluster. The other settings are per cluster too, and must agree with each
other (same cluster name, same ports).

## Add or remove a cluster

Change these variables in your own inventory (see [Inventory explained](inventory/index.md)); each tool page explains its
setting:

| What                          | Variable                               | See |
|-------------------------------|----------------------------------------|-----|
| The cluster, its ports and directories | `stolon_clusters`             | [stolon](../tools/stolon.md#multi-instance) |
| Its backups                   | `walg_clusters`                        | [wal-g](../tools/wal-g.md#multi-instance) |
| Its bucket                    | `minio_buckets`                        | [MinIO](../tools/minio.md#multi-instance) |
| Its PgBouncer                 | `pgbouncer_instances`                  | [PgBouncer](../tools/pgbouncer.md#multi-instance) |
| Its ports in the firewall     | `firewall_ports_hacluster`, `firewall_ports_router` | [Firewall](../tools/firewall.md#multi-instance) |
| Its availability checks       | `avchecker_cluster_members`, `avchecker_defaults` | [avchecker](../tools/avchecker.md#multi-instance) |
| Its routes (generated)        | `haproxy_routes`, `haproxy_config`     | [HAProxy](../tools/haproxy.md#multi-instance) |
| Its pgroute66 group (generated) | `pgroute66_clusters`                 | [pgroute66](../tools/pgroute66.md#multi-instance) |
| Its PgQuartz jobs (generated) | `pgquartz_instances`                   | [PgQuartz](../tools/pgquartz.md#multi-instance) |
| Nagios                        | `nagios_enabled`                       | [Nagios](../tools/nagios.md#multi-instance) |

Keep the ports unique per host. A cluster name must not contain a dash: HAProxy's check scripts take the cluster name
from the backend name up to the first dash.
