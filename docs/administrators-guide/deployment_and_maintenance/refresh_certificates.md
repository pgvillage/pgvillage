---
title: Refreshing certificates
summary: A description of how to refresh mTLS certificates
authors:
  - Sebas Mannem
  - Snehal Kapure
date: 2025-11-11
---

# Refreshing certificates

In the SBB PostgreSQL, an [mTLS](mtls.md) chain is used with [server-](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/mTLS/Server+certificaten/WebHome.html) and [client-](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/mTLS/Server+certificaten/WebHome.html) certificates.

The chain is generated using [Chainsmith](chainsmith.md) and (re)generated using this procedure.

## Dependencies

- [chainsmith](../tools/chainsmith.md)
- [nieuwe uitrol](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Van+server+naar+draaiende+database/WebHome.html)
- [ansible-postgres](ansible.md)
  - [rollout new certs](https://gitlab.int.corp.com/gurus-db-team/ansible-postgres/-/blob/master/rollout_new_certs.yml)
  - [chainsmith config](https://gitlab.int.corp.com/gurus-db-team/ansible-postgres/-/tree/dev/config)

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

There are actually three options:

1. [Restart Chainsmith](chainsmith.md) and [replace certificates with downtime](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Onderhoud/Nieuwe+certificaten+genereren+en+uitrollen/certificaten+vervangen+met+downtime/WebHome.html)
   - Ideal for new environments
   - Easiest, but involves downtime
   - ENV=poc

  ```bash
    rm environments/$ENV/group_vars/all/certs{,.vault}.yml
    bin/chainsmith.sh $ENV
  ```

  - Roll out the new certificates afterwards

2. A procedure where [server and client certificates are replaced with minimal impact](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/mTLS/Certificaten+vervangen+met+weinig+impact/WebHome.html)

   - Manual work, but little to no downtime

3. [New client certificates](https://wiki.corp.com:443/xwiki/bin/create/Infrastructuur/Team%3A%20DBA/Werkinstrukties/Postgres/Bouwsteen/Onderhoud/Nieuwe%20certificaten%20genereren%20en%20uitrollen/nieuwe%20client%20certificaten/WebHome?parent=Infrastructuur.Team%5C%3A+DBA.Algemene+Restore+Server+voor+DBA-Linux.Postgres.Bouwsteen.Onderhoud.Nieuwe+certificaten+genereren+en%20uitrollen.WebHome) added to the existing bundle
   - Easy and no downtime, but does not help fix issues like expiry
```
Follow one of the three procedures above.  
Once the certificate rollout is complete, **PostgreSQL and the application will run using the refreshed certificates.**
