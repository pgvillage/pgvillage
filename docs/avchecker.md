# Introduction

Avchecker is een tool die de beschikbaarheid van PostgreSQL monitort.

He does this as follows:

- It's a Python script
- It makes a connection to a database
- It creates (if necessary) a table with one row
- Endless repeat
  - It reads back the last value
  - It writes away a new value
  - It checks if the difference between the previous and new value is longer than 7.5 seconds (adjustable)
  - If it takes longer than 7.5 seconds, then it reports on stdout

AVchecker draait op alle database servers als service en monitort:

- stolon: direct connection to the master
- proxy: connection to the master through stolon-proxy
- connection via the router on port 5432:

# Requirements and Dependencies

avchecker draait op de database servers als een service met meerdere instances.

avcheker heeft de volgende benodigdheden:

- service:
  - file: /etc/systemd/system/avchecker@.service (ansible managed)
  - Services:
    - avchecker@stolon.service
    - avchecker@proxy.service
    - avchecker@routerro.service
    - avchecker@routerrw.service
- script:
  - /opt/avchecker/avchecker.py (ansible managed)
  - Currently works with python 3.6.8
- linux user (ansible managed):
  - name: avchecker
  - authentication: client certificates (ansible managed)
- table:
  - database: postgres
  - definition: create table public.avchecker(last timezone); #(python script managed)
- configfiles:
  - /etc/default/avchecker\_proxy (configuration for connections via stolon-proxy)
  - /etc/default/avchecker\_stolon (configurations for direct connections to the master)
  - /etc/default/avchecker\_routerro (configurations for connections via haproxy port 5433)
  - /etc/default/avchecker\_routerrw (configurations for connections via haproxy port 5432)
- connections:
  - Each database server makes a connection for each avchecker instance.
  - A cluster with 4 nodes and the router makes thus 16 connections, of which 12 go to the master database
- endpoints
  - stolon: direct connection to the master database on one of the nodes
  - proxy: direct connection to stolon-proxy, which forwards to the master database
  - routerrw:
    - connection to haproxy on port 5432
    - from haproxy to stolon-proxy on the master
    - from stolon-proxy to the master
  - routerro:
    - connection to haproxy
    - connection to haproxy on port 5433
    - from haproxy to stoloeen of the standby instances

# Use

Het mooie aan avchecker is dat je de connectiviteit en beschikbaarheid van de postgres service op specifieke endpoints kunt monitoren.

Bijvoorbeeld

- If the router does not function properly or haphazardly, you will see that the avchecker@proxy and @stolon services do not provide notifications, but the avchecker@routerro and @routerrw services do.
  
- If the application encounters issues, but the avchecker@routerro and @routerrw services do not provide notifications, then the issue lies in the application, routing, or firewalling up to the router VIP.

Daarmee is de avchecker de ideale oplossing om te onderzoeken op welk niveau het issue kan liggen.

Avchecker draait continu als service en rapporteert in systemd journal als er issues zijn.

Daarbij is er een klein verschil tussen routerro en de andere services.

## # Commandos

Status control works best via `journalctl`:

```markdown
[root@acme-dvppg1db-server2 ~]# journalctl -efu avchecker@routerro | head
```

```markdown
-- Logs begin at Sun 2022-10-16 02:26:36 CEST. --
```

```markdown
Oct 16 00:38:06 acme-dvppg1db-server2 avchecker.py[629825]: cannot execute UPDATE in a read-only transaction
```

```
Oct 16 03:38:06 acme-dvppg1db-server2 avchecker.py[629825]: cannot execute UPDATE in a read-only transaction
```

```markdown
Oct 16 03:38:06 acme-dvppg1db-server2 avchecker.py[629825]: cannot execute UPDATE in a read-only transaction
```

```markdown
Oct 16 03:06:38 acme-dvppg1db-server2 avchecker.py[629825]: cannot execute UPDATE in a read-only transaction
```

```markdown
Oct 16 02:38:06 acme-dvppg1db-server2 avchecker.py[629825]: cannot execute UPDATE in a read-only transaction
```

```markdown
Oct 16 02:52:16 acme-dvppg1db-server2 avchecker.py[629825]: cannot execute UPDATE in a read-only transaction
```

```markdown
Oct 1602:52:16 acme-dvppg1db-server2 avchecker.py[629825]: cannot execute UPDATE in a read-only transaction
```

```markdown
Oct 16 05:02:16 acme-dvppg1db-server2 avchecker.py[629825]: cannot execute UPDATE in a read-only transaction
```

