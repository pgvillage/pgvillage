---
title: Azure - EL vs SUSE
summary: Changes to the azure inventory to deploy on openSUSE Leap instead of Enterprise Linux
authors:
  - Sebas Mannem
date: 2026-10-29
---

# Azure - EL vs SUSE

The azure inventory deploys Rocky Linux EL-9, with the EL layer (`inventories/el`). To deploy on openSUSE Leap
(x86_64), use the SUSE layer (`inventories/suse`) instead, and change the image:

```bash
ansible-playbook -i inventories/standard -i inventories/suse -i inventories/azure functional-all.yml
scripts/create_new_cluster.sh azure suse
```

The packages, paths and uninstall lists for SUSE are in `inventories/suse`, see [SUSE](../suse/index.md).

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

`scripts/az_to_env` accepts the image terms (run it again after changing the image).

## Summary

| What                                     | EL (default)                          | openSUSE Leap                                   |
|------------------------------------------|---------------------------------------|-------------------------------------------------|
| OS layer                                 | `-i inventories/el`                   | `-i inventories/suse`                           |
| `azure.yml` in `inventories/azure`       | role default image (Rocky EL-9)       | `susellc:opensuse-leap-x86-64:gen2`, with plan; bastion uses the same |
