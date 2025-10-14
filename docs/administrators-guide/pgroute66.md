# # Introduction

De PostgreSQL bouwsteen kan eventueel worden uitgevoerd met een PostgreSQL router.

The router consists of a HA setup with 2 servers, each having a Virtual IP address and running [HAProxy](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/HAProxy/WebHome.html) and PgRoute66 on both nodes.

[HAProxy](../../../../../../../../pages/xwiki/Infrastructuur/Team%3A+DBA/Werkinstrukties/Postgres/Bouwsteen/HAProxy/WebHome.html) is used to route TCP traffic to the correct PostgreSQL server(s), and PgRoute66 is used to control [HAProxy](../../../../../../../../pages/xwiki/Infrastructuur/Team%3A+DBA/Werkinstrukties/Postgres/Bouwsteen/HAProxy/WebHome.html).

```markdown
Pgroute66 is an open-source project and is maintained by the community at [https://github.com/mannemSolutions/pgroute66/](https://github.com/mannemSolutions/pgroute66/).
```
```

Binnen acme wordt een rpm gebruikt welke beschikbaar wordt gesteld middels

- [rpmbuilder Releases on GitHub](https://github.com/MannemSolutions/rpmbuilder/releases)
- [pgvillage Repository at Mannem Solutions](https://repo.mannemsolutions.nl/yum/pgvillage/)

# Requirements

Op de PostgreSQL router setup zijn de volgende dingen nodig om PgRoute66 goed te laten functioneren:

- The binary is deployed via the depgroute66 rpm (from Satellite).
- The pgroute66 configuration can be found in `/etc/pgroute66/config.yaml` and is deployed and managed through Ansible.
- The pgroute66 service file can be found in `/etc/systemd/system/pgroute66.service` and is deployed and managed through Ansible.
- PgRoute66 runs under a pgroute66 Linux user, which is deployed and managed through Ansible.
- PgRoute66 uses mTLS for PostgreSQL connections through:
  - a client certificate and key (deployed and managed through Ansible)
  - a root certificate to verify the server certificate (deployed and managed through Ansible)
  - All three are located in `~pgroute66/.postgresql/`

# Use

PgRoute66 draait als service en vergt geen verdere handmatige acties.

For troubleshooting, the output of the service can be checked:

---

```
[me@acme-dvppg1pr-server2 ~] $ sudo journalctl -efu pgroute66.service
```

```markdown
-- Logs begin at Thu 2022-10-13 02:09:58 CEST. --
```

```
Oct 13 22:29:19 acme-dvppg1pr-server2 pgroute66[1608249]: [GIN]2022/10/13 - 22:29:19 | 200 | 1.780668ms | 127.0.0.1 | GET "/v1/standbys"
```

```
Oct 1322:29:19 acme-dvppg1pr-server2 pgroute66[1608249]: [GIN]2022/10/13 - 22:29:19 | 200 |    1.931538ms |       127.0.0.1 | GET      "/v1/standbys"
```

```
Oct 13 22:29:19 acme-dvppg1pr-server2 pgroute66[1608249]: [GIN] 2022/10/13 - 22:29:19 | 200 |     1.951384ms |       127.0.0.1 | GET   "/v1/primary"
```

```
Oct 13 22:29:19 acme-dvppg1pr-server2 pgroute66[1608249]: [GIN] 2022/10/13 - 22:29:19 | 200 |    1.986874ms |       127.0.0.1 | GET      "/v1/standbys"
```

```
Oct 1322:29:20 acme-dvppg1pr-server2 pgroute66[1608249]: [GIN]2022/10/13 - 22:29:20 | 200 |     1.917752ms |         127.0.0.1 | GET      "/v1/standbys"
```

```
Oct 1322:29:20 acme-dvppg1pr-server2 pgroute66[1608249]: [GIN]2022/10/13 - 22:29:20 | 200 |      1.69516ms |     127.0.0.1 | GET "/v1/primary"
```

```
Oct 1322:29:21 acme-dvppg1pr-server2 pgroute66[1608249]: [GIN]2022/10/13 - 22:29:21 | 200 |      1.957809ms |       127.0.0.1 | GET    "/v1/standbys"
```

```markdown
Oct 13 22:29:21 acme-dvppg1pr-server2 pgroute66[1608249]: [GIN]2022/10/13 - 22:29:21 | 200 |     1.812061ms |        127.0.0.1 | GET      "/v1/primary"
```

```
Oct 13 22:29:21 acme-dvppg1pr-server2 pgroute66[1608249]: [GIN]2022/10/13 - 22:29:21 | 200 |     1.606772ms |      127.0.0.1 | GET "/v1/standbys"
```

...

Eventueel kan de logging ook (tijdelijk) verhoogd worden door in de configfile de loglevel te verhogen naar debug:

```
[me@acme-dvppg1pr-server2 ~]$ vim /etc/pgroute66/config.yaml
```

```markdown
[me@acme-dvppg1pr-server2 ~]$ grep loglevel /etc/pgroute66/config.yaml
```

```
loglevel: develop
```

```markdown
[me@acme-dvppg1pr-server2 ~]$ systemctl restart pgroute66.service
```

**Note**: HAProxy and PgRoute66 are loosely coupled, and a successful restart of the pgroute66 has no impact on the availability of the service.

---

# ToDo

Eventueel kan PgRoute66 worden aangepast zodat deze de primary kan detecteren op basis van stolon confi in etcd.

In that case, PgRoute66 can run on the database server along with it and HAProxy can be used without the `external-check` and `insecure-fork-wanted` options.

