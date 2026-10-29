# el

Enterprise Linux (e.g. Rocky Linux, RHEL) specifics on top of `inventories/standard`: the PostgreSQL (PGDG rpm) paths
and the uninstall lists. Packages, repositories, users and groups come from the `pgvillage.linux` role, which picks
them for dnf. It has no hosts; use it between standard and a platform inventory:

```bash
ansible-playbook -i inventories/standard -i inventories/el -i inventories/azure functional-all.yml
```

See the [OS docs](../../docs/administrators-guide/platforms/el/index.md).
