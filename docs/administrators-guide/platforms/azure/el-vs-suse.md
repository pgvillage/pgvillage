---
title: Azure - EL vs SUSE
summary: Changes to the azure inventory to deploy on openSUSE Leap instead of Enterprise Linux
authors:
  - Sebas Mannem
date: 2026-10-29
---

# Azure - EL vs SUSE

`inventories/azure` deploys Rocky Linux EL-9. To deploy on openSUSE Leap (x86_64), change the image and the packages.

!!! note
    There are fewer SUSE builds on download.postgresql.org (at the time of writing only leap-16 on x86_64 for
    openSUSE, and sles15/16 on x86_64 for SUSE). We only build rpm's for leap/16 on x86_64. If you need other
    architectures or specific SUSE builds, please reach out to us.

## Image

Add the openSUSE image to `group_vars/all/azure.yml`. The image is a marketplace image, so it needs a plan, and the
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

openSUSE has no `langpacks-en`, `glibc-all-langpacks` or `postgresqlNN-plpython3` packages. Remove them from
`group_vars/all/packages.yml`:

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

Also remove `postgresqlNN-plpython3` from `uninstall_linux_packages` in `group_vars/all/uninstall.yml`.

## Paths

`postgresql_bindir` in `group_vars/all/postgres.yml` is `/usr/pgsql-NN/bin/`, the path used by the PGDG rpm's (both
EL and SUSE). If you use the openSUSE packages instead, change it to `/usr/lib/postgresqlNN/bin`, and change the
`/usr/pgsql-NN` and `/var/lib/pgsql-NN` entries in `uninstall_file_list` accordingly.

## Summary

| File                           | EL (default)                          | openSUSE Leap                                   |
|--------------------------------|---------------------------------------|-------------------------------------------------|
| `group_vars/all/azure.yml`     | role default image (Rocky EL-9)       | `susellc:opensuse-leap-x86-64:gen2`, with plan; bastion uses the same |
| `group_vars/all/packages.yml`  | incl. langpacks and plpython3         | without langpacks and plpython3                 |
| `group_vars/all/uninstall.yml` | incl. plpython3                       | without plpython3                               |
| `group_vars/all/postgres.yml`  | `/usr/pgsql-NN/bin/`                  | same for PGDG rpm's; `/usr/lib/postgresqlNN/bin` for openSUSE packages |
