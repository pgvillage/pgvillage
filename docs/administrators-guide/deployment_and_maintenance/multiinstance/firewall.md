---
title: firewall - multiinstance
summary: A description of configuring firewall to allow traffic for ports for multiple PostgreSQL HA clusters
authors:
  - Sebas Mannem
date: 2026-10-11
---

# firewall - multiinstance

When deploying multiple HA clusters (e.g. stolon or Patroni), firewalld needs to allow traffic to the ports of all components of all clusters.
In the standard inventory (`inventories/standard/group_vars/all/firewall.yml`) you define the ports per inventory group:
`firewall_ports_hacluster`, `firewall_ports_backup` and `firewall_ports_router`. `firewall_ports`, which the firewall
role opens, combines the ports of the groups a host is in. That way a host in several groups (e.g. the router on the
database hosts) gets the ports of all of them: `firewall_ports` set in the group_vars of two groups would replace each
other instead of adding up.

VRRP (keepalived) is not a port: the keepalived role allows it in firewalld (`keepalived_firewall_vrrp`).

## Example

### Combined

When combining router and postgres on the same hosts, they are in both `hacluster` and `router`, and get the ports of
both (see [Postgres](#postgres) and [Router](#router)). You can also put all ports in one group:

!!! example
    ```yaml
    firewall_ports_hacluster:

      cluster1_postgres:     5433
      cluster1_pgbouncer:    6433
      cluster1_stolonproxy: 25433
      cluster1_haproxyrw:   35433
      cluster1_haproxyro:   45433
      cluster1_haproxysp:   55433

      cluster2_postgres:     5434
      cluster2_pgbouncer:    6434
      cluster2_stolonproxy: 25434
      cluster2_haproxyrw:   35434
      cluster2_haproxyro:   45434
      cluster2_haproxysp:   55434

      etcd_client: 2379
      etcd_server: 2380
    ```

### Postgres

When separating router and postgres, you can configure firewalld to open `postgres`, `pgbouncer`, and `stolon-proxy` on postgres nodes for multiple cluster instances as follows:
In `firewall_ports_hacluster` you define the following ports:

!!! example
    ```yaml
    firewall_ports_hacluster:

      cluster1_postgres:     5433
      cluster1_pgbouncer:    6433
      cluster1_stolonproxy: 25433

      cluster2_postgres:     5434
      cluster2_pgbouncer:    6434
      cluster2_stolonproxy: 25434

      etcd_client: 2379
      etcd_server: 2380
    ```

### Router

When separating router and postgres, you can configure firewalld to open `haproxy-rw`, `haproxy-ro`, and `haproxy-sp` on router nodes for multiple cluster instances as follows:
In `firewall_ports_router` you define the following ports (standard takes them from `haproxy_frontends`, see [HAProxy](haproxy.md)):

!!! example
    ```yaml
    firewall_ports_router:

      cluster1_haproxyrw:   35433
      cluster1_haproxyro:   45433
      cluster1_haproxysp:   55433

      cluster2_haproxyrw:   35434
      cluster2_haproxyro:   45434
      cluster2_haproxysp:   55434
    ```

## Description

The key names are only labels; the values are the ports that are opened.

| Key              | Description                                                                         |
|------------------|-------------------------------------------------------------------------------------|
| `<name>_postgres`    | Postgres port of instance `<name>`, equal to `stolon_clusters.<name>.sysconfig.stkeeper.pg_port`. |
| `<name>_pgbouncer`   | PgBouncer port of instance `<name>`, equal to `pgbouncer_instances.<name>.port`. |
| `<name>_stolonproxy` | Stolon proxy port of instance `<name>`, equal to `stolon_clusters.<name>.sysconfig.stproxy.port`. |
| `<name>_haproxyrw`   | HAProxy read-write frontend port of instance `<name>` forwarding to primary postgres instances (see `haproxy_config`). |
| `<name>_haproxyro`   | HAProxy read-only frontend port of instance `<name>` forwarding to readonly postgres instances (see `haproxy_config`). |
| `<name>_haproxysp`   | HAProxy read-write frontend port of instance `<name>` forwarding to stolon-proxy (see `haproxy_config`). |
| `etcd_client`    | etcd client port (shared by all instances).                                         |
| `etcd_server`    | etcd peer port (shared by all instances).                                           |

## Remarks

- Make sure all configured ports are aligned with port configuration for other modules
  - [`stolon`](stolon.md)
  - [`pgbouncer`](pgbouncer.md)
  - [`haproxy`](haproxy.md)
- Best practice is not to open all ports, but to make a proper judgement call on which to open (e.g. you are probably fine with only one of postgres, stolon-proxy and haproxyrw).
- HAProxy frontend ports belong in `firewall_ports_router`, also when router and postgres run on the same hosts.
