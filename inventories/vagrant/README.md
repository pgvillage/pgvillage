# vagrant

Everything specific to the vagrant demo environment: the boxes (`hosts`), the private network (its interface is
looked up in the facts), certificates in `/etc/pki`, and the router (HAProxy, keepalived, pgroute66). The boxes and
scripts are in `vagrant/`. Use it on top of `inventories/standard` and the OS inventory of the boxes (ubuntu by
default, or el or suse):

```bash
ansible-playbook -i inventories/standard -i inventories/ubuntu -i inventories/vagrant functional-all.yml
```

See the [Vagrant docs](../../docs/administrators-guide/platforms/vagrant/index.md), and
[the vagrant inventory](../../docs/administrators-guide/platforms/vagrant/inventory.md) for what it changes and why.
