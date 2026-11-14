---
title: Ansible
summary: A description of requirements to setup Ansible for deploying PgVillage
authors:
  - Sebas Mannem
  - Snehal Kapure
date: 2025-11-11
---

# Ansible

This document describes how to deploy the **PostgreSQL standard building block** using **Ansible**.

Before running Ansible, ensure that all prerequisites are correctly configured.

## 1. Prerequisites

### 1.1 SSH Setup

Ensure that SSH access is properly configured.

- In the platforms shipped with PgVillage ([Azure](../platforms/azure/index.md), [Vagrant](../../try-it/vagrant/index.md)
  and [Lima](../../try-it/lima.md)) this is already taken care of.
  For your own machines (on-prem), make sure that a user with proper permissions and ssh authentication is created,
  see [Bring your own machines](../byo.md#checklist).
- Git clone and Ansible setup of the Ansible code (this work instruction)

---

## 2. Materials needed

To perform this procedure, you will need:

- Access to the **management server**  
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
PgVillage ships its inventories in `inventories/`: the standard config (`inventories/standard`), an OS layer
(`inventories/os/el`, `inventories/os/debian`, `inventories/os/suse`) and platform inventories with the hosts
(`inventories/platform/vagrant`, `inventories/platform/lima`, `inventories/platform/azure`).
Add your own inventory for your hosts, e.g. `inventories/<cluster>`, see [Getting started](../../index.md).  
For detailed steps, refer to:  
[Inventory explained](../inventory/index.md)

---

### Step 3: Run the Ansible Playbook

#### 3.1 Navigate to the Ansible directory

Go to the cloned Ansible repository directory:

```bash
cd ~/git/pgvillage
```

#### 3.2 Run everything

Execute all roles for the selected inventory, on top of the standard config and the OS layer (`os/el`, `os/debian` or
`os/suse`) of your hosts:

```bash
ansible-playbook -i inventories/standard -i inventories/os/el -i inventories/<cluster> functional-all.yml
```

#### 3.3 Run specific roles (example)

If you want to run only specific roles (for example, `stolon` and `avchecker`):

```bash
ansible-playbook -i inventories/standard -i inventories/os/el -i inventories/<cluster> functional-all.yml --tags stolon,avchecker
```

Which roles `functional-all.yml` runs, on which groups and in which order, is set in the inventory: see
[Roles in functional-all.yml](../../reference/steps.md).

#### 3.4 Additional examples

For other related examples and procedures, refer to the following documentation:

- [Chainsmith](../../tools/chainsmith.md)
- [Inventory explained](../inventory/index.md)

