# PostgreSQL Must Tune Parameters

This page describes all parameters that should always be tuned.

---

## Parameters

### 1. `shared_buffers`
Set to **25% of server memory** by default.  
For more tuning, see:  
[PostgreSQL Memory Tuning Guide – shared_buffers](https://tennet.atlassian.net/wiki/spaces/DBA/pages/458981898/PostgreSQL+memory+tuning+guide#shared_buffers)

---

### 2. `effective_cache_size`
Set to **75% of server memory** by default.  
For more info, see:  
[PostgreSQL Memory Tuning Guide – effective_cache_size](https://tennet.atlassian.net/wiki/spaces/DBA/pages/458981898/PostgreSQL+memory+tuning+guide#effective_cache_size)

---

### 3. `min_wal_size`
Set to **25% of the size of the WAL disk**.  
For more info, see:  
[PostgreSQL Disk Tuning Guide – min_wal_size](https://tennet.atlassian.net/wiki/spaces/DBA/pages/458654239/PostgreSQL+disk+tuning+guide#min_wal_size)

---

### 4. `max_wal_size`
Set to **75% of WAL disk**.  
For more info, see:  
[PostgreSQL Disk Tuning Guide – max_wal_size](https://tennet.atlassian.net/wiki/spaces/DBA/pages/458654239/PostgreSQL+disk+tuning+guide#max_wal_size)

---

### 5. `autovacuum_vacuum_scale_factor`
For large tables (>100G), set `autovacuum_vacuum_scale_factor` to **0.01**, so that vacuum is triggered when 1% (1G) consists of dead tuples.  
For more info, see:  
[PostgreSQL Vacuum Tuning Guide – autovacuum_vacuum_threshold and autovacuum_vacuum_scale_factor](https://tennet.atlassian.net/wiki/spaces/DBA/pages/459407698/PostgreSQL+Vacuum+tuning+guide#autovacuum_vacuum_threshold-and-autovacuum_vacuum_scale_factor)

> Example:  
> ```sql
> ALTER TABLE mytable SET (autovacuum_vacuum_scale_factor = 0.01);
> ```

Also tune `autovacuum_analyse_scale_factor` accordingly.

---

### 6. `autovacuum_max_workers`
Set this to the **number of CPUs** as a default.  
For more info, see:  
[PostgreSQL Vacuum Tuning Guide – General Recommendations](https://tennet.atlassian.net/wiki/spaces/DBA/pages/459407698/PostgreSQL+Vacuum+tuning+guide#General-recommendations)

---

### 7. `max_parallel_workers`
Set this to **4× the number of CPUs** as a default.  
For more info, see:  
[PostgreSQL Parallelization Tuning Guide – max_parallel_workers](https://tennet.atlassian.net/wiki/spaces/DBA/pages/458359475/PostgreSQL+Parallellization+tuning+guide#max_parallel_workers)

---

### 8. `max_parallel_workers_per_gather`
Set this to the **number of CPUs** by default.  
For more info, see:  
[PostgreSQL Parallelization Tuning Guide – max_parallel_workers_per_gather](https://tennet.atlassian.net/wiki/spaces/DBA/pages/458359475/PostgreSQL+Parallellization+tuning+guide#max_parallel_workers_per_gather)

---

### 9. `log_min_duration` and `log_duration`
- Check with the business if there are any performance requirements and set `log_min_duration` accordingly.  
- When no business requirement exists, use **10s** as default.  
- Set `log_duration` to **on**.  

For more info, see:  
[PostgreSQL Logging Tuning Guide – log_autovacuum_min_duration](https://tennet.atlassian.net/wiki/spaces/DBA/pages/458850948/PostgreSQL+Logging+tuning+guide#log_autovacuum_min_duration)

---

### 10. `log_checkpoints`
Set to **on**, and monitor the number of checkpoints per minute.  
Alert when there are **more than 10 per minute**.

---

### 11. `log_statement`
Set to **ddl** to ensure schema changes are logged.

---

### 12. `log_temp_files`
Set this equal to the size of `work_mem`, and consider increasing `work_mem` when:  
- Query performance seems poor  
- There is enough free memory  
- Many temporary files are logged

