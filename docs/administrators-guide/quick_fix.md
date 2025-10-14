Deze pagina helpt je tijdens de consignatiedienst om snel issues te kunnen analyseren de juiste oplossing te kiezen.

Kies eerst het soort probleem dat je probeert op te lossen en volg dan de documentatie waarnaar verwezen wordt om het probleem op de juiste manier te analyseren en op te lossen.

# Application does not have access to Postgres

The application actually needs three things to access PostgreSQL:

1. 
2. 
3.

- An available Postgres
- Network access
- A working configuration

Daarom is de eerste stap van het onderzoek om te kijken welk type issue je mee te maken hebt.

1. Check if Postgres itself is available:  
   - Use the checks described in the [avchecker](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/AV+checker/WebHome.html) documentation.  
   - Resolve all issues so that avchecker reports again that Postgres is available.

2. Check if Postgres is available for the application:  
   - Network problems are outside the scope of the DBA.

In principe wordt dit soort issues altijd opgelost door netwerkbeheer, of Container Hosting (CHP).

Conduct the direction yourself, stay engaged in the process and provide clear information on what works (availability within the Postgres architecture) and what does not work (connectivity of the application to the VIP or to Postgres).

- For more information, see the documentation on [Connections and Connection Paths](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Connecties+en+connectiepaden/WebHome.html)
3. Check if the client is correctly configured:
   - **NOTE**: Issues from incorrect configuration result from a change and are actually not part of service availability work!!!
   - Ensure that the client is properly configured, which includes:
     - host (VIP, or a list of Postgres hosts separated by commas)
     - port (on VIP 5432 for RW, 5433 for RO, directly to postgres 25432 for stolon-proxy, 5432 for direct traffic)
     - username and database name
     - client certificates (or password)
     - target\_session\_attrs (libpq) or targetServerType (jdbc)
     - sslmode=verify-full
   - Also verify that the PostgreSQL HBA (pg\_hba) configuration is correct.
   - Review error messages within the application log with the application administrator.
   - Check for error messages in the Postgres log file.
   - For more information, see the documentation on [client configuration](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Clients/WebHome.html) and about [mTLS](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/mTLS/WebHome.html).

# ```markdown
Herstellen / Noodherstel
```

It may happen that an application administrator requests a point-in-time restore to be performed, for example because too much data has been deleted or to roll back database changes from an application update.

Het kan ook zo zijn dat door een disaster scenario alle replica-instances niet meer beschikbaar zijn en alleen nog hersteld kunnen worden met een Restore (latest point in time).

In both situations, this can be resolved by referring to the [Point in Time Restore](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Onderhoud/Point+in+time+Restore/WebHome.html) documentation.

> **NOTE:** In almost all cases, the reason for a point-in-time restore is not due to an error in the Postgres architecture or by the DBA.  
> Therefore, in almost all cases, a point-in-time restore also does not result in downtime of the service.  
> Take the time to perform a proper point-in-time restore...

