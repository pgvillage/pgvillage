# standard

Standard PgVillage config, shared by all platforms: Postgres version, mountpoints, ports, packages, and the config of
stolon, wal-g, avchecker, nagios, etc.

It is multi-instance: two stolon clusters, `cluster1` and `cluster2`, run side by side on the same hosts:

| Cluster    | Postgres | stolon proxy | PgBouncer | Data / wal                                    | Bucket     |
|------------|----------|--------------|-----------|-----------------------------------------------|------------|
| `cluster1` | 5433     | 25433        | 6433      | `<data mountpoint>/cluster1`, `<wal mountpoint>/stolon/cluster1` | `cluster1` |
| `cluster2` | 5434     | 25434        | 6434      | `<data mountpoint>/cluster2`, `<wal mountpoint>/stolon/cluster2` | `cluster2` |

The ports are set in `stolon.yml`, `wal-g.yml`, `pgbouncer.yml`, `avchecker.yml` and `group_vars/hacluster/firewall.yml`;
keep them in line when adding or changing a cluster. See
[multi-instance](../../docs/administrators-guide/deployment_and_maintenance/multiinstance/stolon.md).

It has no hosts. Use it together with a platform inventory, standard first, so the platform values win:

```bash
ansible-playbook -i inventories/standard -i inventories/azure functional-all.yml
```

To change a value for one platform, add a file with the same name to `inventories/<platform>/group_vars/all/`.
