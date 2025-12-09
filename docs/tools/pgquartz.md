---
title: PgQuarts
summary: A description of the PostgreSQL job scheduler shipped with PgVillage
authors:
  - Sebas Mannem
  - Snehal Kapure
date: 2025-11-11
---

# PgQuartz

PgQuartz is a community tool used to configure and execute scheduled jobs in PostgreSQL environments.

It reads and runs job configurations defined in YAML files.

A job definition can include:

```yaml
# Example structure

steps: # What actions need to be performed
checks: # How to verify that everything is working correctly
connections: # Definitions of connections to the PostgreSQL environment
etcd_config: # pgquartz can wait for the same job on other servers via etcd
general_config: # General settings (debug mode, log file path, parallel execution, etc.)
```

## Requirements and Dependencies

PgQuartz is installed by default with the PostgreSQL SBB, but it is only used for vaccination certificates.

More information:

- [Inventory](inventory.md)
- [PgQuartz](https://github.com/pgvillage-tools/pgquartz)

