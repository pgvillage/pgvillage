# Introduction

Er zijn vele verschillende programeertalen die een verbidning kunnen maken naar PostgreSQL en de meesten hebben een eigen client.

Deze documentaie helpt de eindgebruiker op weg om suucesvol een client verbinding op te zetten.

# Dependencies

- JDBC documentation (Java)
  - [https://jdbc.postgresql.org/documentation/use/#connection-parameters/](https://jdbc.postgresql.org/documentation/use/#connection-parameters/)
  - [https://jdbc.postgresql.org/documentation/ssl/](https://jdbc.postgresql.org/documentation/ssl/)
  
- libpq documentation (Python => psycopg2, C clients, PostgreSQL tools)
  - [https://jdbc.postgresql.org/documentation/ssl/](https://jdbc.postgresql.org/documentation/ssl/)
  - [https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-PARAMKEYWORDS](https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-PARAMKEYWORDS)

- nPGSQL (.NET)
  - [https://www.npgsql.org/doc/](https://www.npgsql.org/doc/)
  
- Information for the applicant: [mail to the applicant](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Antwoord+aan+de+aanvrager/WebHome.html)

- pg\_service.conf information
  - [https://www.postgresql.org/docs/current/libpq-pgservice.html](https://www.postgresql.org/docs/current/libpq-pgservice.html)
  - [pg\_service](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Antwoord+aan+de+aanvrager/pg_service/WebHome.html)

- Client certificates:
  - [General information](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/mTLS/Client+certificaten/WebHome.html)
  - [Generate new certificates](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/mTLS/nieuw+client+certificaat/WebHome.html)
  - [openssl commands to convert and read](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/mTLS/openssl/WebHome.html)

# Instructions

Afhankelijk van de driver dient de configuratie op een andere manier te geschieden.

Kijk bij de Afhankelijkheden lijst naar de bestreffende soort driver en lees de bijbehorende documentatie.

Furthermore, the following should be taken into account:

- Use the latest version of the driver whenever possible
  - At a minimum, use the version that was released after the used PostgreSQL Major. Example:
    - PostgreSQL 14
    - [https://www.postgresql.org/support/versioning/](https://www.postgresql.org/support/versioning/) => September 30, 2021
    - [https://mvnrepository.com/artifact/org.postgresql/postgresql](https://mvnrepository.com/artifact/org.postgresql/postgresql) => at least 42.3.0
- The client certificate, private key, and root certificate must be readable by the application user account.
- Ensure the path is configured correctly. See [mail to the requester](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Antwoord+aan+de+aanvrager/WebHome.html) for options to deliver the information to the end-user.
  - Note: Private keys must only be sent encrypted!!!
- Direct connection to PostgreSQL (port 5432 of the database hosts)
  - has several advantages
    - A direct connection avoids (software / network) hops and associated latencies
    - The hba file can be configured more specifically
  - however, it also has disadvantages
    - follow the master is 100% dependent on the intelligence of the driver and the software that uses it
    - See the following documentation for Client Connect Failover (follow the master)
      - jdbc: [https://jdbc.postgresql.org/documentation/use/#connection-fail-over](https://jdbc.postgresql.org/documentation/use/#connection-fail-over)
      - libpq: [https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-PARAMKEYWORDS](https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-PARAMKEYWORDS)
        - Check out target\_session\_attrs
        - Options are version-dependent

