# PostgreSQL Memory Tuning Guide

This page describes PostgreSQL configuration options that have immediate impact on memory utilization and consumption, and how to tune them.

---

## Parameters

### 1. `shared_buffers`

When Postgres starts, the initial process (called **postmaster**) allocates a block of shared memory.  
After that, every background process and every connection is forked from postmaster and has access to this segment.  

This shared block of memory that every fork has access to is called **Shared Buffers**, and its size is defined by the `shared_buffers` parameter.  
The block contains some small buffers, like `wal_buffers`, but most of shared buffers are used for **page buffers**.

**Recommendations:**  
- As a starting point, `shared_buffers` can be set to **25% of total server memory**, which is also the default that TPA-exec sets it to.  
- Setting it too large brings risks 
    - to background Linux processes (e.g., cron) being starved for memory 
    - Out Of Memory killer that must free memory for the OS to remain functional.
- Setting it too small brings risk for **double buffering**, where only a few pages are kept in shared buffers and everything is cached in the page cache.  
Double buffering has a small performance impact but is otherwise harmless.  
- Tune it together with `max_connections` and `work_mem`.

---

### 2. `work_mem`

Every query runs one or more operations (sort, merge, index lookup, etc.).  
Each operation can request a block of memory, and the size of that block is limited by the `work_mem` parameter.  

Thus, `work_mem` is one of the most important parameters for limiting **private memory**, the other being `max_connections`.

- Too large values for `work_mem` will make the server starve for memory, trigger **Out Of Memory killer**, or (in worst cases) down the system.  
- Too small values for `work_mem` will result in PostgreSQL using **temp files** more frequently (its form of swapping).  

**Tuning `work_mem`:**
1. Start with a sane value.  
2. Theoretical lower bound could be 25% of server memory divided by max_connections,
complexity and parallelization.  
3. Usually you can select a practical value which is 2-4 times bigger  
4. Round to a power of (e.a. 16MB).  
5. Monitor for memory utilization (how much caching is applied) and if there is little OS caching (0-20%) decrease work_mem (or shared_buffers, or increase server memory) by halving the
value  
6. Monitor PostgreSQL logs for **temp files**; if many appear, increase `work_mem`.  
7. Adjust `log_temp_files` when changing `work_mem` globally.

---

### 3. `max_connections`

`max_connections` defines the **maximum number of concurrent connections** accepted by PostgreSQL. When setting and/or tuning `max_connections`, the following needs to be taken in
consideration  

Each connection is a separate process, which adds overhead for the Linux kernel, memory usage, and increases risk of locking.

**Considerations when tuning:**  
- There’s an optimal “hot zone” where you have enough, but not excessive, parallelization.  
- It depends on **storage performance**.
- It depends on **cpu / memory performance**. 
- It depends on the number of CPUʼs.
- Applications with connection poolers can be adjusted to run enough and no too much
 parallel connections, alternatively PgBouncer can be used instead.


**Recommendations:**  
- Keep it **below 2000 connections**, or use a **connection pooler** such as PgBouncer.  
- Ensure enough (virtual) CPUs and memory.  
- Memory formula guideline:  
  ```text
  (max_connections * work_mem * query_complexity * parallelization_factor)
  + shared_buffers + os_memory + caching
  ```
- If needed, lower `shared_buffers` (when possible) or increase total server memory.

---

### 4. `effective_cache_size`

`Effective_cache_size` is a parameter with very limited impact.
The Postgres query planner uses this parameter as an estimate of cache size, which in turn is
used to see see if a block that is not in shared_buffers is expected to be in the filesystem cache (which is faster) or would result in an actual IO.
Best is to set it to the **theoretical max cache size** (which would be something like 75% of
OSmemory).

---

## Background – Tuning Memory Parameters

To tune memory parameters effectively, follow this structured approach:

### Step 1: Consider server memory allocation
| Component | Recommended Share | Description |
|------------|-------------------|--------------|
| `shared_buffers` | ~25% | Shared memory for pages |
| Private memory | ~25% | Memory used by connections |
| OS + Kernel processes | 10–25% | Includes `ssh`, `cron`, `systemd`, etc. |
| Cache / Overflow | Remainder | Used for filesystem caching |

---

### Step 2: Consider query complexity
- Estimate the average number of **complex operations** (e.g., sorts, merges).  
- Complex operations consume more memory.  
  - Transactional systems: ~1  
  - Analytical systems: 8–16  

---

### Step 3: Consider parallelization
- Determine how many queries are run in parallel and the number of parallel workers.  
- Typical values:  
  - 1 → no parallelization  
  - [max_parallel_workers_per_gather](https://postgresqlco.nf/doc/en/param/max_parallel_workers_per_gather/) for 100% parallelization 

---

### Step 4: Compute total memory allocation

- Consider [max_connections](https://postgresqlco.nf/doc/en/param/max_connections/)

---
