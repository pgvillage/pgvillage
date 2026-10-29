# ubuntu

Ubuntu specifics on top of `inventories/standard` (which is for Enterprise Linux): package names, apt repositories,
system users and groups, paths, and the uninstall package list. It has no hosts; use it between standard and a platform
inventory:

```bash
ansible-playbook -i inventories/standard -i inventories/ubuntu -i inventories/vagrant functional-all.yml
```

See the [Ubuntu docs](../../docs/administrators-guide/platforms/ubuntu/index.md).
