# Introduction

Certificates are internally generated using an automation tool [chainsmith](https://wiki.corp.com/xwiki/bin/view/Infrastructuur/Team%3A%20DBA/Werkinstrukties/Postgres/Bouwsteen/Chainsmith/).

De basis hiervoor is om een nieuwe chain te genereren en te vervangen in 1 swing.

There is a procedure for [replacing certificates with minimal impact](../../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/mTLS/Certificaten+vervangen+met+weinig+impact/WebHome.html).

This procedure describes the standard method by which certificates can be replaced with downtime.

# Dependencies

- Knowledge of [mTLS](https://wiki.corp.com/xwiki/bin/view/Infrastructuur/Team%3A%20DBA/Werkinstrukties/Postgres/Bouwsteen/mTLS/)
  - Note that this page provides guidance, but it does not make you an expert in the field of [mTLS](https://wiki.corp.com/xwiki/bin/view/Infrastructuur/Team%3A%20DBA/Werkinstrukties/Postgres/Bouwsteen/mTLS/)
- Knowledge of Postgres and how it functions with [mTLS](../../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/mTLS/WebHome.html)
- Knowledge of [Ansible](https://docs.ansible.com/), [Ansible inventory](https://docs.ansible.com/ansible/latest/user_guide/intro_inventory.html), and [Ansible-vault](https://docs.ansible.com/ansible/latest/user_guide/vault.html)
- Knowledge of the application and its associated [PostgreSQL client and how it works with mTLS](https://wiki.corp.com/xwiki/bin/view/Infrastructuur/Team%3A%20DBA/Werkinstrukties/Postgres/Bouwsteen/Clients/)
- The option to execute this in a POC environment, as well as test and acceptance environments
- [Chainsmith](../../../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Chainsmith/WebHome.html)

# Werkinstructie

Check if it's necessary to adjust the Chainsmith configuration:

---

ENV=poc

```markdown
edit config/chainsmith_${ENV}.yml
```

Add all application users (check the database request form in Acme-IV-BI-Ops > General > Files > Database request forms).

Let op dat de juiste extensions ook enabled zijn.

- JDBC requires the following extensions (both client and server):

  - `keyUsages`:
    - `keyEncipherment`
    - `dataEncipherment`
    - `digitalSignature`
    
  - `extendedKeyUsages`:
    - `serverAuth`

Generating a new chain can be done as follows:

```markdown

```

ENV=poc

```markdown
rm -f environments/$ENV/group_vars/all/certs{,.vault}.yml
```

```bash
bin/chainsmith.sh $ENV
```

Afterwards, an MR can also be created if it's not already part of a Merge Request:

ENV=poc

```markdown
git checkout -b "feature/new_certs_$ENV" dev
```

```markdown
git add config/chainsmith_${ENV}.yml environments/${ENV}/group_vars/all/certs{,vault}.yml
```

```markdown
git commit -m "New chainsmith configuration and certificates for $ENV"
```

git push

#glab, or follow the link in the output of the `git push` command

glab mr create

Rol de nieuwe chain uit met Ansible:

ENV=poc

```markdown
cd ~/git/ansible-postgres
```

```markdown
export ANSIBLE_VAULT_PASSWORD_FILE=~/git/ansible-postgres/bin/gpgvault
```

```markdown
ansible-playbook -i environments/\$ENV rollout_new_certs.yml
```

With issues:

- Restart all stolon-keeper services so that `service=master` works, then run Ansible again.
- If this doesn't resolve the issue, investigate and fix it (this can be anything really).
- Once `service=master` is working, rerun the Ansible command.

Then:

- For new clusters: Proceed with [the procedure 'From Server to Running Database'](/xwiki/bin/view/Infrastructuur/Team%3A%20DBA/Werkinstrukties/Postgres/Bouwsteen/Van%20server%20naar%20draaiende%20database/)
- For new certificates for existing clusters: Set the Merge Request to Ready status and merge the MR

