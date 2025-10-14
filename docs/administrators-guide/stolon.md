# # Introduction

Stolon is a PostgreSQL High Availability tool that uses etcd (or another key/value store) for consensus.

Dat betekent dat etcd ervoor zorgt dat het hele cluster dezelfde config ziet en dat stolon met die config een HA Postgres cluster maakt en managed.

Stolon provides, among other things:

- One-time initialization of the cluster
- Cloning the master to the standbys
- Management of replication
- Management of High Availability
- Routing 25432 to 5432 on the master (stolon-proxy)
- Configuration management (pg_hba.conf and postgresql.conf)

Stolon is an open-source project maintained by the community at [https://github.com/sorintlab/stolon/](https://github.com/sorintlab/stolon/).

Binnen acme wordt een rpm gebruikt welke beschikbaar wordt gesteld middels

- [https://github.com/MannemSolutions/rpmbuilder/releases](https://github.com/MannemSolutions/rpmbuilder/releases)
- [https://repo.mannemsolutions.nl/yum/pgvillage/](https://repo.mannemsolutions.nl/yum/pgvillage/)

At the time of this writing, an adapted RPM is being used, which is based on:

- The latest version of [https://github.com/sorintlab/stolon/tags](https://github.com/sorintlab/stolon/tags)
- This change: [https://github.com/sorintlab/stolon/pull/865](https://github.com/sorintlab/stolon/pull/865) (for use in combination with a separate WAL location)
- This change: [https://github.com/sorintlab/stolon/pull/870](https://github.com/sorintlab/stolon/pull/870) (for use in combination with client certificates)

De intentie is om deze 2 pull requests gemerged te kriijgen zodat hier geen aparte builds meer nodig zijn.

# Requirements

For a stolon, the following components are needed:

- the stolon binaries  
  - stolonctl (cli), stolon-keeper (postgres manager), stolon-proxy (tcp proxy voor traffic forwarding naar de master), stolon-sentinel (cluster manager)  
  - are deployed in /usr/local/bin/ via the rpm  
- systemd files  
  - stolon-keeper.service, stolon-proxy.service, stolon-sentinel.service  
  - are deployed by Ansible in /etc/systemd/system/  
- The stolon config files  
  - stolon-stkeeper, stolon-stproxy, stolon-stsentinel  
  - are deployed by Ansible in /etc/sysconfig/  
- a working etcd and configuration to access it  
  - We use the standard ports, but if not, then the custom port must be configured  
  - We don't yet use etcd with tls / client certificate, but if so, then the certificates need to be available and configured  
- stolon takes care of all postgres matters, including initialization, cloning, and starting Postgres  
  - stolon needs the paths to the correct postgres binaries, datadir, and waldir  
  - is located in /etc/sysconfig/stolon-stkeeper

# Usage

Configuratie en aansturing van stolon is volledig geimplementeerd in Ansible (de [stolon rol](https://gitlab.int.corp.com/gurus-db-team/ansible-postgres/-/tree/dev/roles/stolon)).

Furthermore, it is important to be able to use `stolonctl` in particular to query information and (if necessary) make adjustments.

`stolonctl` requires a few configuration parameters so that it knows how to connect to etcd and which cluster it operates on (we use only one, but the configuration is still necessary).
```

Met deze parameters ingesteld kan stolonctl worden gebruikt onder elke user (connect naar etcd via de API).

A few examples:

## Check Status

#instellenconfigbenodigdvoorstolonctl

```markdown
export STOLONCTL_CLUSTER_NAME=stolon-cluster
```

```markdown
export STOLON_CTL_STORE_BACKEND=etcdv3
```

#opvragenclusterstatus

```markdown
[root@acme-dvppg1db-server1 sysconfig]#/usr/local/bin/stolonctl status
```

===Activesentinels===

IDLEADER

3b05c06etrue

6b467314false

7ae581fffalse

902f6b4dfalse

===Activeproxies===

ID

09605cac

308fcad1

4a1634ea

534074d4

### Keepers

UIDHEALTHYPGLISTENADDRESSPGHEALTHYPGWANTEDGENERATIONPGCURRENTGENERATION

```markdown
acme_dvppg1db_server1true10.0.4.42:5432true33
```

```
acme_dvppg1db_server2 true 10.0.4.43:5432 true 55
```

```
acme_dvppg1db_server3true10.0.4.44:5432true33
```

acme\_dvppg1db\_server4true10.0.4.45:5432true33

```markdown
===ClusterInfo===
```

MasterKeeper:acme\_dvppg1db\_server2

==Keepers/DBtree==

---

```markdown
acme_dvppg1db_server2 (master)
```

```markdown
├─acme_dvppg1db_server4
```

```
├- acme_dvppg1db_server3
```

```markdown
└─acme_dvppg1db_server1
```

## Query the current configuration

#set up config required for stolonctl

```markdown
export STOLONCTL_CLUSTER_NAME=stolen-cluster
```

```markdown
export STOLONCTL_STORE_BACKEND=etcdv3
```

#Request cluster spec

```
[root@acme-dvppg1db-server1 sysconfig]# /usr/local/bin/stolonctl spec
```

Outcome:

{

```json
"initMode": "new",
```

```markdown
"defaultSUReplAccessMode": "strict",
```

```markdown
"pgParameters": {
```

```markdown
"archive_command": "/opt/wal-g/scripts/archive.sh %p",
```

```markdown
"archive_mode": "on",
```

```markdown
"datestyle": "ISO, MDY",
```

```markdown
"default_text_search_config": "pg_catalog.english",
```

```markdown
"dynamic_shared_memory_type": "posix",
```

```markdown
"effective_cache_size": "5822MB",
```

```markdown
"idle_in_transaction_session_timeout": "60 minutes",
```

"lc\_messages": "en\_US.UTF-8",

```json
"LC_MONETARY": "en_US.UTF-8"
```

```json
"lc_numeric": "C.UTF-8",
```

```markdown
"lc_time": "en_US.UTF-8",
```

```json
"listen_addresses": "['*']",
```

```markdown
"log_connections": "on",
```

```markdown
"log_destination": "csvlog",
```

```markdown
"log_directory": "/var/log/postgresql",
```

```markdown
"log_disconnections": "on",
```

```markdown
"log_error_verbosity": "verbose",
```

```
"log_file_mode": "0600",
```

```markdown
"log_filename": "postgresql-%Y%m%d.log",
```

```markdown
"log_line_prefix": "%m [%p%: [%l-1] db=%d,user=%u,app=%a,client=%h ",
```

```markdown
"log_min_duration_statement": "5000",
```

```
"log_min_error_statement": "error",
```

```markdown
"log_min_messages": "warning",
```

```markdown
"log_rotation_age": "1d",
```

```markdown
"log_rotation_size": "1GB",
```

```markdown
"log_statement": "ddl",
```

```markdown
"log_timezone": "Europe/Amsterdam",
```

```markdown
"log_truncate_on_rotation": "on",
```

```markdown
"logging_collector": "on",
```

```
"max_connections": "100",
```

```
"max_parallel_workers": "8",
```

```markdown
"max_parallel_workers_per_gather": "2",
```

```markdown
"max_wal_senders": "3",
```

```
"max_wal_size": "76762MB",
```

```markdown
"max_worker_processes": "8",
```

```markdown
"min_wal_size": "25587MB",
```

```markdown
"restore_command": "/opt/wal-g/scripts/archive_restore.sh %f %p",
```

```markdown
"shared_buffers": "1940MB",
```

"ssl": "true",

```markdown
"ssl_ca_file": "/data/postgres/data/certs/root.crt",
```

```markdown
"ssl_cert_file": "/data/postgres/data/certs/server.crt",
```

```markdown
"ssl_key_file": "/data/postgres/data/certs/server.key",
```

```markdown
"statement_timeout": "60min",
```

```markdown
"timezone": "Europe/Amsterdam",
```

```json
"wal_level": "archive",
```

```markdown
"work_mem": "29813kB"
```

},

```
"pgHBA": [
```

```plaintext
[local] all all ident
```

```
"hostssl postgres avchecker samenet cert",
```

```markdown
hostssl vcbe_db cims_rw sanet scram-sha-256,
```

"hostssl all all samenet cert"

\]

}

## Update cluster config

#```markdown
set up configuration required for stolonctl
```

```markdown
export STOLONCTL_CLUSTER_NAME=stolon-cluster
```

```markdown
export STOLONCTL_STORE_BACKEND=etcdv3
```

#adjust cluster spec

/usr/local/bin/stolonctl update -f /data/postgres/data/stolon\_custom\_config.yml --patch

The command should give no output (if it works correctly).

### # Patch

Incidentally, the patch offers options to adjust configurations, but this configuration "comes alongside."

Settings that do not receive a value from the custom_config file retain their current configuration.

The entire configuration can also be completely adjusted by first setting it with the `spec` option in a file, then making adjustments, and finally reloading without the `--patch` option using `stolonctl update`.

#```markdown
set up configuration required for stolonctl
```

```markdown
export STOLONCTL_CLUSTER_NAME=stolon-cluster
```

```markdown
export STOLONCTL_STORE_BACKEND=etcdv3
```

\# dumping

```bash
/usr/local/bin/stolonctl spec > /tmp/stolon_custom_config.yml
```

\# adjust

```markdown
edit /tmp/stolon_custom_config.yml
```

#Check if it's still JSON.

cat /tmp/stolon\_custom\_config.yml \| python -m json.tool

#read cluster specification

```
/usr/local/bin/stolonctl update -f /data/postgres/data/stolon_custom_config.yml
```

## Help

To list all options of `stolonctl`, you can run the command with the `-h` option:

```bash
stolonctl -h
```

Or use the `--help` option:

```bash
stolonctl --help
```

```markdown
[root@acme-dvppg1db-server1 sysconfig]# /usr/local/bin/stolonctl
```

stolon command line client

Usage:

stolonctl \[flags\]

```markdown
stolonctl [command]
```

```markdown
Available Commands:
```

manage cluster data  
Manage current cluster data

Failkeeper - Force keeper as "temporarily" failed. The sentinel will compute new cluster data, considering it as failed, and then restore its state to the actual one.

help  
&nbsp;&nbsp;Help about any command

initialize    Initialize a new cluster

```markdown
promote      Een back-upcluster bevorderen naar een primaire cluster
```
```

```markdown
register     Register stolon keepers for service discovery
```

removekeeper Removes keeper from cluster data

```markdown
spec      Retrieve the current cluster specification
```

```
status      Display the current cluster status
```

update  
Update a cluster specification

```markdown
version     Display the version
```

Flags:

```markdown
--cluster-name string   cluster name
```

```
-h, --help       help for stolonctl
```

```markdown
--kube-context string           name of the kubeconfig context to use
```
```

```markdown
--kube-namespace string        name of the Kubernetes namespace to use
```

---

`--kube-resource-kind string` the Kubernetes resource kind to be used to store Stolon cluster data and perform sentinel leader election (currently, only `"configmap"` is supported).

```markdown
--kubeconfig string               path to kubeconfig file. Overrides `$KUBECONFIG`
```

```markdown
--log-level string                debug, info (default), warn or error (default "info")
```

```markdown
--metrics-listen-address string metrics listen address, e.g., "0.0.0.0:8080" (disabled by default)
```

---

```markdown
--store-backend string         store backend type (etcdv2/etcd, etcdv3, consul, or kubernetes)
```
```

```markdown
--store-ca-file string        verify certificates of HTTPS-enabled store servers using this CA bundle
```

```markdown
--store-cert-file string  certificate file for client identification to the store
```

---

```markdown
--store-endpoints string   a comma-delimited list of store endpoints (use https scheme for TLS communication) (defaults: http://127.0.0.1:2379 for etcd, http://127.0.0.1:8500 for consul)
```

`--store-key string` private key file for client identification to the store

```
--store-prefix string              the store base prefix (default "stolon/cluster")
```

```markdown
--store-skip-tls-verify       skip store certificate verification (insecure!!!)
```
```

```markdown
--store-timeout duration      store request timeout (default 5s)
```

---

```markdown
--version                             version for stolonctl
```

Gebruik "stolonctl [command] --help" voor meer informatie over een opdracht.

---

## Wanneer niets anders werkt

We hebben een specifieke situatie gehad waarbij stolon niet meer goed wilde starten.

The situation was as follows:

- The 3rd node was (according to Stolon) the master.
- The 3rd node had issues with the datadir and refused to start again.
- The other nodes were also not okay anymore.

This has been resolved by reinitializing the cluster:

---

#Set up configuration required for `stolonctl`.

```markdown
export STOLONCTL_CLUSTER_NAME=stolon-cluster
```

```markdown
export STOLONCTL_STORE_BACKEND=etcdv3
```

```markdown
# reinitialize
```

### NOTE: Preferably perform a point-in-time restore!!!

---

/usr/local/bin/stolonctl init

There is a "are you sure" prompt and then the cluster information is cleared afterwards.

Daarna is Ansible gewoon weer uitgevoerd en een nieuw cluster gecreerd.

Daarna is de backup weg gegooid en hersteld.

Dit is geen ideale optie en wordt ook niet aangeraden.

It is better to use the [Point in time restore](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Onderhoud/Point+in+Time+Restore/WebHome.html) procedure. It also executes an init but with the PITR option so that the latest backup is restored from WAL-G.

---

