# Stolon

**Stolon** is a PostgreSQL High Availability (HA) tool that uses **etcd** (or another key/value store) for consensus.

This means etcd ensures the entire cluster shares the same configuration, and Stolon uses that configuration to create and manage an HA PostgreSQL cluster.

Stolon provides, among other things:

- One-time initialization of the cluster
- Cloning the master to the standbys
- Management of replication
- Management of High Availability
- Routing 25432 to 5432 on the master (stolon-proxy)
- Configuration management (pg_hba.conf and postgresql.conf)

Stolon is an open-source project maintained by the community.

- [rpmbuilder Releases on GitHub](https://github.com/pgvillage-build/rpmbuilder)
- [pgvillage Repository](https://github.com/pgvillage/pgvillage/releases)

> **Intent:**  
> The goal is to get these two pull requests merged upstream so separate builds are no longer required.

## Requirements
For a stolon, the following components are needed:

- **Stolon binaries**  
Installed in `/usr/local/bin/` via the RPM:

- `stolonctl` – CLI management tool  
- `stolon-keeper` – PostgreSQL manager  
- `stolon-proxy` – TCP proxy for forwarding traffic to the master  
- `stolon-sentinel` – Cluster manager

- **Systemd files**  
Deployed by Ansible to `/etc/systemd/system/`:

- `stolon-keeper.service`  
- `stolon-proxy.service`  
- `stolon-sentinel.service`

- **The stolon config files** 
Deployed by Ansible to `/etc/sysconfig/`:

- `stolon-stkeeper`  
- `stolon-stproxy`  
- `stolon-stsentinel`

- a working etcd and configuration to access it  
  - We use the standard ports, but if not, then the custom port must be configured  
  - We don't yet use etcd with tls / client certificate, but if so, then the certificates need to be available and configured  
- stolon takes care of all postgres matters, including initialization, cloning, and starting Postgres  
  - stolon needs the paths to the correct postgres binaries, datadir, and waldir  
  - is located in `/etc/sysconfig/stolon-stkeeper`

## Usage

Configuration and management of Stolon are fully implemented in PgVillage. 

Furthermore, it is important to be able to use `stolonctl` in particular to query information and (if necessary) make adjustments.

`stolonctl` requires a few configuration parameters so that it knows how to connect to etcd and which cluster it operates on (we use only one, but the configuration is still necessary).

With these parameters set, stolonctl can be used under any user (connect to etcd via the API).

A few examples:

## Check Status

### Setting up Environment Variables

```bash
export STOLONCTL_CLUSTER_NAME=stolon-cluster
export STOLON_CTL_STORE_BACKEND=etcdv3
```
### Check Cluster Status

```bash
[root@acme-dvppg1db-server1 sysconfig]#/usr/local/bin/stolonctl status
```
=== Active Sentinels ===
ID         LEADER
3b05c06e   true
6b467314   false
7ae581ff   false
902f6b4d   false

=== Active Proxies ===
ID
09605cac
308fcad1
4a1634ea
534074d4

=== Keepers ===

UID                    HEALTHY  PG_LISTEN_ADDRESS   PG_HEALTHY  PG_WANTED_GEN  PG_CURRENT_GEN
acme_dvppg1db_server1  true     10.0.4.42:5432      true        33             33
acme_dvppg1db_server2  true     10.0.4.43:5432      true        55             55
acme_dvppg1db_server3  true     10.0.4.44:5432      true        33             33
acme_dvppg1db_server4  true     10.0.4.45:5432      true        33             33

===Cluster Info===
MasterKeeper: acme_dvppg1db_server2

== Keepers/DB Tree ==
acme_dvppg1db_server2 (master)
├─ acme_dvppg1db_server4
├─ acme_dvppg1db_server3
└─ acme_dvppg1db_server1
---

## Query the current configuration

```bash
#set up config required for stolonctl

export STOLONCTL_CLUSTER_NAME=stolen-cluster

export STOLONCTL_STORE_BACKEND=etcdv3

# Request cluster spec

[root@acme-dvppg1db-server1 sysconfig]# /usr/local/bin/stolonctl spec

Outcome:

{

"initMode": "new",
"defaultSUReplAccessMode": "strict",
"pgParameters": {
"archive_command": "/opt/wal-g/scripts/archive.sh %p",
"archive_mode": "on",
"datestyle": "ISO, MDY",
"default_text_search_config": "pg_catalog.english",
"dynamic_shared_memory_type": "posix",
"effective_cache_size": "5822MB",
"idle_in_transaction_session_timeout": "60 minutes",
"lc\_messages": "en\_US.UTF-8",
"LC_MONETARY": "en_US.UTF-8"
"lc_numeric": "C.UTF-8",
"lc_time": "en_US.UTF-8",
"listen_addresses": "['*']",
"log_connections": "on",
"log_destination": "csvlog",
"log_directory": "/var/log/postgresql",
"log_disconnections": "on",
"log_error_verbosity": "verbose",
"log_file_mode": "0600",
"log_filename": "postgresql-%Y%m%d.log",
"log_line_prefix": "%m [%p%: [%l-1] db=%d,user=%u,app=%a,client=%h ",
"log_min_duration_statement": "5000",
"log_min_error_statement": "error",
"log_min_messages": "warning",
"log_rotation_age": "1d",
"log_rotation_size": "1GB",
"log_statement": "ddl",
"log_timezone": "Europe/Amsterdam",
"log_truncate_on_rotation": "on",
"logging_collector": "on",
"max_connections": "100",
"max_parallel_workers": "8",
"max_parallel_workers_per_gather": "2",
"max_wal_senders": "3",
"max_wal_size": "76762MB",
"max_worker_processes": "8",
"min_wal_size": "25587MB",
"restore_command": "/opt/wal-g/scripts/archive_restore.sh %f %p",
"shared_buffers": "1940MB",
"ssl": "true",
"ssl_ca_file": "/data/postgres/data/certs/root.crt",
"ssl_cert_file": "/data/postgres/data/certs/server.crt",
"ssl_key_file": "/data/postgres/data/certs/server.key",
"statement_timeout": "60min",
"timezone": "Europe/Amsterdam",
"wal_level": "archive",
"work_mem": "29813kB"

},

"pgHBA": [

[local] all all ident

"hostssl postgres avchecker samenet cert",

hostssl vcbe_db cims_rw sanet scram-sha-256,

"hostssl all all samenet cert"

\]
```

## Update cluster config

```bash
set up configuration required for stolonctl

export STOLONCTL_CLUSTER_NAME=stolon-cluster

export STOLONCTL_STORE_BACKEND=etcdv3

# adjust cluster spec

/usr/local/bin/stolonctl update -f /data/postgres/data/stolon\_custom\_config.yml --patch

The command should give no output (if it works correctly).

# Patch

Incidentally, the patch offers options to adjust configurations, but this configuration "comes alongside."

Settings that do not receive a value from the custom_config file retain their current configuration.

The entire configuration can also be completely adjusted by first setting it with the `spec` option in a file, then making adjustments, and finally reloading without the `--patch` option using `stolonctl update`.

set up configuration required for stolonctl

export STOLONCTL_CLUSTER_NAME=stolon-cluster

export STOLONCTL_STORE_BACKEND=etcdv3


# dumping
/usr/local/bin/stolonctl spec > /tmp/stolon_custom_config.yml

# adjust
edit /tmp/stolon_custom_config.yml


# Check if it's still JSON.
cat /tmp/stolon\_custom\_config.yml \| python -m json.tool

#read cluster specification
/usr/local/bin/stolonctl update -f /data/postgres/data/stolon_custom_config.yml
```

## Help

To list all options of `stolonctl`, you can run the command with the `-h` option:

```bash
stolonctl -h
Or use the `--help` option:
stolonctl --help

[root@acme-dvppg1db-server1 sysconfig]# /usr/local/bin/stolonctl

stolon command line client

Usage:

stolonctl [Flags]
stolonctl [command]
```

Available Commands:
manage cluster data  
Manage current cluster data

Failkeeper - Force keeper as "temporarily" failed. The sentinel will compute new cluster data, considering it as failed, and then restore its state to the actual one.

help  
&nbsp;&nbsp;Help about any command
```bash
| Command | Description |
|----------|-------------|
| `initialize` | Initialize a new cluster |
| `promote` | Promote a standby to primary |
| `register` | Register stolon keepers for service discovery |
| `removekeeper` | Removes keeper from cluster data |
| `spec` | Retrieve current cluster specification |
| `status` | Display the current cluster status |
| `update` | Update cluster configuration |
| `version` | Show stolonctl version |

# Flags:

--cluster-name string            cluster name
-h, --help                       help for stolonctl
--kube-context string             name of the kubeconfig context to use
--kube-namespace string           name of the Kubernetes namespace to use

--kube-resource-kind string       the Kubernetes resource kind to be used to store Stolon cluster data
                                  and perform sentinel leader election (currently, only "configmap" is supported).

--kubeconfig string               path to kubeconfig file. Overrides $KUBECONFIG
--log-level string                debug, info (default), warn or error (default "info")
--metrics-listen-address string   metrics listen address, e.g., "0.0.0.0:8080" (disabled by default)
--store-backend string            store backend type (etcdv2/etcd, etcdv3, consul, or kubernetes)
--store-ca-file string            verify certificates of HTTPS-enabled store servers using this CA bundle
--store-cert-file string          certificate file for client identification to the store
--store-endpoints string          a comma-delimited list of store endpoints
                                  (use https scheme for TLS communication)
                                  (defaults: http://127.0.0.1:2379 for etcd, http://127.0.0.1:8500 for consul)
--store-key string                private key file for client identification to the store
--store-prefix string             the store base prefix (default "stolon/cluster")
--store-skip-tls-verify           skip store certificate verification (insecure!!!)
--store-timeout duration          store request timeout (default 5s)
--version                         version for stolonctl
```

Use `stolonctl [command] --help` for more information about a specific command.

---

## When Nothing Else Works

In some cases, Stolon may fail to recover automatically. 

The situation was as follows:

- The 3rd node was (according to Stolon) the master.
- The 3rd node had issues with the datadir and refused to start again.
- The other nodes were also not okay anymore.

This has been resolved by reinitializing the cluster:

---
```bash
# Set up configuration required for `stolonctl`.

export STOLONCTL_CLUSTER_NAME=stolon-cluster
export STOLONCTL_STORE_BACKEND=etcdv3

# reinitialize
/usr/local/bin/stolonctl init
```

!!! Note

    Preferably perform a point-in-time restore!!!

There is a "are you sure" prompt and then the cluster information is cleared afterwards.

Once confirmed, the existing cluster metadata will be cleared.

---

After that, the backup was discarded and restored.

This approach is **not recommended** for production use.

It is better to use the [Point in time restore](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Onderhoud/Point+in+Time+Restore/WebHome.html) procedure. It also executes an init but with the PITR option so that the latest backup is restored from WAL-G.
