# lima

Everything specific to the lima VMs of `lima/up.sh`: the hosts (`hosts`, by their names on the user-v2 network) and the
VIP with unicast VRRP (`group_vars/all/keepalived.yml`). Use it on top of `inventories/standard` and the OS of the VMs
(Ubuntu by default):

```bash
ansible-playbook -i inventories/standard -i inventories/ubuntu -i inventories/lima functional-all.yml
```

See the [lima docs](../../docs/administrators-guide/platforms/lima.md).
