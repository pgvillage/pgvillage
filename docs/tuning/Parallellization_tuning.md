# PostgreSQL Parallelization Tuning Guide

Since PostgreSQL 10, there is support for **parallel query**.  

The main idea is that the planner takes parallel plans into account.  
- Parallel plans are more efficient, as parts run in parallel.  
- Plans are also less efficient, as there is extra setup cost.  

As such, the executor will calculate and compare total cost of plans with and without parallelization, and choose the most optimal one.  

This page describes the most important options and how they affect the planning or execution phase.

---

## Parameters

### 1. `parallel_setup_cost`

This parameter sets the extra cost to take into account when using parallel query.

---

### 2. `parallel_tuple_cost`

This parameter sets the extra cost to take into account for every tuple that is passed to the coordinator when using parallel query.

---

### 3. `max_parallel_workers`

This parameter limits the number of workers that can be used for parallel query overall.  

Example:  
If one query is using **4 workers**, only **2 remain available** for another parallel query, and all other parallel queries need to wait for the running queries to finish.

---

### 4. `max_parallel_workers_per_gather`

This parameter limits the number of workers that can be used for a single running parallel query.

---

### 5. `min_parallel_*_size`

These settings can be used to limit parallel query only to objects that are larger than the setting.

| Parameter | Description |
|------------|--------------|
| `min_parallel_index_scan_size` | Limits by size of an index |
| `min_parallel_relation_size` | Limits by size of a relation (e.g., table) |
| `min_parallel_table_scan_size` | Limits the size of a table that needs to be scanned (e.g., when indices are used to filter parts of the table) |

---

## Advice & Tuning

Parallel query can have **unexpected behavior**, and therefore the default settings are very relaxed.  

If you want to experiment with parallel query on an active system, you could test with **more aggressive settings**, by:  

- Increasing `parallel_setup_cost` (so that the planner more quickly considers parallel query)  
- Increasing `max_parallel_workers` (so that more processing power is available for parallel queries)  
- Increasing `max_parallel_workers_per_gather` (so that more processing power is available for a single parallel query)

**When tuning, consider the following:**  
1. Monitor and actively track the overall runtime of queries.  
2. When overall query runtime increases, parallel processing power might be too much at the expense of normal queries.  
3. Check effect on complex queries with long duration interactively:  
   - Start a session  
   - Set parameters in the session  
   - Run query with `EXPLAIN ANALYZE`  
   - Check the effect on the plan for different values of the settings

---

## Partitioning

By splitting a table into multiple partitions, operations on the table can be split into multiple operations (one per partition) and as such run in parallel.  
Using native partitioning helps with parallel query.
