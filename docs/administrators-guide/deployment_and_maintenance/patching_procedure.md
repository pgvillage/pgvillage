---
title: Patching
summary: A description of how to patch a PgVillage deployment
authors:
  - Sebas Mannem
  - Snehal Kapure
date: 2025-11-11
---

# Patching

PgVillage is specifically designed to guarantee High Availability (HA).

Patching should have little to no impact on the running system.

This documentation explains how patching is performed in this HA environment and what HA guarantees remain during the process.

## Dependencies

- repo with rom's (direct or through **Satellite**)

- patch per server (or per server group)

!!! note
    In a multicluser environment, create server groups
    - first nodes of all clusters
    - second nodes of all cluster
    - third nodes of all clusters
    - tooling systems and other
    Order (which of the thgre you call node 1) does not matter.
    The only thing that matters is that all three nodes are patched and rebooted separately.

- you can issue a switchover before patching (see #86 for documenting this)

- just patch (`dnf upgrade -y`) and then reboot the system

- check that all functions properly

- next server (or group)
