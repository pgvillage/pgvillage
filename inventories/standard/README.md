# standard

See [Getting started](../../docs/index.md) for how to use it with your own machines.

Standard PgVillage config, shared by all platforms: Postgres version, mountpoints, ports, packages, and the config of
stolon, wal-g, avchecker, nagios, etc.

It is multi-instance: two stolon clusters, `cluster1` and `cluster2`, run side by side on the same hosts:

| Cluster    | Postgres | stolon proxy | PgBouncer | Data / wal                                    | Bucket     |
|------------|----------|--------------|-----------|-----------------------------------------------|------------|
| `cluster1` | 5433     | 25433        | 6433      | `<data mountpoint>/cluster1`, `<wal mountpoint>/stolon/cluster1/wal` | `cluster1` |
| `cluster2` | 5434     | 25434        | 6434      | `<data mountpoint>/cluster2`, `<wal mountpoint>/stolon/cluster2/wal` | `cluster2` |

The ports are set in `stolon.yml`, `wal-g.yml`, `pgbouncer.yml`, `avchecker.yml` and `firewall.yml` (`pgroute66.yml` and
`haproxy.yml` take them from `stolon_clusters`: HAProxy on the router listens on 35433/45433/55433 (read-write,
read-only, stolon proxy) for `cluster1` and 35434/45434/55434 for `cluster2`);
keep them in line when adding or changing a cluster. See
[multi-instance](../../docs/deploy/multi-instance.md).

It has no OS specifics and no hosts. `hosts` only has the groups, and the standard architecture: stolon and etcd run on
the database hosts (`stolon` and `etcd_master` are subgroups of `hacluster`); the platform inventory adds the hosts to
`hacluster`, `backup` and `localhosts`, and to `router` and `haproxy` when it has a router (it needs a VIP on the
platform's network, e.g. `inventories/platform/vagrant`). Use it with an OS layer (`inventories/os/el`, `inventories/os/debian`,
`inventories/os/suse`) and a platform inventory, in this order, so later values win:

```bash
ansible-playbook -i inventories/standard -i inventories/os/el -i inventories/platform/azure functional-all.yml
```

To change a value for one OS or platform, add a file with the same name to `inventories/os/<os>/group_vars/all/` or
`inventories/platform/<platform>/group_vars/all/`.
