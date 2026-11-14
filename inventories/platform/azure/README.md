# azure

Everything specific to Azure: the dynamic inventory (`azure_rm.yml`), the settings for the azure role (`azure.yml`),
and overrides of the standard config for the Load Balancer VIP (`generic.yml`, `chainsmith.yml`) and backups to Azure
Storage (`wal-g.yml`). Use it on top of `inventories/standard`:

```bash
ansible-playbook -i inventories/standard -i inventories/os/el -i inventories/platform/azure functional-all.yml
```

It deploys Rocky Linux EL-9 on AMD64, with a VMSS of 3 database hosts, a bastion host, a Load Balancer VIP and backups
to an Azure Storage container.

See the [Azure docs](../../../docs/deploy/platforms/azure/index.md) for how to use it,
[Azure integration](../../../docs/deploy/platforms/azure/azure.md) for all `azure_` parameters, and the
changes to deploy on [openSUSE](../../../docs/deploy/platforms/azure/el-vs-suse.md) or
[ARM64](../../../docs/deploy/platforms/azure/amd-vs-arm.md).
