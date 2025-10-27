# Ansible

This document describes how to deploy the **PostgreSQL standard building block** using **Ansible**.

Before running Ansible, ensure that all prerequisites are correctly configured.

## 1. Prerequisites

### 1.1 SSH Setup

Ensure that SSH access is properly configured.  

- In our predefinied deployments (`pgv_azure` and `pgv_vagrant`) this is already taken care of.
For on-prem deployments, make sure that a user with proper permissions and ssh authentication is created.
- Git clone and Ansible setup of the Ansible code (this work instruction)

---
## 2. Materials needed

To perform this procedure, you will need:

- Access to the **management server**  
  (See also the [SSH documentation](../ssh.md))
- Access to the **Ansible code repository:**  
  [https://github.com/pgvillage/pgvillage](https://github.com/pgvillage/pgvillage)

---
## 3. Working instruction

### Step 1: Clone the repository

Create a Git folder in your home directory, navigate into it, and clone the repository:

```bash
mkdir -p ~/git
cd ~/git
git clone git@github.com:pgvillage/pgvillage.git
```
---
### Step 2: (Optional) Adjust the inventory configuration

Optionally adjust the inventory configuration to suit your environment.  
For detailed steps, refer to:  
[From Server to Running Database](inventory.md)

---
### Step 3: Run the Ansible Playbook

#### 3.1 Navigate to the Ansible directory

Go to the cloned Ansible repository directory:

```bash
cd ~/git/ansible-postgres
```

#### 3.2 Run everything

Execute all roles for the selected environment:

```bash
ansible-playbook -i environments/[ENV] functional-all.yml
```

#### 3.3 Run specific roles (example)

If you want to run only specific roles (for example, `stolon` and `avchecker`):

```bash
ansible-playbook -i environments/[ENV] functional-all.yml --tags stolon,avchecker
```

#### 3.4 Additional examples

For other related examples and procedures, refer to the following documentation:

- [Chainsmith](chainsmith.md)
- [Inventory](inventory.md)