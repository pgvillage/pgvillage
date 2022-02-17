etcd-package
====================

Role installs packages for [etcd](https://github.com/coreos/etcd)

Requirements
------------

See [meta/main.yml](meta/main.yml)

Role Variables
--------------

See [defaults/main.yml](defaults/main.yml)

Dependencies
------------

See [meta/main.yml](meta/main.yml)

Example Playbook
----------------

```yml
- hosts: servers
  roles:
	- etcd-install
```

License
-------

MIT

Author Information
------------------

Sebastiaan Mannem <sebastiaan.mannem@rivm.nl>
