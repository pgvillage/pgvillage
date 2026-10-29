# lima

Everything specific to the lima vm's (eth0 is the NAT network): the hosts (`hosts`), the network interface (`eth1`) and certificates in
`/etc/pki/postgres`. The vm's run Enterprise Linux, so use it on top of `inventories/standard` and `inventories/el`:

```bash
ansible-playbook -i inventories/standard -i inventories/el -i inventories/lima functional-all.yml
```

See the [lima docs](../../docs/administrators-guide/platforms/lima.md).
