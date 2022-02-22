---
- name: "Gather facts on all servers"
  hosts:
    - all
  become: true
  tasks:
    - name: "Run uninstall"
      script: uninstall.sh
