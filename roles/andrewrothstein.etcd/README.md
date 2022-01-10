andrewrothstein.etcd
====================
[![Build Status](https://travis-ci.org/andrewrothstein/ansible-etcd.svg?branch=master)](https://travis-ci.org/andrewrothstein/ansible-etcd)

Role installs [etcd](https://github.com/coreos/etcd)

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
	- andrewrothstein.etcd
```

License
-------

MIT

Author Information
------------------

Andrew Rothstein <andrew.rothstein@gmail.com>
