---
title: Bring Your Own - Server Certificates
summary: A description of how to use PgVillage with server certificates signed by your own CA
authors:
  - Sebas Mannem
  - Snehal Kapure
date: 2025-12-09
---

# Bring your own - Server Certificates

## TLDR

- create a CSR for every server
  - use the full qualified domain name as the Common Name
  - use all options for connecting as entries in the SAN
- have it signed by your own CA
- have the signed certificate shipped to PostgreSQL as `$PGDATA/server.crt` and `$PGDATA/server.key` and reload
- make sure the hba file has a corresponding lines to enable ssl (hostssl) and reload if necessary
- make sure ssl is enabled (`ssl=on` in postgresql.conf).
  **Note**, it is easier to start with a PgVillage deployment with chainsmith, and change to internal CA signed certificates instead of directly configuring ssl and using your own certificates in once.
- ship the chain to the client (to ~/.postgresql/root.crt)
- make sure tls is working properly
- make sure `verify-full` is used as the `ssl method`

and you should be good to go...


## Introduction

By default PgVillage uses [chainsmith](../../tools/chainsmith.md) for managing server and client certificates.
There is an option to use certificates signed by your own CA.

## How it works

Whenever
- A client connects to PostgreSQL;
- PostgreSQL is configured to use `hostssl` (pg_hba.conf)
- PostgreSQL responds with a certiticate, and the client verifies:
  - the common name to be, or SAN to contain, the hostname that is connected to
  - if the certiticate is trusted
  - if the certificate is still valid
  - if the certificate is on the CRL
  - if the server has the corresponding private key

if the certificate validates properly, the client will continue communication and encrypt the data.

## How do you set this up

- configure all properly
- reload PostgreSQL
- reconnect
- check that all works as expected
