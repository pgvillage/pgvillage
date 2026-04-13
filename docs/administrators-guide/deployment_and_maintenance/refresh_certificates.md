---
title: Refreshing certificates
summary: A description of how to refresh mTLS certificates
authors:
  - Sebas Mannem
  - Snehal Kapure
date: 2025-11-11
---

# Refreshing certificates

In the SBB PostgreSQL, an [mTLS](../../architecture/mtls.md) chain is used with [server-](byo-server-certs.md) and [client-](byo-client-certs.md) certificates.

The chain is generated using [Chainsmith](../../tools/chainsmith.md) and (re)generated using this procedure.

## Dependencies

- [chainsmith](../../tools/chainsmith.md)
- [nieuwe uitrol](inventory.md)
- [ansible](ansible.md)

## Work Instructions

### 1. Check the database request form and update Chainsmith configuration (if needed)
Adjust:

```bash
ansible/config/chainsmith_[ENV].yml

# If configuration changes are needed, create a merge request:

ENV=poc
git checkout dev -b "feature/chainsmith_$(printenv ENV).yml"
git add config/chainsmith\_$ENV.yml
git commit -m "New chainsmith config $ENV"
git push
#Use `glab`, or follow the link in the output of the `git push` command.
glab mr create
```

**Ensure correct certificate extensions**

- JDBC requires the following extensions (both client and server):
  - keyUsages:
    - keyEncipherment
    - dataEncipherment
    - digitalSignature

  - extendedKeyUsages:
    - serverAuth

### 2. Generate the new certificates

- When using chainsmith: [Rerun Chainsmith](../../tools/chainsmith.md)
- When using `bring your own` certificates: [byo server certs](byo-server-certs.md)

Once the certificate rollout is complete, **PostgreSQL and the application will run using the refreshed certificates.**
