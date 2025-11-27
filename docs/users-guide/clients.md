# Clients Introduction

There are many different programming languages that can create a connection to PostgreSQL, and most of them have their own client.

This documentation helps the end user get started with successfully setting up a client connection.

## Dependencies

- JDBC documentation (Java)
  - [JDBC](jdbc.md)
  - [https://jdbc.postgresql.org/documentation/ssl/](https://jdbc.postgresql.org/documentation/ssl/)
  
- libpq documentation (Python => psycopg2, C clients, PostgreSQL tools)
  - [https://jdbc.postgresql.org/documentation/ssl/](https://jdbc.postgresql.org/documentation/ssl/)
  - [https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-PARAMKEYWORDS](https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-PARAMKEYWORDS)

- nPGSQL (.NET)
  - [https://www.npgsql.org/doc/](https://www.npgsql.org/doc/)
  
- Information for the applicant: define an internal template to send to every requestor, and send the mail once the request has been fulfilled

- pg_service.conf information
  - [https://www.postgresql.org/docs/current/libpq-pgservice.html](https://www.postgresql.org/docs/current/libpq-pgservice.html)
  - [pg_service](../architecture/pg_service.md)

- Client certificates:
  - [General information](../architecture/mtls.md)
  - [Generate new certificates](../administrators-guide/deployment_and_maintenance/byo-client-certs.md)
  - [openssl commands to convert and read](../administrators-guide/troubleshooting/openssl.md)

## Instructions

Depending on the driver, the configuration must be done in a different way.

Check the Dependencies list for the relevant type of driver and read the associated documentation.

Furthermore, the following should be taken into account:

- Use the latest version of the driver whenever possible
  - At a minimum, use the version that was released after the used PostgreSQL Major. Example:
    - PostgreSQL 14
    - [https://www.postgresql.org/support/versioning/](https://www.postgresql.org/support/versioning/) => September 30, 2021
    - [https://mvnrepository.com/artifact/org.postgresql/postgresql](https://mvnrepository.com/artifact/org.postgresql/postgresql) => at least 42.3.0
- The client certificate, private key, and root certificate must be readable by the application user account.
- Ensure the path is configured correctly.
  - Note: Private keys must only be sent encrypted!!!
- Direct connection to PostgreSQL (port 5432 of the database hosts)
  - has several advantages
    - A direct connection avoids (software / network) hops and associated latencies
    - The hba file can be configured more specifically
  - however, it also has disadvantages
    - follow the master is 100% dependent on the intelligence of the driver and the software that uses it
    - See the following documentation for Client Connect Failover (follow the master)
      - jdbc: [client_connection_failover](../users-guide/client_connection_failover.md)
      - libpq: [https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-PARAMKEYWORDS](https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-PARAMKEYWORDS)
        - Check out target_session_attrs
        - Options are version-dependent

