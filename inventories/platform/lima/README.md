# lima

Everything specific to the lima VMs of `lima/up.sh`: the hosts (`hosts`, by their names on the user-v2 network) and the
VIP with unicast VRRP (`group_vars/all/keepalived.yml`), and fixed S3 keys for the backup host (`group_vars/all/minio.yml`,
demo only). Use it on top of `inventories/standard` and the OS of the VMs
(Ubuntu by default):

```bash
ansible-playbook -i inventories/standard -i inventories/os/debian -i inventories/platform/lima functional-all.yml
```

See the [lima docs](../../../docs/try-it/lima.md).

This inventory selects the chainsmith hosts explicitly (optional, the same as the defaults): `localhost` in `chainsmith_controller`
and `hacluster` and `backup` as children of `chainsmith_nodes`; see [Chainsmith](../../../docs/tools/chainsmith.md).
