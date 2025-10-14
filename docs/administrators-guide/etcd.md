# Introduction

Etcd is a key-value store.

Etcd consists of:

- an etcd service  
- an etcdctl tool to read data from etcd via the command line  
- an API that can be used by other tools (such as Stolon and PGQuartz) to read and use configuration

## Benodigdheden en afhankelijkheden

In het bouwblok voor Postgresql wordt etcd ingezet als consensus mechanisme voor de cluster laag.

Stolon stores the cluster-wide configuration in etcd, such as:

- pg_hba configuration
- PostgreSQL.conf settings
- Which cluster member database is primary and which one is standby.

This configuration is consistently distributed across the entire cluster by etcd, which means:

- all nodes see the same configuration, or
- one or more nodes see that etcd is not available

---

The stolon ensures that Postgres is available only when the configuration (consistent with consensus) is available for the stolon instance.

In addition to stolon, both pgquart and WAL-G (`/opt/wal-g/scripts/backup_locked.sh`) also directly use etcd.

## Execution

## Operational background information

### ```markdown
Etcd database size
```

Etcd has its own database and retains old information. Etcd keeps the size of this database (with retention) to about 2.1 GB.

```markdown
Etcd has its own database and retains old information. Etcd keeps the size of this database (with retention) to about 2.1 GB.
```
```

This can be adjusted in the etcd configuration, but a larger database has an impact on the performance of etcd and thus the availability of Stolon and PostgreSQL.

We houden de standaard aan.

> **Note**: In the past, there have been issues with the etcd database size.
>
> Since then, `ETCD_AUTO_COMPACTION_RETENTION` has been set and it has been stable since.
>
> The following instructions are still included for their historical value.

If issues arise, the database can also be manually reduced using a compact/defragment command:

1: If problems occur, you can see it as follows:
-

```markdown
[etcd@gurus-pgsdb-server1 ~]$ systemctl status etcd
```

```markdown
● etcd.service - Etcd Server
```

Loaded: loaded (/etc/systemd/system/etcd.service; enabled; vendor preset: disabled)

```
Active: active (running) since Tue 2022-01-19 14:58:39 CET; 2 months 21 days ago
```

Main PID: 2142547 (etcd)

Tasks: 10 (limit: 49457)

Memory: 344.0 MB

```
CGroup: /system.slice/etcd.service
```

```markdown
└─2142547 /usr/local/bin/etcd
```

```markdown
Oct 10 10:07:16 gurus-pgsdb-server1 bash[2142547]: {"level":"warn","ts":"2022-07-26T11:07:49.311+0200","caller":"clientv3/retry_interceptor.go:62","msg":"retrying of unary invoker failed","target":"endpoint://client-02e576d1-d16f-4610-8fee-0586f7dbe4c1/127.0.0.1:2379","attempt":0,"error":"rpc error: code = ResourceExhausted desc = etcdserver: mvcc: database space exceeded"}
```

2: The size of the database can be queried as follows:

```markdown
# Requesting Status Endpoints:
```

etcdctl --write-out=table endpoint status

# Request Alarm Status

etcdctl alarm list

3: This can be resolved by manually executing the following on all cluster members:

> **Note**: This should not be executed on all members at the same time, as it affects the availability of etcd and, consequently, also that of PostgreSQL.

```markdown
# 1) Request an audit
```

```markdown
etcdctl get mykey -w=json
```

```markdown
{"header":{"cluster_id":4788661511241613818,"member_id":336793577597500103,"revision":700518,"raft_term":26}}
```

\# 2) Compact Revision

---

```
[etcd@gurus-pgsdb-server1 ~]$
```  
`etcdctl compact 700518`

compacted revision 700518

\# 3) Defragment database

```markdown
[etcd@gurus-pgsdb-server1 ~]$ etcdctl defrag
```

```markdown
# 4) Remove All Alarms
```

etcdctl alarm disarm

