# PostgreSQL Vacuum Tuning Guide

This guide describes the options available to tune (auto)vacuum.  

In most situations, the autovacuum tuning options are the most optimal values, but in some corner cases, tuning vacuum really helps.  

This page describes the options and when and how to tune them.

!!! Note 
> 1. Never change a winning team. Use defaults unless you need to change them.  
> 2. Improving storage or increasing CPU power usually is more beneficial.  
> 3. There is a tradeoff between performance for vacuum vs performance for user processes.  
> 4. Too little vacuum also has a counterproductive effect where statistics are behind too much.

---

## Generic

**autovacuum_vacuum_ prefixed parameter**

Many parameters prefixed with `autovacuum_vacuum_` have a counterpart without `autovacuum_` (so just `vacuum_` as a prefix).  

In these cases, the `autovacuum_vacuum_` prefixed parameters overrule the `vacuum_` prefixed items when autovacuum triggers a vacuum.

---

## Parameters

### 1. `autovacuum_vacuum_cost_limit` and `autovacuum_vacuum_cost_delay`

These parameters set values for `vacuum_cost_limit` and `vacuum_cost_delay` when autovacuum runs a vacuum process.  
They are set softer, so that vacuums run more in the background when run by autovacuum compared to manually with default settings.

**Basic working:**  
All vacuum operations have cost. The vacuum process tracks cost, and once `vacuum_cost_limit` is reached, the process halts for `vacuum_cost_delay`.  
Together, they throttle a vacuum — higher `vacuum_cost_limit` and lower `vacuum_cost_delay` make vacuum run more aggressively.

**Tuning advice:**  
In most cases, the defaults are optimal. When autovacuums take too long and the system has available resources, raising `autovacuum_vacuum_cost_limit` and/or lowering `autovacuum_vacuum_cost_delay` can make vacuum run more in the foreground.  
> Usually, faster storage is the better solution.

---

### 2. `autovacuum_vacuum_threshold` and `autovacuum_vacuum_scale_factor`

These parameters define when a table is due for vacuum.

- **`autovacuum_vacuum_threshold`** → Number of dead tuples that could trigger a vacuum.  
- **`autovacuum_vacuum_scale_factor`** → Fraction (percentage) of dead tuples in the table that triggers vacuum.  

Unexpectedly, not the minimum, but the **sum** of both is used by autovacuum to decide on running a vacuum.

**Tuning advice:**  
For most tables, defaults work fine. For large tables (>100 GB), decreasing scale factor (e.g., 0.01 instead of 0.2) triggers autovacuum more often and avoids cluttered datafiles and bad statistics.  

> These settings can be set per table using:  
> `ALTER TABLE mytable SET (key = value);`

---

### 3. `autovacuum_analyse_threshold` and `autovacuum_analyse_scale_factor`

Vacuum can run with or without an analyze.  

These settings work similarly to `autovacuum_vacuum_threshold` and `autovacuum_vacuum_scale_factor`, but instead of triggering a vacuum, they control whether a vacuum should also trigger an analyze (to update statistics).

---

### 4. `autovacuum_max_workers`

This parameter controls how many vacuums run in parallel.  

When a cluster has many small tables, increasing this value can significantly improve vacuum performance.  
However, tuning this also increases autovacuum’s impact on system performance.

A good approach is to pair this with adjustments to:  
- `autovacuum_vacuum_cost_limit` / `autovacuum_vacuum_cost_delay`, or  
- `autovacuum_naptime`  

> A sane default is to tune this to match the number of vCPUs in the system.

---

### 5. `autovacuum_naptime`

This parameter defines how long a vacuum worker sleeps between running a vacuum on a table.

---

## General Recommendations

If autovacuum seems not to keep up, consider the following **in order**:

1. Check for `io_waits`, queue lengths, etc., and improve storage performance if needed.  
2.  Increase [autovacuum_max_workers](https://tennet.atlassian.net/wiki/spaces/DBA/pages/459407698/PostgreSQL+Vacuum+tuning+guide#autovacuum_max_workers) (double the number of CPUʼs 
power unused during vacuumʼs) .  
3. Add CPUs (and increase `autovacuum_max_workers` accordingly).  
4. Tune [autovacuum_vacuum_cost_limit and autovacuum_vacuum_cost_delay](https://tennet.atlassian.net/wiki/spaces/DBA/pages/459407698/PostgreSQL+Vacuum+tuning+guide#autovacuum_vacuum_cost_limit-and-autovacuum_vacuum_cost_delay) to make vacuum run more in the foreground.  
   - Consider doing this only for specific tables if the issue is not system-wide.

