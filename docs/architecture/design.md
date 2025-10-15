# Design

In short description:

- High Availability:

  - The database runs in Physical Streaming Replication Mode.
  - etcd (cluster consensus) and stolon (cluster management) ensure HA (a master, standbys, and failover/switchover as needed).

- Backup and Restore

  - WAL-g handles backup and restore to a bucket.
  - A separate server with minio is used for backups.
  - The filesystem behind minio goes to CommVault.

- Routing

  - stolon-proxy routes all traffic on port 25432 of a database server to the primary database server on port 5432.
  - Optionally, a routing cluster can be deployed with:
    - keepalived (virtual IP address)
    - haproxy is a TCP proxy and directs all TCP traffic
      - incoming on 5432 (rw) to 25432 on the primary DB server
      - incoming on 5433 (ro) to 5432 on the standby database servers
    - pgroute66 determines which server is primary and coordinates haproxy
  - All [client](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Clients/WebHome.html) libraries can be used in combination with the additional routing cluster.
  - Most libraries also support 'Client Connect Failover' and can be used without a routing cluster.

- ldap integration / pgfga is not implemented.
- PgWatch and monitoring are not implemented.
- pgquartz handles cluster-wide scheduling of (TAB and infra) jobs.
  - Currently only deployed for vaccination certificate TAB jobs.
