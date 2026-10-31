---
title: Ansible config
summary: Settings for running Ansible against your hosts, such as the user to log in with
authors:
  - Sebas Mannem
date: 2026-10-31
---

# Ansible config

Settings that are not PgVillage config, but tell Ansible how to reach your hosts. `ansible.cfg` in the root of this
repository is used when you run `ansible-playbook` from there.

## The user on the hosts

By default Ansible logs in to the hosts with the name of the user running `ansible-playbook`. If the user on the
hosts is different, set it in one of these places:

- In `ansible.cfg`, for every inventory:
  ```ini
  [defaults]
  remote_user = pgvillage
  ```
- In the `hosts` of your platform inventory, for all its hosts (as `inventories/vagrant` does with `vagrant`):
  ```yaml
  all:
    vars:
      ansible_user: pgvillage
  ```
- On the command line: `ansible-playbook -u pgvillage ...`.

`ansible_user` in the inventory wins over `remote_user` in `ansible.cfg`. The user needs ssh access with a key, and
sudo without a password (or use `--ask-become-pass`).