```markdown
Oct 1602:52:16 acme-dvppg1db-server2 avchecker.py[629825]: cannot execute UPDATE in a read-only transaction
```

```markdown
[root@acme-dvppg1db-server2 ~]# journalctl -efu avchecker@proxy
```

```
Logs begin at Sun 2022-10-16 02:26:36 CEST.
```

```markdown
Oct 16 20:25:28 acme-dvppg1db-server2 avchecker.py[629455]: 0:00:08.314879
```

^C

```markdown
[root@acme-dvppg1db-server2 ~]# journalctl -efu avchecker@stolon
```

```markdown
-- Logs begin at Sun 2022-10-16 02:26:36 CEST. --
```

^C

```markdown
[root@acme-dvppg1db-server2 ~]# journalctl -efu avchecker@routerrw
```

```markdown
-- Logs begin at Sun 2022-10-16 02:26:36 CEST.
```

^C

At the first router, we see an enormous amount of notifications.

The reason for this is that the update does not work, which is understandable and logical for routerro.

Er is besloten om deze meldingen wel in de output te zetten.

Het is immers belangrijk te weten dat we tegen een standby instance werken.

The downside is that there are more messages per second on stdout, causing the logs to fill up quickly. Hence the use of `| head 20`.

SYstemd managed dit gewoon prima en heeft hier niet veel last van.

Als alternatief kan besloten worden om bijvoorbeeld iedere n keer eenmelidng te geven en voor de rest te skippen.

This feature is (for now) not implemented.

For the proxy service, you see a notification:

```
Oct 16 20:25:28 acme-dvppg1db-server2 avchecker.py[629455]: 0:00:08.314879
```

This means that once the stolon proxy took a long time to reconnect and rewrite the data (8.31 seconds).

```markdown

```

This can mean that the stolon-proxy has been restarted or that the query took relatively long due to locking and loading.

De overige services geven geen meldingen.

## Controls

If it's important to check availability, then you do the following:

- Log in to one of the database servers (preferably not the master)
- Check the output of `journalctl` for all available services

### Everything

Enter the following commands

```
cat /var/log/syslog | grep 'avchecker\|proxy'
```

journalctl -efu avchecker@stolon

journalctl -efu avchecker@routerrw

```markdown
```

And check the following:
-

- The services have few interruptions  
  - Only routerro has many and recent rules, which only give notifications for `cannot execute UPDATE in a read-only transaction`  
  - All other interruptions are points to look at  
- Interruptions from different services don't coincide  
  - If interruptions for all avchecker@ services coincide, there was likely an issue that the application also experienced  
  - An interruption for a single service probably indicates longer transaction times (postgres was busy) and is likely not noticed by the application  
- The endpoint used by the application works properly  
  - Systems with a router config are probably routerw and routerro  
  - Systems without a router are likely stolon (direct to master)  
- The routerro service has recent rules  
  - and only gives notifications for `cannot execute UPDATE in a read-only transaction`  
  - if there are no recent rules, it could be that the avcheker@routerro service is down or that the entire environment has been down for a long time. First check the avcheker@stolon service and all related controls.

**NOTE:** For a quick end-to-end check of PostgreSQL with a router, check the `@routerrw` and `@routerro` services.

---

See at @routerrw and @routerro what to look out for…

### @stolon

journalctl -efu avchecker@stolon

Als je issues met avchecker@stolon herkend, ga die als eerste onderzoeken en oplossen:

Check if there is a master available, whether it can be reached from the current server, and ensure that the client certificates are functioning correctly (for example, they have not expired):

```markdown
[postgres@acme-dvppg1db-server1 ~]$ psql service=master
```

PostgreSQL (12.11)
-

```markdown
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
```

Type "help" for help.

```markdown
postgres=# \q
```

```
[postgres@acme-dvppg1db-server1 ~]$
```

Connecting with `service=master` does the following:

- Connects one-to-one to all nodes and
  - Performs a full SSL check (`sslmode=verify-full`)
  - Authenticates with client certificates (for user `postgres`)
  - Checks if it is a master instance
- Goes on to the next node if necessary

If this works then you already know a lot:

- The server operates with a server certificate that can be verified with the root certificate (~postgres/.postgresql/root.crt).
- Client certificates are functioning correctly, can be verified by the server, and have not expired.
  - NOTE: The entire chain expires simultaneously.
  - NOTE: There is certificate monitoring for this certificate!
- A master instance is available.

### @proxy

The next step is the stolon-proxy layer. Check it with

journalctl -efu avchecker@proxy

