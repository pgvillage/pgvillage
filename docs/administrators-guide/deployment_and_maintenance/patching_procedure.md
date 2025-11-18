---
title: Patching
summary: A description of how to patch a PgVillage deployment
authors:
  - Sebas Mannem
  - Snehal Kapure
date: 2025-11-11
---

# Patching

The SBB platform is specifically designed to guarantee High Availability (HA).

Patching should have little to no impact on the running system.

This documentation explains how patching is performed in this HA environment and what HA guarantees remain during the process.

## Dependencies

- **Satellite:**   
  - [https://gurus-satl6-server1.int.corp.com/](https://gurus-satl6-server1.int.corp.com/)
  - Here, the various patchsets per environment are maintained

- **SHS Patch Process**
  - In this process, servers are divided into server groups (A, B, C, and D)
  - The server groups are patched as a whole
  - Patching is done entirely automatically
  - The DBA team remains informed about the patching

- **Demote Script**
  - ~postgres/bin/demote.sh (Ansible managed [in the stolon role](https://gitlab.int.corp.com/gurus-db-team/ansible-postgres/-/blob/dev/roles/stolon/files/bin/demote.sh))
  - Is executed before patching is performed
  - Ensures that "this server is no longer a master"
  - Only works if everything comes back correctly after patching

## Facts

- The starting point is not that there are no issues
  - the starting point is that all issues in A are encountered and resolved
  - the starting point is that at P all issues have been encountered and resolved

- `~postgres/bin/demote.sh`
  - is executed by the patching process so that switchover can be carried out quickly
  - This has an impact on running transactions (they are canceled, application may reinitiate them)
  - This has an impact on maintenance jobs
  
- After ~postgres/bin/demote.sh, patching and reboot have almost no more impact
  - The impact is a catch-up when the database server is back from the reboot
  - The impact is also that read-only (RO) queries are terminated if the server reboots (see [router](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Keepalived/WebHome.html)).

- Application clients must
  - use [Client Connect Failover](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Clients/WebHome.html), or
  - use [a router with a VIP](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Keepalived/WebHome.html)
  
- The router uses KeepAliveD and is configured without preferred master
  - the server that was master and reboots causes a failover to the other router
  - per patch round, a maximum of 2 failovers can occur
  - servers are patched separately, so there is always one available
    - as long as after a patch round of a group an intake takes place
