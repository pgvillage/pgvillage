# standard

Standard PgVillage config, shared by all platforms: Postgres version, mountpoints, ports, packages, and the config of
stolon, wal-g, avchecker, nagios, etc.

It has no hosts. Use it together with a platform inventory, standard first, so the platform values win:

```bash
ansible-playbook -i inventories/standard -i inventories/azure functional-all.yml
```

To change a value for one platform, add a file with the same name to `inventories/<platform>/group_vars/all/`.
