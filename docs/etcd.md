# Etcd

Etcd is high available key value store whicj in PgVilllage is used for consensus across the PostgreSQL nodes.
The High Availability manager (stolon) stores clusterstate and configuration in etcd.
Everry instance has either a consistent copy of `state and config`, or it does not accept requests from an etcd client (e.a. stolon).

Etcd consists of the following components:

- an etcd service
- an etcdctl tool for managing etcd from commandline
- etcd exposes an api which can be consumed by the etcdctl tool, or other other tools such as stolon or PgQuartz

## Requirements and dependencies

Stolon uses etcd to store settings and state, which consists of:

- pg_hba settings
- postgresql.conf settings
- node role (which node is primary and which is standby

Etcd makes sure these setiings and state is either consistently available, or not available at all, which makes for the following:

- nodes either perceive the same config as all other nodes, and can compete for the primary role, or
- nodes either perceive the same config as all other nodes, and are left with a standby role, or
- nodes perceive etcd downtime and can take action accordingly

Depending on state, stolon can make PostgreSQL available as a primary (only one node can do that), as a standby (all other healthy nodes), or stop PostgreSQL (when etcd is down).
Within PgVillage next to stolon also the walg-g backup script (/opt/wal-g/scripts/backup_locked.sh) and PgQuartz utilize etcd to coordinate runs that should be run on one node only.

## Tips 'n tricks

### Etcd database size

Etcd keeps track of changes with a retention which can build up to 2.1 GB before it is (automatically) cleaned.

This maximum soze can be changed in configuration, but this is not encouraged, as it may impact performance and a vailability of both stolon and PostgreSQL.
