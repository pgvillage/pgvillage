---
title: Azure integration
summary: Reference for the Azure integration - the azure role, all azure_ parameters, and how the inventory uses them
authors:
  - Sebas Mannem
date: 2026-10-29
---

# Azure integration

The Azure integration has three parts:

1. **The `azure` role** (`roles/azure`) creates the Azure resources: resource group, storage account, network, load
   balancer, bastion host and a VM Scale Set (VMSS) for the database hosts. It runs on the control node, against
   `localhost`.
2. **The inventory** (`inventories/azure`, on top of `inventories/standard`) finds the created VMs with the
   `azure_rm` dynamic inventory plugin, and passes the Azure details (VIP, storage account) to the PgVillage roles.
3. **pgv_azure** ([repo](https://github.com/pgvillage/pgv_azure)) bootstraps the control node, configures the data and
   wal disks, and has the scripts to create (`create_new_cluster.sh`) and clean clusters. See [Azure](index.md).

## Resources

All resources are created in `azure_resource_group`, in `azure_location`.

| Resource                       | Name parameter               | Default name                      | Task          |
|--------------------------------|------------------------------|-----------------------------------|---------------|
| Resource group                 | `azure_resource_group`       | `rg_<cluster>`                    | `rg.yml`      |
| Storage account                | `azure_storage_account_name` | `sa<cluster><machine id>`         | `bucket.yml`  |
| Storage container (backups)    | `azure_storage_container`    | `backup<cluster>`                 | `bucket.yml`  |
| Virtual network (`10.0.0.0/16`)| `azure_nw_name`              | `nw_<cluster>`                    | `nw.yml`      |
| Subnet (`10.0.1.0/24`)         | `azure_subnet_name`          | `sn_<cluster>`                    | `nw.yml`      |
| Public IP (VIP)                | `azure_vip_name`             | `vip_<cluster>`                   | `nw.yml`      |
| Network security group         | `azure_sg_name`              | `sg_<cluster>`                    | `nw.yml`      |
| Load balancer                  | `azure_lb_name`              | `lb_<cluster>`                    | `nw.yml`      |
| Load balancer frontend         | `azure_lbfe_name`            | `lbfe_<cluster>`                  | `nw.yml`      |
| Load balancer backend pool     | `azure_lbbe_name`            | `lbbe_<cluster>`                  | `nw.yml`      |
| Bastion VM                     | `azure_bastion_name`         | `bastion<cluster>`                | `vmss.yml`    |
| VM Scale Set (database hosts)  | `azure_vmss_name`            | `vmss<cluster>`                   | `vmss.yml`    |

`<cluster>` is `azure_cluster_name`, which the inventory sets to the name of the inventory folder.

## Parameters

### Cluster and location

| Parameter                   | Default                                                              | Description |
|-----------------------------|----------------------------------------------------------------------|-------------|
| `azure_cluster_name`        | `cluster1` (inventory: `{{ cluster_name }}`)                         | Base for all resource names. |
| `azure_cluster_unique_name` | `{{ azure_cluster_name }}{{ ansible_machine_id \| truncate(10, true, '') }}` | Cluster name plus the first 10 characters of the machine id of the control node. Used where Azure needs a globally unique name: the storage account and the VIP DNS name. |
| `azure_resource_group`      | `rg_{{ azure_cluster_name }}` (also set in the inventory)            | Resource group for all resources. Must match `azure_rm.yml`. |
| `azure_location`            | `westeurope`                                                         | Azure region. Also part of `azure_vip_dns_fqdn`. |
| `azure_control_ip`          | none (inventory: placeholder)                                        | Public IP of the control node. The only source allowed to ssh, see [Security group](#security-group). |
| `azure_allow_clean`         | none (inventory: `true`)                                             | Allows the pgv_azure clean playbook to remove the cluster. |

!!! warning
    `azure_cluster_unique_name` depends on the machine id of the control node. It changes when you use another
    control node, and then the storage account and VIP DNS name change too. **For production, set
    `azure_storage_account_name` and `azure_vip_dns_name` to fixed, unique values.**

### Network and VIP

| Parameter            | Default                                                   | Description |
|----------------------|-----------------------------------------------------------|-------------|
| `azure_nw_name`      | `nw_{{ azure_cluster_name }}`                             | Virtual network (`10.0.0.0/16`, hardcoded). |
| `azure_subnet_name`  | `sn_{{ azure_cluster_name }}`                             | Subnet (`10.0.1.0/24`, hardcoded). Bastion and VMSS are both in it. |
| `azure_vip_name`     | `vip_{{ azure_cluster_name }}`                            | Static Standard public IP, used as load balancer frontend. |
| `azure_vip_dns_name` | `{{ azure_cluster_unique_name }}`                         | DNS label of the VIP. |
| `azure_vip_dns_fqdn` | `{{ azure_vip_dns_name }}.{{ azure_location }}.cloudapp.azure.com` | FQDN of the VIP. |
| `azure_sg_name`      | `sg_{{ azure_cluster_name }}`                             | Network security group. |
| `azure_lb_name`      | `lb_{{ azure_cluster_name }}`                             | Standard load balancer. |
| `azure_lbfe_name`    | `lbfe_{{ azure_cluster_name }}`                           | Load balancer frontend IP configuration. |
| `azure_lbbe_name`    | `lbbe_{{ azure_cluster_name }}`                           | Load balancer backend pool (the VMSS). |

### Bastion

| Parameter               | Default                   | Description |
|-------------------------|---------------------------|-------------|
| `azure_bastion_name`    | `bastion{{ azure_cluster_name }}` | Name of the bastion VM. |
| `azure_bastion_vm_size` | `Standard_B1ls`           | VM size. |
| `azure_bastion_image`   | `{{ azure_vmss_image }}`  | Image; same as the VMSS by default. |
| `azure_bastion_plan`    | `{{ azure_vmss_plan }}`   | Marketplace plan. When not empty, the image terms are accepted automatically. Set to `{}` for images without a plan. |

### Database hosts (VMSS)

| Parameter            | Default                    | Description |
|----------------------|----------------------------|-------------|
| `azure_vmss_name`    | `vmss{{ cluster_name }}`   | Name of the VM Scale Set. Note: uses `cluster_name`, not `azure_cluster_name`. |
| `azure_vmss_vm_size` | `Standard_DS1_v2`          | VM size. |
| `azure_vmss_vm_count`| `3`                        | Number of database hosts. |
| `azure_vmss_image`   | Rocky Linux 9 x86_64 (`resf:rockylinux-x86_64:9-base:9.6.20250531`) | Image: `offer`, `publisher`, `sku`, `version`. See [EL vs SUSE](el-vs-suse.md) and [AMD vs ARM](amd-vs-arm.md). |
| `azure_vmss_plan`    | `resf` / `rockylinux-x86_64` / `9-base` | Marketplace plan: `name`, `publisher`, `product`. Set to `null` for images without a plan. |

### Disks

Each database host gets an OS disk and two data disks. pgv_azure mounts them on `postgresql_data_mountpoint` and
`postgresql_wal_mountpoint`.

| Parameter              | Default                     | Description |
|------------------------|-----------------------------|-------------|
| `azure_vm_disk_type`   | `Standard_LRS`              | Managed disk type for the OS disks (bastion and VMSS). |
| `azure_data_gb`        | `100`                       | Size of the data disk (LUN 0). |
| `azure_data_disk_type` | `{{ azure_vm_disk_type }}`  | Disk type of the data disk. |
| `azure_wal_gb`         | `10`                        | Size of the wal disk (LUN 1). |
| `azure_wal_disk_type`  | `{{ azure_data_disk_type }}`| Disk type of the wal disk. |

### Backups (storage account)

| Parameter                    | Default                                | Description |
|------------------------------|----------------------------------------|-------------|
| `azure_storage_account_name` | `sa{{ azure_cluster_unique_name }}`    | Storage account. Must be globally unique (3-24 lowercase letters and digits). |
| `azure_storage_account_type` | `Standard_RAGRS`                       | Replication type of the storage account. |
| `azure_storage_container`    | `backup{{ azure_cluster_name }}` (also set in the inventory) | Blob container wal-g writes to. |
| `azure_backup_access_key`    | generated                              | Access key of the storage account, see [Generated files](#generated-files). |

## Load balancer

The load balancer sends traffic on the VIP to all database hosts. Health probes decide which hosts get traffic.

| Frontend port | Backend port | Probe port | Use |
|---------------|--------------|------------|-----|
| 22            | 22           | 22         | ssh to a (random) database host |
| 5432          | 25432        | 5432       | read-write, through the stolon proxy on each host (which connects to the primary) |
| 5433          | 5432         | 25432      | read-only, directly to PostgreSQL on any host (primary or standby) |

These match `postgresql_rw_port: 5432`, `postgresql_ro_port: 5433` and `postgresql_proxy_port: 25432` in
`inventories/standard/group_vars/all/generic.yml`, but they are hardcoded in the role.

## Security group

| Rule          | Port | Source                    |
|---------------|------|---------------------------|
| ssh           | 22   | `{{ azure_control_ip }}/32` |
| PostgreSQL_rw | 5432 | any                       |
| PostgreSQL_ro | 5433 | any                       |

## SSH access

- The role reads `~/.ssh/id_rsa.pub` of the control node user and installs it for the admin user on the bastion and
  the VMSS hosts. The admin user is the user running Ansible on the control node (`ansible_user_id`).
- Ansible reaches the database hosts through the bastion (see `proxy.yml` below).

## Generated files

The role writes these files into the inventory, so the PgVillage playbook can use the values:

| File                              | Written by   | Contents |
|-----------------------------------|--------------|----------|
| `group_vars/all/azure_vip.yml`    | `nw.yml`     | `azure_vip_ip`, `azure_vip_dns_fqdn` |
| `group_vars/_postgres/wal-g.yml`  | `bucket.yml` | `azure_backup_access_key`, `azure_storage_account_name` |
| `group_vars/_postgres/proxy.yml`  | `vmss.yml`   | `ansible_ssh_common_args` with a `ProxyCommand` through the bastion's public IP |

!!! danger
    `group_vars/_postgres/wal-g.yml` contains the storage account access key. Never commit these files; they are
    in `.gitignore`.

## Inventory

### Dynamic inventory

`azure_rm.yml` uses the `azure.azcollection.azure_rm` plugin. It reads VMs from the `pgVillage` resource group (the
control node) and the cluster resource group, including the VMSS instances. `keyed_groups` on the
`applicationRole` tag creates a group per role:

| Tag `applicationRole` | Set on          | Group              |
|-----------------------|-----------------|--------------------|
| `ansible_runner`      | control node    | `_ansible_runner`  |
| `bastion`             | bastion VM      | `_bastion`         |
| `postgres`            | VMSS            | `_postgres`        |
| `backup`              | storage account | (not a VM, no group) |

`auth_source: auto` takes the Azure credentials from the environment (e.g. `. azure_creds.env`, see
[Azure](index.md)), `~/.azure/credentials` or `az login`. Without credentials the plugin fails to parse and the
inventory has no database hosts.

`hosts`:

- Maps `_postgres` to the PgVillage groups `hacluster`, `stolon` and `etcd_master`.
- Defines `localhost` in `localhosts`. It must be defined here and not in `inventories/standard`: `inventory_dir`
  of `localhost` is the inventory that defines it, and that sets `cluster_name` (and so all resource names) and
  the folder the role writes its [generated files](#generated-files) to.
- The `backup` group is empty: there is no minio, wal-g writes to the storage account.

`host_vars/localhost` makes Ansible run locally on the control node (`ansible_connection: local`, with the Python
of `ansible-playbook`), and sets no chainsmith cert files (`chainsmith_cert_files: []`).

`group_vars/_postgres/.README` is a placeholder, so git creates the folder the role writes `wal-g.yml` and
`proxy.yml` to.

### How PgVillage uses the Azure values

The Azure values are passed to PgVillage by files in `inventories/azure/group_vars/all/` that override the file
with the same name in `inventories/standard/group_vars/all/`.

| Inventory file                  | Uses                                    | For |
|---------------------------------|-----------------------------------------|-----|
| `group_vars/all/azure.yml`      | `azure_*`                               | Settings for the azure role. |
| `group_vars/all/generic.yml`    | `azure_vip_dns_fqdn`, `azure_vip_ip`    | `postgresql_vip_fqdn`, `postgresql_vip_ip` |
| `group_vars/all/generic.yml`    | `azure_vip_ip`                          | `stolon_pg_hba`: the standard rules plus `hostssl all all <vip>/32 cert`, for traffic through the load balancer |
| `group_vars/all/chainsmith.yml` | `azure_vip_dns_fqdn`, `azure_vip_ip`    | VIP added to the SANs of all server certificates |
| standard `avchecker.yml`        | `postgresql_vip_fqdn`                   | `routerrw` and `routerro` checks on the VIP (ports 5432 and 5433); no override needed |
| `group_vars/all/wal-g.yml`      | `azure_storage_container`, `azure_storage_account_name`, `azure_backup_access_key` | `walg_bucket_defaults`: `WALG_AZ_PREFIX`, `AZURE_STORAGE_ACCOUNT`, `AZURE_STORAGE_ACCESS_KEY` |

### Firewall

Traffic from outside is filtered by the network security group. The `pgvillage.firewall` play still runs on
`hacluster`, but the azure inventory sets no `firewall_*` variables, so the role runs with its defaults.

## Known limitations

- Ports in the load balancer and security group are hardcoded (5432, 5433, 25432); they don't follow
  `postgresql_*_port`. Multi-instance (more ports per host) needs changes in the role.
- The network ranges (`10.0.0.0/16`, `10.0.1.0/24`) are hardcoded.
- The ssh public key path is hardcoded to `/home/azureuser/.ssh/authorized_keys`, while the admin user is the user
  running Ansible. Run Ansible as `azureuser`, or the key ends up in the wrong home directory.
- Only `~/.ssh/id_rsa.pub` is supported (no ed25519 keys).
- PostgreSQL ports are open to any source in the security group.
- The role creates the security group, but doesn't attach it to the subnet or the VMSS (no `security_group`
  parameter). Check in the Azure portal whether it is applied.
- Port 22 on the VIP goes to a random database host.
- The VMSS uses `upgrade_policy: Automatic`: changes to the VMSS model are applied to all instances at once.
