---
title: firewall - multiinstance
summary: A description of configuring firewall to allow traffic for ports for multiple PostgreSQL HA clusters
authors:
  - Sebas Mannem
date: 2026-10-11
---

# firewall - multiinstance

When deploying multiple HA clusters (e.g. stolon or Patroni), firewalld needs to allow traffic to the ports of all components of all clusters.
To do so, you can edit the firewall config (e.g. `environments/cluster1/group_vars/{role}/firewall.yml`) and define all ports to be allowed.

## Example

### Combined

When combining router and postgres, you can configure firewalld to open `postgres`, `pgbouncer`, `stolon-proxy`, `haproxy-rw`, `haproxy-ro`, and `haproxy-sp` for multiple cluster instances as follows:
In the inventory config for hacluster (e.g. `environments/cluster1/group_vars/hacluster/firewall.yml`) you can define all ports:

!!! example
    ```yaml
    firewall_type: firewalld
    firewall_ports:

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
In the inventory config for hacluster (e.g. `environments/cluster1/group_vars/hacluster/firewall.yml`) you can define the following ports:

!!! example
    ```yaml
    firewall_type: firewalld
    firewall_ports:

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

When separating router and postgres, you can configure firewalld to open `haproxy-rw`, `haproxy-ro`, nd `haproxy-sp` on router nodes for multiple cluster instances as follows:
In the inventory config for router (e.g. `environments/cluster1/group_vars/router/firewall.yml`) you can define the following ports:

!!! example
    ```yaml
    firewall_type: firewalld
    firewall_ports:

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
- When router and postgres run on separate hosts, HAProxy frontend ports belong in the firewall config of the `router` group rather than in `hacluster`.
