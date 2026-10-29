---
title: Azure - EL vs SUSE
summary: Changes to the azure inventory to deploy on openSUSE Leap instead of Enterprise Linux
authors:
  - Sebas Mannem
date: 2026-10-29
---

# Azure - EL vs SUSE

The azure inventory deploys Rocky Linux EL-9. To deploy on openSUSE Leap (x86_64), change the image and the packages.

The packages and paths are standard config, in `inventories/standard`. Don't change them there (other platforms
use them too): override them with a file of the same name in `inventories/azure/group_vars/all/`.

!!! note
    There are fewer SUSE builds on download.postgresql.org (at the time of writing only leap-16 on x86_64 for
    openSUSE, and sles15/16 on x86_64 for SUSE). We only build rpm's for leap/16 on x86_64. If you need other
    architectures or specific SUSE builds, please reach out to us.

## Image

Add the openSUSE image to `inventories/azure/group_vars/all/azure.yml`. The image is a marketplace image, so it needs a plan, and the
bastion uses the same image and plan as the VMSS:

```yaml
# x64             opensuse-leap-x86-64      susellc      gen2   susellc:opensuse-leap-x86-64:gen2:2026.04.01   2026.04.01
azure_bastion_image: "{{ azure_vmss_image }}"
azure_bastion_plan: "{{ azure_vmss_plan }}"

azure_vmss_image:
  offer: opensuse-leap-x86-64
  publisher: susellc
  sku: gen2
  version: 2026.04.01

azure_vmss_plan:
  name: gen2
  publisher: susellc
  product: opensuse-leap-x86-64
```

Accept the image terms first:

```bash
az vm image terms accept --urn susellc:opensuse-leap-x86-64:gen2:2026.04.01
```

## Packages

openSUSE has no `langpacks-en`, `glibc-all-langpacks` or `postgresqlNN-plpython3` packages. Override
`linux_packages` without them in `inventories/azure/group_vars/all/packages.yml`:

```yaml
linux_packages:
  hacluster:
    - "postgresql{{ linux_pg_version|replace('.','') }}"
    - "postgresql{{ linux_pg_version|replace('.','') }}-server"
    - "postgresql{{ linux_pg_version|replace('.','') }}-contrib"
    - 'stolon'
    - 'wal-g-pg'
    - 'etcd'
    - python3-psycopg2
  localhosts:
    - chainsmith
```

Also override `uninstall_linux_packages` without `postgresqlNN-plpython3` in
`inventories/azure/group_vars/all/uninstall.yml`.

## Paths

`postgresql_bindir` in `inventories/standard/group_vars/all/postgres.yml` is `/usr/pgsql-NN/bin/`, the path used by the PGDG rpm's (both
EL and SUSE). If you use the openSUSE packages instead, override it with `/usr/lib/postgresqlNN/bin` in
`inventories/azure/group_vars/all/postgres.yml`, and override `uninstall_file_list` with the `/usr/pgsql-NN` and
`/var/lib/pgsql-NN` entries changed accordingly.

## Summary

| File (in `inventories/azure/group_vars/all/`) | EL (default)           | openSUSE Leap                                   |
|--------------------------------|---------------------------------------|-------------------------------------------------|
| `azure.yml`                    | role default image (Rocky EL-9)       | `susellc:opensuse-leap-x86-64:gen2`, with plan; bastion uses the same |
| `packages.yml`                 | standard: incl. langpacks and plpython3 | without langpacks and plpython3                 |
| `uninstall.yml`                | standard: incl. plpython3             | without plpython3                               |
| `postgres.yml`                 | standard: `/usr/pgsql-NN/bin/`        | same for PGDG rpm's; `/usr/lib/postgresqlNN/bin` for openSUSE packages |
