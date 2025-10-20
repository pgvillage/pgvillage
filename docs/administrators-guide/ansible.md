# Ansible

This document describes how to deploy the **PostgreSQL standard building block** using **Ansible**.

Before running Ansible, ensure that all prerequisites are correctly configured.

## 1. Prerequisites

### 1.1 SSH Setup

Ensure that SSH access is properly configured.  

- [ssh](../../../../../../../../pages/xwiki/Infrastructuur/Team%3A+DBA/Werkinstrukties/Postgres/Bouwsteen/ssh/WebHome.html) setup (andere WI)
- Git clone and Ansible setup of the Ansible code (this work instruction)

---
## 2. Materials needed

To perform this procedure, you will need:

- Access to the **management server**  
  (See also the [SSH documentation](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/ssh/WebHome.html))
- Access to the **Ansible code repository:**  
  [https://gitlab.int.corp.com/gurus-db-team/ansible-postgres](https://gitlab.int.corp.com/gurus-db-team/ansible-postgres)

---
## 3. Working instruction

### Step 1: Clone the repository

Create a Git folder in your home directory, navigate into it, and clone the repository:

```bash
mkdir -p ~/git
cd ~/git
git clone git@gitlab.int.corp.com:gurus-db-team/ansible-postgres.git
```

### Step 2: Set up GPG

Set up GPG by following the instructions provided in the repository documentation:  
[GPGVAULT.md](https://gitlab.int.corp.com/gurus-db-team/ansible-postgres/-/blob/dev/GPGVAULT.md)

---
### Step 3: (Optional) Adjust the inventory configuration

Optionally adjust the inventory configuration to suit your environment.  
For detailed steps, refer to:  
[From Server to Running Database](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Van+server+naar+draaiende+database/WebHome.html)


---
### Step 4: Run the Ansible Playbook

#### 4.1 Navigate to the Ansible directory

Go to the cloned Ansible repository directory:

```bash
cd ~/git/ansible-postgres
```

#### 4.2 Export the vault password file

Set the Ansible Vault password file environment variable:

```bash
export ANSIBLE_VAULT_PASSWORD_FILE=~/git/ansible-postgres/bin/gpgvault
```

#### 4.3 Run everything

Execute all roles for the selected environment:

```bash
ansible-playbook -i environments/[ENV] functional-all.yml
```

#### 4.4 Run specific roles (example)

If you want to run only specific roles (for example, `stolon` and `avchecker`):

```bash
ansible-playbook -i environments/[ENV] functional-all.yml --tags stolon,avchecker
```

#### 4.5 Additional examples

For other related examples and procedures, refer to the following documentation:

- [Roll Out New Certificates](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Onderhoud/Nieuwe+certificaten+genereren+en+uitrollen/WebHome.html)
- [New Features](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Onderhoud/Nieuwe+features/WebHome.html)
- [From Server to Running Database](../../../../../../../../pages/xwiki/Infrastructuur/Team%253A+DBA/Werkinstrukties/Postgres/Bouwsteen/Van+server+naar+draaiende+database/WebHome.html)