# suse

openSUSE / SUSE specifics on top of `inventories/standard`: the package list (without `plpython3`, which is not
available for openSUSE), the PostgreSQL (PGDG rpm) paths and the uninstall lists. Repositories, users and groups come
from the `pgvillage.linux` role, which picks them for zypper. It has no hosts; use it between standard and a platform
inventory:

```bash
ansible-playbook -i inventories/standard -i inventories/os/suse -i inventories/platform/azure functional-all.yml
```

Out of the box, SUSE runs on x86_64 only: PGDG has no PostgreSQL builds for SUSE on ARM64, so on ARM64 you need
PostgreSQL packages from another source (see the docs).

See the [SUSE docs](../../../docs/administrators-guide/platforms/suse/index.md).
