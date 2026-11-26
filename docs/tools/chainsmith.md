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

The two groups are independent: define one or both, at the top level of the inventory. The controller can be any host
that Ansible reaches, and can also receive certificates. For example, a database host as the controller:

```yaml
all:
  children:
    chainsmith_controller:
      hosts:
        node-01:
    hacluster:
      hosts:
        node-01:
        node-02:
        node-03:
```

Here `node-01` generates the chain. Without `chainsmith_nodes`, the recipients are `hacluster` and `backup`, so
`node-01` receives certificates too. Use the same inventory hostname for a machine in every group. Membership in
`chainsmith_nodes` does not configure a service to use the certificates (e.g. etcd TLS has its own configuration).

The controller needs the chainsmith package. The `linux` step installs it on `localhosts` (`linux_packages`); for
another controller, let the chainsmith role install it, in the controller's `host_vars`
(`inventories/standard` sets `chainsmith_package_names: []`):

```yaml
# host_vars/node-01/chainsmith.yml
chainsmith_package_names:
  - chainsmith
```

The role installs it from the PgVillage repository, which the `linux` step sets up on all PgVillage hosts.

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
