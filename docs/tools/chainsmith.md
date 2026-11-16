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

The parent inventory group `chainsmith` contains two child groups:

| Group | Responsibility |
|-------|----------------|
| `chainsmith_controller` | Exactly one host that generates the certificate chain. |
| `chainsmith_nodes` | One or more hosts that receive certificates and are checked for expiry. |

`functional-all.yml` selects `chainsmith` to run the role on both child groups together.
`inventories/standard/hosts` and the OS layers declare the group structure without selecting hosts. Each platform
inventory explicitly selects `localhost` as the controller and lists the recipient groups: `hacluster` and `backup`
for Vagrant and Lima, and `hacluster` for Azure. The controller can have any inventory name and can
be reached locally or over SSH. `localhosts` remains a separate management-host group; it does not select the
Chainsmith controller.

A controller can also receive certificates. For example, on top of the standard inventory:

```yaml
all:
  children:
    localhosts:
      hosts:
        node-01:
          ansible_connection: local
          ansible_python_interpreter: "{{ ansible_playbook_python }}"
    chainsmith:
      children:
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

Here `node-01` performs generation and receives certificates; `node-02` and `node-03` receive certificates through
`hacluster`. Use the same inventory hostname for a machine in every group. Configure the certificate paths,
owners and `chainsmith_users` for the services on each recipient; the users must already exist. A standalone
router or another service host that needs certificates can be added to `chainsmith_nodes` in the same way.
Membership in this group does not configure a service to use the certificates; for example, etcd TLS has its own
configuration.

## What runs where

The `linux` step installs the Chainsmith package on `chainsmith_controller` and OpenSSL on `chainsmith_nodes`.
It runs on both groups so repositories, packages and configured service users are ready before the Chainsmith step.
The standard inventory sets `chainsmith_package_names: []` because the linux step handles package installation.

On the controller, the Chainsmith role creates a temporary output directory. On every recipient it reads the OS
users, writes a list of expected certificate files, and checks whether certificates are missing or expire within
`chainsmith_expiry_days` (30 days by default).

If any recipient needs replacement, the controller creates a temporary configuration and runs `chainsmith issue`
to generate a complete CA chain, server certificates, client certificates and private keys. Each recipient then
writes its configured certificates and keys with the configured ownership. A controller that is also a recipient
performs both sets of tasks. The controller removes its temporary configuration and output directory afterwards,
also when generation or deployment fails.

Replacement regenerates and redeploys the complete chain to all recipients. The role itself does not reload the
services that use the certificates.

## Running Chainsmith

Use the normal deployment playbook, or select the certificate tasks:

```bash
ansible-playbook -i inventories/standard -i inventories/os/el -i inventories/mycluster functional-all.yml --tags chainsmith
```

The Chainsmith step selects `chainsmith`, including `chainsmith_controller` and `chainsmith_nodes`. Both child
groups must be in the same play batch, also with `--limit` or `serial`. Keep the default `linear` execution strategy so all certificate
checks finish before generation and deployment. When packages or users still need preparation, run the full
playbook or include `--tags linux,chainsmith`.

## Migrating an existing inventory

`requirements.yml` temporarily selects `fix/chainsmith-localhost-dependency` from the Chainsmith role's Git
repository; the previous `v0.3.0` pin does not support these groups. The updated role must be available on that
branch before installing it on another control node. Replace the branch with a released version when available.

1. Define `chainsmith` with `chainsmith_controller` and `chainsmith_nodes` as child groups, as in the example
   above. Select exactly one controller host.
2. Explicitly add recipients to `chainsmith_nodes` in your platform inventory, directly or through child groups
   such as `hacluster` and `backup`. Add the controller too if it runs a service that needs certificates.
3. Remove overrides of `chainsmith_controller_host` and `chainsmith_nodes` that select hosts through `localhosts`,
   `hacluster` or `backup`. The role now derives them from the explicit groups.
4. If you override `pgvillage_roles.chainsmith.groups`, select the parent group: `groups: [chainsmith]`.
   Custom `linux_packages` mappings must install `chainsmith` on the controller and `openssl` on the recipients.
5. Remove any `chainsmith_cert_files: []` workaround from controller host variables. The controller is checked only
   when it belongs to `chainsmith_nodes`.

See [Roles in functional-all.yml](../reference/steps.md) for step overrides and
[Inventory explained](../deploy/inventory/index.md) for inventory layering.
