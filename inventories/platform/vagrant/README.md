# vagrant

Everything specific to the vagrant demo environment: the boxes (`hosts`), the private network (its interface is
looked up in the facts), certificates in `/etc/pki`, the router (HAProxy, keepalived, pgroute66), and fixed S3 keys for the backup host
(`group_vars/all/minio.yml`, demo only). The boxes and
scripts are in `platforms/vagrant/`. Use it on top of `inventories/standard` and the OS inventory of the boxes
(ubuntu by default, or el or suse):

```bash
ansible-playbook -i inventories/standard -i inventories/os/debian -i inventories/platform/vagrant functional-all.yml
```

See the [Vagrant docs](../../../docs/try-it/vagrant/index.md), and
[the vagrant inventory](../../../docs/deploy/inventory/vagrant-example.md) for what it changes and why.

This inventory selects the chainsmith hosts explicitly (optional, the same as the defaults): `localhost` in `chainsmith_controller`
and `hacluster` and `backup` as children of `chainsmith_nodes`; see [Chainsmith](../../../docs/tools/chainsmith.md).
