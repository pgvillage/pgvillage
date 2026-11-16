# lima

Everything specific to the lima VMs of `lima/up.sh`: the hosts (`hosts`, by their names on the user-v2 network) and the
VIP with unicast VRRP (`group_vars/all/keepalived.yml`). Use it on top of `inventories/standard` and the OS of the VMs
(Ubuntu by default):

```bash
ansible-playbook -i inventories/standard -i inventories/os/debian -i inventories/platform/lima functional-all.yml
```

See the [lima docs](../../../docs/try-it/lima.md).

Under the parent `chainsmith` group, this inventory explicitly selects `localhost` in `chainsmith_controller`
and `hacluster` and `backup` as children of `chainsmith_nodes`; see [Chainsmith](../../../docs/tools/chainsmith.md).
