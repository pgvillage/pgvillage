---
title: PostgreSQL Service File
summary: A description of the PostgreSQL Service file, how it works, and how it is implemented in PgVillage
authors:
  - Sebas Mannem
  - Snehal Kapure
date: 2025-11-11
---

# postres services

Connecting to Postgres may require a lot of configuration, including user, database, multiple hosts, connection parameters, etc.

!!! note
    Please don;t configure passwords clear text in configuration files!!!

PostgreSQL clients can be used with a pg_service.conf file to configure services, where every service represents a connection with different setting.

PgVillage creates a ~postgres/pg_service.conf file whichh conatins all types of connections that the linux user for the postgres service could require.

!!! example
    [local]
    host=/tmp
    port=5432

    [proxy]
    host=127.0.01
    port=25432
    sslmode=verify-full

    [master]
    host=host1.mydomain.org,host2.mydomain.org,host3.mydomain.org
    port=5432
    target_session_attrs=read-write
    sslmode=verify-full

    [standby]
    host=host1.mydomain.org,host2.mydomain.org,host3.mydomain.org
    port=5432
    target_session_attrs=read-write

## Background

For more information, please refer to [PostgreSQL docs](https://www.postgresql.org/docs/current/libpq-pgservice.html).
