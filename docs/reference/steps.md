---
title: Roles in functional-all.yml
summary: Which roles functional-all.yml runs, on which groups and in which order, and how to change that in the inventory
authors:
  - Sebas Mannem
date: 2026-11-11
---

# Roles in functional-all.yml

`functional-all.yml` deploys PgVillage in one play. It runs a list of steps, in order, each on the hosts of its groups.
A step is a role (or a task file). You change the list in the inventory with `pgvillage_roles`, without changing the
playbook.

## The default steps

| Order | Step                   | Runs                                  | Groups                                    | Extra tags |
|-------|------------------------|---------------------------------------|-------------------------------------------|------------|
| 10    | `linux`                | `pgvillage.linux`                     | `hacluster`, `backup`, `router`, `localhost` | `packages` |
| 20    | `chainsmith`           | `pgvillage.chainsmith`                | `hacluster`, `backup`, `router`, `localhost` | `certificates`, `certs` |
| 30    | `firewall`             | `pgvillage.firewall`                  | `hacluster`, `backup`, `router`           | `firewalld` |
| 40    | `etcd`                 | `pgvillage.etcd`                      | `etcd_master`                             | |
| 50    | `minio`                | `pgvillage.minio`                     | `backup`                                  | |
| 60    | `walg`                 | `pgvillage.walg`                      | `hacluster`                               | |
| 70    | `stolon_wal_subfolder` | `tasks/stolon_wal_subfolder.yml`      | `hacluster`                               | `stolon`, `postgres`, `postgresql`, `pg` |
| 71    | `stolon`               | `pgvillage.stolon`                    | `hacluster`                               | `postgres`, `postgresql`, `pg` |
| 80    | `avchecker`            | `pgvillage.avchecker`                 | `hacluster`                               | `availability_checker` |
| 90    | `haproxy`              | `pgvillage.haproxy`                   | `router`                                  | `router` |
| 91    | `keepalived`           | `pgvillage.keepalived`                | `router`                                  | `router` |
| 92    | `pgroute66`            | `pgvillage.pgroute66`                 | `router`                                  | `router` |
| 100   | `pgbouncer`            | `pgvillage.pgbouncer`                 | `hacluster`                               | `bouncer`, `pooler` |
| 110   | `nagios`               | `pgvillage.nagios`                    | `haproxy`, `backup`, `hacluster`          | |
| 120   | `pgquartz`             | `pgvillage.pgquartz`                  | `hacluster`                               | |

The name of a step is always a tag too, so `--tags stolon,avchecker` runs those two roles (and the steps that have
these tags), as before.

A step ends on all its hosts, including its handlers (restarts), before the next step starts: the same as the separate
plays that `functional-all.yml` had before.

## Changing the steps

Set `pgvillage_roles` in your inventory (e.g. `group_vars/all/roles.yml`). It is merged into the defaults per step, so
you only set what changes:

```yaml
---
pgvillage_roles:
  # Skip a step
  nagios:
    enabled: false
  # Run a step on other groups
  pgquartz:
    groups: [hacluster, backup]
  # Replace minio with RustFS (pgvillage.rustfs), at the same position
  minio:
    enabled: false
  rustfs:
    order: 50
    groups: [backup]
  # Add a role of your own, right after linux (from requirements.yml or your roles path)
  mycompany.hardening:
    order: 15
    groups: [hacluster, backup, router]
    tags: [hardening]
```

Per step:

| Setting   | Meaning |
|-----------|---------|
| `order`   | Position; required for a new step. Steps with the same order run in the order of their names. |
| `groups`  | Groups (or host names, e.g. `localhost`) the step runs on; required for a new step. |
| `enabled` | `false` skips the step (default `true`). |
| `role`    | The role to run. Default: the name of the step, prefixed with `pgvillage.` when it has no dot. |
| `tasks`   | A task file (relative to the playbook) to run instead of a role. |
| `tags`    | Extra tags; the name of the step is always a tag. |

`groups` is a list, and replaces the default list as a whole.

!!! note
    `pgvillage_roles` is one variable: when more than one of your inventories (`-i`) set it, the last one wins, like
    any other variable. Put it in one place.

!!! note
    `minimal.yml`, `rollout_new_certs.yml` and `uninstall.yml` still have a play per role, and don't use
    `pgvillage_roles`.
