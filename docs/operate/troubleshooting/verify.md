---
title: Verifying a PgVillage deployment
summary: A description of how to verify a PgVillage deployment
authors:
  - Sebas Mannem
  - Snehal Kapure
date: 2025-11-11
---

# Component: PostgreSQL Building Block

The PostgreSQL Building Block consists of the following components:

- **PostgreSQL**
- **Stolon**
- **Etcd**
- **wal-g**

## Requirements and Dependencies

PostgreSQL

1. `sudo su - postgres`
2. `psql`
3. `create database pgbench;`
4. `\q`
5. `/usr/pgsql-12/bin/pgbench -i -s10000 pgbench` # filling
6. Test: `/usr/pgsql-12/bin/pgbench -c 10 -l -j 4 -P 120 -T 600 pgbench`

### POC Results

```bash
starting vacuum...end.

progress: 120.0 s, 210.3 tps, lat 47.515 ms stddev 29.338
progress: 240.0 s, 275.6 tps, lat 36.283 ms stddev 21.895
progress: 360.0 s, 415.2 tps, lat 24.077 ms stddev 49.606
progress: 480.0 s, 497.7 tps, lat 20.087 ms stddev 18.762
progress: 600.0 s, 522.0 tps, lat 19.151 ms stddev 16.870

Transaction Type: <builtin: TPC-B>
Scaling factor: 10000
query mode: simple
number of clients: 10
number of threads: 4
duration: 600 s

number of transactions actually processed: 230507
average latency = 26.023 ms
latency stddev = 30.854 ms

tps = 384.125073 (including connection establishments)
tps = 384.128736 (excluding connection establishments)
```

#### Etcd

As postgres: `etcdctl check performance`
This command can be run on any of the three nodes.

---

#### Stolon

```bash
On the master:
/home/postgres/bin/demote.sh

On a standby:
/home/postgres/bin/reinstate.sh

On a keeper (master or standby):
reboot
kill -9 stolon-keeper

As the PostgreSQL user:
stolonctl status

== Active Sentinels ==

ID           LEADER
81cfd599     false
d4c10d79     true
f71041f5     false

=== Active Proxies ===

ID
6b72f506
b9e1cb00
cde31aea

=== Keepers ===

UID                   HEALTHY  PG LISTEN ADDRESS   PG HEALTHY  PG WANTED GEN  PG CUR GEN
gurus_pgsdb_server1   true     10.0.5.66:5432      true        2              2
gurus_pgsdb_server2   true     10.0.5.67:5432      true        5              5
gurus_pgsdb_server3   true     10.0.5.68:5432      true        2              2

=== Cluster Information ===

Master Keeper: gurus_pgsdb_server2

== Keepers/Database Tree ==

gurus_pgsdb_server2 (master)
├─ gurus_pgsdb_server3
└─ gurus_pgsdb_server1

# Run 24/5/2022
[postgres@gurus-pgsdb-server2 ~]$ /usr/pgsql-12/bin/pgbench -c 10 -l -j 4 -P 120 -T 600 pgbench

starting vacuum...end.
progress: 120.0 s, 365.6 tps, lat 27.336 ms stddev 15.355
progress: 240.0 s, 361.2 tps, lat 27.673 ms stddev 16.090
progress: 360.0 s, 289.1 tps, lat 34.586 ms stddev 40.564
progress: 480.0 s, 343.4 tps, lat 29.108 ms stddev 17.820
progress: 600.0 s, 354.7 tps, lat 28.194 ms stddev 17.010

# Additional info:

transaction type: <builtin: TPC-B>
scaling factor: 10000
query mode: simple
number of clients: 10
number of threads: 4
duration: 600 s


Number of transactions processed: 205685
average latency = 29.163 ms
latency stddev = 22.633 ms
tps = 342.771509 (including connection establishments)
tps = 342.778836 (excluding connection establishments)
```

## Execution