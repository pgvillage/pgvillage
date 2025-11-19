# PostgreSQL Forbidden Parameters

This is a list of parameters that should **never be changed**, along with explanations why.

---

## Parameters

### 1. `fsync`

The `fsync` parameter controls whether fsync is **enabled or disabled**.  
Fsync guarantees **disk writes**, and failed fsyncs are **retried** — commits are halted until successful writes occur.  
As such, fsync is a **crucial part of PostgreSQL’s durability mechanism**.

!!! Important
> - `fsync` should **never** be disabled.  
> - It is considered a **debug parameter** for developers who know exactly what they are doing.  
> - Disabling it (`fsync = false`) **breaks community and vendor support**.  

If you ever run into a PostgreSQL cluster with fsync switched to on, immediately
1. **Dump the data.**  
2. **Recreate the instance.**  
3. **Load the data.**  

The instance might have inconsistencies that need to be manually checked and corrected by **functional application management**.

---

### 2. `autovacuum`

The `autovacuum` parameter controls whether autovacuum is **enabled or disabled**.  

Disabling autovacuum introduces many risks, including:  

- Statistics are **not refreshed**, leading to **poor query performance**.  
- Excessive **I/O operations**.  
- Increased **memory pressure**.  
- Frequent flushing and overwriting of pages in `shared_buffers`, resulting in poor caching.  
- High **CPU usage**.  

Additionally, autovacuum handles **transaction ID wraparound**.  
If disabled, transaction IDs can **exhaust**, leading to a **system-wide halt**.

> **Never disable autovacuum.**  
> - Manual vacuuming may provide some control but offers limited benefits.  
> - Autovacuum generally runs exactly when needed.  
> - If manual vacuum automation is introduced, it should only reduce how often autovacuum triggers — **not replace it**.

If you find a PostgreSQL system where `autovacuum` is switched **off**, you should:  
1. **Turn on autovacuum immediately.**  
2. **Manually vacuum all databases.**  
3. **Wait at least one week** before reporting any issues to the community or vendor.

> `autovacuum` is one of the parameters that, when set to `false`, **voids support** from both the PostgreSQL community and commercial vendors.


