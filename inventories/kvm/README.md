# kvm

Everything specific to the kvm vm's: the hosts (`hosts`), the network interface (`eth0`) and certificates in
`/etc/pki/postgres`. The vm's run Enterprise Linux, so use it on top of `inventories/standard` and `inventories/el`:

```bash
ansible-playbook -i inventories/standard -i inventories/el -i inventories/kvm functional-all.yml
```

See the [kvm docs](../../docs/administrators-guide/platforms/kvm.md).
