---
title: Nagios
summary: A description of nagios checks that can be leveraged to implement alerting
authors:
  - Sebas Mannem
  - Snehal Kapure
date: 2025-11-11
---

# Nagios

For the standard PostgreSQL building block, monitoring has been implemented using **Nagios**.

This documentation describes how it has been implemented, as well as things that can be better.

---

## Requirements and Dependencies

- [check_postgres](https://bucardo.org/check_postgres/)
- ansible-postgres [role for nagios](https://gitlab.int.corp.com/gurus-db-team/ansible-postgres/-/tree/dev/roles/nagios)
- nagios server (ansible managed with role):

  - `gurus-nagios-server1.int.corp.com:/opt/nagios/etc/host.cfg.d/{dbserver fqdn}.cfg`
  - `gurus-nagios-server1.int.corp.com:/opt/nagios/etc/host.cfg.d/{dbserver fqdn}-custom.cfg`

- db servers (ansible managed with role):
  - `/etc/nrpe.d/check_certs.cfg`
  - `/etc/nrpe.d/check_postgres.cfg`
  - `/etc/nrpe.d/multi_check.cfg`
  - `/etc/nrpe.d/proces_check.cfg`
  - `/etc/nrpe.d/service_check.cfg`
  - `/opt/gurus/nrpe/pg_multi_db_checks.sh`
  - `/opt/gurus/nrpe/check_postgres_*`
  - `/opt/gurus/nrpe/check_certs.sh`

---

## Additional information

The configuration is managed in the Ansible inventory at `environments/[ENV]/group_vars/hacluster/nagios.yml`: `nagios_checks`

For the POC environment, the configuration on Nagios itself is disabled:

---

```yaml
# File: environments/poc/group_vars/hacluster/nagios.yml
nagios_servers[1].enabled: false
```

## Todo

The following things can be better:

- Nagios monitoring on certificates
  - Currently all regularly monitored for `~postgres/.postgresql/postgresql.crt`
  - Requires a sudo rule for the nrpe user
  - Redesign of the solution would be immensely helpful
- [https://github.com/Vonng/pg_exporter](https://github.com/Vonng/pg_exporter)
  - Another solution
  - Newer and likely better than check_postgres
  - Requires some scripting (but much simpler from the check_postgres pl script)
- Monitoring on wal-g
  - Custom to build
  - How do we get the retention?

---

**2-12-2022: A manual action for now, to ensure the proper functioning of the certificate check:**

**Add the file `10_sudo_rule_nrpe_postgres` to `/etc/sudoers.d/` with the following content:**

```bash
nrpe ALL=(postgres) NOPASSWD: ALL
```
