# debian

Debian specifics (including Ubuntu) on top of `inventories/standard` (which is for Enterprise Linux): package names, apt repositories,
system users and groups, paths, and the uninstall package list. It has no hosts; use it between standard and a platform
inventory:

```bash
ansible-playbook -i inventories/standard -i inventories/os/debian -i inventories/platform/vagrant functional-all.yml
```

See the [Debian (including Ubuntu) docs](../../../docs/deploy/os/debian.md).
