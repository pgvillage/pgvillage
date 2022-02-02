# pgwatch2

This is a somewhat bare-bones role to setup pgwatch2 on a Postgres host.
pgwatch2 will be configured to monitor one postgres instance and save its metrics to that.

## Variables
These variables already have sensible defaults
```
pgwatch2_db_user: pgwatch2
pgwatch2_db_host: localhost
pgwatch2_db_port: 5432
pgwatch2_db_name: pgwatch2_metrics
pgwatch2_grafana_user: pgwatch2_grafana
```
You need to manually set these variables:
```
pgwatch2_instance_name: # custom name, all metrics are prefixed with this
pgwatch2_db_pass: # password for the `pgwatch2_db_user`
pgwatch2_grafana_db_pass: # password for the `pgwatch2_grafana_user`

```


## Preparations
To result in a working setup, you need to do some manual steps.  
**Note:** The following instructions use the default names for users and the metrics database.

- Create the `pgwatch2` user in you DB and grant superuser privileges. This is needed so pgwatch can automatically setup [helper functions](https://pgwatch2.readthedocs.io/en/latest/preparing_databases.html#rolling-out-helper-functions) on databases it discovers.
    - `CREATE ROLE pgwatch2 WITH LOGIN PASSWORD 'secret';`
    - `ALTER USER pgwatch2 WITH SUPERUSER;`
    - You need to set the `pgwatch2_user_pass` variable to the password used.
- Enable the `plpython3u` extension, otherwise pgwatch will log errors on every scrape.
    - See https://pgwatch2.readthedocs.io/en/latest/preparing_databases.html#pl-python-helpers
- Create and initialize the metrics database
    - `CREATE DATABASE pgwatch2_metrics OWNER pgwatch2;`
    - Deploy a schema from https://github.com/cybertec-postgresql/pgwatch2/tree/master/pgwatch2/sql/metric_store
- Create the `pgwatch2_grafana` user and grant read privileges on the metrics DB.
    - `CREATE USER pgwatch2_grafana PASSWORD 'secret';`
    - `GRANT USAGE on SCHEMA admin to pgwatch2_grafana;`
    - `GRANT SELECT ON ALL TABLES IN SCHEMA admin TO pgwatch2_grafana;`
    - `GRANT SELECT ON ALL TABLES IN SCHEMA public TO pgwatch2_grafana;`
- Make sure the newly created users are allowed to connect to the database. This needs entries like this in `pg_hba.conf`:
    - The`pgwatch2` user can access all databases when connecting from localhost and using a password:
      `host all pgwatch2 samehost md5`
    - The`pgwatch2_grafana` user can access the metrics DB when connecting from the local network and using a password:
      `host pgwatch2_metrics pgwatch2_grafana samenet md5` 
- Add a new datasource in Grafana for the `pgwatch2_metrics` database using the `pgwatch2_grafana` user.
- Import [Grafana dashboards](https://github.com/cybertec-postgresql/pgwatch2/tree/master/grafana_dashboards/postgres/v6)

