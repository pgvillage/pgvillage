---
title: minio - multiinstance
summary: A description of configuring minio to support backups for multiple instances
authors:
  - Sebas Mannem
date: 2026-10-11
---

# minio - multiple buckets

When deploying multiple HA clusters (e.g. stolon or Patroni), you should separate the backups for each cluster to another bucket.
To configure Minio with multiple buckets, edit the minio config (e.g. `environments/cluster1/group_vars/all/minio.yml`) and define a bucket per cluster.
Then configure `s3_prefix` of every cluster in [`walg_clusters`](walg.md) to use the bucket meant for it.

## `minio_buckets`

With multi-instance every Postgres instance gets its own bucket, named after the instance:

```yaml
minio_buckets:
  - cluster1
  - cluster2
```
