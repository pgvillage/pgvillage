---
- name: "Run the playbook"
  hosts:
    - all
  vars_prompt:
    - name: sure
      prompt: "This will remove postgres and all backups. Are you really sure? Type 'yes' in uppercase if you are..."
      private: no
  become: true
  tasks:
    - name: "Are you sure?"
      assert:
        that:
          - "sure == 'YES'"
    - name: "Run uninstall"
      script: uninstall.sh