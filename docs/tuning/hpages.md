# PostgreSQL HugePages Configuration Guide

This guide provides recommended **HugePages settings** for PostgreSQL based on the server's available memory (RAM).  

---

## Recommended HugePages Settings

| Server RAM | Recommended HugePages |
|-------------|-----------------------|
| 8 GB | 1150 |
| 16 GB | 2190 |
| 24 GB | 3241 |
| 32 GB | 4289 |

## Running PostgreSQL with `max_connections = 1000`

Before testing HugePages configuration, stop the PostgreSQL service:

```bash
sudo systemctl stop postgres
```

### 8 GB RAM Server

**Calculation:**  
25% Shared_buffers = 2GB = 1024 HP_blocks + 126 blocks overhead

**Command:**
```bash
/usr/pgsql-16/bin/postgres --shared-buffers=2GB -D /pgdata/fenrir_dev -C shared_memory_size_in_huge_pages

# Output:
1150
```

---

### 16 GB RAM Server

**Calculation:**  
25% Shared_buffers = 4GB = 2048 HP_blocks + 142 blocks overhead

**Command:**
```bash
/usr/pgsql-16/bin/postgres --shared-buffers=4GB -D /pgdata/fenrir_dev -C shared_memory_size_in_huge_pages

# Output:
2190
```

---

### 24 GB RAM Server

**Calculation:**  
25% Shared_buffers = 6GB = 3072 HP_blocks

**Command:**
```bash
/usr/pgsql-16/bin/postgres --shared-buffers=6GB -D /pgdata/fenrir_dev -C shared_memory_size_in_huge_pages

# Output:
3241
```

---

### 32 GB RAM Server

**Calculation:**  
25% Shared_buffers = 8GB = 4096 HP_blocks

**Command:**
```bash
/usr/pgsql-16/bin/postgres --shared-buffers=8GB -D /pgdata/fenrir_dev -C shared_memory_size_in_huge_pages

# Output:
4289
```