---
title: Chainsmith
summary: A description of the tool for generating certificate chains as used for mTLS in PgVillage
authors:
  - Sebas Mannem
  - Snehal Kapure
date: 2025-11-11
---

# Chainsmith

Chainsmith is a community tool that can be configured with a simple YAML file to generate certificate chains.

For more information, please refer to:

- [mTLS](../architecture/mtls.md)
- Community repository: [https://github.com/pgvillage-tools/chainsmith](https://github.com/pgvillage-tools/chainsmith)

---

## Inventory groups

Two optional inventory groups select where chainsmith runs:

| Group | Default when the group isn't defined | Responsibility |
|-------|--------------------------------------|----------------|
| `chainsmith_controller` | the first host in `localhosts` | Exactly one host that generates the certificate chain. |
| `chainsmith_nodes` | the hosts in `hacluster` and `backup` | The hosts that receive certificates and are checked for expiry. |

Existing inventories keep working without them. The platform inventories in `inventories/platform` define them
explicitly: `localhost` as the controller, and `hacluster` and `backup` (Azure: `hacluster`) as recipients. When you
define a group, it must not be empty, so `inventories/standard` and the OS layers don't define them.

The controller can have any inventory name, be reached locally or over SSH, and can also receive certificates:

```yaml
all:
  children:
    localhosts:
      hosts:
        node-01:
          ansible_connection: local
          ansible_python_interpreter: "{{ ansible_playbook_python }}"
    chainsmith_controller:
      hosts:
        node-01:
    chainsmith_nodes:
      hosts:
        node-01:
      children:
        hacluster:
    hacluster:
      hosts:
        node-02:
        node-03:
```

Here `node-01` generates the chain and receives certificates; `node-02` and `node-03` receive certificates through
`hacluster`. Use the same inventory hostname for a machine in every group. Membership in `chainsmith_nodes` does not
configure a service to use the certificates (e.g. etcd TLS has its own configuration).

The `linux` step installs the chainsmith package on `localhosts` (the default `linux_packages` of the pgvillage.linux
role). A controller outside `localhosts` needs the package too: add it to `linux_packages` for that host's group.

## What runs where

On every recipient the role checks whether certificates are missing or expire within `chainsmith_expiry_days`
(30 days by default). If any recipient needs a new one, the controller runs `chainsmith issue`, which generates a
complete new chain (CA, server and client certificates, private keys), and every recipient gets its certificates and
keys. The controller removes its temporary configuration and output afterwards, also when that fails. The role doesn't
reload the services; the step `reload_new_certs` of `functional-all.yml` does.

## Running Chainsmith

Use the normal deployment playbook, or only the certificate step:

```bash
ansible-playbook -i inventories/standard -i inventories/os/el -i inventories/mycluster functional-all.yml --tags chainsmith
```

A new chain must reach all recipients at once, so the role only does its work when the controller and all recipients
are in the play. With `--limit` or `serial` that leaves some out, it skips with a warning and leaves the existing
certificates alone; run it again on all hosts to renew them.
