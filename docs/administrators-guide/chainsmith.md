# Chainsmith

Chainsmith is a community tool that can be configured with a simple YAML file to generate certificate chains.

- Community repository: [https://github.com/pgvillage-tools/chainsmith](https://github.com/pgvillage-tools/chainsmith)

---

## Requirements and Dependencies

Within the PostgreSQL deployment, we use Chainsmith as follows:

- We install chainsmith on the management server (and updates).
- We generate and distribute the certificates.
- When monitoring indicates that the certificates are about to expire, we regenerate and redistribute a new set of certificates.

## Use

The PgVillage chainsmith tole takes care if installation, configuration, running and distributing the certificates.
