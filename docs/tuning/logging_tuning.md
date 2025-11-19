# PostgreSQL Logging Tuning Guide

## Parameters

### 1. `log_min_messages`
The PostgreSQL process can log extra information.  
Default is to log **warning** and worse (`error`, `fatal`, `panic`), which is the recommended value.  
This value is for generic purposes. For statement processing, see `log_min_error_statement`.

---

### 2. `log_min_error_statement`
The PostgreSQL process can, while processing a statement, log extra information.  
Default is to log **error** and worse (`fatal`, `panic`), which is the recommended value.

---

### 3. `log_min_duration_statement`
PostgreSQL can log statements that take longer than a certain amount of time.  

- Default is **disabled (-1)**.  
- A value of **0** always logs all statements.  
- **Recommended value:**  
  - Set as per business requirement (defined by the database requestor).  
  - Use **10 seconds** when no business requirement exists.

---

### 4. `log_autovacuum_min_duration`
PostgreSQL can log vacuums initiated by autovacuum that take longer than a certain amount of time.  
**Recommendation:** Set this value to **10 seconds**, so that longer vacuums stand out.

---

### 5. `log_checkpoints`
PostgreSQL can track checkpoints.  
**Recommendation:**  
- Set to **on** and monitor checkpoint frequency.  
- Once or twice per minute (or less) is acceptable.  
- More frequent checkpoints (dozens per minute) may indicate excessive WAL usage or that `max_wal_size` is too small and needs immediate attention.

---

### 6. `log_connections`, `log_disconnections`
PostgreSQL can track connections and disconnections.  
However, when **PEM agents** are used (logging every second), enabling these settings floods the logs.  

**Recommendation:** Keep these settings **off** unless:  
- There are **audit requirements**.  
- You are **debugging** connection issues.

---

### 7. `log_duration`
PostgreSQL can log the duration of long-running statements.  
**Recommendation:** Enable this feature (very small overhead).

---

### 8. `log_error_verbosity`
PostgreSQL can log more or less detail.  

- Default value: **default** (recommended).  
- Setting this parameter to **verbose** can be helpful when investigating an issue — only temporarily.  
- Setting to **terse** is not required.

---

### 9. `log_statement`
PostgreSQL can be configured to monitor specific statements.  
Default is **none**.  
**Recommendation:** Set to **ddl** to ensure schema changes are logged.

---

### 10. `log_temp_files`
PostgreSQL can log temp files that are larger than a certain size.  
**Recommendation:** Log temp files when they are larger than `work_mem`, as this indicates that increasing `work_mem` could be beneficial.
