---
title: Troubleshooting guide
summary: A guide to aid when troubleshooting issues
authors:
  - Sebas Mannem
  - Snehal Kapure
date: 2025-11-11
---

# On-Call Troubleshooting Guide

This page helps you during on-call duty to quickly analyze issues and determine the correct resolution path.

Start by identifying the type of problem you are dealing with, then follow the referenced documentation to analyze and resolve it correctly.

---

## Application does not have access to Postgres

An application requires three key components to successfully access PostgreSQL:

1. **An available PostgreSQL instance**
2. **Network connectivity**
3. **A valid configuration**

Therefore, the first step in troubleshooting is to identify which of these areas is causing the issue.

---

### 1. Check if Postgres itself is available:

   - Use the checks described in the [avchecker](../../tools/avchecker.md) documentation.
   - Resolve all issues so that avchecker reports again that Postgres is available.

### 2. Check if Postgres is available for the application:
   - Network problems are outside the scope of the DBA.

  In principle, these kinds of issues are always resolved by network management, or Container Hosting (CHP).

  Conduct the direction yourself, stay engaged in the process and provide clear information on what works (availability within the Postgres architecture) and what does not work (connectivity of the application to the VIP or to Postgres).

- For more information, see the documentation on [Connections and Connection Paths](connectivity.md)

### 3. Check if the client is correctly configured:

!!! note

    Issues caused by incorrect configuration usually result from recent changes and are not part of service availability work.

Ensure that the client configuration includes:

- **Host:** VIP, or a list of PostgreSQL hosts (comma-separated)
- **Port:**
  - 5432 (RW on VIP)
  - 5433 (RO on VIP)
  - 25432 (via stolon-proxy)
  - 5432 (direct connection)
- **Username** and **database name**
- **Authentication:** client certificates (preferred) or password
- **Session targeting:**  
    - `target_session_attrs` (libpq)  
    - `targetServerType` (JDBC)
- **SSL mode:** `sslmode=verify-full`

  Additionally:

  - Verify the PostgreSQL **pg_hba.conf** configuration.
  - Review **application logs** with the app administrator.
  - Check for **PostgreSQL log errors**.
  - For more information, see the documentation on [client configuration](../../users-guide/clients.md) and about [mTLS](../../architecture/mtls.md).

---

## Recovery / Emergency Restore

It may happen that an application administrator requests a point-in-time restore to be performed, for example because too much data has been deleted or to roll back database changes from an application update.

It is also possible that due to a disaster scenario all replica instances are no longer available and can only be restored using a Restore (latest point in time).

In both situations, this can be resolved by referring to the [Point in Time Restore](../deployment_and_maintenance/point_in_time_restore.md) documentation.

!!! note

    In almost all cases, the reason for a point-in-time restore is not due to an error in the Postgres architecture or by the DBA.


Therefore, in almost all cases, a point-in-time restore does not result in service downtime.  
Take the time to perform a proper point-in-time restore.
