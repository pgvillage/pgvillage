# Ansible Role: pgroute66

Installs pgroute66  on RedHat.

## Requirements

None.

## Role Variables

pgroute66_deploydir: /opt/pgroute66
pgroute66_configdir: /etc/pgroute66
pgroute66_osuser: pgroute66
pgroute66_osgroup: pgroute66
pgroute66_pguser: pgroute66


## Dependencies

None.

## Example Playbook

    - hosts: balancer
      sudo: yes
      roles:
        - { role: pgroute66 }
