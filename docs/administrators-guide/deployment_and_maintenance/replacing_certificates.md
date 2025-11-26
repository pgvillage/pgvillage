---
title: Refreshing certificates (2)
summary: A description of how to refresh mTLS certificates
authors:
  - Sebas Mannem
  - Snehal Kapure
date: 2025-11-11
---

<!-- This should be replaced by a playbook with chainsmith replacing certs and reloading services as required -->

# Refreshing certificates (2)

Certificates are internally generated using an automation tool called [chainsmith](../tools/chainsmith.md).

The basic idea is to generate a new certificate chain and replace the old one in a single step.

This also means there will be a period during which the application will no longer accept the PostgreSQL **server certificate**,  
and PostgreSQL will no longer accept the **client certificate**.

This documentation describes a method in which certificates can be replaced through a few manual steps.

In the best-case scenario, this results in only a few reloads of PostgreSQL and the application.  
In practice, a couple of restarts may be required — but even then, this is still minimal downtime compared to a downtime window of several hours.

---

## Dependencies

- Knowledge of:
  - [mTLS](../architecture/mtls.md)
   - Note  that this page is a guide, but reading it does not make one an expert in [mTLS](../architecture/mtls.md)
- Knowledge of Postgres and how it functions with mTLS
- Knowledge of:
- [Ansible](ansible.md)
- [Ansible inventory](https://docs.ansible.com/ansible/latest/user_guide/intro_inventory.html)- [Ansible-vault](https://docs.ansible.com/ansible/latest/user_guide/vault.html)
- Knowledge of the application and the associated [PostgreSQL client and how it works with mTLS](../architecture/mtls.md)
- The option to execute this in a POC environment, a test, and an acceptance environment

## Work Instruction

Summary of the process:

1. Generate a new certificate chain  
   Based on:  
   [Procedure for replacing certificates with minimal downtime](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Onderhoud/Nieuwe+certificaten+genereren+en+uitrollen/certificaten+vervangen+met+downtime/WebHome.html)
   
2. Adjust the configuration so the **root certificates** or **chains** include both:
   - Old certificate bundle
   - New certificate bundle

    This is done in:
      - Ansible inventory  
      - Application configuration (reload or restart required)

    From this point:
      - The application accepts **both** old and new server certificates  
      - Client still connects with **old** certificate

    For PostgreSQL and building block components:
      - PostgreSQL accepts both old and new certificates
      - PostgreSQL immediately switches to using the **new** certificate
      - Tools such as pgQuartz, pgRoute66, and AVChecker will authenticate using the **new** certificate
      - Application connections still use the old client certificate

3. Update the application to use the **new client certificate**
      - From this moment, the **old bundles are no longer needed**

4. Update the bundles so that **only the new certificates** remain
      - Critical: if a certificate in the chain expires, authentication will fail
      - Adjust the Ansible inventory  
      - Roll out through Ansible

---

## Cancelled

1: Generate a new chain according to [Procedure for replacing certificates with minimal downtime](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Onderhoud/Nieuwe+certificaten+genereren+en+uitrollen/certificaten+vervangen+met+downtime/WebHome.html).

Save the new certificates in a Merge Request.
- Create a new merge request if necessary

```bash
ENV=poc
git checkout -b "feature/new_certs_$ENV" dev
#glab, or follow the link in the output of the git push command
glab mr create

# Ensure all changes are included:

ENV=poc
git add config/chainsmith\_$ENV.yml environments/$ENV/group_vars/all/certs{,.vault}.yml
git commit -m "New chainsmith configuration and certificates for $ENV"
git push
```
2: Adjust the configuration so that the root certificates/chains contain both the old and new certificate bundles.

The old chain can be found on the existing database servers:

- `~postgres/.postgresql/root.crt`
- `/data/postgres/data/certs/root.crt`

The easiest way is to prepend these with spaces:

```bash
[root@gurus-pgsdb-server1 ~]# sed 's/^/    /' ~postgres/.postgresql/root.crt
-----BEGIN CERTIFICATE-----

MIIGRTCCBC2gAwIBAgIBATANBgkqhkiG9w0BAQsFADCB1zELMAkGA1UEBhMCTkwx
EDAOBgNVBBEMBzM3MjEgTUExEDAOBgNVBAgMB1V0cmVjaHQxEjAQBgNVBAcMCUJp
bHRob3ZlbjEiMCAGA1UECQwZQW50b25pZSB2IExlZXV3ZW5ob2VrbG4gOTE9MDsG
A1UECgw0Umlqa3NpbnN0aXR1dXQgdm9vciBWb2xrc2dlem9uZGhlaWQgZW4gTWls
aWV1IChSSVZNKTEaMBgGA1UECwwRUG9zdGdyZXMgYm91d2Jsb2sxETAPBgNVBAMM

[root@gurus-pgsdb-server1 ~]# sed 's/^/ /' /data/postgres/data/certs/root.crt

-----BEGIN CERTIFICATE-----
MIIGRTCCBC2gAwIBAgIBAjANBgkqhkiG9w0BAQsFADCB1zELMAkGA1UEBhMCTkwx
EDAOBgNVBBEMBzM3MjEgTUExEDAOBgNVBAgMB1V0cmVjaHQxEjAQBgNVBAcMCUJp
bHRob3ZlbjEiMCAGA1UECQwZQW50b25pZSB2IExlZXV3ZW5ob2VrbG4gOTE9MDsG
A1UECgw0Umlqa3NpbnN0aXR1dXQgdm9vciBWb2xrc2dlem9uZGhlaWQgZW4gTWls
aWV1IChSSVZNKTEaMBgGA1UECwwRUG9zdGdyZXMgYm91d2Jsb2sxETAPBgNVBAMM
CHBvc3RncmVzMB4XDTIyMDgxODE2NDgyOVoXDTI5MTExOTE2NDgyOVowgYsxCzAJ

The certificates can simply be added to the current inventory:

ENV=poc
vim environments/$ENV/group_vars/all/certs.yml

# Add the client certificate to `certs.client.chain` (right before placing the new certificate above it).

# Add the server certificate to certs.server.chain (just before placing the new certificate on top).
```

!!! Note

      By not including this change in the merge request (MR), we can easily roll it back later.

3: Deliver the bundle of old and new chains to the Application Administrators and ask them to adjust the application configuration and load the new root certificates.

Actually, this is what was placed at the previous step at certs.server.chain.

4: Reconfigure Postgres and all related tools from the building block:

```bash
ENV=poc
cd ~/git/ansible-postgres
export ANSIBLE_VAULT_PASSWORD_FILE=~/git/ansible-postgres/bin/gpgvault
ansible-playbook -i environments/$ENV rollout_new_certs.yml
```

5: Deliver the entire bundle (only new `root.crt`, and the client certificates, configuration readme, etc.) to the application administrator.

The procedure [The procedure for 'Antwoord aanvrager](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Antwoord+aan+de+aanvrager/WebHome.html) can be followed.

Request application administrators to register with these new client certificates (configuration adjustment and reload/restart).

6: Roll back the changes, push to GitLab, and run Ansible again.

```bash
ENV=poc
cd ~/git/ansible-postgres
git reset environments/$ENV/group_vars/all/certs{,vault}.yml
export ANSIBLE_VAULT_PASSWORD_FILE=~/git/ansible-postgres/bin/gpgvault
ansible-playbook -i environments/$ENV rollout_new_certs.yml --tags stolon
```

7: Completion

With this final rollout, the environment is now fully migrated to the new certificates and the procedure is complete.
