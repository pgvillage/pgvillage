# vagrant

Everything specific to the vagrant demo environment: the boxes (`hosts`), the private network (`enp0s9`), Ubuntu
packages and paths, certificates in `/etc/pki`, and the router (HAProxy, keepalived, pgroute66). Use it on top of
`inventories/standard`:

```bash
ansible-playbook -i inventories/standard -i inventories/vagrant functional-all.yml
```

See the [Vagrant docs](../../docs/administrators-guide/platforms/vagrant/index.md), and
[the vagrant inventory](../../docs/administrators-guide/platforms/vagrant/inventory.md) for what it changes and why.
