---
title: PgQuarts
summary: A description of the PostgreSQL job scheduler shipped with PgVillage
authors:
  - Sebas Mannem
  - Snehal Kapure
date: 2025-11-11
---

# PgQuartz

PgQuartz is a community tool used to configure and execute scheduled jobs in PostgreSQL environments.

It reads and runs job configurations defined in YAML files.

A job definition can include:

```yaml
# Example structure

steps: # What actions need to be performed
checks: # How to verify that everything is working correctly
connections: # Definitions of connections to the PostgreSQL environment
etcd_config: # pgquartz can wait for the same job on other servers via etcd
general_config: # General settings (debug mode, log file path, parallel execution, etc.)
```

## Requirements and Dependencies

PgQuartz is installed by default with the PostgreSQL SBB, but it is only used for vaccination certificates.

More information:

- [Inventory explained](../deploy/inventory/index.md)
- [PgQuartz](https://github.com/pgvillage-tools/pgquartz)

## Multi-instance

How to configure this for several clusters on the same hosts. See [Multi-instance](../deploy/multi-instance.md)
for the feature, and the [defaults](https://github.com/pgvillage/ansible-role-pgquartz/blob/main/defaults/main.yml) of the role for all its variables.

When deploying multiple HA clusters (e.g. stolon or Patroni), PgQuartz jobs should run for every Postgres instance.
The pgvillage.pgquartz role runs every job once per instance in `pgquartz_instances`.
The standard inventory (`inventories/standard/group_vars/all/pgquartz.yml`) generates `pgquartz_instances` from
[`stolon_clusters`](stolon.md#multi-instance): adding a cluster to `stolon_clusters` also runs all jobs for that cluster.

### How it works

PgQuartz job definitions are static yaml files. For every instance and job, the role renders
`{{ pgquartz_jobsdir }}/<job>.yml` (checked out from `pgquartz_definitions`) to
`/etc/pgquartz/instances/<instance>/<job>.yml` and schedules it in `/etc/cron.d/pgquartz`
(cron entry `pgQuartz job <instance> <job>`). The rendered job is a copy of the original job, with:

| Setting                          | Rendered value                                                                 |
|----------------------------------|--------------------------------------------------------------------------------|
| `connections.<name>.conn_params` | Combined with `conn_params` of the instance (e.g. the Postgres port).          |
| `etcdConfig.lockKey`             | `<instance>/<job>`: the same job for different instances runs independently, the same instance on other hosts still shares the lock. |
| `logFile`                        | `/var/log/pgquartz/<instance>` (only when the job has a `logFile`).            |
| `workdir`                        | The folder of the original job, so relative `file:` references still work.    |

When `pgquartz_instances` is set, jobs are no longer scheduled without an instance.

### `pgquartz_instances`

Dictionary with one entry per Postgres instance. The key is the instance name, which should match the key in
[`stolon_clusters`](stolon.md#multi-instance).

| Key           | Description                                                                                    |
|---------------|------------------------------------------------------------------------------------------------|
| `conn_params` | libpq connection parameters of the instance, e.g. `port` (`stolon_clusters.<name>.sysconfig.stkeeper.pg_port`). |
| `jobs`        | Jobs to schedule for this instance, same format as `pgquartz_jobs` (defaults to `pgquartz_jobs`). |
| `logfolder`   | Log folder of the instance (defaults to `/var/log/pgquartz/<instance>`).                       |

The standard inventory generates (for `cluster1` on 5433 and `cluster2` on 5434):

!!! example
    ```yaml
    pgquartz_instances:
      cluster1:
        conn_params:
          port: "5433"
      cluster2:
        conn_params:
          port: "5434"
    ```

To schedule jobs at another time per instance (e.g. to not run heavy jobs of all instances at the same time),
override `pgquartz_instances` and set `jobs` per instance:

!!! example
    ```yaml
    pgquartz_instances:
      cluster1:
        conn_params:
          port: "{{ stolon_clusters.cluster1.sysconfig.stkeeper.pg_port }}"
        jobs:
          - name: vacuum
            minute: "30"
            hour: "1"
      cluster2:
        conn_params:
          port: "{{ stolon_clusters.cluster2.sysconfig.stkeeper.pg_port }}"
        jobs:
          - name: vacuum
            minute: "30"
            hour: "3"
    ```

### Remarks

- Only the port is set per instance. Jobs that set `host` in `conn_params` keep connecting to that host;
  without a `host`, PgQuartz uses the libpq default (`PGHOST` or the local unix socket).
- Only `pg` steps are instance aware. PgQuartz passes only matrix arguments as environment to `shell` steps,
  so a shell step cannot tell which instance it runs for
  (see [pgvillage-tools/pgquartz#17](https://github.com/pgvillage-tools/pgquartz/issues/17)).
- Multi-instance is supported with the `cron` scheduler (`pgquartz_scheduler: cron`), as used by pgvillage.
