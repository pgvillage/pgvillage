---
title: Nagios - multiinstance
summary: Disabling the nagios role for multi-instance deployments
authors:
  - Sebas Mannem
date: 2026-10-13
---

# Nagios - multi-instance

The nagios role can be disabled in the nagios config (e.g. `environments/cluster1/group_vars/all/nagios.yml`).

## `nagios_enabled`

Boolean to enable or disable the nagios role. It is set to `false` in this inventory
(the README also requires this for Ubuntu deployments).

```yaml
nagios_enabled: false
```
