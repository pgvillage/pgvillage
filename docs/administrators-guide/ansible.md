# Introduction

Het PostgreSQL standaard bouwblok wordt uitgerold middels Ansible.

Voor Ansible dient een aantal zaken goed geregeld te zijn:

- [ssh](../../../../../../../../pages/xwiki/Infrastructuur/Team%3A+DBA/Werkinstrukties/Postgres/Bouwsteen/ssh/WebHome.html) setup (andere WI)
- Git clone and Ansible setup of the Ansible code (this work instruction)

# Materials Needed

- Access to the management server (see also the [ssh](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/ssh/WebHome.html) documentation)
- Access to the Ansible code: [https://gitlab.int.corp.com/gurus-db-team/ansible-postgres](https://gitlab.int.corp.com/gurus-db-team/ansible-postgres)

# Working Instruction

```markdown
1: Create a Git folder in your home directory, navigate into the folder and clone the repository:
```
```

```
mkdir -p ~/git
```

cd ~/git

```markdown
git clone git@gitlab.int.corp.com:gurus-db-team/ansible-postgres.git
```

2: Set up GPG, follow the instructions on [GPGVAULT.md](https://gitlab.int.corp.com/gurus-db-team/ansible-postgres/-/blob/dev/GPGVAULT.md)

---

3: optionally adjust the inventory configuration (see [from server to running database](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Van+server+naar+draaiende+database/WebHome.html) for the procedure)
---

4: Turn crank (ansible):

```markdown
cd ~/git/ansible-postgres
```

```markdown
export ANSIBLE_VAULT_PASSWORD_FILE=~/git/ansible-postgres/bin/gpgvault
```

#Everything

```markdown
ansible-playbook-i-environments/[ENV]functional-all.yml
```

#Specifiekerollen(bijvoorbeeld)

```markdown
ansible-playbook ienenvironments/\[ENV\]functional-all.yml --tags stolon,avchecker
```

For other examples:

```markdown
- [roll out new certificates](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Onderhoud/Nieuwe+certificaten+genereren+en+uitrollen/WebHome.html)
- [new features](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Onderhoud/Nieuwe+features/WebHome.html)
- [from server to running database](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Van+server+naar+draaiende+database/WebHome.html)
```

