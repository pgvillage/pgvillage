# Introduction

Deze documentatie beschrijft hoe evenuele nieuwe features kunnen worden toegevoegd.

# Dependencies

- For expansion of the SBB, consider looking at the community project [PgVillage](https://github.com/pgvillage/pgvillage), where developments are continuing.
- For personal expansions (from Acme), adjustments to the code should be made through Ansible Development.
- For the personal code (from Acme), see: [https://gitlab.int.corp.com/gurus-db-team/ansible-postgres/-/tree/dev/](https://gitlab.int.corp.com/gurus-db-team/ansible-postgres/-/tree/dev/)

# Development

This works through the following steps:

1. Product Ownership

   - Why is the new feature needed
   - How much can it cost in development and operation
   - What is expected of it (availability, Open Source, support options, etc.)

2. Solution Design

   - What solutions are there
   - Which has preference

3. Proof of Concept (POC)

   - Build it in [the POC environment](https://gitlab.int.corp.com/gurus-db-team/ansible-postgres/-/blob/dev/environments/poc/hosts)

4. Automation

   - Ansible role
   - Ansible environment adjustments
   - Roll out where desired

5. Management

   - Documentation
   - Transfer to the management team
   - Availability service

6. Support
   - Investigate support options, support wishes and acquire it