Als je issues met avchecker@proxy herkend, dan is het verstandig die op te lossen voor stolon-rw onderzocht wordt.

HAProxy connects through stolon-proxy, so issues with stOLON-PROXY also have consequences.

If `avchecker@stolon` works properly, the best explanation is that the stolon-proxy service did not start correctly (or at all).

Other issues may be related to firewalling (but the AvChecker also connects locally, and the stolon proxy connects to the master in the same way as the service=`stolon` check).

---

Eventueel kan stolon-proxy ook gecontroleerd worden met psql:

```markdown
[postgres@acme-dvppg1db-server1 ~]$ psql service=proxy
```

PostgreSQL (12.11)
-

```
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
```

Type "help" for help.
-

```markdown
postgres=# \q
```

```markdown
[postgres@acme-dvppg1db-server1 ~]$
```

Connecting with `service=proxy` does the following:

- Connect locally to the stolon-proxy port  
  - Stolon-proxy forwards traffic to the master
- Performs full SSL verification (`sslmode=verify-full`)
- Authenticates with client certificates (for user `postgres`)

If this works out then you already know a lot:

- The server operates with a server certificate that can be verified using the root certificate (~postgres/.postgresql/root.crt).
- The client certificates are functioning properly, can be verified by the server, and have not expired.
  - NOTE: The entire chain expires simultaneously.
  - NOTE: There is certificate monitoring for this certificate!!!
- A master instance is available.
- The local stolon-proxy can successfully connect to it.

Read more information in the documentation of [stolon](../../../../../../../../pages/xwiki/Infrastructuur/Team%3A+DBA/Werkinstrukties/Postgres/Bouwsteen/Stolon/WebHome.html).

---

### ```
@routerrw
```

If a router configuration is used (with [HAProxy](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/HAProxy/WebHome.html), [KeepaliveD](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Keepalived/WebHome.html) and [PgRoute66](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/PgRoute66/WebHome.html)), it is also monitored with the avchecker@routerrw service.

Als @stolon en @proxy issues geven kunnen deze het beste eerst worden opgelost.

If there are no issues with @stolon and @proxy, then the problem must be found in the router configuration.

---

This can best be investigated and resolved with the documentation of [keepalived](../../../../../../../../pages/xwiki/Infrastructuur/Team%3A+DBA/Werkinstrukties/Postgres/Bouwsteen/Keepalived/WebHome.html), [HAProxy](../../../../../../../../pages/xwiki/Infrastructuur/Team%3A+DBA/Werkinstrukties/Postgres/Bouwsteen/HAProxy/WebHome.html) and [pgRoute66](../../../../../../../../pages/xwiki/Infrastructuur/Team%3A+DBA/Werkinstrukties/Postgres/Bouwsteen/PgRoute66/WebHome.html).

The @routerrw service can also be very well used for an end-to-end check.

The best tool for end-to-end control is the `@routerro` service, but it does not verify if the router also forwards to the primary database server.

Therefore, @routerro should also be checked along with @routerrw:

---

journalctl -efu avchecker@routerrw

Check the output, ensuring that there are not (or very few) lines reporting a timeout.

If you don't see any issues but find that insufficient, then check with the [HAProxy](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/HAProxy/WebHome.html) documentation the output of the `show stat` command.

### @routerro

When a router configuration (using [HAProxy](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/HAProxy/WebHome.html), [KeepaliveD](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Keepalived/WebHome.html) and [PgRoute66](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/PgRoute66/WebHome.html)) is used, it is also monitored with the avchecker@routerrw service.

If there are issues with `@stolon` and `@proxy`, it's best to resolve these first.

---

If there are no issues from @stolon and @proxy, then the problem must be found in the router configuration.

This can best be investigated and resolved with the documentation of [keepalived](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Keepalived/WebHome.html), [HAProxy](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/HAProxy/WebHome.html) and [pgRoute66](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/PgRoute66/WebHome.html).

The @routerro service can also be very well used for an end-to-end check.

The main advantage of the routerro service is that it provides continuous output and affects all components.

Het resultaat van deze controle geeft dus meteen veel informatie.

journalctl -efu avchecker@routerro \| head

Check the output, ensuring primarily that the router service provides recent rules (such as "cannot execute UPDATE in a read-only transaction") and nothing else.

This tells you that:

- The router is still working properly.
- At least one of the other services is still updating the table.
- Streaming replication is still functioning (the other service updates the master and the changes reach this standby).
- The VIP is still linked to the server with a healthy HAProxy and pgrouter66 (i.e., the primary router is still working well).
- Server and client certificates are still working properly.

