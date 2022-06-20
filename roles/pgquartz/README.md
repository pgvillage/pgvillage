# Ansible Role: pgquartz

Installs pgquartz on RedHat.

## Requirements

None.

## Role Variables

pgquartz_configdir: /etc/pgquartz
pgquartz_osuser: pgquartz
pgquartz_osgroup: pgquartz
pgquartz_pguser: pgquartz

## Dependencies

None.

## Example Playbook

    - hosts: balancer
      sudo: yes
      roles:
        - { role: pgquartz }
