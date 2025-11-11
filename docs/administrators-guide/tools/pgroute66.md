---
title: PgRoute66
summary: A description of PgRoute66 which can be used to control where HAProxy outes traffic
authors:
  - Sebas Mannem
  - Snehal Kapure
date: 2025-11-11
---

# PgRoute66

The PostgreSQL building block can optionally be executed with a PostgreSQL router.

The router consists of a HA setup with 2 servers, each having a Virtual IP address and running [HAProxy](haproxy.md) and PgRoute66 on both nodes.

HAProxy is used to route TCP traffic to the correct PostgreSQL server(s), and PgRoute66 is used to control HAProxy.
[HAProxy](haproxy.md).

Pgroute66 is an open-source project and is maintained by the community.

- [rpmbuilder Releases on GitHub](https://github.com/pgvillage-build/rpmbuilder)
- [pgvillage Repository](https://github.com/pgvillage/pgvillage/releases)

## Requirements

For the PostgreSQL router setup, the following components are required for PgRoute66 to function correctly:

- The binary is deployed via the **depgroute66** RPM (from Satellite).
- The PgRoute66 configuration file is located at:  
  `/etc/pgroute66/config.yaml`  
  and is deployed and managed through **Ansible**.
- The PgRoute66 service file can be found at:  
  `/etc/systemd/system/pgroute66.service`  
  and is also deployed and managed through **Ansible**.
- PgRoute66 runs under the **pgroute66** Linux user, which is deployed and managed through **Ansible**.
- PgRoute66 uses **mTLS** for PostgreSQL connections through:
  - a client certificate and key (deployed and managed through Ansible)
  - a root certificate to verify the server certificate (deployed and managed through Ansible)
  - all three located in `~pgroute66/.postgresql/`

---

## Use

PgRoute66 runs as a service and does not require any manual actions.

For troubleshooting, check the service logs:

---

```bash
[me@pgv-dvppg1pr-server2 ~] $ sudo journalctl -efu pgroute66.service

-- Logs begin at Thu 2022-10-13 02:09:58 CEST.
Oct 13 22:29:19 pgv-dvppg1pr-server2 pgroute66[1608249]: [GIN] 2022/10/13 - 22:29:19 | 200 | 1.780668ms | 127.0.0.1 | GET "/v1/standbys"
Oct 13 22:29:19 pgv-dvppg1pr-server2 pgroute66[1608249]: [GIN] 2022/10/13 - 22:29:19 | 200 | 1.951384ms | 127.0.0.1 | GET "/v1/primary"
Oct 13 22:29:21 pgv-dvppg1pr-server2 pgroute66[1608249]: [GIN] 2022/10/13 - 22:29:21 | 200 | 1.812061ms | 127.0.0.1 | GET "/v1/primary"
Oct 13 22:29:19 pgv-dvppg1pr-server2 pgroute66[1608249]: [GIN] 2022/10/13 - 22:29:19 | 200 | 1.986874ms | 127.0.0.1 | GET "/v1/standbys"
Oct 13 22:29:20 pgv-dvppg1pr-server2 pgroute66[1608249]: [GIN]2022/10/13 - 22:29:20 | 200 | 1.917752ms |   127.0.0.1 | GET "/v1/standbys"
Oct 13 22:29:20 pgv-dvppg1pr-server2 pgroute66[1608249]: [GIN]2022/10/13 - 22:29:20 | 200 | 1.69516ms |     127.0.0.1 | GET "/v1/primary"
Oct 13 22:29:21 pgv-dvppg1pr-server2 pgroute66[1608249]: [GIN]2022/10/13 - 22:29:21 | 200 | 1.957809ms |   127.0.0.1 | GET "/v1/standbys"
Oct 13 22:29:21 pgv-dvppg1pr-server2 pgroute66[1608249]: [GIN]2022/10/13 - 22:29:21 | 200 | 1.812061ms |   127.0.0.1 | GET  "/v1/primary"
Oct 13 22:29:21 pgv-dvppg1pr-server2 pgroute66[1608249]: [GIN]2022/10/13 - 22:29:21 | 200 | 1.606772ms |  127.0.0.1 | GET "/v1/standbys"
```

If necessary, the logging can also be temporarily increased by raising the log level to debug in the config file:

```bash
[me@pgv-dvppg1pr-server2 ~]$ vim /etc/pgroute66/config.yaml

[me@pgv-dvppg1pr-server2 ~]$ grep loglevel /etc/pgroute66/config.yaml

loglevel: develop

[me@pgv-dvppg1pr-server2 ~]$ systemctl restart pgroute66.service
```

!!! note

    HAProxy and PgRoute66 are loosely coupled, and a successful restart of the pgroute66 has no impact on the availability of the service.

---

## ToDo

PgRoute66 could be enhanced to detect the primary database based on Stolon configuration in etcd.

In that case, PgRoute66 can run on the database server along with it and HAProxy can be used without the `external-check` and `insecure-fork-wanted` options.
