---
title: Azure
summary: Deploying PgVillage on Azure with the pgv_azure playbooks and the azure inventory
authors:
  - Sebas Mannem
date: 2026-10-29
---

# Azure

On Azure, PgVillage is deployed in two steps:

1. The [pgv_azure](https://github.com/pgvillage/pgv_azure) playbooks create the Azure resources.
2. The normal PgVillage playbook deploys PostgreSQL, stolon and all other components on the created VMs.

The inventory is split in two: `inventories/standard` has the standard PgVillage config, and `inventories/azure`
has everything specific to Azure. Use both, standard first, so the Azure values win:

```bash
ansible-playbook -i inventories/standard -i inventories/azure functional-all.yml
```

It deploys Rocky Linux EL-9 on AMD64. See also:

- [Azure integration](azure.md): all `azure_` parameters, the resources, and how the inventory uses them
- [EL vs SUSE](el-vs-suse.md)
- [AMD vs ARM](amd-vs-arm.md)

## What gets created

- A separate resource group (`rg_<cluster name>`)
- A Storage Account with a container for the backups (wal-g writes to it directly, so there is no minio)
- A separate network with a subnet and a Load Balancer, which routes all traffic on a VIP to the database nodes
- A bastion host, to proxy ssh traffic for Ansible to the database hosts
- A Virtual Machine Scale Set (VMSS) with 3 database hosts

After creating the Azure resources, Ansible adds the hosts to `~/.ssh/config` and configures the data and wal disk
mountpoints. Then the normal PgVillage deployment runs on the VMSS hosts:

- Each host gets etcd, stolon-sentinel, stolon-keeper, stolon-proxy, PgBouncer and PostgreSQL
- One host is the primary database server, the others are standbys
- PostgreSQL stores its backups in the storage container

After deployment, both the Ansible control node and the bastion host can be stopped (and if needed removed).

## TL;DR

- Create an Azure VM. This is the control node that runs Ansible to create the environments:
  ```bash
  az group create --name pgVillage --location westeurope
  az vm create \
    --resource-group pgVillage \
    --name pgVControl \
    --image Debian11 \
    --admin-username azureuser \
    --generate-ssh-keys \
    --tags applicationRole=ansible_runner
  ```

    !!! note
        - VM size B1ls seems too small. B1s works properly.
        - You can also use this image: `--image susellc:opensuse-leap-x86-64:gen2:2026.04.01`

- Log into it:
  ```bash
  ssh azureuser@$(az vm show -d -g pgVillage -n pgVControl --query publicIps -o tsv)
  ```

- Bootstrap it into a PgVillage Ansible control node:
  ```bash
  curl https://raw.githubusercontent.com/pgvillage/pgv_azure/main/bootstrap_debian.sh | bash
  ```
  or for SUSE:
  ```bash
  curl https://raw.githubusercontent.com/pgvillage/pgv_azure/main/bootstrap_suse.sh | bash
  ```

- The control node uses the Azure API to create the database VMs, so log in to Azure on it too: `az login`.

    !!! note
        At the time of writing, azure-cli was not compatible with the azure_rm modules.
        Therefore we created `az_to_env`, which creates another virtual env for `az`, downloads it, logs in and then
        generates `azure_creds.env`. After that, run `. azure_creds.env` and then run Ansible with Azure authentication.

- Deploy a cluster:
  ```bash
  ~/git/pgv_azure/create_new_cluster.sh
  ```

### Alternative

- Create a CentOS VM Ansible control node on Azure by following
  [this guide](https://docs.microsoft.com/en-us/azure/developer/ansible/install-on-linux-vm?tabs=azure-cli#install-ansible-on-an-azure-linux-virtual-machine).
- After that, manually do everything the bootstrap script does (no script available yet).
- Then create credentials and follow the instructions above.

## The inventory

`inventories/azure`:

| File                                  | Purpose                                                                                       |
|---------------------------------------|-----------------------------------------------------------------------------------------------|
| `azure_rm.yml`                        | Dynamic inventory: finds the VMs in `pgVillage` and `rg_<cluster name>`, and groups them by the `applicationRole` tag (`_postgres`). |
| `hosts`                               | Maps `_postgres` to the PgVillage groups `hacluster`, `stolon` and `etcd_master`.             |
| `host_vars/localhost/`                | The control node runs Ansible locally and needs no chainsmith cert files.                     |
| `group_vars/_postgres/.README`        | Placeholder, Ansible writes files to this folder.                                             |
| `group_vars/all/azure.yml`            | Azure resources: control node IP, resource group, storage container, and VM size/image/plan.  |
| `group_vars/all/generic.yml`          | VIP and `pg_hba` for the Azure Load Balancer.                                                 |
| `group_vars/all/chainsmith.yml`       | Adds the VIP to the server certificates.                                                      |
| `group_vars/all/wal-g.yml`            | Backups to the storage container (`WALG_AZ_PREFIX`, `AZURE_STORAGE_*`).                       |

`inventories/standard` has the rest: Postgres version, mountpoints, ports, packages, and the config of stolon,
wal-g, avchecker, nagios, etc. A file in `inventories/azure/group_vars/all/` with the same name as one in
`inventories/standard/group_vars/all/` overrides its values. See [Azure integration](azure.md) for details.

### Cluster name

The cluster name is the name of the inventory folder (`cluster_name: "{{ inventory_dir | basename }}"`), so
`inventories/azure` deploys a cluster named `azure` in resource group `rg_azure`.

To deploy another cluster, copy `inventories/azure` and change the resource group names in `azure_rm.yml`:

```yaml
include_vm_resource_groups:
  - pgVillage
  - rg_<new folder name>
include_vmss_resource_groups:
  - rg_<new folder name>
```

### Variants

The inventory used to have three clusters. They are now one inventory plus the changes on these pages:

| Former cluster | OS / architecture        | Changes                                      |
|----------------|--------------------------|----------------------------------------------|
| cluster1       | Rocky Linux EL-9, AMD64  | none (this is the default)                   |
| cluster2       | EL, ARM64                | [AMD vs ARM](amd-vs-arm.md)                  |
| cluster3       | openSUSE Leap, AMD64     | [EL vs SUSE](el-vs-suse.md)                  |

Apart from these changes, the clusters differed only in their name (and thus the resource groups in `azure_rm.yml`).

### Control node IP

Set `azure_control_ip` in `inventories/azure/group_vars/all/azure.yml` to the public IP of your control node:

```yaml
azure_control_ip: 203.0.113.10
```

## Using other images

1. Find the publisher, the offer and the urn of the image to use
   (in this example we use [resf](https://forums.rockylinux.org/t/rocky-linux-images-on-azure-important-update/13721)):
   ```bash
   az vm image list-publishers --location westeurope --output table
   az vm image list --output table --all --publisher resf
   az vm image list --publisher resf --offer rockylinux-aarch64 --all --output table
   ```

2. Accept the license:
   ```bash
   az vm image terms accept --publisher resf --offer rockylinux-x86_64 --plan 9-lvm
   ```

3. Change `inventories/azure/group_vars/all/azure.yml` to use this image for the bastion and/or the VMSS (replace the fields in `[]`
   with the corresponding columns of the command). See [EL vs SUSE](el-vs-suse.md) and [AMD vs ARM](amd-vs-arm.md)
   for examples.
   ```yaml
   azure_vmss_image:
     offer: [Offer]
     publisher: [Publisher]
     version: [Version]
     sku: [Sku]
   azure_vmss_plan:
     name: [Sku]
     product: [Offer]
     publisher: [Publisher]
   ```

## Known issues and quirks

- VM size B1ls seems too small for pgVControl. B1s works fine.
- Every now and then, upgrade the Ansible code, bootstrap script and Python modules:
  ```bash
  cd ~/git/pgv_azure/
  git pull
  ./bootstrap_debian.sh
  ```
- `roles/azure/defaults/main.yml` derives `azure_storage_account_name` from the cluster name and the machine_id of the
  control node. That makes it pretty much unique across Azure (which is the idea), but it might change after a reboot,
  and it changes between control nodes. **For production, always set it to a unique but hardcoded value.**
- When rerunning, the vmss module complains with `The orchestration_mode parameter cannot be updated!`. This should
  probably be fixed by the Ansible community.
- If the VMSS uses a different image than the bastion, you need to accept the image terms, e.g. for Rocky Linux:
  ```bash
  az vm image terms accept --urn resf:rockylinux-x86_64:9-base:9.6.20250531
  ```
