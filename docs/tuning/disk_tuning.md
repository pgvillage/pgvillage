# PostgreSQL Disk Tuning Guide

This page describes PostgreSQL configuration options that have an **immediate impact on disk utilization and consumption**, and how to tune them.

---

## Parameters

### 1. `min_wal_size`

When PostgreSQL WAL files take less space than this setting, the existing WAL files are **reused instead of removed and recreated**, which is a cheaper operating system operation.  

**Recommendation:**  
- Always use a **separate filesystem** for WAL files.  
- Set `min_wal_size` to **25% of the filesystem size**.

---

### 2. `max_wal_size`

When PostgreSQL WAL files take more space than this setting, PostgreSQL **tries to archive as much as possible** to free up WAL space.  

**Recommendation:**  
- Always use a **separate filesystem** for WAL files.  
- Set `max_wal_size` to **75% of the filesystem size**.

---

### 3. `checkpoint_timeout`

Checkpoints automatically occur as needed, but if no checkpoint occurs within this duration, PostgreSQL **forces a checkpoint** after the timeout.  

This ensures:  
1. WAL files are still archived to the archive location, **reducing RPO** (Recovery Point Objective) during a disaster.  
   - This is less critical in some setups.  
2. Checkpoints have **less work to do** when they occur.

**Recommendation:**  
Align this timeout with the **maximum RPO target** during a disaster (e.g., when the primary DC fails and the standby in DR is not online).

---

### 4. `hot_standby_feedback`

When this setting is **off**, standby servers do **not send feedback** to the primary about active queries.  
This can lead to the **primary cleaning up transaction info** that is still required by queries on the standby, resulting in a **“snapshot too old”** failure.

When switched **on**, standby servers **report query info** back to the primary.  

**Behavior:**  
1. Ensures that **snapshot info** for standby queries remains preserved.  
2. Introduces risk — snapshot info may not be cleaned, causing **WAL file buildup** and possible **WAL location flooding**.
