---
title: RustFS - multiinstance
summary: A description of configuring RustFS to support backups for multiple instances
authors:
  - Sebas Mannem
date: 2026-11-11
---

# RustFS - multiple buckets

When deploying multiple HA clusters (e.g. stolon or Patroni), you should separate the backups for each cluster to another bucket.
To configure [RustFS](../../../tools/rustfs.md) with multiple buckets, edit the RustFS config (e.g. `inventories/standard/group_vars/all/rustfs.yml`) and define a bucket per cluster.
Then configure `s3_prefix` of every cluster in [`walg_clusters`](walg.md) to use the bucket meant for it.

## `rustfs_buckets`

With multi-instance every Postgres instance gets its own bucket, named after the instance:

```yaml
rustfs_buckets:
  - cluster1
  - cluster2
```
