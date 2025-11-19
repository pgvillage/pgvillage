---
title: mTLS
summary: A description of mTLS, how it works, and how it helps improving PgVillage security
authors:
  - Sebas Mannem
  - Snehal Kapure
date: 2025-11-11
---

# mTLS

The building block uses certificates for encryption of network traffic (server certificates) and for authentication (client certificates).
For situations where one chain is comprised of both client and server certificates, this is called mTLS.

## chainsmith

The default option is to use [chainsmith](../tools/chainsmith.md) to create a single chain for every new cluster.
The chain contains

- a freshly created root certificate
- 2 intermediates, server and client, both signed by the root
- a server certificate for every server that the cluster is comprised of, all of them signed by the server intermediate
- client certificates for every service requiring certificate authentication, all of them signed by the client intermediate

## Bring your own

As an alternative you have the option to generate your own certificates from your own intermediate.

!!! note
    Signing client certificates by your root certificate brings down security, and is not advised

## Background information

- Background information about the tool: [chainsmith](chainsmith.md)
