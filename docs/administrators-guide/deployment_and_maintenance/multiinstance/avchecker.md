---
title: avchecker - multiinstance
summary: A description of configuring AVChecker to monitor multiple PostgreSQL HA clusters
authors:
  - Sebas Mannem
date: 2026-10-11
---

# avchecker - multi-instance

When deploying multiple HA clusters (e.g. stolon or Patroni), AVChecker can monitor all instances if you simply define them as separate instances of AVChecker.
Edit the avchecker config (e.g. `inventories/standard/group_vars/all/avchecker.yml`) and define all instances.

## Example

!!! example
    ```yaml
    avchecker_sleeptime: 5
    avchecker_cluster_members: |
      {%- set nodes = [] -%}
      {%- for node in groups.hacluster -%}
      {%- do nodes.append(hostvars[node].ansible_facts.fqdn) -%}
      {%- endfor -%}
      {{ nodes | list | join(',') }}
    avchecker_database: postgres
    avchecker_sslmode: "verify-full"
    avchecker_rw_mode: read-write
    avchecker_defaults:
      cluster1-stolon:
        PGPORT: "5433"
        AVCHECKER_SLEEPTIME: "{{ avchecker_sleeptime }}"
        PGHOST: "{{ avchecker_cluster_members }}"
        PGDATABASE: "{{ avchecker_database }}"
        PGSSLMODE: "{{ avchecker_sslmode }}"
        PGTARGETSESSIONATTRS: "{{ avchecker_rw_mode }}"
      cluster1-proxy:
        PGPORT: 25433
        AVCHECKER_SLEEPTIME: "{{ avchecker_sleeptime }}"
        PGHOST: "{{ avchecker_cluster_members }}"
        PGDATABASE: "{{ avchecker_database }}"
        PGSSLMODE: "{{ avchecker_sslmode }}"
      cluster2-stolon:
        PGPORT: "5434"
        AVCHECKER_SLEEPTIME: "{{ avchecker_sleeptime }}"
        PGHOST: "{{ avchecker_cluster_members }}"
        PGDATABASE: "{{ avchecker_database }}"
        PGSSLMODE: "{{ avchecker_sslmode }}"
        PGTARGETSESSIONATTRS: "{{ avchecker_rw_mode }}"
      cluster2-proxy:
        PGPORT: 25434
        AVCHECKER_SLEEPTIME: "{{ avchecker_sleeptime }}"
        PGHOST: "{{ avchecker_cluster_members }}"
        PGDATABASE: "{{ avchecker_database }}"
        PGSSLMODE: "{{ avchecker_sslmode }}"
    ```

## Details

### `avchecker_cluster_members`

Comma separated list of the FQDNs of all hosts in the `hacluster` group. Used as `PGHOST` in every avchecker instance.

```yaml
avchecker_cluster_members: "{% set nodes = [] %}{% for node in groups.hacluster %}{% do nodes.append(hostvars[node].ansible_facts.fqdn) %}{% endfor %}{{ nodes | list | join(',') }}"
```

### `avchecker_defaults`

Dictionary with one entry per avchecker instance. The key is the instance name and the value is the set of environment
variables for that instance. Previously there were two entries (`stolon` and `proxy`); with multi-instance there is a
pair per Postgres instance, named `<cluster>-stolon` and `<cluster>-proxy`:

- `<cluster>-stolon` checks the Postgres port directly, with `PGTARGETSESSIONATTRS: read-write` so it connects to the primary.
- `<cluster>-proxy` checks the stolon proxy port of the instance.

| Variable               | Description                                                                         |
|------------------------|-------------------------------------------------------------------------------------|
| `AVCHECKER_SLEEPTIME`  | Seconds between checks.                                                             |
| `PGHOST`               | Hosts to connect to, normally `{{ avchecker_cluster_members }}`.                     |
| `PGPORT`               | Postgres port (`stkeeper.pg_port`) for `-stolon`, proxy port (`stproxy.port`) for `-proxy`. |
| `PGDATABASE`           | Database to connect to.                                                              |
| `PGSSLMODE`            | libpq SSL mode.                                                                      |
| `PGTARGETSESSIONATTRS` | libpq target session attributes (`read-write` for the `-stolon` instances).          |

!!! note
    The ports are hardcoded here. They must match the ports in [`stolon_clusters`](stolon.md); you could reference them
    instead, e.g. `"{{ stolon_clusters.cluster1.sysconfig.stkeeper.pg_port }}"`.
