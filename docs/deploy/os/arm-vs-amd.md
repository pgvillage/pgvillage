---
title: ARM vs AMD
summary: Running PgVillage on ARM64 (aarch64) or AMD64 (x86_64), and what differs per OS and platform
authors:
  - Sebas Mannem
date: 2026-11-01
---

# ARM vs AMD

PgVillage runs on AMD64 (x86_64) and on ARM64 (aarch64), with the same inventories: nothing in `inventories/standard`
or the OS layers depends on the architecture. The roles pick the packages and repositories for the architecture of
each host (the Debian names `amd64` and `arm64` for apt, `x86_64` and `aarch64` for dnf and zypper).

## Per OS

| OS | AMD64 | ARM64 |
|----|-------|-------|
| [Debian (including Ubuntu)](debian.md) | yes | yes |
| [EL](el.md) (Rocky Linux, RHEL 9) | yes | yes |
| [SUSE](suse.md) | yes | not out of the box: download.postgresql.org has no PostgreSQL builds for SUSE on ARM64, see [SUSE](suse.md) |

The PgVillage repositories (stolon, wal-g, etcd, RustFS, chainsmith, ...) have builds for both architectures. The
packages of PostgreSQL itself come from download.postgresql.org (EL, SUSE) or the Ubuntu repositories.

We test with all hosts of an environment on the same architecture.

## Per platform

- **Your own machines**: no changes; use the OS layer of your hosts. See [Getting started](../../index.md).
- **Azure**: ARM64 needs other VM sizes and an ARM64 image. See [Azure - AMD vs ARM](../platforms/azure/amd-vs-arm.md).
- **Vagrant on Apple silicon**: the boxes are ARM64 (build them on the Mac, see
  [Creating the boxes](../../try-it/vagrant/boxes.md)). See also [OpenSSL on VirtualBox](#openssl-on-virtualbox) below.
- **Lima on Apple silicon**: the VMs are ARM64, from the cloud images of the distributions; no changes needed. See
  [Lima](../../try-it/lima.md).

## OpenSSL on VirtualBox

On Apple silicon, VirtualBox reports CPU features to some guest kernels (EL9) that the CPU can't run (SVE2). OpenSSL
then uses them, and processes crash with `Illegal instruction`. With Ansible, it is the OpenSSL in the `cryptography`
wheel, e.g. in the dnf module on the Ansible host.

The fix is to tell OpenSSL not to use the CPU's crypto extensions:

```bash
export OPENSSL_armcap=0
```

The vagrant `bootstrap.sh` sets it in `~/.bashrc` of the Ansible host, and keeps it for `sudo` (a file in
`/etc/sudoers.d`), so become tasks have it too. Set it yourself when you run `ansible-playbook` from a shell that
doesn't read `~/.bashrc`.
