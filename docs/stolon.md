# Stolon

## Introduction

Stolon is a tool manaaging High Availability for PostgreSQL setups.

In PgVillage, stolon is configured to use etcd as an external consensus store.

In other words, etcd maintains a conistent state and config across the cluster, and stolon manages PostgreSQL accordingly.

Stolon manages the following things:

- PostgreSQL Datadirectory initialization (once)
- Setup physical standby instances
- configuring replication
- High Availability
- forwarding incoming from 25432 on any database node to port 5432 on the master instance
- maintain consistent config across the cluster for accessibility (pg_hba.conf)
- maintain consistent config across the cluster for (postgresql.conf)

stolon is een Open Source project en wordt door de community onderhouden op [https://github.com/sorintlab/stolon/](https://github.com/sorintlab/stolon/).

Binnen rivm wordt een rpm gebruikt welke beschikbaar wordt gesteld middels

- [https://github.com/MannemSolutions/rpmbuilder/releases](https://github.com/MannemSolutions/rpmbuilder/releases)
- [https://repo.mannemsolutions.nl/yum/pgvillage/](https://repo.mannemsolutions.nl/yum/pgvillage/)

Ten tijde van dit schrijven wordt gebruik gemaakt van een aangepaste rpm, welke is gebaseerd op:

- De laatste versie van [https://github.com/sorintlab/stolon/tags](https://github.com/sorintlab/stolon/tags)
- Deze aanpassing: [https://github.com/sorintlab/stolon/pull/865](https://github.com/sorintlab/stolon/pull/865) (voor gebruik in combinatie met een aparte wal locatie)
- Deze aanpassing: [https://github.com/sorintlab/stolon/pull/870](https://github.com/sorintlab/stolon/pull/870) (voor gebruik in combinatie met client certificaten)

De intentie is om deze 2 pull requests gemerged te kriijgen zodat hier geen aparte builds meer nodig zijn.

# Benodigdheden

Voor stolon zijn de volgende componenten nodig:

- de stolon binaries
  - stolonctl (cli), stolon-keeper (postgres manager), stolon-proxy (tcp proxy voor traffic forwarding naar de master), stolon-sentinel (cluster manager)
  - Worden in /usr/local/bin/ uitgerold middels de rpm
- systemd files
  - stolon-keeper.service, stolon-proxy.service, stolon-sentinel.service
  - Worden door Ansible uitgerold in /etc/systemd/system/
- De stolon config files
  - stolon-stkeeper, stolon-stproxy, stolon-stsentinel
  - Worden door Ansible uitgerold in /etc/sysconfig/
- een goed werkende etcd en config hoe deze te benaderen
  - We gebruiken de standaard poorten, maar zo niet dan moet de custom poort worden geconfigureerd
  - We gebruiken etd nog niet met tls / client certificaat, maar zo wel, dan moeten de certificaten beschikbaar en geconfigureerd worden
- stolon zorgt verder voor alle postgres zaken, waaronder initialisatie, clonen en starten Postgres
  - stolon heeft de pagen naar de juiste postgres binaries, datadir en waldir nodig
  - staat in /etc/sysconfig/stolon-stkeeper

# Gebruik

Configuratie en aansturing van stolon is volledig geimplementeerd in Ansible (de [stolon rol](https://gitlab.int.ssc-campus.nl/ssc-bi-dba/ansible-postgres/-/tree/dev/roles/stolon)).

Verder is het wel belangrijk om met name stolonctl te kunnen gebruiken om informatie op te vragen en (eventueel) aan te passen.

stolonctl vereist een paar config parameters zodat hij weet dat hij naar etcd moet connecten en welk cluster het om draait (we gebruiken er maar 1 maar config is toch nodig).

Met deze parameters ingesteld kan stolonctl worden gebruikt onder elke user (connect naar etcd via de API).

Een paar voorbeelden:

## Status opvragen

#instellenconfigbenodigdvoorstolonctl

exportSTOLONCTL_CLUSTER_NAME=stolon-cluster

exportSTOLONCTL_STORE_BACKEND=etcdv3

#opvragenclusterstatus

\[root@rivm-dvppg1db-l01p sysconfig\]#/usr/local/bin/stolonctlstatus

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

===Keepers===

UIDHEALTHYPGLISTENADDRESSPGHEALTHYPGWANTEDGENERATIONPGCURRENTGENERATION

rivm_dvppg1db_l01ptrue131.224.233.22:5432true33

rivm_dvppg1db_l02ptrue131.224.233.23:5432true55

rivm_dvppg1db_l03ptrue131.224.233.24:5432true33

rivm_dvppg1db_l04ptrue131.224.233.25:5432true33

===ClusterInfo===

MasterKeeper:rivm_dvppg1db_l02p

=====Keepers/DBtree=====

rivm_dvppg1db_l02p(master)

├─rivm_dvppg1db_l04p

├─rivm_dvppg1db_l03p

└─rivm_dvppg1db_l01p

## De huidige config opvragen

#instellen config benodigd voor stolonctl

exportSTOLONCTL_CLUSTER_NAME=stolon-cluster

exportSTOLONCTL_STORE_BACKEND=etcdv3

#opvragen cluster spec

\[root@rivm-dvppg1db-l01p sysconfig\]\# /usr/local/bin/stolonctl spec

Resultaat:

{

"initMode": "new",

"defaultSUReplAccessMode": "strict",

"pgParameters": {

"archive_command": "/opt/wal-g/scripts/archive.sh %p",

"archive_mode": "on",

"datestyle": "iso, mdy",

"default_text_search_config": "pg_catalog.english",

"dynamic_shared_memory_type": "posix",

"effective_cache_size": "5822MB",

"idle_in_transaction_session_timeout": "60min",

"lc_messages": "en_US.UTF-8",

"lc_monetary": "en_US.UTF-8",

"lc_numeric": "en_US.UTF-8",

"lc_time": "en_US.UTF-8",

"listen_addresses": "'\*'",

"log_connections": "on",

"log_destination": "csvlog",

"log_directory": "/var/log/postgresql",

"log_disconnections": "on",

"log_error_verbosity": "verbose",

"log_file_mode": "0600",

"log_filename": "postgresql-%Y%m%d.log",

"log_line_prefix": "%m \[%p\]: \[%l-1\] db=%d,user=%u,app=%a,client=%h ",

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

"pgHBA": \[

"local all all ident",

"hostssl postgres avchecker samenet cert",

"hostssl vcbe_db cims_rw samenet scram-sha-256",

"hostssl all all samenet cert"

\]

}

## Update cluster config

#instellen config benodigd voor stolonctl

exportSTOLONCTL_CLUSTER_NAME=stolon-cluster

exportSTOLONCTL_STORE_BACKEND=etcdv3

#aanpassencluster spec

/usr/local/bin/stolonctl update -f /data/postgres/data/stolon_custom_config.yml --patch

Het commando geeft (als het goed is) geen output.

### Patch

Overigens geeft de patch optie de mogelijkheden om configuratie aan te passen, maar deze config 'komt ernaast'.

Settings die niet in de custom_config file een waarde krijgen houden zijn huidige config.

De gehele config kan ook geheel worden aangepast door eerst met de spec optie in een file te zetten, daarna aan te passen en daarna zonder de --patch optie in te laden met stolonctl update.

#instellen config benodigd voor stolonctl

exportSTOLONCTL_CLUSTER_NAME=stolon-cluster

exportSTOLONCTL_STORE_BACKEND=etcdv3

\# dumpen

/usr/local/bin/stolonctl spec > /tmp/stolon_custom_config.yml

\# aanpassen

vim /tmp/stolon_custom_config.yml

#checken dat het nog json is

cat /tmp/stolon_custom_config.yml \| python -m json.tool

#inlezen cluster spec

/usr/local/bin/stolonctl update -f /data/postgres/data/stolon_custom_config.yml

## Help

Om alle opties van stolonctl op te vragen kun je het commando onder optie uitvoeren:

\[root@rivm-dvppg1db-l01p sysconfig\]\# /usr/local/bin/stolonctl

stolon command line client

Usage:

stolonctl \[flags\]

stolonctl \[command\]

Available Commands:

clusterdata  Manage current cluster data

failkeeper   Force keeper as "temporarily" failed. The sentinel will compute a new clusterdata considering it as failed and then restore its state to the real one.

help         Help about any command

init         Initialize a new cluster

promote      Promotes a standby cluster to a primary cluster

register     Register stolon keepers for service discovery

removekeeper Removes keeper from cluster data

spec         Retrieve the current cluster specification

status       Display the current cluster status

update       Update a cluster specification

version      Display the version

Flags:

--cluster-name string             cluster name

-h, --help                            helpfor stolonctl

--kube-context string             name of the kubeconfig context to use

--kube-namespace string           name of the kubernetes namespace to use

--kube-resource-kind string       the k8s resource kind to be used to store stolon clusterdata and do sentinel leader election (only "configmap" is currently supported)

--kubeconfig string               path to kubeconfig file. Overrides $KUBECONFIG

--log-level string                debug, info (default), warn or error (default "info")

--metrics-listen-address string   metrics listen address i.e "0.0.0.0:8080"(disabled by default)

--store-backend string            store backend type(etcdv2/etcd, etcdv3, consul or kubernetes)

--store-ca-file string            verify certificates of HTTPS-enabled store servers using this CA bundle

--store-cert-file string          certificate file for client identification to the store

--store-endpoints string          a comma-delimited list of store endpoints (use https scheme for tls communication)(defaults: http://127.0.0.1:2379 for etcd, http://127.0.0.1:8500 for consul)

--store-key string                private key file for client identification to the store

--store-prefix string             the store base prefix (default "stolon/cluster")

--store-skip-tls-verify           skip store certificate verification (insecure!!!)

--store-timeout duration          store request timeout (default 5s)

--version                         version for stolonctl

Use "stolonctl \[command\] --help"for more information about a command.

## When all else fails

We hebben een specifieke situatie gehad waarbij stolon niet meer goed wilde starten.

Het volgende was de situatie:

- De 3e node was (volgens stolon) master
- De 3e node had problemen met de datadirectory en wilde niet meer starten
- De overige nodes waren ook niet meer ok.

Dit is opgelost door het cluster opnieuw te initialiseren:

#instellen config benodigd voor stolonctl

exportSTOLONCTL_CLUSTER_NAME=stolon-cluster

exportSTOLONCTL_STORE_BACKEND=etcdv3

\# opnieuw initialiseren

\### LET OP: Liever Point in time Restore uitvoeren!!!

/usr/local/bin/stolonctl init

Er komt een 'are you sure' vraag terug en daarna wordt de cluster informatie gewist.

Daarna is Ansible gewoon weer uitgevoerd en een nieuw cluster gecreerd.

Daarna is de backup weg gegooid en hersteld.

Dit is geen ideale optie en wordt ook niet aangeraden.

Beter is het om de [Point in time restore](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Onderhoud/Point+in+time+Restore/WebHome.html) procedure te gebruiken. DIe voert ook een init uit, maar met de pitr optie zodat de laatste backup vanuit wal-g wordt terug geplaatst.

0

Tags:

[\[+\]](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Algemene+Restore+Server+voor+DBA-Linux/Postgres/Bouwsteen/Stolon/WebHome.html 'Add tags')

Created by [Paul Victoriashoop](https://wiki.ssc-campus.nl:443/xwiki/bin/view/XWiki/victorip) on 2023/07/24 15:31

- [Comments (0)](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Algemene+Restore+Server+voor+DBA-Linux/Postgres/Bouwsteen/Stolon/WebHome.html)
- [Attachments (0)](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Algemene+Restore+Server+voor+DBA-Linux/Postgres/Bouwsteen/Stolon/WebHome.html)
- [History](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Algemene+Restore+Server+voor+DBA-Linux/Postgres/Bouwsteen/Stolon/WebHome.html)
- [Information](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Algemene+Restore+Server+voor+DBA-Linux/Postgres/Bouwsteen/Stolon/WebHome.html)

Version: 14.10.20

# Quick Links

- [Sandbox](https://wiki.ssc-campus.nl:443/xwiki/bin/view/Sandbox/)

**Links**

[Infrastructuur](https://wiki.ssc-campus.nl/xwiki/bin/view/Infrastructuur/)

[Diensten](https://wiki.ssc-campus.nl/xwiki/bin/view/Infrastructuur/Diensten)

[Componenten](https://wiki.ssc-campus.nl/xwiki/bin/view/Infrastructuur/Componenten)

[Werkinstructies](https://wiki.ssc-campus.nl/xwiki/bin/view/Infrastructuur/Werkinstructies)

[EAP lijst](https://wiki.ssc-campus.nl/xwiki/bin/view/Infrastructuur/EAP)

**Teams**

[(Overzicht alle teams)](https://wiki.ssc-campus.nl/xwiki/bin/view/Infrastructuur/Teams)

[Servers Windows](https://wiki.ssc-campus.nl/xwiki/bin/view/Infrastructuur/Team%3A+Windows)

[Servers Linux](https://wiki.ssc-campus.nl/xwiki/bin/view/Infrastructuur/Team%3A+Linux)

[IAM](https://wiki.ssc-campus.nl/xwiki/bin/view/Infrastructuur/Team%20IAM/)

[DBA](https://wiki.ssc-campus.nl/xwiki/bin/view/Infrastructuur/Team%3A%20DBA/)

[Hosting Specifiek](https://wiki.ssc-campus.nl/xwiki/bin/view/Infrastructuur/Team%3A%20Hosting%20Specifiek/)

[Generieke Hosting](https://wiki.ssc-campus.nl/xwiki/bin/view/Infrastructuur/Team%20Generieke%20Hosting/)

[Container Hosting](https://wiki.ssc-campus.nl/xwiki/bin/view/Infrastructuur/Team%20Container%20Hosting//)

[Core Infra](https://wiki.ssc-campus.nl/xwiki/bin/view/Infrastructuur/Team%3A%20Core%20Infra///)

[Security](https://wiki.ssc-campus.nl/xwiki/bin/view/Infrastructuur/Team%3A%20Security////)

[Storage](https://wiki.ssc-campus.nl/xwiki/bin/view/Infrastructuur/Team%3A+Storage)

[Netwerkbeheer](https://wiki.ssc-campus.nl/xwiki/bin/view/Infrastructuur/Team%3A+Netwerkbeheer)

[Automation](https://wiki.ssc-campus.nl/xwiki/bin/view/Infrastructuur/Team%3A%20Automation)

VIRT: Virtualisatie

[VIRT: Backup & Recovery](https://wiki.ssc-campus.nl/xwiki/bin/view/Infrastructuur/Virtueel+team%3A+Backup+en+Recovery)

[Technical Leads](https://wiki.ssc-campus.nl/xwiki/bin/view/Infrastructuur/Technical%20Leads/////)

[XWiki 14.10.20](https://extensions.xwiki.org?id=org.xwiki.platform:xwiki-platform-distribution-war:14.10.20:::/xwiki-commons-pom/xwiki-platform/xwiki-platform-distribution/xwiki-platform-distribution-war)
