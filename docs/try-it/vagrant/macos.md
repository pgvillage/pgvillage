---
title: macOS
summary: Running a PgVillage demo environment on a Mac with Apple silicon, with Lima or Vagrant
authors:
  - Sebas Mannem
date: 2026-11-01
---

# macOS

On a Mac you run PgVillage in VMs: five of them (an Ansible host, three database hosts and a backup host), on a private
network on your Mac. There are two ways to create them:

|                     | [Lima](../lima.md)                                | [Vagrant](index.md)                         |
|---------------------|------------------------------------------------|-----------------------------------------------------|
| Install             | `brew install lima`                            | VirtualBox and Vagrant                              |
| Images              | The cloud images of the distributions          | Boxes that you build yourself ([Creating the boxes](boxes.md)) |
| Virtualization      | Apple's Virtualization framework (`vz`)        | VirtualBox                                          |
| Network             | DHCP addresses behind names; your Mac can't reach the VMs directly | Static addresses that your Mac can reach |
| AMD64 VMs           | With emulation, but very slow                  | No                                                  |
| Speed (deploy)      | About twice as fast                            |                                                     |

We recommend Lima: it needs less to set up and it is faster. Use Vagrant when you also use it on Linux, or when you need
to reach the VMs from your Mac.

## Requirements

- A Mac with Apple silicon (M1 or newer). The VMs are ARM64 (aarch64); see [ARM vs AMD](../../deploy/os/arm-vs-amd.md).
- About 9 GB of free memory for the five VMs, and 20 GB of disk.
- [Homebrew](https://brew.sh/), or another way to install Lima or VirtualBox and Vagrant.
- Internet access for the VMs (through your Mac), for the packages and Ansible Galaxy.

## What to know

- **openSUSE Leap 16**: PostgreSQL.org has no ARM64 packages for it, so on a Mac you run Ubuntu or EL (Rocky Linux), or
  another distribution that is built for ARM.
- **AMD64**: VirtualBox on Apple silicon only runs ARM64 VMs. Lima can emulate AMD64 VMs, but a deploy takes many
  times longer.
- **OpenSSL on VirtualBox**: on the Rocky Linux boxes, Ansible crashes with `Illegal instruction` unless
  `OPENSSL_armcap=0` is set; the vagrant bootstrap sets it. Lima doesn't have this issue. See
  [OpenSSL on VirtualBox](../../deploy/os/arm-vs-amd.md#openssl-on-virtualbox).
- **Sleep**: after your Mac has slept, the clocks of the VMs are behind. Lima steps them on wake-up (chrony); etcd and
  the certificates need a correct clock.
