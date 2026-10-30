---
title: Vagrant - creating the boxes
summary: Creating the Ubuntu, Rocky Linux and openSUSE vagrant boxes with the VirtualBox guest additions
authors:
  - Sebas Mannem
date: 2026-10-30
---

# Vagrant - creating the boxes

The `Vagrantfile` uses local boxes: `nibble/ubuntu-26.04`, `nibble/rocky-9` and `nibble/suse-16` (see
[Other operating systems](index.md#other-operating-systems)). They are public boxes with the VirtualBox guest
additions added, which the shared folders need. You create them once, and only the one for the OS you use.

The steps work on amd64 and on aarch64 (Apple silicon). The only difference is the guest additions installer:
`VBoxLinuxAdditions-arm64.run` on aarch64, `VBoxLinuxAdditions.run` on amd64.

All boxes start the same way:

1. Go to a new folder: `cd $(mktemp -d)`.
2. Create a vagrant VM from the public box (see below) with `vagrant init <box>`, start it with `vagrant up` and log in
   with `vagrant ssh`.

And end the same way:

1. (optionally) Add your modifications to `/etc/motd`.
2. Clear the history: `history -c && history -w`.
3. Stop the VM: `vagrant halt`.
4. Package the box: `vagrant package --output <name>.box`.
5. Add the box to the local registry: `vagrant box add <name>.box --name <box name>`.

## Ubuntu box

Based on `cloud-image/ubuntu-26.04`, box version `20260421.0.0`.

1. `vagrant init cloud-image/ubuntu-26.04 --box-version 20260421.0.0`, `vagrant up` and `vagrant ssh`.
2. Update the packages:
   ```bash
   sudo apt-get update && sudo apt-get upgrade -y
   ```
3. Stop the VM: `vagrant halt`.
4. In VirtualBox (the GUI) go to the VM, Settings, Storage, click the CD-ROM with the +, select
   `VBoxGuestAdditions.iso`, click Choose and click OK.
5. Start the VM and log in again: `vagrant up` and `vagrant ssh`.
6. Install the guest additions:
   ```bash
   sudo mount /dev/cdrom /mnt/
   cd /mnt/ && sudo ./VBoxLinuxAdditions-arm64.run   # VBoxLinuxAdditions.run on amd64
   ```
7. Restart the VM so VirtualBox finishes setting up the guest additions: `vagrant reload`.
8. Finish as above, with `vagrant package --output nibble-ubuntu.box` and
   `vagrant box add nibble-ubuntu.box --name nibble/ubuntu-26.04`.

## Rocky Linux box

Based on `bento/rockylinux-9`.

1. `vagrant init bento/rockylinux-9`, `vagrant up` and `vagrant ssh`.
2. Update the packages and install what the guest additions need to build:
   ```bash
   sudo dnf update -y
   sudo dnf install epel-release -y
   sudo dnf install dkms gcc make kernel-devel bzip2 binutils patch libgomp glibc-headers glibc-devel -y
   ```
3. Stop the VM, add `VBoxGuestAdditions.iso` and install the guest additions, as in steps 3 to 7 of the
   [Ubuntu box](#ubuntu-box).
4. Finish as above, with `vagrant package --output nibble-rocky-9.box` and
   `vagrant box add nibble-rocky-9.box --name nibble/rocky-9`.

## openSUSE box

Based on `bento/opensuse-leap-16.0`.

!!! note
    The PostgreSQL community has no aarch64 packages for SUSE.

1. `vagrant init bento/opensuse-leap-16.0`, `vagrant up` and `vagrant ssh`.
2. Update the packages: `sudo zypper update -y`.
3. Stop the VM: `vagrant halt`.
4. In VirtualBox (the GUI) add `VBoxGuestAdditions.iso` to the VM, as in step 4 of the [Ubuntu box](#ubuntu-box).
5. Start the VM and log in again: `vagrant up` and `vagrant ssh`. It installs the guest additions by itself (and
   probably finishes updating packages).
6. Install what the guest additions need, and avahi:
   ```bash
   sudo zypper install -y gcc make dkms kernel-default-devel patch binutils avahi
   sudo systemctl enable --now avahi-daemon
   ```
7. Give root sudo permissions:
   ```bash
   sudo bash -c 'echo "root ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers'
   ```
8. Finish as above, with `vagrant package --output nibble-suse-16.box` and
   `vagrant box add nibble-suse-16.box --name nibble/suse-16`.

## Other boxes

Any box with the VirtualBox guest additions works. Use its name with `PGV_BOX`, together with the `PGV_OS` that
matches its OS:

```bash
PGV_OS=el PGV_BOX=my/almalinux-9 vagrant up
```
