---
title: Refreshing certificates (2)
summary: A description of how to refresh mTLS certificates
authors:
  - Sebas Mannem
  - Snehal Kapure
date: 2025-11-11
---

<!-- This should be replaced by a playbook with chainsmith replacing certs and reloading services as required -->

# Introduction

Certificates are internally generated using an automation tool called [chainsmith](../../../../../../../../../pages/xwiki/Infrastructuur/Team%3A+DBA/Werkinstrukties/Postgres/Bouwsteen/Chainsmith/WebHome.html).

De basis hiervoor is echter om een nieuwe chain te genereren en te vervangen in 1 swing.

Dit betekent ook een venster waarin de applicatie het server certificaat van PostgreSQL niet meer accepteert

and a window where PostgreSQL no longer accepts the client certificate.

Deze documentatie beschrijft een methode waarin binnen een paar handmatige stappen het certificaat wordt vervangen.

Best case scenario betekent dit een paar keer een reload van PostgreSQL en een paar keer een reload van de applicatie.

In practice, it will likely be a restart a couple of times, but even that is minimal downtime compared to a downtime window of several hours.

````

# Dependencies

- Knowledge of [mTLS](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/mTLS/WebHome.html)
  - Note that this page is a guide, but reading it does not make one an expert in [mTLS](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/mTLS/WebHome.html)
