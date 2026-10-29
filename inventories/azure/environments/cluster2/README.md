# cluster1

In this setup, we deploy PgVillage on Azure, which means that:
- Ansible uses Azure modules to create Azure resources, such as VM's, buckets and loadbalancers
- The inventory uses the azure_rm plugin to autodetect al VM's and automatically add them to the repository
- We create a seperate resource group
- We create a Storage Account with a bucket
- We create a seperate network, with a subnet and a Loadbalancer which will route all traffic on a VIP to the database nodes
- We create a bastion host (to proxy ssh traffic for Ansible to the database hosts)
- We create a Virtual Machine Scaleset with 3 database hosts

After creating the Azure resources, Ansible will udd the hosts to ~/.ssh/config, and configure the data and wal disk mountpoints.
Once finished the normal [PgVillage](https://github.com/pgvillage/pgvillage) deployment will be executed to deploy PostgreSQL, stolon and all other components on the VMSS hosts.

  - Each host will have etcd, stolon-sentinel, stolon-keeper, stolon-proxy, PgBouncer, and PostgreSQL
  - One will be a primary database serer, the others will be standby's
  - PostgreSQL is configured to store it's backup's on the storage bucket

After deployment, both the Ansible host, and the bastion host can be stopped (and if needed removed).

This deployment is based on Rocky Linux EL-9 on ARM.
