---
title: Azure - deploy
summary: Step by step deployment of a PgVillage cluster on Azure
authors:
  - Sebas Mannem
date: 2026-10-29
---

# Azure - deploy

This page describes how to deploy a PgVillage cluster on Azure, from an empty subscription to a running cluster.
For what gets created and all parameters, see [Azure](index.md) and [Azure integration](azure.md).

Everything runs from an Ansible control node in Azure:

| Path                                  | What                                                                             |
|---------------------------------------|----------------------------------------------------------------------------------|
| `scripts/bootstrap_debian.sh`         | Turns a Debian VM into a control node (Ansible, collections, roles, chainsmith, az). |
| `scripts/bootstrap_suse.sh`           | Same for openSUSE.                                                               |
| `scripts/az_to_env`                   | Creates a service principal and writes its credentials to `azure_creds.env`.     |
| `scripts/create_new_cluster.sh`       | Runs all playbooks below, in order.                                              |
| `playbooks/azure/create_resources.yml`| Creates the Azure resources with the `azure` role (`roles/azure`).               |
| `playbooks/azure/inventory.yml`       | Adds the bastion and database hosts to `~/.ssh/config`.                          |
| `playbooks/azure/mount.yml`           | Partitions, formats and mounts the data and wal disks (`files/mount_part.sh`).   |
| `functional-all.yml`                  | The normal PgVillage deployment.                                                 |
| `playbooks/azure/clean_resources.yml` | Removes the cluster (the whole resource group).                                  |

All playbooks use both inventories, standard first: `-i inventories/standard -i inventories/azure`.

## Prerequisites

- An Azure subscription, and permission to create a service principal with the Contributor role on it.
- The [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) on your workstation, logged in
  (`az login`).

## 1. Create the control node

Create a resource group `pgVillage` and a VM in it. The name `pgVillage` is fixed: `azure_rm.yml` reads VMs from it.

```bash
az group create --name pgVillage --location westeurope
az vm create \
  --resource-group pgVillage \
  --name pgVControl \
  --image Debian11 \
  --size Standard_B1s \
  --admin-username azureuser \
  --generate-ssh-keys \
  --tags applicationRole=ansible_runner
```

!!! note
    - Use `azureuser` as admin user. The `azure` role creates the database hosts with the same user as the one
      running Ansible, but installs the ssh key in `/home/azureuser`.
    - B1ls is too small; B1s works.
    - For openSUSE, use `--image susellc:opensuse-leap-x86-64:gen2:2026.04.01` and `bootstrap_suse.sh` below.

Log in:

```bash
ssh azureuser@$(az vm show -d -g pgVillage -n pgVControl --query publicIps -o tsv)
```

## 2. Bootstrap the control node

```bash
curl https://raw.githubusercontent.com/pgvillage/pgvillage/main/scripts/bootstrap_debian.sh | bash
```

or for openSUSE:

```bash
curl https://raw.githubusercontent.com/pgvillage/pgvillage/main/scripts/bootstrap_suse.sh | bash
```

This clones PgVillage to `~/git/pgvillage`, installs Ansible, the `azure.azcollection` collection and its Python
requirements, the PgVillage roles and collections from `requirements.yml`, chainsmith (Debian) and the Azure CLI, and
creates an ssh key (`~/.ssh/id_rsa`).

!!! tip
    To deploy from another branch, set `PGVILLAGE_BRANCH`, e.g.
    `curl .../scripts/bootstrap_debian.sh | PGVILLAGE_BRANCH=my-branch bash`.

Then log out and in again (or `source ~/.profile`, `source ~/.bashrc` on openSUSE) to get `ansible-playbook` in your
`PATH`.

## 3. Azure credentials

The Azure CLI conflicts with the Python modules of the Ansible Azure modules, so Ansible uses a service principal
instead:

```bash
cd ~/git/pgvillage
scripts/az_to_env
source azure_creds.env
```

`az_to_env` creates a venv for the Azure CLI (`~/venv_az`, only used inside the script), logs in, creates (or resets) the service principal
`Ansible-Power-User` with the Contributor role on the subscription, and writes its credentials to `azure_creds.env`.
`azure_creds.env` is in `.gitignore`; keep it private.

!!! warning
    `az ad sp create-for-rbac` resets the secret when the service principal already exists, so an `azure_creds.env`
    on another control node stops working when you run `az_to_env` again.

Check that Ansible can reach Azure; this should list the control node in `_ansible_runner`:

