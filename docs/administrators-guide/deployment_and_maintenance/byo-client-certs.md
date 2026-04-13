---
title: Bring Your Own - Client Certificates
summary: A description of how to use PgVillage with client certificates signed by your own CA
authors:
  - Sebas Mannem
  - Snehal Kapure
date: 2025-12-09
---

# Bring your own - Client Certificates

## TLDR

- create a CSR for a client certificate, with the user to connect to PostgreSQL as the common name
- have it signed by your own CA
- have the root shipped to PostgreSQL as `$PGDATA/root.crt` (and reload if needed)
- make sure the hba file has a corresponding line and set method to `cert` (and reload if needed)
- ship the client certificate (with chain), and private key to the client (to ~/.postgresql.postgres.crt and ~/.postgresql/postgres.key)
- make sure tls is working properly

!!! note
    do this for all client certificate connections, also the internal services, such as:
    - postgres
    - avchecker
    - pgquartz
    - pgfga
    - pgroute66
    - minio

and you should be good to go...


## Introduction

By default PgVillage uses [chainsmith](../../tools/chainsmith.md) for managing server and client certificates.
There is an option to use certificates signed by your own CA.


!!! note
    If you sign your client certificates by your CA, you also need to use your CA root certificate for PostgreSQL to accept client certificates.
    Which basically means that all client certificztes signed by the CA will be accepted if a corresponding user exists in PostgreSQL.
    Which adds a securitu risk. When someone in your organization requests a client certificate with common name `postgres`, and your CA signs off on it,
    the requestor receives a client certiicate which has access to all PostgreSQL clusters as the root user (postgres) with superuser permissions.
    This is why we like the Chainsmith option over trustinging client certificates issued by a company wide CA.

## How it works

Whenever 
- A client connects to PostgreSQL;
- PostgreSQL is configured to accept client certificates (cert as method in the hba file);
- The root certificate (or intermediate certificate) is trusted by PostgreSQL;
- The user that is trying to connect is listed in the client certificate as the Common Name; and
- The user exists in PostgreSQL

then the connection is accepted and enters postgreSQL as the user (as specificed).

## How do you set this up

- configure all properly
- reload PostgreSQL
- reconnect
- check that all works as expected
