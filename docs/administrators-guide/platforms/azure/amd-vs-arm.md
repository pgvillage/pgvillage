---
title: Azure - AMD vs ARM
summary: Changes to the azure inventory to deploy on ARM64 instead of AMD64
authors:
  - Sebas Mannem
date: 2026-10-29
---

# Azure - AMD vs ARM

`inventories/azure` deploys on AMD64 (x86_64). To deploy on ARM64, change the VM sizes and the image.

## VM sizes

ARM64 needs ARM VM sizes (the `p` in `D2pls_v5`). Add them to `group_vars/all/azure.yml`:

```yaml
# For arm64 we need other vm sizes and images
azure_bastion_vm_size: Standard_D2pls_v5
azure_vmss_vm_size: Standard_D2pls_v5
```

## Image

Add an arm64 image to `group_vars/all/azure.yml`. This example uses RHEL 8.6 for arm64, which needs no plan:

```yaml
#Arm64           rhel-arm64                              RedHat                                    8_6-arm64                                        RedHat:rhel-arm64:8_6-arm64:8.6.2022060901                                                                  8.6.2022060901
azure_vmss_image:
  offer: rhel-arm64
  publisher: RedHat
  sku: 8_6-arm64
  version: 8.6.2022060901

azure_bastion_plan: {}
azure_vmss_plan: null
```

!!! note
    This image is old (2022) and EL-8. For Rocky Linux EL-9 on arm64, look up the current image with
    `az vm image list --publisher resf --offer rockylinux-aarch64 --all --output table` and set
    `azure_vmss_image` and `azure_vmss_plan` as described in [Using other images](index.md#using-other-images).

## Summary

| File                           | AMD64 (default)          | ARM64                                                |
|--------------------------------|--------------------------|------------------------------------------------------|
| `group_vars/all/azure.yml`     | role default VM size and image | `Standard_D2pls_v5` for bastion and VMSS, arm64 image, no plan |
