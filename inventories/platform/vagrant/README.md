# vagrant

Everything specific to the vagrant demo environment: the boxes (`hosts`), the private network (its interface is
looked up in the facts), certificates in `/etc/pki`, and the router (HAProxy, keepalived, pgroute66). The boxes and
scripts are in `vagrant/`. Use it on top of `inventories/standard` and the OS inventory of the boxes (ubuntu by
default, or el or suse):

```bash
ansible-playbook -i inventories/standard -i inventories/os/debian -i inventories/platform/vagrant functional-all.yml
```

See the [Vagrant docs](../../../docs/try-it/vagrant/index.md), and
[the vagrant inventory](../../../docs/deploy/inventory/vagrant-example.md) for what it changes and why.