```bash
ansible-inventory -i inventories/standard -i inventories/azure --graph
```

## 4. Configure the inventory

Set `azure_control_ip` in `inventories/azure/group_vars/all/azure.yml` to the public IP of the control node. It is the
only address allowed to ssh to the bastion and database hosts:

```bash
curl -s https://ifconfig.me
```

```yaml
azure_control_ip: 203.0.113.10
```

Optionally:

- **Another cluster name**: the cluster name is the inventory folder name, `azure` by default (resource group
  `rg_azure`). Copy the folder and change the resource groups in `azure_rm.yml`, see
  [Cluster name](index.md#cluster-name).
- **Another OS or architecture**: see [EL vs SUSE](el-vs-suse.md) and [AMD vs ARM](amd-vs-arm.md).
- **Production**: set fixed values for `azure_storage_account_name` and `azure_vip_dns_name`, see
  [Azure integration](azure.md#cluster-and-location).

## 5. Deploy

```bash
cd ~/git/pgvillage
scripts/create_new_cluster.sh            # inventories/azure
scripts/create_new_cluster.sh mycluster  # inventories/mycluster
```

The script runs these steps; you can also run them one by one:

```bash
INV="-i inventories/standard -i inventories/azure"
ansible-playbook $INV playbooks/azure/create_resources.yml
sleep 90   # give the VMSS hosts time to boot
ansible-playbook $INV playbooks/azure/inventory.yml
ansible-playbook $INV playbooks/azure/mount.yml
ansible-playbook $INV functional-all.yml
```

1. **`create_resources.yml`** creates the resource group, storage account and container, network, VIP, security
   group, load balancer, bastion and VMSS. It writes the VIP, storage account key and bastion proxy settings into the
   inventory (see [Generated files](azure.md#generated-files)); the next playbooks read them.
2. **`inventory.yml`** adds every bastion and database host to `~/.ssh/config`, so you can `ssh <host>` from the
   control node (through the bastion).
3. **`mount.yml`** finds the unpartitioned disks on each database host, partitions and formats them (ext4), and mounts
   the largest on `postgresql_data_mountpoint` and the smallest on `postgresql_wal_mountpoint`.
4. **`functional-all.yml`** deploys PostgreSQL, stolon, etcd, wal-g, PgBouncer, avchecker, etc.

## 6. Check the deployment

List the hosts:

```bash
ansible-inventory -i inventories/standard -i inventories/azure --graph
```

Log in to a database host and check PostgreSQL:

```bash
ssh <database host>
sudo -iu postgres psql -h /tmp -c 'select pg_is_in_recovery()'
```

One host returns `f` (the primary), the others `t` (standbys).

Clients connect to the VIP (`azure_vip_dns_fqdn` in `inventories/azure/group_vars/all/azure_vip.yml`): port 5432 for
read-write, 5433 for read-only. `pg_hba` only allows certificate authentication (`hostssl ... cert`), so clients need a
client certificate from chainsmith.

## 7. Afterwards

- The control node and the bastion are only needed for deployments and maintenance. You can stop them:
  ```bash
  az vm deallocate -g pgVillage -n pgVControl
  az vm deallocate -g rg_azure -n bastionazure
  ```
- Keep the control node up to date every now and then:
  ```bash
  cd ~/git/pgvillage && git pull && scripts/bootstrap_debian.sh
  ```

## Remove the cluster

```bash
ansible-playbook -i inventories/standard -i inventories/azure playbooks/azure/clean_resources.yml
```

This deletes the resource group `rg_azure` with everything in it (only when `azure_allow_clean` is `true`), and
removes the generated files from the inventory. Backups in the storage account are deleted too.

Remove the control node with `az group delete --name pgVillage`.

## Troubleshooting

- **`Failed to get credentials`** when parsing `azure_rm.yml`: `azure_creds.env` is not loaded in this shell
  (`source azure_creds.env`).
- **`The orchestration_mode parameter cannot be updated!`** when rerunning `create_resources.yml`: a known issue of the
  VMSS module on reruns.
- **Image terms not accepted**: if the VMSS uses another image than the bastion, accept its terms first, e.g.
  `az vm image terms accept --urn resf:rockylinux-x86_64:9-base:9.6.20250531`.
- **`mount.yml` fails with `more disks then I expected`**: the host has more than two unpartitioned disks.
- **Hosts unreachable after `create_resources.yml`**: the VMSS hosts were not up yet; rerun `inventory.yml`.
