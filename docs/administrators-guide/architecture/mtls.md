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

Here, mutual TLS (mTLS) is used, which means there is a certificate chain with a root, two intermediaries (one for the client and one for the server), and the server and client certificates.

```markdown
![chain.png](../../../../../../../../attachment/xwiki/Infrastructuur/Team%3A+DBA/Algemene+Restore+Server+voor+DBA-Linux/Postgres/Bouwsteen/mTLS/WebHome/chain.png)
```

## Generate

The certificate chain can either be:

- Requested from an **external certificate authority**, or
- **Generated internally** using a self-managed process.

However, the current process for requesting certificates is **complex, slow**, and often **dependent on other teams** within the organization.

Therefore, a community tool ([chainsmith](chainsmith.md)) is used to generate the chain.

## Background information

- Background information about the tool: [chainsmith](chainsmith.md)
- [inventory](inventory.md)