- Knowledge of Postgres and how it functions with mTLS
- Knowledge of [Ansible](https://docs.ansible.com/), [Ansible inventory](https://docs.ansible.com/ansible/latest/user_guide/intro_inventory.html) and [Ansible-vault](https://docs.ansible.com/ansible/latest/user_guide/vault.html)
- Knowledge of the application and the associated [PostgreSQL client and how it works with mTLS](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Clients/WebHome.html)
- The option to execute this in a POC environment, a test, and an acceptance environment

# Werkinstructie

This comes down to this:

- Generate a new chain
  - According to [Procedure for replacing certificates with minimal downtime](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Onderhoud/Nieuwe+certificaten+genereren+en+uitrollen/certificaten+vervangen+met+downtime/WebHome.html)
- Adjust the configuration so that the root certificates / chains include both old and new certificate bundles
  - In the Ansible inventory
  - For the application, also perform a reload (or restart)
    - From then on, the application will accept both the old and the new server certificate
    - The client continues to connect with the old certificate
  - For PostgreSQL and all PostgreSQL components including pgQuartz, pgRoute66, and AVChecker (via Ansible)
    - From then on, PostgreSQL will accept both the old and new server certificate
    - PostgreSQL also works from that point onward with the new certificate
    - All building block tools, including pgQuartz, pgRoute66, and AVChecker, will also log in using the new certificate
    - Application connections are still accepted via the old client certificate
- Adjust the application so it logs in with the new client certificate
  - From then on, the old bundles are no longer necessary
- Restore the bundles to use only the new certificates
  - Very important because if a certificate in the chain expires, the (client or server) certificate will no longer be trusted
  - Adjust in the Ansible inventory
  - Roll out at PostgreSQL (via Ansible)

## Cancelled

1: Generate a new chain according to [Procedure for replacing certificates with minimal downtime](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Onderhoud/Nieuwe+certificaten+genereren+en+uitrollen/certificaten+vervangen+met+downtime/WebHome.html).

Sla de nieuwe certificaten op in een Merge Request.

- Create a new merge request if necessary

ENV=poc

```markdown
git checkout -b "feature/new_certs_$ENV" dev
````

#glab, or follow the link in the output of the git push command

glab mr create

- ensure that the adjustments are saved in a new commit:

-

ENV=poc

```markdown
git add config/chainsmith\_$ENV.yml environments/$ENV/group_vars/all/certs{,.vault}.yml
```

```markdown
git commit -m "New chainsmith configuration and certificates for $ENV"
```

git push

2: Adjust the configuration so that the root certificates/chains contain both the old and new certificate bundles.

The old chain can be found on the existing database servers:

- `~postgres/.postgresql/root.crt`
- `/data/postgres/data/certs/root.crt`

The easiest way is to prepend these with spaces:

```
[root@gurus-pgsdb-server1 ~]# sed 's/^/    /' ~postgres/.postgresql/root.crt
```

```
-----BEGIN CERTIFICATE-----
```

MIIGRTCCBC2gAwIBAgIBATANBgkqhkiG9w0BAQsFADCB1zELMAkGA1UEBhMCTkwx

EDAOBgNVBBEMBzM3MjEgTUExEDAOBgNVBAgMB1V0cmVjaHQxEjAQBgNVBAcMCUJp

bHRob3ZlbjEiMCAGA1UECQwZQW50b25pZSB2IExlZXV3ZW5ob2VrbG4gOTE9MDsG

A1UECgw0Umlqa3NpbnN0aXR1dXQgdm9vciBWb2xrc2dlem9uZGhlaWQgZW4gTWls

aWV1IChSSVZNKTEaMBgGA1UECwwRUG9zdGdyZXMgYm91d2Jsb2sxETAPBgNVBAMM

...

```markdown
[root@gurus-pgsdb-server1 ~]# sed 's/^/ /' /data/postgres/data/certs/root.crt
```

```markdown
-----BEGIN CERTIFICATE-----
```

MIIGRTCCBC2gAwIBAgIBAjANBgkqhkiG9w0BAQsFADCB1zELMAkGA1UEBhMCTkwx

EDAOBgNVBBEMBzM3MjEgTUExEDAOBgNVBAgMB1V0cmVjaHQxEjAQBgNVBAcMCUJp

bHRob3ZlbjEiMCAGA1UECQwZQW50b25pZSB2IExlZXV3ZW5ob2VrbG4gOTE9MDsG

A1UECgw0Umlqa3NpbnN0aXR1dXQgdm9vciBWb2xrc2dlem9uZGhlaWQgZW4gTWls

aWV1IChSSVZNKTEaMBgGA1UECwwRUG9zdGdyZXMgYm91d2Jsb2sxETAPBgNVBAMM

CHBvc3RncmVzMB4XDTIyMDgxODE2NDgyOVoXDTI5MTExOTE2NDgyOVowgYsxCzAJ

...

The certificates can simply be added to the current inventory:

ENV=poc

```markdown
vim environments/$ENV/group_vars/all/certs.yml
```

```markdown
# Add the client certificate to `certs.client.chain` (right before placing the new certificate above it).
```

```markdown
# Add the server certificate to certs.server.chain (just before placing the new certificate on top).
```

Note: By not including this change in the merge request (MR), we can easily roll it back later.

## 3: Deliver the bundle of old and new chains to the Application Administrators and ask them to adjust the application configuration and load the new root certificates.

Eigenlijk is dit wat bij de vorige stap bij certs.server.chain is geplaatst.

4: Reconfigure Postgres and all related tools from the building block:

ENV=poc

```markdown
cd ~/git/ansible-postgres
```

```markdown
export ANSIBLE_VAULT_PASSWORD_FILE=~/git/ansible-postgres/bin/gpgvault
```

```markdown
ansible-playbook -i environments/$ENV rollout_new_certs.yml
```

5: Deliver the entire bundle (only new `root.crt`, and the client certificates, configuration readme, etc.) to the application administrator.

The procedure [De procedure voor 'Antwoord aanvrager](../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Antwoord+aan+de+aanvrager/WebHome.html) can be followed.

Request application administrators to register with these new client certificates (configuration adjustment and reload/restart).

```markdown
6: Roll back the changes, push to GitLab, and run Ansible again.
```

ENV=poc

cd ~/git/ansible-postgres

```markdown
git reset environments/$ENV/group_vars/all/certs{,vault}.yml
```

```markdown
export ANSIBLE_VAULT_PASSWORD_FILE=~/git/ansible-postgres/bin/gpgvault
```

```markdown
ansible-playbook -i environments/$ENV rollout_new_certs.yml --tags stolon
```

7: With this, the adjustment has been successfully implemented.
