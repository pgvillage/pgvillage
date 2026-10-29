# Lima

Running a demo environment of PgVillage on your laptop with Lima.

The deployment uses three inventories, in this order, so later values win:

- `inventories/standard`: the standard PgVillage config, multi-instance (`cluster1` and `cluster2`).
- `inventories/el`: Enterprise Linux specifics (the vm's run EL), see [Enterprise Linux](el/index.md).
- `inventories/lima`: the hosts, the network interface (`eth1`) and certificates in `/etc/pki/postgres`.

## Getting started

1. Get a machine (e.a. laptop) with Ubuntu
2. Setup KVM, create machines, etc. ([See here](./steps.md))
3. Make sure all [preps](./preps.md) are ready
4. Log in to ansible host and deploy:
   ```bash
   cd ~/git/pgvillage/
   ansible-playbook -i inventories/standard -i inventories/el -i inventories/lima functional-all.yml
   ```
5. Be amazed

!!! warning
    Lima has not worked yet. The inventory now listens on `eth1` (the shared network) instead of the NAT interface,
    but a full deployment has not been tested.
